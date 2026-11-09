@preconcurrency import AVFoundation
import Foundation
import os
import Speech

/// Encapsula o buffer em tipo Sendable com lock para alimentar o AVAudioConverter de forma concorrente.
private final class SingleBufferProvider: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private let consumed = OSAllocatedUnfairLock(initialState: false)

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func provide(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioPCMBuffer? {
        let isAlreadyConsumed = consumed.withLock { isConsumed -> Bool in
            let previous = isConsumed
            isConsumed = true
            return previous
        }

        if isAlreadyConsumed {
            status.pointee = .noDataNow
            return nil
        } else {
            status.pointee = .haveData
            return buffer
        }
    }
}

final class SpeechAnalyzerTranscriber: SpeechTranscriber, @unchecked Sendable {
    let locale: Locale
    var onError: (@Sendable (STTError) -> Void)?

    init(
        locale: Locale = Locale(identifier: "pt-BR"),
        onError: (@Sendable (STTError) -> Void)? = nil
    ) {
        self.locale = locale
        self.onError = onError
    }

    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { continuation in
            guard #available(iOS 26, *) else {
                onError?(.unavailable)
                continuation.finish()
                return
            }

            let task = Task {
                await self.runTranscription(audio: audio, continuation: continuation)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func transcribeThrowing(_ audio: AsyncStream<AudioBuffer>) throws -> AsyncStream<Transcript> {
        guard #available(iOS 26, *) else {
            throw STTError.unavailable
        }
        return transcribe(audio)
    }

    @available(iOS 26, *)
    private func runTranscription(
        audio: AsyncStream<AudioBuffer>,
        continuation: AsyncStream<Transcript>.Continuation
    ) async {
        do {
            let transcriber = Speech.SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            let analyzer = Speech.SpeechAnalyzer(modules: [transcriber])
            let naturalFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 8000,
                channels: 1,
                interleaved: false
            )
            let targetFormat = await Speech.SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber],
                considering: naturalFormat
            )
            try await analyzer.prepareToAnalyze(in: targetFormat)

            let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
            try await analyzer.start(inputSequence: inputSequence)

            let resultsTask = startResultsCollector(from: transcriber, continuation: continuation)
            try await feedAudio(
                audio,
                to: inputContinuation,
                targetFormat: targetFormat
            )

            inputContinuation.finish()
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            _ = await resultsTask.result
            continuation.finish()
        } catch {
            onError?(.internalError(error.localizedDescription))
            continuation.finish()
        }
    }

    @available(iOS 26, *)
    private func startResultsCollector(
        from transcriber: Speech.SpeechTranscriber,
        continuation: AsyncStream<Transcript>.Continuation
    ) -> Task<Void, Never> {
        Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    continuation.yield(Transcript(text: text, isFinal: result.isFinal))
                }
            } catch {
                self.onError?(.internalError(error.localizedDescription))
            }
        }
    }

    @available(iOS 26, *)
    private func feedAudio(
        _ audio: AsyncStream<AudioBuffer>,
        to inputContinuation: AsyncStream<AnalyzerInput>.Continuation,
        targetFormat: AVAudioFormat?
    ) async throws {
        var cachedConverter: AVAudioConverter?
        var cachedInputFormat: AVAudioFormat?

        for await buffer in audio {
            guard !Task.isCancelled else { break }
            guard !buffer.samples.isEmpty else { continue }

            if let input = try convertToAnalyzerInput(
                buffer: buffer,
                targetFormat: targetFormat,
                cachedConverter: &cachedConverter,
                cachedInputFormat: &cachedInputFormat
            ) {
                inputContinuation.yield(input)
            }
        }
    }

    @available(iOS 26, *)
    private func makePCMBuffer(
        from buffer: AudioBuffer,
        cachedInputFormat: inout AVAudioFormat?
    ) throws -> AVAudioPCMBuffer {
        let inputFormat: AVAudioFormat
        if let cached = cachedInputFormat, cached.sampleRate == buffer.sampleRate {
            inputFormat = cached
        } else {
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: buffer.sampleRate,
                channels: 1,
                interleaved: false
            ) else {
                throw STTError.conversionFailed
            }
            inputFormat = format
            cachedInputFormat = format
        }

        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: AVAudioFrameCount(buffer.samples.count)
        ) else {
            throw STTError.conversionFailed
        }
        pcmBuffer.frameLength = AVAudioFrameCount(buffer.samples.count)
        if let channelData = pcmBuffer.floatChannelData {
            buffer.samples.withUnsafeBufferPointer { ptr in
                if let baseAddress = ptr.baseAddress {
                    channelData[0].initialize(from: baseAddress, count: buffer.samples.count)
                }
            }
        }
        return pcmBuffer
    }

    @available(iOS 26, *)
    private func convertPCMBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        to targetFormat: AVAudioFormat,
        cachedConverter: inout AVAudioConverter?
    ) throws -> AVAudioPCMBuffer? {
        let converter: AVAudioConverter
        if let cached = cachedConverter,
           cached.inputFormat == inputBuffer.format,
           cached.outputFormat == targetFormat {
            converter = cached
        } else {
            guard let newConverter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else {
                throw STTError.conversionFailed
            }
            converter = newConverter
            cachedConverter = newConverter
        }

        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let targetCapacity = max(1, AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 100))
        guard let convertedPCMBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetCapacity
        ) else {
            throw STTError.conversionFailed
        }

        var conversionError: NSError?
        let provider = SingleBufferProvider(buffer: inputBuffer)
        _ = converter.convert(to: convertedPCMBuffer, error: &conversionError) { _, outStatus in
            provider.provide(status: outStatus)
        }
        if let conversionError = conversionError {
            throw conversionError
        }
        guard convertedPCMBuffer.frameLength > 0 else { return nil }
        return convertedPCMBuffer
    }

    @available(iOS 26, *)
    private func convertToAnalyzerInput(
        buffer: AudioBuffer,
        targetFormat: AVAudioFormat?,
        cachedConverter: inout AVAudioConverter?,
        cachedInputFormat: inout AVAudioFormat?
    ) throws -> AnalyzerInput? {
        let pcmBuffer = try makePCMBuffer(from: buffer, cachedInputFormat: &cachedInputFormat)
        guard let target = targetFormat, target != pcmBuffer.format else {
            return AnalyzerInput(buffer: pcmBuffer)
        }
        guard let converted = try convertPCMBuffer(pcmBuffer, to: target, cachedConverter: &cachedConverter) else {
            return nil
        }
        return AnalyzerInput(buffer: converted)
    }
}
