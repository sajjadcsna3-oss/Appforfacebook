import Foundation

/// The narrow browser capabilities consumed by non-browser features.
/// Keeping these protocols small lets their view models be tested without WebKit.
@MainActor
protocol FacebookContentProviding: AnyObject {
    func readableText(maxCharacters: Int) async throws -> String
    func readableArticle() async throws -> ReadableArticle
}

@MainActor
protocol FacebookTextInserting: AnyObject {
    func insert(text: String) async -> Bool
}

