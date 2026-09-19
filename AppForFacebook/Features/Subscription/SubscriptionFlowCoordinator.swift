//
//  SubscriptionFlowCoordinator.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//
import SwiftUI
import Combine
@MainActor
final class SubscriptionFlowCoordinator: ObservableObject {
    enum Screen: Identifiable, Equatable {
        case paywall
        case premiumActivated

        var id: Int {
            switch self {
            case .paywall: 0
            case .premiumActivated: 1
            }
        }
    }

    enum PremiumAction: Equatable {
        case addAccount
        case tryAI
        case dockAccount
    }

    @Published var screen: Screen?
    @Published var premiumAction: PremiumAction?

    func openSubscription() {
        screen = .paywall
    }

    func showPremiumActivated() {
        screen = .premiumActivated
    }

    func close() {
        screen = nil
    }

    func perform(_ action: PremiumAction) {
        screen = nil
        premiumAction = action
    }

    func clearPremiumAction() {
        premiumAction = nil
    }
}
