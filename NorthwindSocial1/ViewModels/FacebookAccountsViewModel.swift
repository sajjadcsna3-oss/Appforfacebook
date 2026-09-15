import Combine
import Foundation

@MainActor
final class FacebookAccountsViewModel: ObservableObject {
    @Published private(set) var accounts: [FacebookAccount] = []
    @Published var activeID: UUID? { didSet { save() } }

    private let accountsKey = "facebook.accounts.v4"
    private let activeKey = "facebook.activeAccount.v4"

    init() {
        if let data = UserDefaults.standard.data(forKey: accountsKey) {
            accounts = (try? JSONDecoder().decode([FacebookAccount].self, from: data)) ?? []
        }
        activeID = UserDefaults.standard.string(forKey: activeKey).flatMap(UUID.init(uuidString:))
        if active == nil { activeID = accounts.first?.id }
    }

    var active: FacebookAccount? { accounts.first { $0.id == activeID } }

    @discardableResult
    func ensureAccount() -> FacebookAccount {
        if let active { return active }
        let account = FacebookAccount(sessionID: nil)
        accounts.append(account)
        activeID = account.id
        save()
        return account
    }

    func addAccount() {
        let account = FacebookAccount()
        accounts.append(account)
        activeID = account.id
        save()
    }

    func select(_ account: FacebookAccount) { activeID = account.id }

    func updateActive(name: String?, avatarURL: URL?, isLoggedIn: Bool? = nil) {
        guard let index = accounts.firstIndex(where: { $0.id == activeID }) else { return }
        if let name, !name.isEmpty { accounts[index].name = name }
        if let avatarURL { accounts[index].avatarURL = avatarURL }
        if let isLoggedIn { accounts[index].isLoggedIn = isLoggedIn }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(data, forKey: accountsKey) }
        UserDefaults.standard.set(activeID?.uuidString, forKey: activeKey)
    }
}
