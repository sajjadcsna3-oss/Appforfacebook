import Foundation

enum OverlayRoute: String, Identifiable {
    case settings, tabs, summary, draft, templates, reader, notes
    var id: String { rawValue }
}
