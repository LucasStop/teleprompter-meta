import Foundation

enum STTError: Error, Sendable, Equatable, LocalizedError {
    case unavailable
    case unsupportedLocale(Locale)
    case conversionFailed
    case internalError(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Reconhecimento de fala com SpeechAnalyzer indisponível nesta versão do iOS."
        case .unsupportedLocale(let locale):
            return "Locale \(locale.identifier) não suportado pelo transcritor."
        case .conversionFailed:
            return "Falha ao converter o buffer de áudio para o formato do analisador."
        case .internalError(let reason):
            return "Erro interno no transcritor: \(reason)"
        }
    }
}
