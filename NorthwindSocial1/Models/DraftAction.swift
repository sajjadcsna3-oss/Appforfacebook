import Foundation

enum DraftAction: String, CaseIterable, Identifiable {
    case generate = "Generate"
    case improve = "Improve"
    case rewrite = "Rewrite"
    case shorten = "Make shorter"
    case professional = "Professional"
    var id: String { rawValue }
}

