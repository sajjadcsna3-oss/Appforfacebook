import SwiftUI

struct SidebarView: View {
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var accounts: FacebookAccountsViewModel
    let isLoggedIn: Bool
    @Binding var selectedTab: FacebookDestination
    let showLabels: Bool
    let navigate: (FacebookDestination) -> Void
    let show: (OverlayRoute) -> Void
    let openReader: () -> Void
    let addAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountSection
            Divider().padding(.vertical, 4)

            if settings.toolsAtTop { tools; Divider().padding(.vertical, 4) }
            navigation
            if !settings.toolsAtTop { Spacer(minLength: 16); tools }
        }
        .padding(10)
        .background(Color.sidebarBackground)
        .animation(.easeInOut(duration: 0.18), value: showLabels)
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
            accounts.select(account)
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
            }
            sidebarButton("Edit Tabs", icon: "EditIcon") { show(.tabs) }
        }
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionTitle("TOOLS")
            ForEach(SidebarTool.allCases) { tool in
                sidebarButton(tool.title, icon: tool.icon) {
                    switch tool {
                    case .summarize: show(.summary)
                    case .draft: show(.draft)
                    case .reader: openReader()
                    case .settings: show(.settings)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Group { if showLabels { Text(title).font(.caption2.bold()).foregroundStyle(.secondary).padding(.leading, 10).padding(.vertical, 4) } }
    }

    private func sidebarButton(_ title: String, icon: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(icon).frame(width: 20)
                if showLabels { Text(title).lineLimit(1); Spacer() }
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
