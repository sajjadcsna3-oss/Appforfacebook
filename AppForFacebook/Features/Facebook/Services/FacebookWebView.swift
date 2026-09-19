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
            // The one selected pre-migration account retains its existing login.
            configuration.websiteDataStore = .default()
        }
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.add(context.coordinator, name: Coordinator.accountMessageName)
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Coordinator.accountObserverScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = nil

        context.coordinator.observe(webView)
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)
        Task { @MainActor in viewModel.attach(webView) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving()
        webView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.accountMessageName)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKHTTPCookieStoreObserver {
        static let accountMessageName = "facebookAccountDetails"

        static let accountExtractionScript = #"""
        (() => {
          const generic = new Set([
            'profile', 'your profile', 'account', 'facebook', 'notifications',
            'account controls and settings', 'edit', 'edit profile', 'see all profiles',
            'settings & privacy', 'help & support', 'log out'
          ]);
          const cleanName = value => (value || '')
            .replace(/^profile picture of\s+/i, '')
            .replace(/['’]s profile picture$/i, '')
            .replace(/^your profile[,]?\s*/i, '')
            .replace(/[,]?\s*profile$/i, '')
            .trim();
          const usable = value => value.length > 1 && value.length < 80
            && !generic.has(value.toLowerCase())
            && !/^(edit|menu|button|image|photo)(\s|$)/i.test(value);
          const anchors = [...document.querySelectorAll('a[href]')];
          const profileLinks = anchors.filter(a => {
            const label = (a.getAttribute('aria-label') || '').toLowerCase();
            const path = (() => { try { return new URL(a.href).pathname; } catch { return ''; } })();
            return label === 'your profile' || label.includes('see your profile')
              || path === '/me/' || path === '/me' || path.startsWith('/profile.php');
          });
          const profileLink = profileLinks.find(a => usable(cleanName(a.innerText)))
            || profileLinks.find(a => a.querySelector('img, image')) || profileLinks[0]
            || document.querySelector('[aria-label="Your profile"]');
          const profileImage = profileLink?.querySelector('img, image');
          const path = location.pathname.toLowerCase();
          const linkedPath = (() => { try { return new URL(profileLink?.href || '').pathname.toLowerCase(); } catch { return ''; } })();
          const isProfilePage = path === '/me/' || path === '/me' || path.startsWith('/profile.php')
            || (linkedPath && linkedPath === path);
          const heading = isProfilePage ? (document.querySelector('h1')?.innerText || '') : '';
          const titleName = isProfilePage
            ? (document.title || '').replace(/\s*[|\-–]\s*Facebook.*$/i, '').trim() : '';
          const names = [
            profileLink?.innerText,
            heading,
            profileLink?.getAttribute('aria-label'),
            profileImage?.getAttribute('alt'),
            titleName
          ].map(cleanName);
          const name = names.find(usable) || '';
          const image = profileImage?.href?.baseVal
            || profileImage?.getAttribute('href')
            || profileImage?.getAttribute('xlink:href')
            || profileImage?.src
            || [...document.images].find(img => name && img.alt?.toLowerCase().includes(name.toLowerCase()))?.src
            || '';
          const unread = [...document.querySelectorAll('[aria-label]')]
            .map(a => {
              const label = a.getAttribute('aria-label') || '';
              // Facebook also describes feed/navigation state as "new". Only
              // the two controls whose numbers are actual unread totals belong
              // in the app sidebar; routing arbitrary labelled links caused the
              // Home tab's selected indicator to appear as a count of 1.
              let path;
              if (/\b(messenger|message|chat)\b/i.test(label)) {
                path = '/messages/t/';
              } else if (/\bnotification\b/i.test(label)) {
                path = '/notifications/';
              } else {
                return null;
              }
              // Never invent the old fallback count of 1. A badge is exposed
              // only when Facebook publishes a numeric unread count itself.
              const number = label.match(/(\d[\d,.]*)\s*(?:unread|new)?/i)?.[1];
              if (!number) return null;
              const count = parseInt(number.replace(/\D/g, ''), 10);
              if (!Number.isFinite(count) || count <= 0) return null;
              return { path, count };
            })
            .filter(Boolean);
          return { name, image, unread };
        })()
        """#

        static let accountObserverScript = #"""
        (() => {
          if (/^\/(login|checkpoint|two_step_verification)(\/|$)/i.test(location.pathname)) return;
          let timer;
          const publish = () => {
            clearTimeout(timer);
            timer = setTimeout(() => {
              const details = __ACCOUNT_EXTRACTION__;
              if (details.name || details.image || details.unread) {
                window.webkit.messageHandlers.facebookAccountDetails.postMessage(details);
              }
            }, 150);
          };
          new MutationObserver(publish).observe(document.documentElement, { childList: true, subtree: true });
          publish();
        })()
        """#.replacingOccurrences(of: "__ACCOUNT_EXTRACTION__", with: accountExtractionScript)
        @available(macOS 12.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let host = origin.host.lowercased()
            guard host == "facebook.com" || host.hasSuffix(".facebook.com") else {
                decisionHandler(.deny)
                return
            }
            decisionHandler(.prompt) // defers to macOS's native camera/mic permission dialog
        }
        var parent: FacebookWebView
        private var observations: [NSKeyValueObservation] = []
        private weak var observedWebView: WKWebView?
        private var accountDetailsWorkItem: DispatchWorkItem?

        init(_ parent: FacebookWebView) { self.parent = parent }

        func observe(_ webView: WKWebView) {
            observedWebView = webView
            observations = [
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.isLoading, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.canGoBack, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.canGoForward, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) },
                webView.observe(\.url, options: [.new]) { [weak self, weak webView] _, _ in self?.refresh(webView) }
            ]
        }

        func stopObserving() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
            accountDetailsWorkItem?.cancel()
            accountDetailsWorkItem = nil
            observedWebView = nil
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard let webView = observedWebView else { return }
            updateSessionState(webView)
        }

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
                self?.scheduleAccountDetailsRead(from: webView)
            }
        }

        private func scheduleAccountDetailsRead(from webView: WKWebView) {
            accountDetailsWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView, self.observedWebView === webView else { return }
                self.readAccountDetails(from: webView)
            }
            accountDetailsWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

        private func readAccountDetails(from webView: WKWebView) {
            webView.evaluateJavaScript(Self.accountExtractionScript) { [weak self, weak webView] value, _ in
                self?.applyAccountDetails(value as Any, from: webView)
                guard let result = value as? [String: Any],
                      (result["name"] as? String)?.isEmpty != false,
                      let webView else { return }
                self?.readAccountDetailsFromProfilePage(webView)
            }
        }

        private func readAccountDetailsFromProfilePage(_ webView: WKWebView) {
            let script = #"""
            fetch('/me/', { credentials: 'include', cache: 'no-store' })
              .then(response => response.text())
              .then(html => {
                const doc = new DOMParser().parseFromString(html, 'text/html');
                const clean = value => (value || '')
                  .replace(/\s*[|\-–]\s*Facebook.*$/i, '')
                  .replace(/['’]s profile.*$/i, '')
                  .trim();
                const candidates = [
                  doc.querySelector('meta[property="og:title"]')?.content,
                  doc.querySelector('meta[name="twitter:title"]')?.content,
                  doc.querySelector('h1')?.innerText,
                  doc.title
                ].map(clean);
                const invalid = /^(facebook|profile|your profile|edit|log in|sign up)$/i;
                const name = candidates.find(value => value.length > 1 && value.length < 80 && !invalid.test(value)) || '';
                const image = doc.querySelector('meta[property="og:image"]')?.content || '';
                return { name, image };
              })
              .catch(() => ({ name: '', image: '' }))
            """#
            webView.evaluateJavaScript(script) { [weak self, weak webView] value, _ in
                self?.applyAccountDetails(value as Any, from: webView)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.accountMessageName else { return }
            applyAccountDetails(message.body, from: message.webView)
        }

        private func applyAccountDetails(_ value: Any, from webView: WKWebView?) {
            guard let result = value as? [String: Any] else { return }
            let name = result["name"] as? String
            let avatarURL = (result["image"] as? String).flatMap(URL.init(string:))
            let unreadItems = result["unread"] as? [[String: Any]] ?? []
            var unreadCounts: [FacebookDestination: Int] = [:]
            for item in unreadItems {
                guard let path = item["path"] as? String,
                      let url = URL(string: "https://www.facebook.com\(path)"),
                      let destination = FacebookDestination.destination(for: url) else { continue }
                guard let count = (item["count"] as? NSNumber)?.intValue,
                      count > 0 else { continue }
                guard destination == .messages || destination == .notifications else { continue }
                unreadCounts[destination] = max(unreadCounts[destination] ?? 0, count)
            }
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView, self.parent.viewModel.webView === webView else { return }
                self.parent.viewModel.updateAccount(name: name, avatarURL: avatarURL)
                self.parent.viewModel.updateUnreadCounts(unreadCounts)
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""

            // Keep normal Facebook/Meta HTTPS authentication, checkpoint,
            // consent, and redirect pages inside this same WKWebView session.
            if ["http", "https", "about", "blob", "data"].contains(scheme) {
                let host = url.host?.lowercased() ?? ""
                let isFacebookHost = host == "facebook.com" || host.hasSuffix(".facebook.com")
                let normalizedPath = url.path.lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

                // Preserve the project's canonical Messenger route.
                if isFacebookHost,
                   action.targetFrame?.isMainFrame != false,
                   normalizedPath == "messages" {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.path = "/messages/t/"
                    if let inboxURL = components?.url, inboxURL != url {
                        webView.load(URLRequest(
                            url: inboxURL,
                            cachePolicy: action.request.cachePolicy,
                            timeoutInterval: action.request.timeoutInterval
                        ))
                        decisionHandler(.cancel)
                        return
                    }
                }

                // Facebook can use target="_blank" during login/security flows.
                // Reuse this view so the per-account cookies/data store are retained.
                if action.targetFrame == nil {
                    webView.load(action.request)
                    decisionHandler(.cancel)
                    return
                }

                decisionHandler(.allow)
                return
            }

            // Non-web schemes leave the app only after an explicit user click.
            if action.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = action.request.url else { return nil }
            let scheme = url.scheme?.lowercased() ?? ""

            // Do not create a second WebView for Facebook/Meta auth popups.
            // Loading the request here keeps the same isolated account session.
            if ["http", "https", "about", "blob", "data"].contains(scheme) {
                webView.load(action.request)
            } else if action.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
            }

            return nil
        }
    }
}
