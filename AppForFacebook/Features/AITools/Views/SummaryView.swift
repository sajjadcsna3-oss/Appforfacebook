import SwiftUI

struct SummaryView: View {
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var ai = AIToolsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.06))

            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                repliesSection
                footer
            }
            .padding(20)
        }
        .frame(width: 650, height: 458)
        .background(Color(red: 0.055, green: 0.060, blue: 0.070))
        .task { await ai.summarize(browser: facebook) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.accentBlue)
            Text("AI assist")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Text("Facebook  ·  current page")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .frame(height: 58)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("SUMMARY")
            Group {
                if ai.state == .loading && ai.summary.isEmpty {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text("Reading the current Facebook page…")
                    }
                } else if !ai.summary.isEmpty {
                    Text(ai.summary).textSelection(.enabled)
                } else {
                    stateView
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .lineSpacing(7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SUGGESTED REPLIES")
            if ai.suggestedReplies.isEmpty {
                replyPlaceholder
            } else {
                ForEach(Array(ai.suggestedReplies.enumerated()), id: \.offset) { index, reply in
                    replyCard(reply, index: index)
                }
            }
        }
    }

    private var replyPlaceholder: some View {
        HStack(spacing: 9) {
            if ai.state == .loading { ProgressView().controlSize(.small) }
            Text(ai.state == .loading ? "Writing suggested replies…" : "No suggested replies available.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func replyCard(_ reply: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(reply)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { ai.copy(reply) } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(index == ai.selectedReplyIndex ? Color.accentBlue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy reply")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(index == ai.selectedReplyIndex ? Color.accentBlue.opacity(0.42) : Color.white.opacity(0.08))
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { ai.selectedReplyIndex = index }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            secondaryButton("Shorter") { Task { await ai.refineSelectedReply("shorter and more concise") } }
            secondaryButton("Warmer") { Task { await ai.refineSelectedReply("warmer and friendlier") } }
            Spacer()
            if let message = ai.message {
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Button("Paste into reply") {
                guard ai.suggestedReplies.indices.contains(ai.selectedReplyIndex) else { return }
                Task { await ai.insert(ai.suggestedReplies[ai.selectedReplyIndex], into: facebook) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.22, green: 0.42, blue: 0.94))
            .controlSize(.large)
            .disabled(ai.state == .loading || ai.suggestedReplies.isEmpty)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(ai.state == .loading || ai.suggestedReplies.isEmpty)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.48))
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
