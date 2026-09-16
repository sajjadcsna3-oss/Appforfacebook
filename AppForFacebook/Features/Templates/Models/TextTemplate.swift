import Foundation

struct TextTemplate: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var body: String
}
