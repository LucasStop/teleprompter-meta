import Observation

/// Lente do iPhone (US-06): guarda o mesmo conteúdo que iria para os óculos e a `LensView` o exibe.
@MainActor @Observable
final class SimulatedLens: Lens {
    private(set) var content: LensContent?

    func show(_ content: LensContent) { self.content = content }
    func clear() { content = nil }
}
