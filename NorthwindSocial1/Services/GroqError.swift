import Foundation

enum GroqError: LocalizedError {
    case missingAPIKey, invalidResponse, emptyResponse, server(String), network(String), decoding(String)
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "The Groq API key is not configured in Keychain."
        case .invalidResponse: "Groq returned an invalid response."
        case .emptyResponse: "Groq returned an empty response. Please try again."
        case .server(let message): message
        case .network(let message): "Network error: \(message)"
        case .decoding(let message): "Could not read the Groq response: \(message)"
        }
    }
}

