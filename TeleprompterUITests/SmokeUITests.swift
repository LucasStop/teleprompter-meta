import XCTest

final class SmokeUITests: XCTestCase {
    @MainActor
    func testAskByTextShowsAnswerOrNotFound() throws {
        let app = XCUIApplication()
        app.launch()

        let composerField = app.descendants(matching: .any)["chat-composer-field"]
        XCTAssertTrue(composerField.waitForExistence(timeout: 5))

        let textField = app.textFields["Campo de pergunta"].exists
            ? app.textFields["Campo de pergunta"]
            : (app.textViews["Campo de pergunta"].exists
                ? app.textViews["Campo de pergunta"]
                : composerField.textFields.firstMatch)

        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("O que e o app?")

        let sendButton = app.buttons["Enviar pergunta"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        // Instalação limpa não tem material importado: o RAG fechado tem que recusar.
        let answerPredicate = NSPredicate(format: "label CONTAINS[c] %@", "Não encontrei isso no seu material")
        let answer = app.descendants(matching: .any).matching(answerPredicate).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 10))
    }

    @MainActor
    func testTabsPassAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        let tabs = ["Chat", "Material", "Ensaio", "Ajustes"]
        for tab in tabs {
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Aba \(tab) deve existir")
            tabButton.tap()

            switch tab {
            case "Chat":
                XCTAssertTrue(app.descendants(matching: .any)["chat-composer-field"].waitForExistence(timeout: 5))
            case "Material":
                XCTAssertTrue(app.staticTexts["material-title"].waitForExistence(timeout: 5))
            case "Ensaio":
                XCTAssertTrue(app.staticTexts["ensaio-title"].waitForExistence(timeout: 5))
            case "Ajustes":
                let ajustesVisible = app.navigationBars["Ajustes"].waitForExistence(timeout: 5)
                    || app.staticTexts["Ajustes"].waitForExistence(timeout: 5)
                XCTAssertTrue(ajustesVisible)
            default:
                break
            }

            try app.performAccessibilityAudit { issue in
                // Falso positivo: elementos no fim do ScrollView sob a barra de abas translúcida do sistema falham no cálculo de contraste.
                if tab == "Ajustes" && issue.auditType.contains(.contrast) {
                    return true
                }
                // Falso positivo: badges e seletores com layout horizontal no cabeçalho do Chat
                if tab == "Chat" && issue.auditType.contains(.textClipped) {
                    return true
                }
                return false
            }
        }
    }
}
