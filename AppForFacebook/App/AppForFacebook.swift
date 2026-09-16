import SwiftUI
import CoreServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var launchedAsLoginItem = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return }
        launchedAsLoginItem = event.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil
    }
}

@main
struct AppForFacebookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsViewModel()
    @State private var appliedLaunchSettings = false

    var body: some Scene {
        Window("App for Facebook", id: "main") {
            RootView(settings: settings)
                .preferredColorScheme(.dark)
                .onChange(of: settings.keepWindowAbove) { _, enabled in
                    NSApp.windows.forEach { $0.level = enabled ? .floating : .normal }
                }
                .onAppear {
                    NSApp.windows.forEach { $0.level = settings.keepWindowAbove ? .floating : .normal }
                    guard !appliedLaunchSettings else { return }
                    appliedLaunchSettings = true
                    if appDelegate.launchedAsLoginItem && settings.showInMenuBar && settings.startHidden {
                        DispatchQueue.main.async { NSApp.windows.forEach { $0.orderOut(nil) } }
                    }
                }
        }
        .defaultSize(width: 1320, height: 820)
        .windowResizability(.contentMinSize)

    }
}
