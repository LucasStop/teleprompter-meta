import SwiftUI
import XCTest
@testable import Teleprompter

@MainActor
final class DesignSystemComponentsTests: XCTestCase {
    func testPrimaryButtonStates() {
        var tapped = false
        let defaultButton = PrimaryButton(title: "Confirmar", action: { tapped = true })
        XCTAssertEqual(defaultButton.title, "Confirmar")
        XCTAssertFalse(defaultButton.isLoading)
        XCTAssertTrue(defaultButton.isEnabled)

        let loadingButton = PrimaryButton(title: "Enviando", isLoading: true, action: {})
        XCTAssertTrue(loadingButton.isLoading)

        let disabledButton = PrimaryButton(title: "Indisponível", isEnabled: false, action: {})
        XCTAssertFalse(disabledButton.isEnabled)

        defaultButton.action()
        XCTAssertTrue(tapped)
    }

    func testMessageBubbleRoles() {
        let questionBubble = MessageBubble(role: .question, text: "Por que Swift?")
        XCTAssertEqual(questionBubble.role, .question)
        XCTAssertEqual(questionBubble.text, "Por que Swift?")

        let answerBubble = MessageBubble(
            role: .answer,
            text: "Resposta do modelo",
            bullets: ["Ponto 1", "Ponto 2"],
            sources: ["docs/PRD.md"],
            caption: "0,6 s"
        )
        XCTAssertEqual(answerBubble.role, .answer)
        XCTAssertEqual(answerBubble.bullets.count, 2)
        XCTAssertEqual(answerBubble.sources, ["docs/PRD.md"])
        XCTAssertEqual(answerBubble.caption, "0,6 s")

        let partialBubble = MessageBubble(role: .partial, text: "Ouvindo...")
        XCTAssertEqual(partialBubble.role, .partial)
    }

    func testSourceChipInitialization() {
        var clicked = false
        let staticChip = SourceChip(title: "docs/ADR-0001.md")
        XCTAssertEqual(staticChip.title, "docs/ADR-0001.md")
        XCTAssertNil(staticChip.action)

        let interactiveChip = SourceChip(title: "qa/stack.md", action: { clicked = true })
        XCTAssertNotNil(interactiveChip.action)
        interactiveChip.action?()
        XCTAssertTrue(clicked)
    }

    func testStatusBadgeAllStatuses() {
        for status in StatusBadge.Status.allCases {
            let badge = StatusBadge(status: status)
            XCTAssertEqual(badge.status, status)
            XCTAssertFalse(status.defaultTitle.isEmpty)
            XCTAssertFalse(status.iconName.isEmpty)
        }

        let customBadge = StatusBadge(status: .ativo, title: "Ouvindo a banca")
        XCTAssertEqual(customBadge.title, "Ouvindo a banca")
    }

    func testBannerStylesAndActions() {
        var actionFired = false
        var dismissed = false

        let banner = Banner(
            style: .danger,
            title: "Sem conexão",
            message: "Verifique a rede e tente de novo.",
            actionTitle: "Tentar de novo",
            action: { actionFired = true },
            onDismiss: { dismissed = true }
        )

        XCTAssertEqual(banner.title, "Sem conexão")
        XCTAssertEqual(banner.message, "Verifique a rede e tente de novo.")
        XCTAssertEqual(banner.actionTitle, "Tentar de novo")

        banner.action?()
        XCTAssertTrue(actionFired)

        banner.onDismiss?()
        XCTAssertTrue(dismissed)
    }

    func testComposerFieldStatesAndActions() {
        var text = ""
        var sendTapped = false
        var micTapped = false

        let emptyComposer = ComposerField(
            text: Binding(get: { text }, set: { text = $0 }),
            isListening: false,
            onSend: { sendTapped = true },
            onMicTapped: { micTapped = true }
        )

        XCTAssertEqual(emptyComposer.placeholder, "Pergunte sobre o seu material")
        XCTAssertFalse(emptyComposer.isListening)

        emptyComposer.onMicTapped?()
        XCTAssertTrue(micTapped)

        text = "Nova pergunta"
        let typingComposer = ComposerField(
            text: Binding(get: { text }, set: { text = $0 }),
            isListening: false,
            onSend: { sendTapped = true },
            onMicTapped: { micTapped = true }
        )
        typingComposer.onSend?()
        XCTAssertTrue(sendTapped)
    }
}
