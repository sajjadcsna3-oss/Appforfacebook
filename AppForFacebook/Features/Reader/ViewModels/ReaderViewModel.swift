import Combine
import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    enum State { case loading, loaded, empty, failed(String) }
    @Published var state: State = .loading
    @Published var article: ReadableArticle?
    @Published var fontSize: Double = 17

    func load(from browser: any FacebookContentProviding) async {
        state = .loading
        do {
            let loadedArticle = try await browser.readableArticle()
            try Task.checkCancellation()
            article = loadedArticle
            state = .loaded
        } catch is CancellationError {
            state = .loading
        }
        catch FacebookBrowserError.noReadableContent { state = .empty }
        catch { state = .failed(error.localizedDescription) }
    }
}
