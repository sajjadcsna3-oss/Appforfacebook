import Combine
import Foundation

@MainActor
final class FacebookAccountsViewModel: ObservableObject {
    @Published private(set) var accounts: [FacebookAccount] = []
    @Published var activeID: UUID? { didSet { save() } }
    @Published private(set) var persistenceWarning: String?
    static let accountsStorageKey = "facebook.accounts.v4"
    private let accountsKey = FacebookAccountsViewModel.accountsStorageKey
    private let activeKey = "facebook.activeAccount.v4"
    private let defaults: UserDefaults
    private let store: CodableStore
    static var hasSavedAccounts: Bool {
        guard let data = UserDefaults.standard.data(forKey: accountsStorageKey) else { return false }
        return (try? JSONDecoder().decode([FacebookAccount].self, from: data))?.isEmpty == false
    }
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        store = CodableStore(defaults: defaults)
        var shouldSave = false
        if let data = store.rawData(forKey: accountsKey) {
            do {
                accounts = try store.load(forKey: accountsKey) ?? []
            } catch {
                // Keep the unreadable payload intact so a future migration or support build
                // can recover it before normal use writes a fresh account list.
                let recoveryKey = "\(accountsKey).recovery"
                if store.rawData(forKey: recoveryKey) == nil {
                    store.setRawData(data, forKey: recoveryKey)
                }
                persistenceWarning = "Saved account information could not be read. A recovery copy was preserved."
                accounts = []
            }
        }
        // Older extraction code could mistake Facebook controls such as "Edit" for
        // the person's name. Never keep those values as account identity.
        let invalidNames = Set(["edit", "edit profile", "profile", "your profile", "account"])
        for index in accounts.indices {
            if let name = accounts[index].name?.trimmingCharacters(in: .whitespacesAndNewlines),
               invalidNames.contains(name.lowercased()) {
                accounts[index].name = nil
                shouldSave = true
            }
        }
        activeID = defaults.string(forKey: activeKey).flatMap(UUID.init(uuidString:))
        if active == nil { activeID = accounts.first?.id }
       
        for index in accounts.indices where accounts[index].sessionID == nil && accounts[index].id != activeID {
            accounts[index].sessionID = accounts[index].id
            accounts[index].isLoggedIn = false
            shouldSave = true
        }
        if shouldSave { save() }
    }

    var active: FacebookAccount? { accounts.first { $0.id == activeID } }

    @discardableResult
    func ensureAccount() -> FacebookAccount {
        if let active { return active }
        let account = FacebookAccount()
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

    func remove(_ account: FacebookAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        let wasActive = account.id == activeID
        accounts.remove(at: index)

        if wasActive {
            activeID = accounts.isEmpty ? nil : accounts[min(index, accounts.count - 1)].id
        } else {
            save()
        }
    }

    func updateActive(name: String?, avatarURL: URL?, isLoggedIn: Bool? = nil) {
        guard let index = accounts.firstIndex(where: { $0.id == activeID }) else { return }
        if let name, !name.isEmpty { accounts[index].name = name }
        if let avatarURL { accounts[index].avatarURL = avatarURL }
        if let isLoggedIn { accounts[index].isLoggedIn = isLoggedIn }
        save()
    }

    private func save() {
        try? store.save(accounts, forKey: accountsKey)
        defaults.set(activeID?.uuidString, forKey: activeKey)
    }
}
