import Foundation
import XCTest
@testable import Teleprompter

final class OpenRouterAuthServiceTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        FakeLLMURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeLLMURLProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        FakeLLMURLProtocol.reset()
        session = nil
        super.tearDown()
    }

    func testPKCEGenerationCreatesURLSafeVerifierAndChallenge() {
        let service = OpenRouterAuthService(session: session)
        let pkce = service.generatePKCE()

        XCTAssertEqual(pkce.method, "S256")
        // 32 bytes sem padding em base64url resultam em 43 caracteres
        XCTAssertEqual(pkce.verifier.count, 43)
        XCTAssertEqual(pkce.challenge.count, 43)

        let urlSafeCharset = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        XCTAssertTrue(pkce.verifier.unicodeScalars.allSatisfy { urlSafeCharset.contains($0) })
        XCTAssertTrue(pkce.challenge.unicodeScalars.allSatisfy { urlSafeCharset.contains($0) })
        XCTAssertFalse(pkce.verifier.contains("="))
        XCTAssertFalse(pkce.challenge.contains("="))
    }

    func testMakeAuthURLFormatsParametersCorrectly() {
        let service = OpenRouterAuthService(session: session)
        let challenge = "test_challenge_1234567890"
        let url = service.makeAuthURL(challenge: challenge)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            XCTFail("URLComponents inválida")
            return
        }

        XCTAssertEqual(components.host, "openrouter.ai")
        XCTAssertEqual(components.path, "/auth")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "callback_url" })?.value, "teleprompter://openrouter")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "code_challenge" })?.value, challenge)
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
    }

    func testExtractCodeFromCallbackURL() throws {
        let service = OpenRouterAuthService(session: session)

        let validURL = try XCTUnwrap(URL(string: "teleprompter://openrouter?code=auth_code_xyz123"))
        let code = try service.extractCode(from: validURL)
        XCTAssertEqual(code, "auth_code_xyz123")

        let fragmentURL = try XCTUnwrap(URL(string: "teleprompter://openrouter#code=auth_code_frag456"))
        let fragmentCode = try service.extractCode(from: fragmentURL)
        XCTAssertEqual(fragmentCode, "auth_code_frag456")
    }

    func testExtractCodeThrowsWhenCodeIsMissingOrEmpty() throws {
        let service = OpenRouterAuthService(session: session)

        let noCodeURL = try XCTUnwrap(URL(string: "teleprompter://openrouter?error=access_denied"))
        XCTAssertThrowsError(try service.extractCode(from: noCodeURL)) { error in
            XCTAssertEqual(error as? OpenRouterAuthError, .missingCallbackCode)
        }

        let emptyCodeURL = try XCTUnwrap(URL(string: "teleprompter://openrouter?code="))
        XCTAssertThrowsError(try service.extractCode(from: emptyCodeURL)) { error in
            XCTAssertEqual(error as? OpenRouterAuthError, .missingCallbackCode)
        }
    }

    func testExchangeCodeSuccessReturnsApiKeyAndSendsCorrectPayload() async throws {
        let expectedApiKey = "sk-or-v1-abcdef1234567890"
        let jsonResponse = Data("""
        {"key": "\(expectedApiKey)"}
        """.utf8)

        FakeLLMURLProtocol.config = .init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            rawData: jsonResponse
        )

        let service = OpenRouterAuthService(session: session)
        let apiKey = try await service.exchangeCode(code: "code_abc", verifier: "verifier_xyz")

        XCTAssertEqual(apiKey, expectedApiKey)
        XCTAssertEqual(FakeLLMURLProtocol.recordedRequests.count, 1)

        guard let request = FakeLLMURLProtocol.recordedRequests.first,
              let bodyData = FakeLLMURLProtocol.recordedBodies.first else {
            XCTFail("Requisição não foi gravada")
            return
        }

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/auth/keys")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(json["code"] as? String, "code_abc")
        XCTAssertEqual(json["code_verifier"] as? String, "verifier_xyz")
        XCTAssertEqual(json["code_challenge_method"] as? String, "S256")
    }

    func testExchangeCodeThrowsOnHTTP4xx() async {
        FakeLLMURLProtocol.config = .init(
            statusCode: 401,
            headers: ["Content-Type": "application/json"],
            rawData: Data(#"{"error": "Unauthorized"}"#.utf8)
        )

        let service = OpenRouterAuthService(session: session)
        do {
            _ = try await service.exchangeCode(code: "bad_code", verifier: "verifier_123")
            XCTFail("Deveria lançar erro HTTP 401")
        } catch let error as OpenRouterAuthError {
            XCTAssertEqual(error, .httpError(statusCode: 401))
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testExchangeCodeThrowsWhenKeyIsMissingInJSON() async {
        FakeLLMURLProtocol.config = .init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            rawData: Data(#"{"status": "ok"}"#.utf8)
        )

        let service = OpenRouterAuthService(session: session)
        do {
            _ = try await service.exchangeCode(code: "code_123", verifier: "verifier_123")
            XCTFail("Deveria lançar missingKeyInResponse")
        } catch let error as OpenRouterAuthError {
            XCTAssertEqual(error, .missingKeyInResponse)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testExchangeCodeThrowsWhenKeyIsEmptyInJSON() async {
        FakeLLMURLProtocol.config = .init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            rawData: Data(#"{"key": "   "}"#.utf8)
        )

        let service = OpenRouterAuthService(session: session)
        do {
            _ = try await service.exchangeCode(code: "code_123", verifier: "verifier_123")
            XCTFail("Deveria lançar missingKeyInResponse")
        } catch let error as OpenRouterAuthError {
            XCTAssertEqual(error, .missingKeyInResponse)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }
}
