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

    /// The Product ID configured in StoreProducts.plist.
    var productID: String {
        switch self {
        case .monthly:
            StoreConfiguration.monthlyProductID
        case .annual:
            StoreConfiguration.annualProductID
        case .lifetime:
            StoreConfiguration.lifetimeProductID
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
