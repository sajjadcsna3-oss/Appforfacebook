import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var railWidth: RailWidth { didSet { save() } }
    @Published var expandOnHover: Bool { didSet { save() } }
    @Published var showBadges: Bool { didSet { save() } }
    @Published var toolsAtTop: Bool { didSet { save() } }
    @Published var keepWindowAbove: Bool { didSet { save() } }
    @Published var rememberWindowSize: Bool { didSet { save() } }
    @Published var showInMenuBar: Bool { didSet { save(); MenuBarService.shared.setEnabled(showInMenuBar) } }
    @Published var startup: StartupDestination { didSet { save() } }
    @Published var startupAccountID: UUID? { didSet { save() } }
    @Published var launchAtLogin: Bool { didSet { save(); updateLoginItem() } }
    @Published var startHidden: Bool { didSet { save() } }
    @Published var enabledTabs: Set<FacebookDestination> { didSet { save() } }
    @Published var tabOrder: [FacebookDestination] { didSet { save() } }
    @Published var groqAPIKey: String
    @Published var statusMessage: String?

    private let settingsKey = "facebook.settings.v1"

    private struct Stored: Codable {
        var railWidth: RailWidth
        var expandOnHover: Bool
        var showBadges: Bool
        var toolsAtTop: Bool
        var keepWindowAbove: Bool
        var rememberWindowSize: Bool?
        var showInMenuBar: Bool?
        var startup: StartupDestination
        var startupAccountID: UUID?
        var launchAtLogin: Bool
        var startHidden: Bool?
        var enabledTabs: Set<FacebookDestination>
        var tabOrder: [FacebookDestination]
    }

    init() {
        let stored = UserDefaults.standard.data(forKey: settingsKey)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        railWidth = stored?.railWidth ?? .comfortable
        expandOnHover = stored?.expandOnHover ?? true
        showBadges = stored?.showBadges ?? true
        toolsAtTop = stored?.toolsAtTop ?? false
        keepWindowAbove = stored?.keepWindowAbove ?? false
        rememberWindowSize = stored?.rememberWindowSize ?? true
        showInMenuBar = stored?.showInMenuBar ?? false
        startup = stored?.startup ?? .lastSession
        startupAccountID = stored?.startupAccountID
        launchAtLogin = stored?.launchAtLogin ?? false
        startHidden = stored?.startHidden ?? false
        enabledTabs = stored?.enabledTabs ?? Set(FacebookDestination.allCases)
        tabOrder = stored?.tabOrder ?? FacebookDestination.allCases
        groqAPIKey = KeychainSecret.read(service: GroqService.keychainService, account: GroqService.keychainAccount) ?? ""
        MenuBarService.shared.setEnabled(showInMenuBar)
    }

    var visibleTabs: [FacebookDestination] {
        tabOrder.filter(enabledTabs.contains)
    }

    func moveTabs(from source: IndexSet, to destination: Int) {
        tabOrder.move(fromOffsets: source, toOffset: destination)
    }

    func saveGroqAPIKey() {
        do {
            let key = groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try KeychainSecret.write(key, service: GroqService.keychainService, account: GroqService.keychainAccount)
            statusMessage = key.isEmpty ? "API key removed." : "Groq API key saved in Keychain."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func save() {
        let stored = Stored(railWidth: railWidth, expandOnHover: expandOnHover, showBadges: showBadges, toolsAtTop: toolsAtTop, keepWindowAbove: keepWindowAbove, rememberWindowSize: rememberWindowSize, showInMenuBar: showInMenuBar, startup: startup, startupAccountID: startupAccountID, launchAtLogin: launchAtLogin, startHidden: startHidden, enabledTabs: enabledTabs, tabOrder: tabOrder)
        if let data = try? JSONEncoder().encode(stored) { UserDefaults.standard.set(data, forKey: settingsKey) }
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
