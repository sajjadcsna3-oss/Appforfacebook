import SwiftUI

struct BrowserBar: View {
    @ObservedObject var facebook: FacebookViewModel
    let account: FacebookAccount?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: facebook.goBack) { Image(systemName: "chevron.left") }.disabled(!facebook.canGoBack)
            Button(action: facebook.goForward) { Image(systemName: "chevron.right") }.disabled(!facebook.canGoForward)
            Button {
                if facebook.isLoading { facebook.stopLoading() }
                else { facebook.reload() }
            } label: {
                Image(systemName: facebook.isLoading ? "xmark" : "arrow.clockwise")
            }
            .help(facebook.isLoading ? "Stop loading" : "Reload")
            Spacer()
            HStack(spacing: 7) {
                Image("lockIcon").foregroundStyle(isFacebookPage ? Color.green : Color.secondary)
                Text(pageLabel).lineLimit(1).font(.caption)
            }
            .padding(.horizontal, 14).frame(height: 28)
            .background(.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 7))
            Spacer()
            Color.clear.frame(width: 74, height: 1)
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
        .padding(.horizontal, 16).frame(height: 40)
        .background(Color.appBackground)
    }

    private var isFacebookPage: Bool {
        guard let host = facebook.currentURL.host?.lowercased() else { return false }
        return host == "facebook.com" || host.hasSuffix(".facebook.com")
    }

    private var pageLabel: String {
        guard isFacebookPage else { return facebook.currentURL.host ?? facebook.pageTitle }
        return account?.name.map { "Facebook · \($0)" } ?? "Facebook"
    }
}
