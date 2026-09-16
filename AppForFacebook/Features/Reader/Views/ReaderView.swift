import SwiftUI

struct ReaderView: View {
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var model = ReaderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image("ReaderIcon")
                .renderingMode(.template)
                .foregroundStyle(Color.accentBlue)
                Text("Reader").font(.headline)
                Spacer()
                Button { model.fontSize = max(13, model.fontSize - 1) } label: { Image(systemName: "textformat.size.smaller") }
                Button { model.fontSize = min(25, model.fontSize + 1) } label: { Image(systemName: "textformat.size.larger") }
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }.buttonStyle(.plain).padding(.horizontal, 20).frame(height: 56)
            Divider()
            Group {
                switch model.state {
                case .loading: ProgressView("Extracting readable content…")
                case .empty: ContentUnavailableView("No readable content", systemImage: "doc.text.magnifyingglass", description: Text("Open a post or select text on Facebook and try again."))
                case .failed(let message): ContentUnavailableView("Reader unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
                case .loaded:
                    ScrollView {
                        if let article = model.article {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(article.title).font(.system(size: model.fontSize + 9, weight: .bold)).textSelection(.enabled)
                                if let host = article.sourceURL?.host { Text(host).font(.caption).foregroundStyle(.secondary) }
                                Text(article.text).font(.system(size: model.fontSize)).lineSpacing(7).textSelection(.enabled)
                            }.frame(maxWidth: 720, alignment: .leading).padding(34)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(minWidth: 680, idealWidth: 820, minHeight: 520, idealHeight: 640)
            .background(Color.appBackground).task { await model.load(from: facebook) }
    }
}
