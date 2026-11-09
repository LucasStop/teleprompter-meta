import AVFoundation

final class MicrophoneAudioSource: AudioSource, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var isRunning = false
    private var continuation: AsyncStream<AudioBuffer>.Continuation?

    func start() -> AsyncStream<AudioBuffer> {
        AsyncStream { continuation in
            self.lock.withLock {
                self.continuation = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.stop()
            }

            do {
                try self.configureAudioSession()
                try self.startEngine(continuation: continuation)
            } catch {
                continuation.finish()
            }
        }
    }

    func stop() {
        let (wasRunning, savedContinuation) = lock.withLock { () -> (Bool, AsyncStream<AudioBuffer>.Continuation?) in
            let previous = isRunning
            isRunning = false
            let current = continuation
            continuation = nil
            return (previous, current)
        }

        guard wasRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        savedContinuation?.finish()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        if let availableInputs = session.availableInputs {
            if let bluetoothInput = availableInputs.first(where: { $0.portType == .bluetoothHFP }) {
                try session.setPreferredInput(bluetoothInput)
            }
        }
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine(continuation: AsyncStream<AudioBuffer>.Continuation) throws {
        lock.withLock {
            isRunning = true
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            continuation.yield(AudioBuffer(samples: samples, sampleRate: sampleRate))
        }

        try engine.start()
    }
}
