import SwiftUI
import UIKit
import XCTest
@testable import Teleprompter

@MainActor
final class DesignSystemTokensTests: XCTestCase {
    private struct ColorExpectation {
        let token: SemanticColor
        let lightHex: String
        let darkHex: String
    }

    func testSemanticColorsResolveToHexInLightAndDarkMode() {
        let expectedTable: [ColorExpectation] = [
            ColorExpectation(token: .background, lightHex: "#FAF8F4", darkHex: "#0B0B0C"),
            ColorExpectation(token: .surface, lightHex: "#FFFFFF", darkHex: "#151517"),
            ColorExpectation(token: .surfaceRaised, lightHex: "#FFFFFF", darkHex: "#1E1E21"),
            ColorExpectation(token: .foreground, lightHex: "#1C1B19", darkHex: "#F5F3EE"),
            ColorExpectation(token: .muted, lightHex: "#5F5B54", darkHex: "#A3A09A"),
            ColorExpectation(token: .border, lightHex: "#DDD8CF", darkHex: "#2C2C30"),
            ColorExpectation(token: .primary, lightHex: "#A8560A", darkHex: "#F5A524"),
            ColorExpectation(token: .primaryHover, lightHex: "#8F4906", darkHex: "#FFB84D"),
            ColorExpectation(token: .primaryForeground, lightHex: "#FFFFFF", darkHex: "#1A1203"),
            ColorExpectation(token: .success, lightHex: "#1F7A33", darkHex: "#3FB950"),
            ColorExpectation(token: .warning, lightHex: "#8A5A00", darkHex: "#E3B341"),
            ColorExpectation(token: .danger, lightHex: "#C62828", darkHex: "#F85149"),
            ColorExpectation(token: .info, lightHex: "#0B5FB0", darkHex: "#58A6FF"),
            ColorExpectation(token: .focusRing, lightHex: "#A8560A", darkHex: "#FFC857"),
            ColorExpectation(token: .disabled, lightHex: "#A9A49B", darkHex: "#5A5853"),
        ]

        let lightTrait = UITraitCollection(userInterfaceStyle: .light)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)

        for item in expectedTable {
            let uiColor = item.token.uiColor

            let resolvedLight = uiColor.resolvedColor(with: lightTrait).toHexString()
            XCTAssertEqual(
                resolvedLight.uppercased(),
                item.lightHex.uppercased(),
                "Token \(item.token.rawValue) em modo claro deveria ser \(item.lightHex), mas obteve \(resolvedLight)"
            )

            let resolvedDark = uiColor.resolvedColor(with: darkTrait).toHexString()
            XCTAssertEqual(
                resolvedDark.uppercased(),
                item.darkHex.uppercased(),
                "Token \(item.token.rawValue) em modo escuro deveria ser \(item.darkHex), mas obteve \(resolvedDark)"
            )
        }
    }

    func testTypographySpecsMatchDesignTable() {
        XCTAssertEqual(Typography.displaySize, 34)
        XCTAssertEqual(Typography.displayLineHeight, 41)

        XCTAssertEqual(Typography.h1Size, 28)
        XCTAssertEqual(Typography.h1LineHeight, 34)

        XCTAssertEqual(Typography.h2Size, 22)
        XCTAssertEqual(Typography.h2LineHeight, 28)

        XCTAssertEqual(Typography.h3Size, 17)
        XCTAssertEqual(Typography.h3LineHeight, 22)

        XCTAssertEqual(Typography.bodySize, 17)
        XCTAssertEqual(Typography.bodyLineHeight, 24)

        XCTAssertEqual(Typography.bodySmSize, 15)
        XCTAssertEqual(Typography.bodySmLineHeight, 20)

        XCTAssertEqual(Typography.captionSize, 12)
        XCTAssertEqual(Typography.captionLineHeight, 16)

        XCTAssertEqual(Typography.codeSize, 15)
        XCTAssertEqual(Typography.codeLineHeight, 20)
    }

    func testSpacingAndCornerRadiiTokensMatchDesignTable() {
        XCTAssertEqual(Spacing.scale, [4, 8, 12, 16, 24, 32, 48, 64])
        XCTAssertEqual(Spacing.s1, 4)
        XCTAssertEqual(Spacing.s2, 8)
        XCTAssertEqual(Spacing.s3, 12)
        XCTAssertEqual(Spacing.s4, 16)
        XCTAssertEqual(Spacing.s5, 24)
        XCTAssertEqual(Spacing.s6, 32)
        XCTAssertEqual(Spacing.s7, 48)
        XCTAssertEqual(Spacing.s8, 64)
        XCTAssertEqual(Spacing.gutter, 16)
        XCTAssertEqual(Spacing.minTouchTarget, 44)

        XCTAssertEqual(CornerRadius.sm, 8)
        XCTAssertEqual(CornerRadius.md, 12)
        XCTAssertEqual(CornerRadius.lg, 16)
        XCTAssertEqual(CornerRadius.full, 999)

        XCTAssertEqual(Borders.standard, 1)
    }

    func testLensTokensRemainIntact() {
        XCTAssertEqual(LensTokens.size, 600)
        XCTAssertEqual(LensTokens.margin, 32)
    }
}
