//
//  SwiftUIView.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//
import Foundation

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case monthly
    case annual
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .annual: "Annual"
        case .lifetime: "Lifetime"
        }
    }

    // Replace with the exact IDs created in App Store Connect.
    var productID: String {
        switch self {
        case .monthly:
            "com.yourcompany.appforfacebook.premium.monthly"
        case .annual:
            "com.yourcompany.appforfacebook.premium.annual"
        case .lifetime:
            "com.yourcompany.appforfacebook.premium.lifetime"
        }
    }

    var priceSuffix: String {
        switch self {
        case .monthly: "/ month"
        case .annual: "/ year"
        case .lifetime: "once"
        }
    }
}

