import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var settings: SettingsViewModel
    @StateObject private var accounts = FacebookAccountsViewModel()
    @StateObject private var facebook = FacebookViewModel()
    @EnvironmentObject private var storeKit: StoreKitService
    @EnvironmentObject private var subscriptionFlow: SubscriptionFlowCoordinator
    @State private var route: OverlayRoute?
    @State private var selectedTab: FacebookDestination = .home
    @State private var railHovered = false
    @State private var isBrowserOpen: Bool
    @State private var sidebarHidden = false
    @State private var selectedTool: SidebarTool?
    @State private var clearingSessionAccountID: UUID?
    @State private var webViewGeneration = UUID()
    @State private var preDockWindowFrame: NSRect?
    private let localDataStore = AccountLocalDataStore()
    private let windowFrameStore = WindowFrameStore()

    init(settings: SettingsViewModel, startInBrowser: Bool = false) {
        self.settings = settings
        _isBrowserOpen = State(
            initialValue: startInBrowser || FacebookAccountsViewModel.hasSavedAccounts
        )
    }

    private var isPremium: Bool { storeKit.entitlementState == .premium }

    var body: some View {
        Group {
            if isBrowserOpen { mainContent }
            else { FacebookChooserView(openFacebook: openFacebook) }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1200, minHeight: 800)
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            if !sidebarHidden { SidebarView(
                settings: settings,
                accounts: accounts,
                selectedTab: $selectedTab,
                isLoggedIn: facebook.isLoggedIn,
                showLabels: settings.railWidth != .iconsOnly || railHovered,
                navigate: navigate,
                show: { route = $0 },
                addAccount: addAccount,
                removeAccount: removeAccount,
                dockBesideCurrent: dockBesideCurrent,
                reloadSession: facebook.reload,
                signOut: signOut,
                activateTool: activateTool,
                selectedTool: selectedTool,
                unreadCounts: facebook.unreadCounts,
                isPremium: isPremium,
                onUpgrade: { subscriptionFlow.openSubscription() }
            )
            .frame(width: sidebarWidth)
            .onHover { railHovered = $0 }

            Divider() }

            VStack(spacing: 0) {
                BrowserBar(facebook: facebook, account: accounts.active)
                if facebook.isLoading {
                    ProgressView(value: facebook.progress).progressViewStyle(.linear).frame(height: 2)
                }
                ZStack {
                    if let account = accounts.active,
                       clearingSessionAccountID != account.id {
                        FacebookWebView(account: account, viewModel: facebook)
                            .id("\(account.id.uuidString)-\(webViewGeneration.uuidString)")
                    }
                    if let error = facebook.loadError {
                        LoadErrorView(message: error, retry: facebook.reload)
                    }
                }
            }

        }
        .background(Color.appBackground)
        .sheet(item: $route, onDismiss: { selectedTool = nil }) { route in
            switch route {
            case .settings:
                SettingsView(settings: settings, accounts: accounts) { account in
                    accounts.select(account)
                    facebook.navigate(to: FacebookViewModel.homeURL)
                }
            case .tabs: EditTabsView(settings: settings)
            case .summary: SummaryView(facebook: facebook)
            case .draft: DraftView(facebook: facebook)
            case .templates: TemplatesView(facebook: facebook)
            case .reader: ReaderView(facebook: facebook)
            case .notes:
                if let account = accounts.active {
                    NotesView(account: account)
                }
            }
        }
        .onAppear(perform: applyStartupSettings)
        .onChange(of: accounts.activeID) { oldID, newID in
            facebook.resetForAccount()
            updateWindowFrame(from: oldID, to: newID)
        }
        .onChange(of: facebook.accountName) { _, name in accounts.updateActive(name: name, avatarURL: facebook.accountAvatarURL) }
        .onChange(of: facebook.accountAvatarURL) { _, avatar in accounts.updateActive(name: facebook.accountName, avatarURL: avatar) }
        .onChange(of: facebook.isLoggedIn) { _, isLoggedIn in
            guard facebook.webView != nil else { return }
            accounts.updateActive(name: facebook.accountName, avatarURL: facebook.accountAvatarURL, isLoggedIn: isLoggedIn)
        }
        .onChange(of: facebook.currentURL) { _, url in
            if let destination = FacebookDestination.destination(for: url), selectedTab != destination {
                selectedTab = destination
            }
        }
        .onChange(of: subscriptionFlow.premiumAction) { _, action in
            guard let action else { return }
            subscriptionFlow.clearPremiumAction()
            switch action {
            case .addAccount:
                addAccount()
            case .tryAI:
                activateTool(.summarize)
            case .dockAccount:
                dockBesideCurrent()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndLiveResizeNotification)) { notification in
            guard let window = notification.object as? NSWindow, window == NSApp.keyWindow else { return }
            saveWindowFrame(for: accounts.activeID, window: window)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)) { notification in
            guard let window = notification.object as? NSWindow, window == NSApp.keyWindow else { return }
            saveWindowFrame(for: accounts.activeID, window: window)
        }
        .onDisappear { saveWindowFrame(for: accounts.activeID) }
        .background(keyboardShortcuts)
        .overlay(alignment: .bottomLeading) {
            if sidebarHidden {
                Button { sidebarHidden = false } label: { Label("Show Sidebar", systemImage: "sidebar.left") }
                    .buttonStyle(.borderedProminent).padding(12)
            }
        }
    }

    /// Summarise, Draft, Templates, Reader and Notebook are Premium tools.
    /// Free users are routed to the existing paywall instead of the tool;
    /// subscribed users go straight in. The Subscription entry itself is
    /// never gated — tapping it always opens the paywall directly, whether
    /// to upgrade, switch plans, or just see current status.
    private func activateTool(_ tool: SidebarTool) {
        if tool == .subscription {
            selectedTool = nil
            if isPremium {
                subscriptionFlow.showPremiumActivated()
            } else {
                subscriptionFlow.openSubscription()
            }
            return
        }
        if tool.isPremium && !isPremium {
            subscriptionFlow.openSubscription()
            return
        }
        selectedTool = tool
        switch tool {
        case .summarize: route = .summary
        case .draft: route = .draft
        case .templates: route = .templates
        case .reader: route = .reader
        case .notebook: route = .notes
        case .subscription: break // handled above
        case .sidebar: sidebarHidden = true; selectedTool = nil
        case .settings: route = .settings
        }
    }

    private func openFacebook() {
        accounts.ensureAccount()
        if let startupID = settings.startupAccountID,
           let account = accounts.accounts.first(where: { $0.id == startupID }) {
            accounts.select(account)
        }
        isBrowserOpen = true
        facebook.navigate(to: FacebookViewModel.homeURL)
    }

    private func addAccount() {
        facebook.resetForAccount()
        accounts.addAccount()
        facebook.navigate(to: FacebookViewModel.homeURL)
    }

    private func removeAccount(_ account: FacebookAccount) {
        let wasActive = account.id == accounts.activeID
        if wasActive { facebook.resetForAccount() }

        accounts.remove(account)
        localDataStore.removeData(for: account.id)
        if settings.startupAccountID == account.id {
            settings.startupAccountID = accounts.activeID
        }
        if accounts.accounts.isEmpty {
            isBrowserOpen = false
            selectedTab = .home
        }

        // Removing the view first releases its data store, as required by WebKit.
        Task {
            await Task.yield()
            await FacebookSessionService.removeSession(for: account, retries: 2)
        }
    }

    /// Side-by-side docking is a Premium feature (see SubscriptionView's
    /// "Side-by-side panels" row), so it's gated the same way as the tools.
    private func dockBesideCurrent() {
        guard isPremium else {
            subscriptionFlow.openSubscription()
            return
        }
        guard let window = NSApp.keyWindow else { return }

        if let restoreFrame = preDockWindowFrame {
            preDockWindowFrame = nil
            window.setFrame(restoreFrame, display: true, animate: false)
            saveWindowFrame(for: accounts.activeID, window: window)
            return
        }

        guard let screen = window.screen ?? NSScreen.main else { return }
        saveWindowFrame(for: accounts.activeID, window: window)
        preDockWindowFrame = window.frame

        let visible = screen.visibleFrame
        let gap: CGFloat = 6
        let frame = NSRect(
            x: visible.midX + gap / 2,
            y: visible.minY,
            width: visible.width / 2 - gap / 2,
            height: visible.height
        )
        window.setFrame(frame, display: true, animate: true)
    }

    private func signOut(_ account: FacebookAccount) {
        guard account.id == accounts.activeID,
              clearingSessionAccountID == nil else { return }

        // Detach the WebView first so WebKit releases this account's data store.
        clearingSessionAccountID = account.id
        facebook.stopLoading()
        facebook.resetForAccount()

        // Clear the Facebook session, then remove this account from the rail.
        Task {
            await FacebookSessionService.removeSession(for: account, retries: 2)
            localDataStore.removeData(for: account.id)

            if settings.startupAccountID == account.id {
                settings.startupAccountID = nil
            }

            accounts.remove(account)
            clearingSessionAccountID = nil
            webViewGeneration = UUID()
            selectedTab = .home

            if let nextAccount = accounts.active {
                if settings.startupAccountID == nil {
                    settings.startupAccountID = nextAccount.id
                }
                facebook.navigate(to: FacebookViewModel.homeURL)
            } else {
                isBrowserOpen = false
            }
        }
    }

    private func navigate(_ destination: FacebookDestination) {
        selectedTab = destination
        facebook.navigate(to: destination)
    }

    private var sidebarWidth: CGFloat {
        if settings.railWidth == .iconsOnly { return settings.expandOnHover && railHovered ? 232 : 68 }
        return settings.railWidth == .compact ? 208 : 232
    }

    private func applyStartupSettings() {
        guard isBrowserOpen else { return }
        accounts.ensureAccount()
        DispatchQueue.main.async { restoreWindowFrame(for: accounts.activeID) }
        let destination: URL
        switch settings.startup {
        case .lastSession:
            let savedURL = UserDefaults.standard.string(forKey: "facebook.lastURL").flatMap(URL.init(string:))
            destination = savedURL.flatMap(FacebookViewModel.restorableURL) ?? FacebookViewModel.homeURL
        case .home: destination = FacebookDestination.home.url
        case .messages:
            destination = settings.enabledTabs.contains(.messages)
                ? FacebookDestination.messages.url
                : FacebookDestination.home.url
        }
        facebook.navigate(to: destination)
    }

    private func updateWindowFrame(from oldID: UUID?, to newID: UUID?) {
        guard settings.rememberWindowSize, let window = NSApp.keyWindow else { return }
        // Docking is window-level state. Switching accounts must not replace the
        // docked frame or overwrite the exact frame captured for restoration.
        guard preDockWindowFrame == nil else { return }
        // A removed account must not have its just-deleted window state recreated
        // by the active-account change observer.
        if let oldID, accounts.accounts.contains(where: { $0.id == oldID }) {
            saveWindowFrame(for: oldID, window: window)
        }
        restoreWindowFrame(for: newID, window: window)
    }

    private func restoreWindowFrame(for accountID: UUID?, window: NSWindow? = NSApp.keyWindow) {
        guard settings.rememberWindowSize, let window, let accountID,
              let frame = windowFrameStore.restoreFrame(for: accountID, on: NSScreen.screens) else { return }
        window.setFrame(frame, display: true, animate: true)
    }

    private func saveWindowFrame(for accountID: UUID?, window: NSWindow? = NSApp.keyWindow) {
        guard settings.rememberWindowSize, preDockWindowFrame == nil,
              let accountID, let window else { return }
        windowFrameStore.save(frame: window.frame, for: accountID)
    }

    private var keyboardShortcuts: some View {
        HStack {
            Button("") { activateTool(.summarize) }.keyboardShortcut("j", modifiers: .command)
            Button("") { activateTool(.draft) }.keyboardShortcut("k", modifiers: .command)
            Button("") { facebook.reload() }.keyboardShortcut("r", modifiers: .command)
            Button("") { sidebarHidden.toggle() }.keyboardShortcut("s", modifiers: [.command, .option])
        }
        .frame(width: 0, height: 0).opacity(0)
    }
}
