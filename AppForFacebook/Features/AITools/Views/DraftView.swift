import SwiftUI

struct DraftView: View {
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var ai = AIToolsViewModel()
    @State private var input = ""
    @State private var action: DraftAction = .generate
    @State private var extractionMessage: String?
    @State private var isExtracting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    dismiss()
                }
                label: { Label("Back", systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(Color.facebookBlue)
                PanelHeader(icon: "DraftIcon", title: "Draft")
            }
            Picker("Action", selection: $action) { ForEach(DraftAction.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            HStack {
                Text("PROMPT").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Button("Use selected/page content") {
                    Task {
                        isExtracting = true
                        extractionMessage = nil
                        defer { isExtracting = false }
                        do { input = try await facebook.readableText(maxCharacters: 6_000) }
                        catch { extractionMessage = error.localizedDescription }
                    }
                }.buttonStyle(.plain).foregroundStyle(Color.facebookBlue).disabled(isExtracting)
            }
            EnhancedTextEditor(
                text: $input,
                placeholder: action == .generate ? "Describe what you want to write…" : "Paste text to change…"
            )
                .frame(height: 100)
                .padding(4)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            if ai.state == .loading { ProgressView("Working with Groq…") }
            if case .empty = ai.state { Label("Enter some text first.", systemImage: "text.cursor").foregroundStyle(.secondary) }
            if case .failure(let message) = ai.state { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            if isExtracting { ProgressView("Reading Facebook content…").controlSize(.small) }
            if let extractionMessage { Label(extractionMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            TextEditor(text: $ai.draft).frame(height: 120)
                .padding(8)
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if let message = ai.message { Text(message)
                .font(.caption)
                .foregroundStyle(.secondary) }
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
