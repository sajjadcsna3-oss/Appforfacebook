import Foundation

enum FacebookBrowserError: LocalizedError {
    case webViewUnavailable
    case noReadableContent

    var errorDescription: String? {
        switch self {
        case .webViewUnavailable:
            "Facebook is not ready yet."
        case .noReadableContent:
            "No readable text was found on this Facebook page."
        }
    }
}
