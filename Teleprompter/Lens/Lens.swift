protocol Lens: Sendable {
    func show(_ content: LensContent) async
    func clear() async
}
