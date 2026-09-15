import SwiftUI

@main
struct NorthWindSocialApp: App {
    @StateObject private var settings = SettingsViewModel()
    @State private var appliedLaunchSettings = false

    var body: some Scene {
        WindowGroup("App for Facebook") {
            RootView(settings: settings)
                .preferredColorScheme(.dark)
                .onChange(of: settings.keepWindowAbove) { _, enabled in
                    NSApp.windows.forEach { $0.level = enabled ? .floating : .normal }
                }
                .onAppear {
                    NSApp.windows.forEach { $0.level = settings.keepWindowAbove ? .floating : .normal }
                    guard !appliedLaunchSettings else { return }
                    appliedLaunchSettings = true
                    if settings.launchAtLogin && settings.showInMenuBar && settings.startHidden {
                        DispatchQueue.main.async { NSApp.windows.forEach { $0.orderOut(nil) } }
                    }
                }
        }
        .defaultSize(width: 1320, height: 820)

    }
}
