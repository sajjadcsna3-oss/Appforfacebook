import Foundation

enum RailWidth: String, Codable, CaseIterable, Identifiable {
    case iconsOnly = "Icons only", compact = "Compact", comfortable = "Comfortable"
    var id: String { rawValue }
}

