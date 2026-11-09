import SwiftUI
import XCTest
@testable import Teleprompter

@MainActor
final class DesignSystemRootTabViewTests: XCTestCase {
    func testRootTabViewHasFourTabsInOrder() {
        let expectedTabs: [AppTab] = [.chat, .material, .ensaio, .ajustes]
        XCTAssertEqual(RootTabView.tabs, expectedTabs)
        XCTAssertEqual(RootTabView.tabs.count, 4)
    }

    func testAppTabTitlesMatchDesignSpec() {
        XCTAssertEqual(AppTab.chat.title, "Chat")
        XCTAssertEqual(AppTab.material.title, "Material")
        XCTAssertEqual(AppTab.ensaio.title, "Ensaio")
        XCTAssertEqual(AppTab.ajustes.title, "Ajustes")
    }

    func testAppTabIconsAreValidSFSymbols() {
        XCTAssertFalse(AppTab.chat.iconName.isEmpty)
        XCTAssertFalse(AppTab.material.iconName.isEmpty)
        XCTAssertFalse(AppTab.ensaio.iconName.isEmpty)
        XCTAssertFalse(AppTab.ajustes.iconName.isEmpty)
    }
}
