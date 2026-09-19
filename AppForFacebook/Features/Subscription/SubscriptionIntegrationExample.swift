//
//  SubscriptionIntegrationExample.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//

import SwiftUI

/// Use this pattern in your existing app.
/// Do NOT create another RootView if you already have one.
struct AppSubscriptionContainer<MainContent: View>: View {
    @StateObject private var storeKit = StoreKitService()
    @StateObject private var launch = AppLaunchCoordinator()
    @StateObject private var subscriptionFlow = SubscriptionFlowCoordinator()

    let mainContent: (StoreKitService, SubscriptionFlowCoordinator) -> MainContent

    var body: some View {
        ZStack {
            switch launch.phase {
            case .splash:
                SplashView(progress: launch.progress)

            case .main:
                mainContent(storeKit, subscriptionFlow)
            }

            if let screen = subscriptionFlow.screen {
                switch screen {
                case .paywall:
                    SubscriptionView(
                        storeKit: storeKit,
                        onClose: {
                            subscriptionFlow.close()
                        },
                        onPremiumActivated: {
                            subscriptionFlow.showPremiumActivated()
                        }
                    )

                case .premiumActivated:
                    PremiumActivatedView(
                        onBackToDesk: {
                            subscriptionFlow.close()
                        },
                        onAddAccount: {
                            // Connect to your existing Add Account action.
                            subscriptionFlow.close()
                        },
                        onTryAI: {
                            // Connect to your existing AI/Draft action.
                            subscriptionFlow.close()
                        },
                        onDockAccount: {
                            // Connect to your existing Dock Account action.
                            subscriptionFlow.close()
                        }
                    )
                }
            }
        }
        .task {
            await launch.start(storeKit: storeKit)
        }
    }
}

/*
 Example @main integration:

 @main
 struct AppForFacebookApp: App {
     var body: some Scene {
         WindowGroup {
             AppSubscriptionContainer { storeKit, subscriptionFlow in
                 RootView()
                     .environmentObject(storeKit)
                     .environmentObject(subscriptionFlow)
             }
         }
     }
 }

 Existing sidebar Subscription button:

 @EnvironmentObject var subscriptionFlow: SubscriptionFlowCoordinator

 Button("Subscription") {
     subscriptionFlow.openSubscription()
 }

 Premium feature gating:

 @EnvironmentObject var storeKit: StoreKitService
 @EnvironmentObject var subscriptionFlow: SubscriptionFlowCoordinator

 func openPremiumFeature() {
     guard storeKit.entitlementState == .premium else {
         subscriptionFlow.openSubscription()
         return
     }

     // Continue with the premium feature.
 }
*/
