import Foundation

struct AccountLocalDataStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func removeData(for accountID: UUID) {
        let id = accountID.uuidString
        ["facebook.window.\(id)", "facebook.notebook.\(id)", "facebook.notes.\(id)"].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}

