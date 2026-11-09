import SwiftUI
import XCTest
@testable import Teleprompter

@MainActor
final class LensViewTests: XCTestCase {
    func testSimulatedLensHoldsWhatWasShown() {
        let lens = SimulatedLens()
        let content = LensContent(question: "Q?", body: "• A", sources: [])
        lens.show(content)
        XCTAssertEqual(lens.content, content)
        lens.clear()
        XCTAssertNil(lens.content)
    }

    func testLensViewRenders600x600() throws {
        let view = LensView(content: LensContent(question: "Por que Swift?", body: "• DAT SDK só tem Swift", sources: []))
        let image = try XCTUnwrap(ImageRenderer(content: view).uiImage)
        XCTAssertEqual(image.size, CGSize(width: 600, height: 600))
    }
}
