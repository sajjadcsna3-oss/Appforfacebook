import SwiftUI

struct SidebarView: View {
    @State private var menuAccountID: UUID?
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var accounts: FacebookAccountsViewModel
    @Binding var selectedTab: FacebookDestination
    let isLoggedIn: Bool
    let showLabels: Bool
    let navigate: (FacebookDestination) -> Void
    let show: (OverlayRoute) -> Void
    let addAccount: () -> Void
    let removeAccount: (FacebookAccount) -> Void
    let dockBesideCurrent: () -> Void
    let reloadSession: () -> Void
    let signOut: (FacebookAccount) -> Void
    let activateTool: (SidebarTool) -> Void
    let selectedTool: SidebarTool?
    let unreadCounts: [FacebookDestination: Int]
    let isPremium: Bool
    let onUpgrade: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            sidebarContent
            ScrollView(.vertical) { sidebarContent }
        }
        .background(Color.sidebarBackground)
        .animation(.easeInOut(duration: 0.18), value: showLabels)
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountSection
            Divider()
            .padding(.vertical, 4)

            if settings.toolsAtTop { tools; Divider().padding(.vertical, 4) }
            navigation
            if !settings.toolsAtTop {
                Spacer(minLength: 16)
                Divider().padding(.vertical, 4)
                tools
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionTitle("ACCOUNTS")
                Spacer()
                Button(action: addAccount) {
                    Image(systemName: "plus.circle").foregroundStyle(Color.facebookBlue)
                }
                .buttonStyle(.plain)
                .help("Add Facebook account")
            }

            if availableAccounts.count > 3 {
                ScrollView(.vertical) { accountList }
                    .frame(height: 150)
            } else {
                accountList
            }
        }
    }

    private var subscriptionButton: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 8) {
                Image("workspace_premium")
                    .renderingMode(.template)
                    .foregroundStyle(Color(red: 0.89, green: 0.69, blue: 0.28))
                    .frame(width: 20)

                if showLabels {
                    Text("Subscription")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)

                    Spacer(minLength: 2)

                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.18, green: 0.14, blue: 0.07))
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(Color(red: 0.96, green: 0.74, blue: 0.30))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.89, green: 0.69, blue: 0.28))
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(Color(red: 0.20, green: 0.16, blue: 0.08).opacity(0.62))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.58, green: 0.42, blue: 0.13), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(showLabels ? "" : "Subscription")
    }

    private var accountList: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(availableAccounts) { account in
                accountButton(account)
            }
        }
    }

    private var availableAccounts: [FacebookAccount] {
        accounts.accounts
    }

    private func accountButton(_ account: FacebookAccount) -> some View {
        Button {
            if account.id == accounts.activeID {
                menuAccountID = menuAccountID == account.id ? nil : account.id
            } else {
                menuAccountID = nil
                accounts.select(account)
            }
        } label: {
            HStack(spacing: 10) {
                accountAvatar(account)
                if showLabels {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name ?? "Sign in to Facebook").fontWeight(.semibold).lineLimit(1)
                        Text("Facebook").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .background(account.id == accounts.activeID ? Color.facebookBlue.opacity(0.12) : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(account.id == accounts.activeID ? Color.facebookBlue.opacity(0.45) : .clear)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: Binding(
                get: { menuAccountID == account.id },
                set: { if !$0 { menuAccountID = nil } }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .trailing
        ) {
            accountMenu(for: account)
        }
        .contextMenu {
            Button("Remove Account", role: .destructive) {
                removeAccount(account)
            }
        }
    }

    private func accountMenu(for account: FacebookAccount) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                accountAvatar(account)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.name ?? "Facebook Account")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(accountSubtitle(account))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
            }
            .padding(10)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            menuDivider
            // Side-by-side panels is a Premium feature.
            accountMenuButton("Dock beside current", systemImage: "rectangle.split.2x1", locked: !isPremium) {
                dockBesideCurrent()
            }
            accountMenuButton("Notes for this account", systemImage: "note.text") {
                show(.notes)
            }
            accountMenuButton("Tabs for this account…", systemImage: "slider.horizontal.3") {
                show(.tabs)
            }
            menuDivider
            accountMenuButton("Reload session", systemImage: "arrow.clockwise") {
                reloadSession()
            }
            accountMenuButton("Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
                signOut(account)
            }
        }
        .padding(7)
        .frame(width: 258)
        .background(Color(red: 0.115, green: 0.125, blue: 0.145))
    }

    private func accountSubtitle(_ account: FacebookAccount) -> String {
        var subtitle = "Facebook"
        if account.id == accounts.activeID, isLoggedIn,
           let total = unreadCounts.values.reduce(0, +) as Int?, total > 0 {
            subtitle += " · \(total) unread"
        }
        return subtitle
    }

    private var menuDivider: some View {
        Divider().padding(.horizontal, 4).padding(.vertical, 7)
    }

    private func accountMenuButton(_ title: String, systemImage: String, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            menuAccountID = nil
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title).font(.system(size: 13))
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.facebookBlue)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 37)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func accountAvatar(_ account: FacebookAccount) -> some View {
        if let avatarURL = account.avatarURL {
            AsyncImage(url: avatarURL) { image in image.resizable().scaledToFill() } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
            }
            .frame(width: 34, height: 34).clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(account.id == accounts.activeID && isLoggedIn ? Color.facebookBlue : .secondary)
                .frame(width: 34, height: 34)
        }
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("TABS")
            ForEach(settings.visibleTabs) { destination in
                sidebarButton(destination.title, icon: destination.icon, selected: selectedTab == destination) {
                    navigate(destination)
                }
                .overlay(alignment: .topTrailing) {
                    if settings.showBadges && isLoggedIn && accounts.active != nil,
                       let count = unreadCounts[destination], count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.facebookBlue)
                            .clipShape(Capsule())
                            .padding(.trailing, 5)
                            .padding(.top, 9)
                    }
                }
            }
            sidebarButton("Edit Tabs", icon: "EditIcon") { show(.tabs) }
        }
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionTitle("TOOLS")
            ForEach(SidebarTool.allCases.filter { $0 != .subscription }) { tool in
                sidebarButton(tool.title, icon: tool.icon, systemIcon: tool.usesSystemIcon,
                              selected: selectedTool == tool,
                              shortcut: toolShortcut(for: tool),
                              locked: tool.isPremium && !isPremium) { activateTool(tool) }
            }
            if !isPremium {
                subscriptionButton
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Group { if showLabels { Text(title).font(.caption2.bold()).foregroundStyle(.secondary).padding(.leading, 10).padding(.vertical, 4) } }
    }

    private func toolShortcut(for tool: SidebarTool) -> String? {
        switch tool {
        case .summarize: "⌘J"
        case .draft: "⌘K"
        case .templates, .reader, .notebook, .subscription, .sidebar, .settings: nil
        }
    }

    private func sidebarButton(_ title: String, icon: String, systemIcon: Bool = false, selected: Bool = false, shortcut: String? = nil, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    (systemIcon ? Image(systemName: icon) : Image(icon))
                        .renderingMode(.template)
                        .foregroundStyle(selected ? Color.accentBlue : .secondary)
                        .frame(width: 20)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.facebookBlue)
                            .offset(x: 7, y: 2)
                    }
                }
                if showLabels {
                    Text(title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer()
                    if let shortcut {
                        Text(shortcut)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).frame(height: 36)
            .background(selected ? Color.facebookBlue.opacity(0.22) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? .white : .secondary)
        .help(showLabels ? "" : title)
    }
}
