import Foundation

enum SidebarTool: String, CaseIterable, Identifiable {
    case summarize, draft, pictureInPicture, templates, reader, notebook, sidebar, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summarize: "Summarise"
        case .draft: "Draft"
        case .pictureInPicture: "Picture-in-Picture"
        case .templates: "Templates"
        case .reader: "Reader"
        case .notebook: "Notebook"
        case .sidebar: "Sidebar"
        case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .summarize: "SummariseIcon"
        case .draft: "DraftIcon"
        case .pictureInPicture: "picturetoolIcon"
        case .templates: "Template"
        case .reader: "ReaderIcon"
        case .notebook: "NoteIcon"
        case .sidebar: "SidePanel"
        case .settings: "SettingIcon"
        }
    }

    var usesSystemIcon: Bool { false }
}
