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
    enum Phase {
        case splash
        case main
    }

    @Published private(set) var phase: Phase = .splash
    @Published private(set) var progress: Double = 0

    private var started = false

    func start(storeKit: StoreKitService) async {
        guard !started else { return }
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
        phase = .main
    }
}
