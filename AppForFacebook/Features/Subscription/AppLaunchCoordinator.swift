//
//  AppLaunchCoordinator.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//
import Foundation
import Combine
@MainActor
final class AppLaunchCoordinator: ObservableObject {
    enum Phase: Equatable {
        case splash
        case onboarding
        case main
    }

    @Published private(set) var phase: Phase = .splash
    @Published private(set) var progress: Double = 0

    private static let onboardingCompletedKey = "app.onboarding.completed.v1"
    private let defaults: UserDefaults
    private var started = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Performs the initial launch sequence and reports whether this call
    /// completed it. Callers can use the result for one-time post-launch UI.
    func start(storeKit: StoreKitService) async -> Bool {
        guard !started else { return false }
        started = true

        progress = 0.08

        // Real startup work: fetch StoreKit products.
        async let prepareStore: Void = storeKit.prepare()

        // Smoothly animate the visible progress while startup work runs.
        for step in 1...8 {
            try? await Task.sleep(for: .milliseconds(85))
            progress = min(0.82, Double(step) * 0.10)
        }

        await prepareStore
        progress = 0.92

        try? await Task.sleep(for: .milliseconds(120))
        progress = 1.0

        try? await Task.sleep(for: .milliseconds(160))
        let onboardingCompleted = defaults.bool(forKey: Self.onboardingCompletedKey)
        let isExistingUser = FacebookAccountsViewModel.hasSavedAccounts

        // Users from versions that predate the onboarding flag should not be
        // treated as new when they already have a saved Facebook account.
        if isExistingUser && !onboardingCompleted {
            defaults.set(true, forKey: Self.onboardingCompletedKey)
        }

        phase = (onboardingCompleted || isExistingUser) ? .main : .onboarding
        return true
    }

    func completeOnboarding() {
        guard phase == .onboarding else { return }
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        phase = .main
    }
}
