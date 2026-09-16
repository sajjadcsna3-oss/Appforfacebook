import Foundation

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var modifiedAt = Date()
}
