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
    @Published private(set) var unreadCounts: [FacebookDestination: Int] = [:]
    @Published var loadError: String?

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
        unreadCounts = [:]
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
    func stopLoading() { webView?.stopLoading() }

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
           !["profile", "your profile", "edit", "edit profile", "account"].contains(name.lowercased()),
           accountName != name {
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

    func updateUnreadCounts(_ counts: [FacebookDestination: Int]) {
        if unreadCounts != counts { unreadCounts = counts }
    }

    func insert(text: String) async -> Bool {
        guard let webView else { return false }
        let encoded = (try? JSONEncoder().encode(text)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        let script = """
        (() => {
          const text = \(encoded);
          const field = document.activeElement;
          const isTextInput = field instanceof HTMLTextAreaElement
            || (field instanceof HTMLInputElement && ['text', 'search', 'email', 'url'].includes(field.type));
          const isEditable = field instanceof HTMLElement
            && (field.isContentEditable || field.getAttribute('role') === 'textbox');
          const rect = field instanceof Element ? field.getBoundingClientRect() : null;
          if ((!isTextInput && !isEditable) || !rect || rect.width <= 0 || rect.height <= 0) return false;
          field.focus();
          if (isTextInput) {
            const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(field), 'value')?.set;
            if (setter) setter.call(field, text); else field.value = text;
            field.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'insertText', data:text}));
            field.dispatchEvent(new Event('change', {bubbles:true}));
            return true;
          }
          const selection = window.getSelection();
          if (!selection || selection.rangeCount === 0 || !field.contains(selection.anchorNode)) return false;
          if (!document.execCommand('insertText', false, text)) return false;
          field.dispatchEvent(new InputEvent('input', {bubbles:true, inputType:'insertText', data:text}));
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

    func readableArticle() async throws -> ReadableArticle {
        guard let webView else { throw FacebookBrowserError.webViewUnavailable }
        let script = #"""
        (() => {
          const selected = window.getSelection()?.toString()?.trim();
          const root = selected ? null : (document.querySelector('article') || document.querySelector('[role="main"]') || document.querySelector('main') || document.body);
          const text = selected || root?.innerText?.trim() || '';
          const title = document.querySelector('article h1, article h2, [role="main"] h1, main h1')?.innerText?.trim() || document.title || 'Reader';
          return { title, text, url: location.href };
        })()
        """#
        let value: Any? = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value) }
            }
        }
        guard let result = value as? [String: Any],
              let text = result["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FacebookBrowserError.noReadableContent
        }
        return ReadableArticle(title: result["title"] as? String ?? "Reader",
                               text: String(text.prefix(40_000)),
                               sourceURL: (result["url"] as? String).flatMap(URL.init(string:)))
    }

    func togglePictureInPicture() async -> String {
        guard let webView else { return "Facebook is not available." }
        let script = #"""
        (() => {
          const videos = [...document.querySelectorAll('video')].filter(v => v.readyState > 0);
          const video = videos.find(v => !v.paused) || videos.sort((a,b) => (b.clientWidth*b.clientHeight)-(a.clientWidth*a.clientHeight))[0];
          if (!video) return 'noVideo';
          try {
            if (video.webkitPresentationMode === 'picture-in-picture') {
              video.webkitSetPresentationMode('inline'); return 'closed';
            }
            if (typeof video.webkitSetPresentationMode === 'function') {
              video.webkitSetPresentationMode('picture-in-picture'); video.play(); return 'opened';
            }
            return 'unsupported';
          } catch (_) { return 'unsupported'; }
        })()
        """#
        let result: String = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { value, _ in continuation.resume(returning: value as? String ?? "unsupported") }
        }
        switch result {
        case "opened": return "Picture-in-Picture started."
        case "closed": return "Picture-in-Picture closed."
        case "noVideo": return "Play a Facebook video, then try Picture-in-Picture again."
        default: return "This video does not support Picture-in-Picture."
        }
    }

}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
