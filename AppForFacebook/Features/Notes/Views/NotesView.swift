import SwiftUI

struct NotesView: View {
    @StateObject private var model: NotesViewModel
    @State private var title = ""
    @State private var bodyText = ""
    @Environment(\.dismiss) private var dismiss

    init(account: FacebookAccount) { _model = StateObject(wrappedValue: NotesViewModel(account: account)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Image("NoteIcon").renderingMode(.template).foregroundStyle(.green); Text("Note").font(.headline); Spacer(); Button { model.add(); syncEditor() } label: { Image(systemName: "plus") }; Button { dismiss() } label: { Image(systemName: "xmark") } }
                .buttonStyle(.plain).padding(.horizontal, 18).frame(height: 52)
            Divider()
            HStack(spacing: 0) {
                List(selection: $model.selectedID) {
                    ForEach(model.notes) { note in VStack(alignment: .leading, spacing: 4) { Text(note.title)
                            .lineLimit(1);
                        Text(note.modifiedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }.tag(note.id)

                    }
                }
                .frame(width: 210)
                .onChange(of: model.selectedID) { _, _ in syncEditor()
                }
                Divider()
                if model.selected != nil {
                    VStack(spacing: 10) {
                        TextField("Title", text: $title).font(.title3.bold()).textFieldStyle(.plain)
                        TextEditor(text: $bodyText).scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.white.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        HStack { Button("Delete", role: .destructive) { model.deleteSelected(); syncEditor() };
                            Spacer();
                            Text("Saved locally")
                            .font(.caption)
                            .foregroundStyle(.secondary) }
                    }.padding(16)
                } else { ContentUnavailableView("No notes", systemImage: "note.text", description: Text("Click + to add a note.")) }
            }
        }
        .frame(width: 650, height: 430)
            .background(Color.appBackground)
            .onAppear { syncEditor() }
            .onChange(of: title) { _, _ in saveEditor() }.onChange(of: bodyText) { _, _ in saveEditor() }
    }
    private func syncEditor() { title = model.selected?.title ?? ""; bodyText = model.selected?.body ?? ""
    }
    private func saveEditor() {
        guard let selected = model.selected else { return }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : title
        guard selected.title != normalizedTitle || selected.body != bodyText else { return }
        model.update(title: title, body: bodyText)
    }
}
