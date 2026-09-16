import Combine
import Foundation

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedID: UUID?
    private let account: FacebookAccount
    private var storageKey: String { "facebook.notebook.\(account.id.uuidString)" }

    init(account: FacebookAccount) { self.account = account; load() }
    var selectedIndex: Int? { selectedID.flatMap { id in notes.firstIndex { $0.id == id } } }
    var selected: Note? { selectedIndex.map { notes[$0] } }

    func add() { let note = Note(title: "Untitled note", body: ""); notes.insert(note, at: 0); selectedID = note.id; persist() }
    func update(title: String, body: String) {
        guard let index = selectedIndex else { return }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : title
        guard notes[index].title != normalizedTitle || notes[index].body != body else { return }
        notes[index].title = normalizedTitle
        notes[index].body = body
        notes[index].modifiedAt = Date()
        persist()
    }
    func deleteSelected() { guard let selectedID else { return }; notes.removeAll { $0.id == selectedID }; self.selectedID = notes.first?.id; persist() }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey), let saved = try? JSONDecoder().decode([Note].self, from: data) { notes = saved }
        else if let legacy = UserDefaults.standard.string(forKey: "facebook.notes.\(account.id.uuidString)"), !legacy.isEmpty { notes = [Note(title: "Imported note", body: legacy)] }
        selectedID = notes.first?.id
    }
    private func persist() { UserDefaults.standard.set(try? JSONEncoder().encode(notes), forKey: storageKey) }
}
