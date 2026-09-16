import Foundation

enum StartupDestination: String, Codable, CaseIterable, Identifiable {
    case lastSession = "Last session", 
         home = "Home",
         messages = "Messages"
    var id: String { rawValue }
}

