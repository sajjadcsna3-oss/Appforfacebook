//
//  StoreKitService.swift
//  AppForFacebook
//
//  Created by Mac Mini on 17/09/2026.
//

import Foundation
import StoreKit
import Combine
@MainActor
final class StoreKitService: ObservableObject {
    enum EntitlementState: Equatable {
        case loading
        case free
        case premium
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var entitlementState: EntitlementState = .loading
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var transactionTask: Task<Void, Never>?

    init() {
        transactionTask = listenForTransactions()
    }

    deinit {
        transactionTask?.cancel()
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(
                for: SubscriptionPlan.allCases.map(\.productID)
            )
        } catch {
            errorMessage = "Unable to load App Store products."
        }
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func displayPrice(for plan: SubscriptionPlan) -> String {
        product(for: plan)?.displayPrice ?? "—"
    }

    /// Raw (unformatted) price for a plan, straight from StoreKit. Used to do
    /// real math (e.g. an annual plan's monthly-equivalent, or comparing it
    /// against 12x the monthly plan) rather than hardcoding marketing numbers.
    func rawPrice(for plan: SubscriptionPlan) -> Decimal? {
        product(for: plan)?.price
    }

    /// Formats an arbitrary Decimal amount using the same currency/locale
    /// style as the given plan's product, so a computed value (like a
    /// monthly-equivalent or a "was" price) still renders correctly for
    /// the storefront the person is in.
    func formattedPrice(_ amount: Decimal, like plan: SubscriptionPlan) -> String? {
        guard let product = product(for: plan) else { return nil }
        return amount.formatted(product.priceFormatStyle)
    }

    /// Returns the true App Store CURRENT NAME/period-adjusted price. If the
    /// annual plan has a real StoreKit introductory offer, use that; the
    /// caller may separately compute a "buy monthly instead" comparison.

    /// Returns the annual plan's price expressed per month (annual ÷ 12),
    /// formatted for display. nil when the annual product isn't loaded yet.
    func annualMonthlyEquivalentPrice() -> String? {
        guard let annual = rawPrice(for: .annual) else { return nil }
        return formattedPrice(annual / 12, like: .annual)
    }

    /// What a year would cost paying month-to-month at the monthly plan's
    /// price (monthly × 12). Used to show a struck-through "was" price next
    /// to the discounted annual price — derived entirely from real StoreKit
    /// pricing, not a hardcoded figure.
    func annualComparedToMonthlyPrice() -> String? {
        guard let monthly = rawPrice(for: .monthly) else { return nil }
        return formattedPrice(monthly * 12, like: .monthly)
    }

    /// Returns the real introductory free-trial text reported by StoreKit.
    /// It does not create a fake local trial.
    func freeTrialText(for plan: SubscriptionPlan) -> String? {
        guard
            plan != .lifetime,
            let subscription = product(for: plan)?.subscription,
            let offer = subscription.introductoryOffer,
            offer.paymentMode == .freeTrial
        else {
            return nil
        }

        let value = offer.period.value
        let unit: String

        switch offer.period.unit {
        case .day: unit = value == 1 ? "day" : "days"
        case .week: unit = value == 1 ? "week" : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year: unit = value == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }

        return "\(value)-\(unit) free trial"
    }

    func purchase(_ plan: SubscriptionPlan) async -> PurchaseOutcome? {
        guard let product = product(for: plan) else {
            errorMessage = "This product is not available yet."
            return nil
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                await transaction.finish()
                await refreshEntitlements()
                return .purchased

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return nil
            }
        } catch {
            errorMessage = "Purchase could not be completed."
            return nil
        }
    }

    func restorePurchases() async {
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "Unable to restore purchases."
        }
    }

    func refreshEntitlements() async {
        entitlementState = .loading
        let premiumIDs = Set(SubscriptionPlan.allCases.map(\.productID))
        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }

            if premiumIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                hasPremium = true
                break
            }
        }

        entitlementState = hasPremium ? .premium : .free
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self,
                      let transaction = try? self.verified(result) else {
                    continue
                }

                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }
}
