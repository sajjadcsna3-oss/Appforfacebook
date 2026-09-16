import Foundation

enum GroqError: LocalizedError {
    case missingAPIKey, invalidResponse, emptyResponse, requestEncoding(String), modelUnavailable(String), server(String), network(String), decoding(String)
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "The Groq API key is not configured in Keychain."
        case .invalidResponse: "Groq returned an invalid response."
        case .emptyResponse: "Groq returned an empty response. Please try again."
        case .requestEncoding(let message): "Could not create the Groq request: \(message)"
        case .modelUnavailable(let model): "The Groq model \"\(model)\" is unavailable for this account. Check the configured model or try again later."
        case .server(let message): message
        case .network(let message): "Network error: \(message)"
        case .decoding(let message): "Could not read the Groq response: \(message)"
        }
    }
}
