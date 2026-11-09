import AVFoundation

final class FileAudioSource: AudioSource, @unchecked Sendable {
    private let url: URL
    private let frameCapacity: AVAudioFrameCount
    private let lock = NSLock()
    private var isStopped = false
    private var activeTask: Task<Void, Never>?

    init(url: URL, frameCapacity: AVAudioFrameCount = 1024) {
        self.url = url
        self.frameCapacity = frameCapacity
    }

    func start() -> AsyncStream<AudioBuffer> {
        AsyncStream { continuation in
            lock.withLock {
                isStopped = false
            }

            let task = Task {
                let audioFile: AVAudioFile
                do {
                    audioFile = try AVAudioFile(forReading: url)
                } catch {
                    continuation.finish()
                    return
                }

                let format = audioFile.processingFormat
                guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                    continuation.finish()
                    return
                }

                while !Task.isCancelled {
                    let stopped = self.lock.withLock { self.isStopped }
                    if stopped { break }

                    do {
                        try audioFile.read(into: pcmBuffer)
                    } catch {
                        break
                    }

                    let framesRead = Int(pcmBuffer.frameLength)
                    if framesRead == 0 {
                        break
                    }

                    guard let channelData = pcmBuffer.floatChannelData else { break }
                    let samples = Array(UnsafeBufferPointer(start: channelData[0], count: framesRead))
                    continuation.yield(AudioBuffer(samples: samples, sampleRate: format.sampleRate))

                    if audioFile.framePosition >= audioFile.length {
                        break
                    }
                }

                continuation.finish()
            }

            lock.withLock {
                activeTask = task
            }

            continuation.onTermination = { [weak self] _ in
                self?.stop()
            }
        }
    }

    func stop() {
        let task = lock.withLock { () -> Task<Void, Never>? in
            isStopped = true
            let current = activeTask
            activeTask = nil
            return current
        }
        task?.cancel()
    }
}
