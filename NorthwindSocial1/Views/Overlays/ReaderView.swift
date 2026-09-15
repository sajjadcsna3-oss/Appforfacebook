import SwiftUI

struct ReaderView: View {
    let article: ReaderArticle
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var ai = AIToolsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { PanelHeader(icon: "ReaderIcon", title: article.title); Button("Done") { dismiss() } }
            Text("\(article.source) · \(article.minutes) min read").font(.caption).foregroundStyle(.secondary)
            ScrollView { Text(article.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).lineSpacing(5) }
            Divider()
            if ai.state == .loading { ProgressView("Summarizing reader text…") }
            if case .failure(let message) = ai.state { Text(message).foregroundStyle(.red) }
            if !ai.summary.isEmpty { Text(ai.summary).padding(12).background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8)) }
            HStack { Button("Summarize with Groq") { Task { await ai.summarize(text: article.text, browser: facebook) } }; Spacer(); Button("Copy") { ai.copy(article.text) } }
        }
        .padding(22).frame(minWidth: 680, minHeight: 560)
    }
}
