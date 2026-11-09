import Foundation
import CryptoKit
import AuthenticationServices

/// Dados do par PKCE (RFC 7636) para autenticação OAuth.
struct OpenRouterPKCE: Sendable, Equatable {
    let verifier: String
    let challenge: String
    let method: String

    init(verifier: String, challenge: String, method: String = "S256") {
        self.verifier = verifier
        self.challenge = challenge
        self.method = method
    }
}

/// Erros tipados do fluxo de autenticação OpenRouter.
enum OpenRouterAuthError: Error, LocalizedError, Equatable, Sendable {
    case missingCallbackCode
    case invalidCallbackURL
    case httpError(statusCode: Int)
    case missingKeyInResponse
    case userCancelled
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingCallbackCode:
            return "Código de autorização não encontrado no retorno."
        case .invalidCallbackURL:
            return "URL de retorno inválida."
        case .httpError(let code):
            return "Erro HTTP \(code) na troca de chave."
        case .missingKeyInResponse:
            return "Chave de API ausente na resposta do provedor."
        case .userCancelled:
            return "Login cancelado ou recusado. Tente de novo."
        case .network(let message):
            return "Falha de rede: \(message)"
        }
    }
}

/// Protocolo testável do serviço de autenticação do OpenRouter (OAuth PKCE).
protocol OpenRouterAuthenticating: Sendable {
    func generatePKCE() -> OpenRouterPKCE
    func makeAuthURL(challenge: String) -> URL
    func extractCode(from callbackURL: URL) throws -> String
    func exchangeCode(code: String, verifier: String) async throws -> String
}

/// Implementação padrão do `OpenRouterAuthenticating`.
final class OpenRouterAuthService: OpenRouterAuthenticating, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    static let defaultCallbackURL = "teleprompter://openrouter"
    static let defaultBaseURL = URL(string: "https://openrouter.ai")!

    init(
        baseURL: URL = OpenRouterAuthService.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Gera `code_verifier` aleatório (32 bytes base64url sem padding)
    /// e `code_challenge` = base64url(SHA256(verifier)).
    func generatePKCE() -> OpenRouterPKCE {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            // Fallback do gerador do sistema (também aleatório) caso o SecRandom falhe
            for idx in 0..<randomBytes.count {
                randomBytes[idx] = UInt8.random(in: 0...255)
            }
        }
        let verifier = Self.base64URLEncode(Data(randomBytes))
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Self.base64URLEncode(Data(digest))
        return OpenRouterPKCE(verifier: verifier, challenge: challenge, method: "S256")
    }

    /// Monta a URL de autorização do OpenRouter com os parâmetros PKCE.
    func makeAuthURL(challenge: String) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("auth"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "callback_url", value: Self.defaultCallbackURL),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components?.url ?? baseURL.appendingPathComponent("auth")
    }

    /// Extrai o `code` retornado na URL de callback após autorização do usuário.
    func extractCode(from callbackURL: URL) throws -> String {
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        if let queryItem = components?.queryItems?.first(where: { $0.name == "code" })?.value,
           !queryItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return queryItem
        }
        if let fragment = components?.fragment {
            let fragmentComponents = URLComponents(string: "?" + fragment)
            if let fragmentItem = fragmentComponents?.queryItems?.first(where: { $0.name == "code" })?.value,
               !fragmentItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return fragmentItem
            }
        }
        throw OpenRouterAuthError.missingCallbackCode
    }

    /// Troca o `code` de autorização e o `code_verifier` pela chave de API permanente do OpenRouter.
    /// Nunca loga `code`, `verifier` ou a chave recebida.
    func exchangeCode(code: String, verifier: String) async throws -> String {
        let exchangeEndpoint = baseURL.appendingPathComponent("api/v1/auth/keys")
        var request = URLRequest(url: exchangeEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload: [String: String] = [
            "code": code,
            "code_verifier": verifier,
            "code_challenge_method": "S256"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw OpenRouterAuthError.network("Falha ao serializar payload de autenticação.")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenRouterAuthError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterAuthError.network("Resposta de rede inválida.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenRouterAuthError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let apiKey = json["key"] as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenRouterAuthError.missingKeyInResponse
        }

        return apiKey
    }

    /// Utilitário para conversão em Base64URL sem padding (RFC 7636).
    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Protocolo de casca fina para abstrair o `ASWebAuthenticationSession` do sistema.
@MainActor
protocol WebAuthenticationSessionProtocol: Sendable {
    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL
}

/// Implementação concreta do `WebAuthenticationSessionProtocol` via `ASWebAuthenticationSession`.
@MainActor
final class SystemWebAuthenticationSession: NSObject, WebAuthenticationSessionProtocol,
                                            ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.first as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
        return window ?? ASPresentationAnchor()
    }

    func authenticate(url: URL, callbackURLScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: OpenRouterAuthError.userCancelled)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: OpenRouterAuthError.invalidCallbackURL)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            guard session.start() else {
                continuation.resume(throwing: OpenRouterAuthError.network("Falha ao iniciar sessão de autenticação."))
                return
            }
        }
    }
}
