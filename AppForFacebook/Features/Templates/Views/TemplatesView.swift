import SwiftUI

struct TemplatesView: View {
    @ObservedObject var facebook: FacebookViewModel
    @StateObject private var model = TemplatesViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack { Image("Template").renderingMode(.template).foregroundStyle(Color.accentBlue); Text("Templates").font(.headline); Spacer(); Button { model.resetEditor() } label: { Image(systemName: "plus") }; Button { dismiss() } label: { Image(systemName: "xmark") } }
                .buttonStyle(.plain).padding(.horizontal, 18).frame(height: 52)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 10) {
                    TextField("Search templates…", text: $model.search).textFieldStyle(.roundedBorder)
                    if model.filtered.isEmpty {
                        ContentUnavailableView(model.templates.isEmpty ? "No templates yet" : "No matches", systemImage: "rectangle.stack", description: Text("Create reusable text with the editor."))
                    } else {
                        List(model.filtered) { template in
                            VStack(alignment: .leading, spacing: 5) { Text(template.title).fontWeight(.medium); Text(template.body).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                                .contentShape(Rectangle()).onTapGesture { model.edit(template) }
                                .contextMenu { Button("Insert") { Task { await model.insert(template, into: facebook) } }; Button("Delete", role: .destructive) { model.remove(template) } }
                        }.listStyle(.inset)
                    }
                }.padding(14).frame(width: 300)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.editingID == nil ? "New template" : "Edit template").font(.headline)
                    TextField("Template name", text: $model.title).textFieldStyle(.roundedBorder)
                    TextEditor(text: $model.body)
                        .padding(8)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    if let message = model.message { Text(message).font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack { if model.editingID != nil { Button("Cancel") { model.resetEditor() } }; Spacer(); Button("Save") { model.save() }.buttonStyle(.borderedProminent) }
                }
                .padding(18)
            }
        }
        .frame(width: 650, height: 430).background(Color.appBackground)
    }
}
