import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var accounts: FacebookAccountsViewModel
    let selectAccount: (FacebookAccount) -> Void
    @State private var section: SettingsSection = .rail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("SettingIcon").foregroundStyle(.secondary)
                Text("Settings").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18).frame(height: 48)
            Divider()

            HStack(spacing: 0) {
                List(SettingsSection.allCases, selection: $section) { item in
                    Label { Text(item.rawValue) } icon: { Image(item.icon) }.tag(item)
                }
                .listStyle(.sidebar)
                .frame(width: 172)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        settingsContent
                        if let message = settings.statusMessage {
                            Text(message).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16).frame(height: 54)
        }
        .frame(width: 720, height: 540)
    }

    @ViewBuilder private var settingsContent: some View {
        switch section {
        case .rail:
            settingsCard("Rail behaviour", icon: "RailIcon", description: "The rail is the only chrome — these control how much of it you see.") {
                Picker("Width", selection: $settings.railWidth) {
                    ForEach(RailWidth.allCases) { Text($0.rawValue).tag($0) }
                }
                Divider()
                Toggle("Expand to labels on hover", isOn: $settings.expandOnHover)
                Toggle("Show unread badges on icons", isOn: $settings.showBadges)
                Toggle("Put tools at the top instead", isOn: $settings.toolsAtTop)
            }
        case .accounts:
            settingsCard(nil, icon: nil, description: nil) {
                ForEach(Array(accountList.enumerated()), id: \.element.id) { index, account in
                    HStack(spacing: 10) {
                        settingsAvatar(account)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name ?? "Facebook account").fontWeight(.medium)
                            Text(account.isLoggedIn ? "Facebook · signed in" : "Facebook · sign-in required")
                                .font(.caption).foregroundStyle(account.isLoggedIn ? Color.secondary : Color.red)
                        }
                        Spacer()
                        if account.id == accounts.activeID {
                            Text("ACTIVE").font(.caption2.bold()).foregroundStyle(.green)
                        } else if account.isLoggedIn {
                            Menu { Button("Use this account") { selectAccount(account) } } label: {
                                Image(systemName: "ellipsis")
                            }.menuStyle(.borderlessButton)
                        } else {
                            Button("Sign in") { selectAccount(account); dismiss() }.buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 5)
                    if index < accountList.count - 1 { Divider() }
                }
                if accountList.isEmpty { Text("No Facebook accounts added.").foregroundStyle(.secondary) }
                if let warning = accounts.persistenceWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        case .window:
            settingsCard("Window", icon: "WindowIcon", description: "Control how the main app window behaves while you work.") {
                Toggle("Keep window above other apps", isOn: $settings.keepWindowAbove)
                Toggle("Remember window size per account", isOn: $settings.rememberWindowSize)
            }
            settingsCard("Menu bar", icon: "WindowIcon", description: "Keep App for Facebook reachable from the macOS menu bar for quick access.") {
                Toggle("Show app in the menu bar", isOn: $settings.showInMenuBar)
            }
        case .startup:
            settingsCard("Startup destination", icon: "StartupIcon", description: "Choose which tab the app opens. Hidden tabs fall back to Home.") {
                Picker("Open on launch", selection: $settings.startup) {
                    ForEach(StartupDestination.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Account to open", selection: $settings.startupAccountID) {
                    Text("Current account").tag(nil as UUID?)
                    ForEach(accounts.accounts.filter(\.isLoggedIn), id: \.id) { account in
                        Text(account.name ?? "Facebook account").tag(account.id as UUID?)
                    }
                }
            }
            settingsCard("Login item", icon: "StartupIcon", description: nil) {
                Toggle("Launch App for Facebook at login", isOn: $settings.launchAtLogin)
                Toggle("Start hidden in the menu bar", isOn: $settings.startHidden)
                    .disabled(!settings.launchAtLogin || !settings.showInMenuBar)
            }
        case .privacy:
            settingsCard("Privacy", icon: "Privacy", description: "Facebook credentials stay on facebook.com. WebKit stores each account's cookies in its own persistent session.") {
                Label("Passwords never pass through this app", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                Divider()
                Link(destination: URL(string: "https://sites.google.com/view/app-for-netflix/privacy-policy")!) {
                    Label("Privacy Policy", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://sites.google.com/view/app-for-netflix/terms-of-use")!) {
                    Label("Terms of Use", systemImage: "arrow.up.right.square")
                }
            }
        case .shortcuts:
            settingsCard("Keyboard shortcuts", icon: "ShortcutsIcon", description: "Quick actions available from the Facebook window.") {
                shortcut("Summarize", keys: "⌘J")
                Divider(); shortcut("Draft", keys: "⌘K")
                Divider(); shortcut("Reload Facebook", keys: "⌘R")
            }
        }
    }

    private func settingsCard<Content: View>(_ title: String?, icon: String?, description: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label { Text(title) } icon: { Image(icon ?? "SettingIcon") }.font(.headline)
            }
            if let description { Text(description).font(.caption).foregroundStyle(.secondary) }
            if title != nil || description != nil { Divider() }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.035))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func shortcut(_ title: String, keys: String) -> some View {
        HStack { Text(title); Spacer(); Text(keys).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
    }

    private var accountList: [FacebookAccount] { accounts.accounts }

    @ViewBuilder private func settingsAvatar(_ account: FacebookAccount) -> some View {
        if let url = account.avatarURL {
            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
            }.frame(width: 34, height: 34).clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary).frame(width: 34, height: 34)
        }
    }
}
