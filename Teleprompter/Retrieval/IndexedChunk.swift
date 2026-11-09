import Foundation

struct IndexedChunk: Sendable, Equatable {
    enum Kind: String, Sendable, CaseIterable, Equatable {
        // swiftlint:disable:next identifier_name
        case qa
        case document
        case code
    }

    var kind: Kind
    var text: String
    var source: SourceRef
    var question: String?

    init(kind: Kind, text: String, source: SourceRef, question: String? = nil) {
        self.kind = kind
        self.text = text
        self.source = source
        self.question = question
    }

    init(kind: Kind, text: String, source: String, question: String? = nil) {
        self.kind = kind
        self.text = text
        self.source = SourceRef(path: source)
        self.question = question
    }
}
