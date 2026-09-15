import Foundation

enum OverlayRoute: String, Identifiable {
    case settings, tabs, summary, draft
    var id: String { rawValue }
}

