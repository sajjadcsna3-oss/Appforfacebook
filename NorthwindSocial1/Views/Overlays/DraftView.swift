import SwiftUI

struct DraftView: View {
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var ai = AIToolsViewModel()
    @State private var input = ""
    @State private var action: DraftAction = .generate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { dismiss() } label: { Label("Back", systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(Color.facebookBlue)
                PanelHeader(icon: "DraftIcon", title: "Draft")
            }
            Picker("Action", selection: $action) { ForEach(DraftAction.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            TextEditor(text: $input).frame(height: 100).padding(8).background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) { if input.isEmpty { Text(action == .generate ? "Describe what you want to write…" : "Paste text to change…").foregroundStyle(.tertiary).padding(14).allowsHitTesting(false) } }
            if ai.state == .loading { ProgressView("Working with Groq…") }
            if case .empty = ai.state { Label("Enter some text first.", systemImage: "text.cursor").foregroundStyle(.secondary) }
            if case .failure(let message) = ai.state { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            TextEditor(text: $ai.draft).frame(height: 120).padding(8).background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 10))
            if let message = ai.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button(action.rawValue) { Task { await ai.createDraft(input: input, action: action) } }.disabled(ai.state == .loading)
                Spacer()
                Button("Copy") { ai.copy(ai.draft) }.disabled(ai.draft.isEmpty)
                Button("Insert") { Task { await ai.insert(ai.draft, into: facebook) } }.buttonStyle(.borderedProminent).disabled(ai.draft.isEmpty)
            }
        }
        .padding(20).frame(width: 680, height: 520)
    }
}
