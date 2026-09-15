import AppKit
import SwiftUI
import WebKit

struct FacebookWebView: NSViewRepresentable {
    let account: FacebookAccount
    @ObservedObject var viewModel: FacebookViewModel

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if let sessionID = account.sessionID {
            configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: sessionID)
        } else {
            configuration.websiteDataStore = .default()
        }
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = nil

        context.coordinator.observe(webView)
        Task { @MainActor in viewModel.attach(webView) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: FacebookWebView
        private var observations: [NSKeyValueObservation] = []

        init(_ parent: FacebookWebView) { self.parent = parent }

        func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.isLoading, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.canGoBack, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.canGoForward, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.url, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) }
            ]
        }

        func stopObserving() { observations.forEach { $0.invalidate() }; observations.removeAll() }

        private func refresh(_ webView: WKWebView?) {
            guard let webView else { return }
            Task { @MainActor [weak self] in self?.parent.viewModel.refresh(from: webView) }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor [weak self] in self?.parent.viewModel.loadError = nil }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self] in
                self?.parent.viewModel.setCurrentURL(webView.url)
                self?.parent.viewModel.refresh(from: webView)
            }
            updateSessionState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }

        private func report(_ error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            Task { @MainActor [weak self] in self?.parent.viewModel.loadError = nsError.localizedDescription }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        private func updateSessionState(_ webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                let signedIn = cookies.contains { $0.name == "c_user" && $0.domain.hasSuffix("facebook.com") }
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView, self.parent.viewModel.webView === webView else { return }
                    self.parent.viewModel.updateLoginState(signedIn)
                }
                guard signedIn else { return }
                self?.readAccountDetails(from: webView)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak webView] in
                    guard let webView else { return }
                    self?.readAccountDetails(from: webView)
                }
            }
        }

        private func readAccountDetails(from webView: WKWebView) {
            let script = #"""
            (() => {
              const generic = new Set(['profile', 'your profile', 'account', 'facebook', 'notifications', 'account controls and settings']);
              const anchors = [...document.querySelectorAll('a')];
              const profileLinks = anchors.filter(a => {
                const label = (a.getAttribute('aria-label') || '').toLowerCase();
                const path = (() => { try { return new URL(a.href).pathname; } catch { return ''; } })();
                return label === 'your profile' || label.includes('see your profile') || path === '/me/' || path === '/me';
              });
              const profileLink = profileLinks.find(a => a.querySelector('img, image')) || profileLinks[0]
                || document.querySelector('[aria-label="Your profile"]');
              const label = profileLink?.getAttribute('aria-label')?.trim() || '';
              const profileImage = profileLink?.querySelector('img, image');
              const imageAlt = profileImage?.getAttribute('alt')?.trim() || '';
              const path = location.pathname.toLowerCase();
              const linkedPath = (() => { try { return new URL(profileLink?.href || '').pathname.toLowerCase(); } catch { return ''; } })();
              const isProfilePage = path === '/me/' || path === '/me' || path.startsWith('/profile.php') || (linkedPath && linkedPath === path);
              const heading = isProfilePage ? (document.querySelector('h1')?.innerText?.trim() || '') : '';
              const cleanName = value => value
                .replace(/^profile picture of\s+/i, '')
                .replace(/['’]s profile picture$/i, '')
                .replace(/^your profile[,]?\s*/i, '')
                .replace(/[,]?\s*profile$/i, '')
                .trim();
              const usable = value => value.length > 1 && value.length < 80 && !generic.has(value.toLowerCase());
              const titleName = isProfilePage ? (document.title || '').replace(/\s*[|\-–]\s*Facebook.*$/i, '').trim() : '';
              const names = [heading, imageAlt, label, titleName].map(cleanName);
              const name = names.find(usable) || '';
              const image = profileImage?.href?.baseVal
                || profileImage?.getAttribute('href')
                || profileImage?.getAttribute('xlink:href')
                || profileImage?.src
                || [...document.images].find(img => name && img.alt?.toLowerCase().includes(name.toLowerCase()))?.src
                || '';
              return { name, image };
            })()
            """#
            webView.evaluateJavaScript(script) { [weak self] value, _ in
                guard let result = value as? [String: Any] else { return }
                let name = result["name"] as? String
                let avatarURL = (result["image"] as? String).flatMap(URL.init(string:))
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView, self.parent.viewModel.webView === webView else { return }
                    self.parent.viewModel.updateAccount(name: name, avatarURL: avatarURL)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.allow); return }
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" || ["about", "blob", "data", "javascript"].contains(scheme) else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            if action.targetFrame == nil {
                webView.load(action.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let request = action.request as URLRequest? { webView.load(request) }
            return nil
        }
    }
}
