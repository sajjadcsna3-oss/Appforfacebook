import Foundation

enum SidebarTool: String, CaseIterable, Identifiable {
    case summarize, draft, templates, reader, notebook, subscription, sidebar, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summarize: "Summarise"
        case .draft: "Draft"
        case .templates: "Templates"
        case .reader: "Reader"
        case .notebook: "Notebook"
        case .subscription: "Subscription"
        case .sidebar: "Sidebar"
        case .settings: "Settings"
        }
    }
    var icon: String {
        switch self {
        case .summarize: "SummariseIcon"
        case .draft: "DraftIcon"
        case .templates: "Template"
        case .reader: "ReaderIcon"
        case .notebook: "NoteIcon"
        case .subscription: "workspace_premium"
        case .sidebar: "SidePanel"
        case .settings: "SettingIcon"
        }
    }

    var usesSystemIcon: Bool { false }

    /// Matches the feature breakdown already shown in SubscriptionView:
    /// AI assist (Summarise/Draft), Reply templates and Reader/Notebook are
    /// Premium. The Subscription entry itself is always open to everyone —
    /// it's how a free user gets to the paywall in the first place.
    var isPremium: Bool {
        switch self {
        case .summarize, .draft, .templates, .reader, .notebook: true
        case .subscription, .sidebar, .settings: false
        }
    }
}
