import SwiftUI

struct EditTabsView: View {
    @ObservedObject var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(icon: "EditIcon", title: "Edit Facebook Tabs")
            Text("Show, hide, or drag tabs into the order you prefer.").foregroundStyle(.secondary)
            List {
                ForEach(settings.tabOrder) { destination in
                    Toggle(isOn: Binding(
                        get: { settings.enabledTabs.contains(destination) },
                        set: { enabled in
                            if enabled { settings.enabledTabs.insert(destination) }
                            else { settings.enabledTabs.remove(destination) }
                        }
                    )) { Label { Text(destination.title) } icon: { Image(destination.icon) } }
                }
                .onMove(perform: settings.moveTabs)
            }
            .frame(height: 330)
            HStack { Text("Hidden tabs are still available inside Facebook.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Done") { dismiss() }.buttonStyle(.borderedProminent) }
        }
        .padding(20).frame(width: 560, height: 480)
    }
}
