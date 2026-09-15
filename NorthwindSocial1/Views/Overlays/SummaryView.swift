import SwiftUI

struct SummaryView: View {
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var ai = AIToolsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { dismiss() } label: { Label("Back", systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(Color.facebookBlue)
                PanelHeader(icon: "SummariseIcon", title: "Summarize")
            }
            Text("Summarizes selected text, or the readable content of the current Facebook page.").foregroundStyle(.secondary)
            stateView
            if !ai.summary.isEmpty {
                ScrollView { Text(ai.summary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14) }
                    .background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let message = ai.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button("Summarize Again") { Task { await ai.summarize(browser: facebook) } }.disabled(ai.state == .loading)
                Spacer()
                Button("Copy") { ai.copy(ai.summary) }.disabled(ai.summary.isEmpty)
            }
        }
        .padding(20).frame(width: 620, height: 430)
        .task { await ai.summarize(browser: facebook) }
    }

    @ViewBuilder private var stateView: some View {
        switch ai.state {
        case .idle: EmptyView()
        case .loading: ProgressView("Reading Facebook content…")
        case .success: EmptyView()
        case .empty: Label("No readable content is available on this page.", systemImage: "doc.text.magnifyingglass").foregroundStyle(.secondary)
        case .failure(let message): Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}
