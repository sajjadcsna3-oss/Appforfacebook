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
    @StateObject private var storeKit = StoreKitService()
    @StateObject private var launch = AppLaunchCoordinator()
    @StateObject private var subscriptionFlow = SubscriptionFlowCoordinator()
    @State private var appliedLaunchSettings = false

    var body: some Scene {
        Window("App for Facebook", id: "main") {
            ZStack {
                switch launch.phase {
                case .splash:
                    SplashView(progress: launch.progress)
                case .main:
                    RootView(settings: settings)
                        .environmentObject(storeKit)
                        .environmentObject(subscriptionFlow)
                }

                // Paywall / post-purchase overlay, reusing the existing
                // subscription views and StoreKit entitlement state.
                if let screen = subscriptionFlow.screen {
                    switch screen {
                    case .paywall:
                        SubscriptionView(
                            storeKit: storeKit,
                            onClose: { subscriptionFlow.close() },
                            onPremiumActivated: { subscriptionFlow.showPremiumActivated() }
                        )
                    case .premiumActivated:
                        PremiumActivatedView(
                            onBackToDesk: { subscriptionFlow.close() },
                            onAddAccount: { subscriptionFlow.perform(.addAccount) },
                            onTryAI: { subscriptionFlow.perform(.tryAI) },
                            onDockAccount: { subscriptionFlow.perform(.dockAccount) }
                        )
                    }
                }
            }
            .task { await launch.start(storeKit: storeKit) }
            .onChange(of: storeKit.entitlementState) { oldState, state in
                if oldState != .premium,
                   state == .premium,
                   subscriptionFlow.screen == .paywall {
                    subscriptionFlow.showPremiumActivated()
                } else if state != .premium,
                          subscriptionFlow.screen == .premiumActivated {
                    subscriptionFlow.close()
                }
            }
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
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
    }
}
