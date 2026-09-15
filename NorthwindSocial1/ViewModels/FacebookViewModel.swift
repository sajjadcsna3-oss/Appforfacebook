import Combine
import Foundation
import WebKit

@MainActor
final class FacebookViewModel: ObservableObject {
    static let homeURL = FacebookDestination.home.url

    @Published private(set) var currentURL = homeURL
    @Published var pageTitle = "facebook.com"
    @Published var isLoading = false
    @Published var progress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoggedIn = false
    @Published private(set) var accountName: String?
    @Published private(set) var accountAvatarURL: URL?
    @Published var loadError: String?
    @Published var readerArticle: ReaderArticle?

    weak var webView: WKWebView?
    private var pendingURL: URL?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        let url = pendingURL ?? currentURL
        pendingURL = nil
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60))
    }

    func resetForAccount() {
        webView = nil
        pendingURL = currentURL
        isLoggedIn = false
        accountName = nil
        accountAvatarURL = nil
        loadError = nil
    }

    func navigate(to destination: FacebookDestination) { navigate(to: destination.url) }

    func navigate(to url: URL) {
        loadError = nil
        currentURL = url
        if let webView {
            webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60))
        } else {
            pendingURL = url
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { loadError = nil; webView?.reload() }

    func refresh(from webView: WKWebView) {
        let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? webView.url?.host ?? "facebook.com"
        if canGoBack != webView.canGoBack { canGoBack = webView.canGoBack }
        if canGoForward != webView.canGoForward { canGoForward = webView.canGoForward }
        if pageTitle != title { pageTitle = title }
        if isLoading != webView.isLoading { isLoading = webView.isLoading }
        if abs(progress - webView.estimatedProgress) > 0.001 { progress = webView.estimatedProgress }
        setCurrentURL(webView.url)
    }

    func setCurrentURL(_ url: URL?) {
        guard let url else { return }
        if currentURL != url { currentURL = url }
        UserDefaults.standard.set(url.absoluteString, forKey: "facebook.lastURL")
    }

    func updateAccount(name: String?, avatarURL: URL?) {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
           !["profile", "your profile"].contains(name.lowercased()), accountName != name {
            accountName = name
        }
        if let avatarURL,
           ["http", "https"].contains(avatarURL.scheme?.lowercased() ?? ""),
           accountAvatarURL != avatarURL {
            accountAvatarURL = avatarURL
        }
    }

    func updateLoginState(_ signedIn: Bool) {
        if isLoggedIn != signedIn { isLoggedIn = signedIn }
        // A missing cookie while Facebook is navigating or refreshing is not proof that
        // previously extracted identity data is invalid. Keep it until accounts switch.
    }

    func insert(text: String) async -> Bool {
        guard let webView else { return false }
        let encoded = (try? JSONEncoder().encode(text)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        let script = """
        (() => {
          const text = \(encoded);
          const fields = [document.activeElement, ...document.querySelectorAll('[contenteditable="true"], [role="textbox"], textarea, input[type="text"]')];
          const field = fields.find(item => item && (item.isContentEditable || 'value' in item));
          if (!field) return false;
          field.focus();
          if ('value' in field) { field.value = text; field.dispatchEvent(new Event('input', {bubbles:true})); return true; }
          document.execCommand('insertText', false, text);
          field.dispatchEvent(new InputEvent('input', {bubbles:true, data:text}));
          return true;
        })()
        """
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in continuation.resume(returning: value as? Bool ?? false) }
        }
    }

    func readableText(maxCharacters: Int = 14_000) async throws -> String {
        guard let webView else { throw FacebookBrowserError.webViewUnavailable }
        let script = "(() => { const selected=window.getSelection()?.toString()?.trim(); const root=document.querySelector('[role=main]')||document.querySelector('main')||document.body; return selected||root?.innerText||''; })()"
        let value: Any? = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: value) }
            }
        }
        let text = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FacebookBrowserError.noReadableContent }
        return String(text.prefix(maxCharacters))
    }

    private func readerText(maxCharacters: Int = 40_000) async throws -> String {
        guard let webView else { throw FacebookBrowserError.webViewUnavailable }
        let script = #"""
        (() => {
          const normalize = value => value
            .replace(/\r/g, '')
            .split(/\n+/)
            .map(line => line.replace(/\s+/g, ' ').trim())
            .filter(Boolean)
            .filter(line => !/^(Like|Comment|Share|Send|Reply|Follow|Sponsored|See translation|Most relevant|All comments)$/i.test(line))
            .filter(line => !/^\d+[KMB]?\s*(comments?|shares?|reactions?|views?)$/i.test(line))
            .filter((line, index, lines) => line.toLowerCase() !== 'facebook' && lines.indexOf(line) === index)
            .join('\n\n')
            .trim();

          const selected = normalize(window.getSelection()?.toString() || '');
          if (selected) return selected;

          const candidates = [...document.querySelectorAll('[role="article"], article, [data-pagelet*="FeedUnit"]')];
          const visibleArea = element => {
            const rect = element.getBoundingClientRect();
            const width = Math.max(0, Math.min(rect.right, innerWidth) - Math.max(rect.left, 0));
            const height = Math.max(0, Math.min(rect.bottom, innerHeight) - Math.max(rect.top, 0));
            return width * height;
          };
          const messageSelector = '[data-ad-preview="message"], [data-ad-comet-preview="message"]';
          const score = element => {
            const messages = [...element.querySelectorAll(messageSelector)];
            const messageLength = messages.reduce((total, node) => total + (node.innerText || '').length, 0);
            const totalLength = (element.innerText || '').length;
            return messageLength * 8 + Math.min(totalLength, 5000) + Math.min(visibleArea(element) / 100, 3000);
          };
          const article = candidates
            .filter(element => normalize(element.innerText || '').length >= 20)
            .sort((left, right) => score(right) - score(left))[0];
          if (!article) return '';

          const messageNodes = [...article.querySelectorAll(messageSelector)]
            .filter(node => !node.parentElement?.closest(messageSelector));
          if (messageNodes.length) {
            return normalize(messageNodes.map(node => node.innerText || '').join('\n\n'));
          }

          const clean = article.cloneNode(true);
          clean.querySelectorAll([
            'nav', 'button', '[role="button"]', '[role="navigation"]', '[role="menu"]',
            '[role="toolbar"]', '[role="dialog"]', 'form', 'input', 'textarea', 'svg',
            '[aria-label*="reaction" i]', '[aria-label*="comment" i]', '[aria-label*="share" i]',
            '[data-visualcompletion="ignore-dynamic"]'
          ].join(',')).forEach(node => node.remove());

          const blocks = [...clean.querySelectorAll('h1, h2, h3, p, [dir="auto"]')]
            .filter(node => !node.querySelector('h1, h2, h3, p, [dir="auto"]'))
            .map(node => normalize(node.innerText || ''))
            .filter(text => text.length > 1);
          return normalize(blocks.join('\n\n') || clean.innerText || '');
        })()
        """#
        let value: Any? = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: value) }
            }
        }
        let text = (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FacebookBrowserError.noReadableContent }
        return String(text.prefix(maxCharacters))
    }

    func openReader() async {
        do {
            let text = try await readerText()
            readerArticle = ReaderArticle(
                title: webView?.title?.nilIfEmpty ?? "Reader",
                source: webView?.url?.host ?? "facebook.com",
                text: text,
                minutes: max(1, text.split(whereSeparator: \Character.isWhitespace).count / 220)
            )
        } catch {
            loadError = error.localizedDescription
        }
    }
}

enum FacebookBrowserError: LocalizedError {
    case webViewUnavailable, noReadableContent
    var errorDescription: String? {
        switch self {
        case .webViewUnavailable: "Facebook is not ready yet."
        case .noReadableContent: "No readable text was found on this Facebook page."
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
