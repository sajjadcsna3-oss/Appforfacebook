import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    var errorDescription: String? { switch self { case .saveFailed(let status): "Could not save the Groq API key (Keychain error \(status))." } }
}
