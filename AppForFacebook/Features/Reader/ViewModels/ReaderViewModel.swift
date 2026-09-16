import Combine
import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    enum State { case loading, loaded, empty, failed(String) }
    @Published var state: State = .loading
    @Published var article: ReadableArticle?
    @Published var fontSize: Double = 17

    func load(from browser: FacebookViewModel) async {
        state = .loading
        do { article = try await browser.readableArticle(); state = .loaded }
        catch FacebookBrowserError.noReadableContent { state = .empty }
        catch { state = .failed(error.localizedDescription) }
    }
}
