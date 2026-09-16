import SwiftUI

struct RootView: View {
    @ObservedObject var settings: SettingsViewModel
    @StateObject private var accounts = FacebookAccountsViewModel()
    @StateObject private var facebook = FacebookViewModel()
    @State private var route: OverlayRoute?
    @State private var selectedTab: FacebookDestination = .home
    @State private var railHovered = false
    @State private var isBrowserOpen = false
    @State private var sidebarHidden = false
    @State private var toolMessage: String?
    @State private var selectedTool: SidebarTool?

    var body: some View {
        Group {
            if isBrowserOpen { mainContent }
            else { FacebookChooserView(openFacebook: openFacebook) }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 620)
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
                unreadCounts: facebook.unreadCounts
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
                    if let account = accounts.active {
                        FacebookWebView(account: account, viewModel: facebook).id(account.id)
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
        .alert("Tools", isPresented: Binding(
            get: { toolMessage != nil },
            set: { if !$0 { toolMessage = nil } }
        )) { Button("OK", role: .cancel) { toolMessage = nil } } message: {
            Text(toolMessage ?? "")
        }
    }

    private func activateTool(_ tool: SidebarTool) {
        selectedTool = tool
        switch tool {
        case .summarize: route = .summary
        case .draft: route = .draft
        case .pictureInPicture:
            Task { toolMessage = await facebook.togglePictureInPicture(); selectedTool = nil }
        case .templates: route = .templates
        case .reader: route = .reader
        case .notebook: route = .notes
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
        if accounts.accounts.isEmpty {
            isBrowserOpen = false
            selectedTab = .home
        }

        // Removing the view first releases its data store, as required by WebKit.
        DispatchQueue.main.async {
            removeSessionWhenAvailable(for: account)
        }
    }

    private func dockBesideCurrent() {
        guard let window = NSApp.keyWindow,
              let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let gap: CGFloat = 6
        let frame = NSRect(
            x: visible.midX + gap / 2,
            y: visible.minY,
            width: visible.width / 2 - gap / 2,
            height: visible.height
        )
        window.setFrame(frame, display: true, animate: true)
        saveWindowFrame(for: accounts.activeID, window: window)
    }

    private func signOut(_ account: FacebookAccount) {
        guard account.id == accounts.activeID else { return }
        facebook.resetForAccount()
        accounts.updateActive(name: account.name, avatarURL: account.avatarURL, isLoggedIn: false)
        DispatchQueue.main.async {
            FacebookSessionService.removeSession(for: account) { _ in
                DispatchQueue.main.async {
                    facebook.navigate(to: FacebookViewModel.homeURL)
                }
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
        DispatchQueue.main.async { restoreWindowFrame(for: accounts.activeID) }
        let destination: URL
        switch settings.startup {
        case .lastSession:
            destination = UserDefaults.standard.string(forKey: "facebook.lastURL").flatMap(URL.init(string:)) ?? FacebookViewModel.homeURL
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
        saveWindowFrame(for: oldID, window: window)
        restoreWindowFrame(for: newID, window: window)
    }

    private func restoreWindowFrame(for accountID: UUID?, window: NSWindow? = NSApp.keyWindow) {
        guard settings.rememberWindowSize, let window, let accountID,
              let saved = UserDefaults.standard.string(forKey: "facebook.window.\(accountID)") else { return }
        let frame = NSRectFromString(saved)
        guard frame.width > 500, frame.height > 400 else { return }
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        if visibleFrames.contains(where: { $0.intersects(frame) }) {
            window.setFrame(frame, display: true, animate: true)
        } else if let screen = window.screen ?? NSScreen.main {
            var adjusted = frame
            adjusted.size.width = min(adjusted.width, screen.visibleFrame.width)
            adjusted.size.height = min(adjusted.height, screen.visibleFrame.height)
            adjusted.origin.x = screen.visibleFrame.midX - adjusted.width / 2
            adjusted.origin.y = screen.visibleFrame.midY - adjusted.height / 2
            window.setFrame(adjusted, display: true, animate: false)
        }
    }

    private func saveWindowFrame(for accountID: UUID?, window: NSWindow? = NSApp.keyWindow) {
        guard settings.rememberWindowSize, let accountID, let window else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "facebook.window.\(accountID)")
    }

    private func removeSessionWhenAvailable(for account: FacebookAccount, retries: Int = 2) {
        FacebookSessionService.removeSession(for: account) { error in
            guard error != nil, retries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                removeSessionWhenAvailable(for: account, retries: retries - 1)
            }
        }
    }

    private var keyboardShortcuts: some View {
        HStack {
            Button("") { route = .summary }.keyboardShortcut("j", modifiers: .command)
            Button("") { route = .draft }.keyboardShortcut("k", modifiers: .command)
            Button("") { facebook.reload() }.keyboardShortcut("r", modifiers: .command)
            Button("") { Task { toolMessage = await facebook.togglePictureInPicture() } }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("") { sidebarHidden.toggle() }.keyboardShortcut("s", modifiers: [.command, .option])
        }
        .frame(width: 0, height: 0).opacity(0)
    }
}
