import Combine
import Foundation

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedID: UUID?
    private let account: FacebookAccount
    private let store: CodableStore
    private let defaults: UserDefaults
    private var storageKey: String { "facebook.notebook.\(account.id.uuidString)" }

    init(account: FacebookAccount, defaults: UserDefaults = .standard) {
        self.account = account
        self.defaults = defaults
        store = CodableStore(defaults: defaults)
        load()
    }
    
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
        if let saved: [Note] = try? store.load(forKey: storageKey) { notes = saved }
        else if let legacy = defaults.string(forKey: "facebook.notes.\(account.id.uuidString)"), !legacy.isEmpty { notes = [Note(title: "Imported note", body: legacy)] }
        selectedID = notes.first?.id
    }
    private func persist() { try? store.save(notes, forKey: storageKey) }
}
