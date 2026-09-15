import SwiftUI

struct RootView: View {
    @ObservedObject var settings: SettingsViewModel
    @StateObject private var accounts = FacebookAccountsViewModel()
    @StateObject private var facebook = FacebookViewModel()
    @State private var route: OverlayRoute?
    @State private var selectedTab: FacebookDestination = .home
    @State private var railHovered = false
    @State private var isBrowserOpen = false

    var body: some View {
        Group {
            if isBrowserOpen { mainContent }
            else { FacebookChooserView(openFacebook: openFacebook) }
        }
        .preferredColorScheme(.dark)
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            SidebarView(
                settings: settings,
                accounts: accounts,
                isLoggedIn: facebook.isLoggedIn,
                selectedTab: $selectedTab,
                showLabels: settings.railWidth != .iconsOnly || railHovered,
                navigate: navigate,
                show: { route = $0 },
                openReader: { Task { await facebook.openReader() } },
                addAccount: addAccount
            )
            .frame(width: sidebarWidth)
            .onHover { railHovered = $0 }

            Divider()

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
        .sheet(item: $route) { route in
            switch route {
            case .settings:
                SettingsView(settings: settings, accounts: accounts) { account in
                    accounts.select(account)
                    facebook.navigate(to: FacebookViewModel.homeURL)
                }
            case .tabs: EditTabsView(settings: settings)
            case .summary: SummaryView(facebook: facebook)
            case .draft: DraftView(facebook: facebook)
            }
        }
        .sheet(item: $facebook.readerArticle) { article in
            ReaderView(article: article, facebook: facebook)
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
        .background(keyboardShortcuts)
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

    private func navigate(_ destination: FacebookDestination) {
        selectedTab = destination
        facebook.readerArticle = nil
        facebook.navigate(to: destination)
    }

    private var sidebarWidth: CGFloat {
        if settings.railWidth == .iconsOnly { return settings.expandOnHover && railHovered ? 232 : 68 }
        return settings.railWidth == .compact ? 208 : 232
    }

    private func applyStartupSettings() {
        guard isBrowserOpen else { return }
        let destination: URL
        switch settings.startup {
        case .lastSession:
            destination = UserDefaults.standard.string(forKey: "facebook.lastURL").flatMap(URL.init(string:)) ?? FacebookViewModel.homeURL
        case .home: destination = FacebookDestination.home.url
        case .messages: destination = FacebookDestination.messages.url
        }
        facebook.navigate(to: destination)
    }

    private func updateWindowFrame(from oldID: UUID?, to newID: UUID?) {
        guard settings.rememberWindowSize, let window = NSApp.keyWindow else { return }
        if let oldID {
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "facebook.window.\(oldID)")
        }
        guard let newID,
              let saved = UserDefaults.standard.string(forKey: "facebook.window.\(newID)") else { return }
        let frame = NSRectFromString(saved)
        if frame.width > 500, frame.height > 400 { window.setFrame(frame, display: true, animate: true) }
    }

    private var keyboardShortcuts: some View {
        HStack {
            Button("") { route = .summary }.keyboardShortcut("j", modifiers: .command)
            Button("") { route = .draft }.keyboardShortcut("k", modifiers: .command)
            Button("") { facebook.reload() }.keyboardShortcut("r", modifiers: .command)
        }
        .frame(width: 0, height: 0).opacity(0)
    }
}

extension ReaderArticle: Identifiable {
    var id: String { title + source + String(text.hashValue) }
}
