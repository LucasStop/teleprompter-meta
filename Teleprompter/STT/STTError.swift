import Foundation

enum STTError: Error, Sendable, Equatable, LocalizedError {
    case unavailable
    case unsupportedLocale(Locale)
    case conversionFailed
    case assetDownloadFailed(String)
    case internalError(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Reconhecimento de fala com SpeechAnalyzer indisponível nesta versão do iOS."
        case .unsupportedLocale(let locale):
            return "Locale \(locale.identifier) não suportado pelo transcritor."
        case .conversionFailed:
            return "Falha ao converter o buffer de áudio para o formato do analisador."
        case .assetDownloadFailed(let reason):
            return "Falha ao baixar o modelo de fala: \(reason). Verifique a conexão com a internet e o espaço disponível no dispositivo."
        case .internalError(let reason):
            return "Erro interno no transcritor: \(reason)"
        }
    }
}
