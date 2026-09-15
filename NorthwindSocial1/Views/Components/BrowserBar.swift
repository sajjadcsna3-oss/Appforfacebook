import SwiftUI

struct BrowserBar: View {
    @ObservedObject var facebook: FacebookViewModel
    let account: FacebookAccount?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: facebook.goBack) { Image(systemName: "chevron.left") }.disabled(!facebook.canGoBack)
            Button(action: facebook.goForward) { Image(systemName: "chevron.right") }.disabled(!facebook.canGoForward)
            Button(action: facebook.reload) { Image(systemName: facebook.isLoading ? "xmark" : "arrow.clockwise") }
            Spacer()
            HStack(spacing: 7) {
                Image("lockIcon").foregroundStyle(.green)
                Text(account?.name.map { "Facebook · \($0)" } ?? "Facebook").lineLimit(1).font(.caption)
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
}
