import Foundation

enum LLMError: Error, Equatable, Sendable, LocalizedError {
    case missingAPIKey
    case network(String)
    case httpStatus(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Chave de API não configurada no armazenamento de segredos."
        case .network(let message):
            return "Erro de rede ao consultar o LLM: \(message)"
        case .httpStatus(let status):
            return "Provedor de LLM retornou status HTTP \(status)."
        case .invalidResponse:
            return "Resposta inválida ou inesperada do provedor de LLM."
        }
    }
}
