import Foundation

enum SidebarTool: String, CaseIterable, Identifiable {
    case summarize, draft, reader, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .summarize: "SummariseIcon"
        case .draft: "DraftIcon"
        case .reader: "ReaderIcon"
        case .settings: "SettingIcon"
        }
    }
}
