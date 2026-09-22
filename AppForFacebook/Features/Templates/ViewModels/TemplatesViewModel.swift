import Combine
import Foundation

@MainActor
final class TemplatesViewModel: ObservableObject {
    @Published private(set) var templates: [TextTemplate] = []
    @Published var search = ""
    @Published var title = ""
    @Published var body = ""
    @Published var editingID: UUID?
    @Published var message: String?
    private let storageKey = "facebook.textTemplates"
    private let store: CodableStore

    init(store: CodableStore? = nil) {
        self.store = store ?? CodableStore()
        load()
    }

    var filtered: [TextTemplate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? templates : templates.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
    }

    func edit(_ template: TextTemplate) { editingID = template.id; title = template.title; body = template.body }
    func resetEditor() { editingID = nil; title = ""; body = "" }

    func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanBody.isEmpty else { message = "Add a title and template text."; return }
        if let editingID, let index = templates.firstIndex(where: { $0.id == editingID }) {
            templates[index].title = cleanTitle; templates[index].body = cleanBody
        } else { templates.append(TextTemplate(title: cleanTitle, body: cleanBody)) }
        persist(); resetEditor(); message = nil
    }

    func remove(_ template: TextTemplate) {
        templates.removeAll { $0.id == template.id }
        if editingID == template.id { resetEditor() }
        persist()
    }
    func insert(_ template: TextTemplate, into browser: any FacebookTextInserting) async {
        message = await browser.insert(text: template.body) ? "Inserted into Facebook." : "Select a Facebook text field first."
    }
    private func load() {
        templates = (try? store.load(forKey: storageKey)) ?? []
    }

    private func persist() {
        do {
            try store.save(templates, forKey: storageKey)
        } catch {
            message = "Templates could not be saved: \(error.localizedDescription)"
        }
    }
}
