protocol AudioSource: Sendable {
    func start() -> AsyncStream<AudioBuffer>
    func stop()
}
