import Foundation

struct FacebookAccount: Identifiable, Codable, Equatable {
    let id: UUID
    let sessionID: UUID?
    var name: String?
    var avatarURL: URL?
    var isLoggedIn: Bool

    init(id: UUID = UUID(), sessionID: UUID? = UUID(), name: String? = nil, avatarURL: URL? = nil, isLoggedIn: Bool = false) {
        self.id = id
        self.sessionID = sessionID
        self.name = name
        self.avatarURL = avatarURL
        self.isLoggedIn = isLoggedIn
    }
}

