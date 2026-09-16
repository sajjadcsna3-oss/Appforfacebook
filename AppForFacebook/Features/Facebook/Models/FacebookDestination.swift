import Foundation

enum FacebookDestination: String, CaseIterable, Codable, Identifiable {
    case home, messages, friends, reels, marketplace, notifications, profile

    var id: String { rawValue }
    var title: String {
        switch self {
        case .messages: "Messenger"
        default: rawValue.capitalized
        }
    }
    var icon: String {
        switch self {
        case .home: "HomeIcon"
        case .messages: "MessageIcon"
        case .friends: "group"
        case .reels: "ReelsIcon"
        case .marketplace: "MarketplaceIcon"
        case .notifications: "NotificationIcon"
        case .profile: "ProfileIcon"
        }
    }
    
    var url: URL {
        let path: String
        switch self {
        case .home: path = "/"
        // Use Facebook's canonical full-page thread-list destination.
        case .messages: path = "/messages/t/"
        case .friends: path = "/friends/"
        case .reels: path = "/reel/"
        case .marketplace: path = "/marketplace/"
        case .notifications: path = "/notifications/"
        case .profile: path = "/me/"
        }
        return URL(string: "https://www.facebook.com\(path)")!
    }

    static func destination(for url: URL) -> FacebookDestination? {
        guard let host = url.host?.lowercased(),
              host == "facebook.com" || host.hasSuffix(".facebook.com") else { return nil }

        let path = url.path.lowercased()
        let firstComponent = path.split(separator: "/").first.map(String.init) ?? ""
        switch firstComponent {
        case "": return .home
        case "home.php": return .home
        case "messages", "messenger": return .messages
        case "friends": return .friends
        case "reel", "reels": return .reels
        case "marketplace": return .marketplace
        case "notifications": return .notifications
        case "me": return .profile
        case "profile.php":
            // `/profile.php` without an id is Facebook's route for the signed-in user.
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.contains(where: { $0.name == "id" }) == true ? nil : .profile
        default:
            // Vanity-name URLs can represent either the signed-in user or somebody else,
            // so retaining the existing selection is safer than guessing Profile.
            return nil
        }
    }
}
