import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case rail = "Rail", accounts = "Accounts", window = "Window", startup = "Startup", privacy = "Privacy", shortcuts = "Shortcuts"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .rail: "RailIcon"
        case .accounts: "SettingAccountIcon"
        case .window: "WindowIcon"
        case .startup: "StartupIcon"
        case .privacy: "Privacy"
        case .shortcuts: "ShortcutsIcon"
        }
    }
}
