import SwiftUI
import StoreKit
import AppKit

struct SubscriptionView: View {

    @ObservedObject var storeKit: StoreKitService

    let onClose: () -> Void
    let onPremiumActivated: () -> Void

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var statusMessage: String?

    // MARK: - Colors

    private let figmaBlue = Color(
        red: 45.0 / 255.0,
        green: 107.0 / 255.0,
        blue: 234.0 / 255.0
    )

    private let modalBackground = Color(
        red: 0.055,
        green: 0.060,
        blue: 0.073
    )

    private let premiumBackground = Color(
        red: 0.055,
        green: 0.085,
        blue: 0.135
    )

    // MARK: - Layout

    private enum Layout {

        static let modalWidth: CGFloat = 820
        static let modalHeight: CGFloat = 720

        static let contentWidth: CGFloat = 752

        static let horizontalPadding: CGFloat = 34
        static let topPadding: CGFloat = 32
        static let bottomPadding: CGFloat = 20

        static let iconSize: CGFloat = 40

        static let selectorHeight: CGFloat = 34

        static let annualWidth: CGFloat = 136
        static let normalPlanWidth: CGFloat = 100
        static let planHeight: CGFloat = 28.8

        static let cardSpacing: CGFloat = 16
        static let freeCardWidth: CGFloat = 360
        static let premiumCardWidth: CGFloat = 376
        static let cardHeight: CGFloat = 396

        static let footerHeight: CGFloat = 37

        static let modalRadius: CGFloat = 14
        static let cardRadius: CGFloat = 13
    }

    // MARK: - Body

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                // Facebook/Home screen stays visible behind modal.
                Color.black
                    .opacity(0.68)
                    .ignoresSafeArea()

                subscriptionContainer
                    .frame(
                        width: min(
                            Layout.modalWidth,
                            max(
                                700,
                                geometry.size.width - 40
                            )
                        ),
                        height: min(
                            Layout.modalHeight,
                            max(
                                620,
                                geometry.size.height - 30
                            )
                        )
                    )
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .center
            )
        }
        .task {
            // Product metadata can change in App Store Connect while the app
            // is running. Fetch again whenever the paywall is presented so a
            // previously loaded Product does not keep an outdated price for
            // the lifetime of this app process.
            await storeKit.loadProducts()
        }
    }

    // MARK: - Subscription Container

    private var subscriptionContainer: some View {

        ZStack(alignment: .topTrailing) {

            VStack(spacing: 0) {

                header

                planSelector
                    .padding(.top, 22)

                cards
                    .padding(.top, 24)

                Spacer(minLength: 18)

                Divider()
                    .overlay(
                        Color.white.opacity(0.10)
                    )

                footer
                    .frame(height: Layout.footerHeight)
            }
            .padding(
                .horizontal,
                Layout.horizontalPadding
            )
            .padding(
                .top,
                Layout.topPadding
            )
            .padding(
                .bottom,
                Layout.bottomPadding
            )

            closeButton
        }
        .background(
            RoundedRectangle(
                cornerRadius: Layout.modalRadius,
                style: .continuous
            )
            .fill(modalBackground)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: Layout.modalRadius,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.12),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.55),
            radius: 35,
            x: 0,
            y: 12
        )
    }

    // MARK: - Close Button

    private var closeButton: some View {

        Button {

            onClose()

        } label: {

            Image(systemName: "xmark")
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.78)
                )
                .frame(
                    width: 28,
                    height: 28
                )
                .background(
                    Circle()
                        .fill(
                            Color.white.opacity(0.08)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .padding(.trailing, 14)
        .help("Close")
    }

    // MARK: - Header

    private var header: some View {

        VStack(spacing: 0) {

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(
                    width: Layout.iconSize,
                    height: Layout.iconSize
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 9,
                        style: .continuous
                    )
                )

            Text("Unlock Premium Tools")
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .padding(.top, 13)

            Text(
                "Unlock all premium tools for a better Facebook experience."
            )
            .font(.system(size: 12))
            .foregroundStyle(
                Color.white.opacity(0.52)
            )
            .multilineTextAlignment(.center)
            .padding(.top, 6)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
    }

    // MARK: - Plan Selector

    private var planSelector: some View {

        HStack(spacing: 0) {

            planButton(.monthly)

            planButton(.annual)

            planButton(.lifetime)
        }
        .padding(3)
        .frame(height: Layout.selectorHeight)
        .background(
            RoundedRectangle(
                cornerRadius: 9,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.06)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 9,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        )
        .fixedSize(
            horizontal: true,
            vertical: false
        )
    }

    private func planButton(
        _ plan: SubscriptionPlan
    ) -> some View {

        let isSelected = selectedPlan == plan

        return Button {

            withAnimation(
                .easeInOut(duration: 0.15)
            ) {
                selectedPlan = plan
            }

        } label: {

            HStack(spacing: 8) {

                Text(plan.title)
                    .font(
                        .system(
                            size: 12,
                            weight: isSelected
                                ? .semibold
                                : .regular
                        )
                    )
                    .lineLimit(1)
                    .fixedSize(
                        horizontal: true,
                        vertical: false
                    )

                if plan == .annual {

                    Text(annualSaveBadgeText)
                        .font(
                            .system(
                                size: 8,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(
                            horizontal: true,
                            vertical: false
                        )
                        .padding(
                            .horizontal,
                            6
                        )
                        .padding(
                            .vertical,
                            3
                        )
                        .background(
                            Color(
                                red: 0.035,
                                green: 0.118,
                                blue: 0.255
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 4,
                                style: .continuous
                            )
                        )
                }
            }
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : Color.white.opacity(0.60)
            )
            .padding(
                .horizontal,
                plan == .annual ? 16 : 14
            )
            .padding(.vertical, 7)
            .frame(
                width: plan == .annual
                    ? Layout.annualWidth
                    : Layout.normalPlanWidth,
                height: Layout.planHeight
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? figmaBlue
                        : Color.clear
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 7
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cards

    private var cards: some View {

        HStack(
            alignment: .top,
            spacing: Layout.cardSpacing
        ) {

            freeCard

            premiumCard
        }
        .frame(
            width: Layout.contentWidth,
            alignment: .center
        )
    }

    // MARK: - Free Card

    private var freeCard: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            Text("FREE")
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.55)
                )

            HStack(
                alignment: .firstTextBaseline,
                spacing: 5
            ) {

                Text("$0")
                    .font(
                        .system(
                            size: 34,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.white)

                Text("forever")
                    .font(.system(size: 11))
                    .foregroundStyle(
                        Color.white.opacity(0.45)
                    )
            }
            .padding(.top, 4)

            Text(
                "Basic Facebook access on your Mac."
            )
            .font(.system(size: 11))
            .foregroundStyle(
                Color.white.opacity(0.46)
            )
            .padding(.top, 7)

            Divider()
                .overlay(
                    Color.white.opacity(0.10)
                )
                .padding(.vertical, 17)

            VStack(
                alignment: .leading,
                spacing: 11
            ) {

                featureRow(
                    "Facebook access",
                    enabled: true
                )

                featureRow(
                    "Sidebar navigation",
                    enabled: true
                )

                featureRow(
                    "Facebook tabs",
                    enabled: true
                )

                featureRow(
                    "Summarise",
                    enabled: false
                )

                featureRow(
                    "Draft",
                    enabled: false
                )

                featureRow(
                    "Templates",
                    enabled: false
                )

                featureRow(
                    "Reader",
                    enabled: false
                )

                featureRow(
                    "Notebook",
                    enabled: false
                )
            }

            // Guaranteed gap so the bottom box never sits flush against
            // the last feature row, even when the card is tight on space.
            Spacer(minLength: 22)

            Text(
                storeKit.entitlementState == .premium
                    ? "Premium is active"
                    : "Your current plan"
            )
            .font(
                .system(
                    size: 11,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.white.opacity(0.65)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(
                    cornerRadius: 8
                )
                .stroke(
                    Color.white.opacity(0.13),
                    lineWidth: 1
                )
            )
        }
        .padding(20)
        .frame(
            width: Layout.freeCardWidth,
            height: Layout.cardHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(
                cornerRadius: Layout.cardRadius,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.025)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: Layout.cardRadius,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.09),
                lineWidth: 1
            )
        )
    }

    // MARK: - Premium Card

    private var premiumCard: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            Text(
                "PREMIUM · \(selectedPlan.title.uppercased())"
            )
            .font(
                .system(
                    size: 12,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                Color(
                    red: 0.46,
                    green: 0.68,
                    blue: 1
                )
            )

            HStack(
                alignment: .firstTextBaseline,
                spacing: 6
            ) {

                Text(
                    storeKit.displayPrice(
                        for: selectedPlan
                    )
                )
                .font(
                    .system(
                        size: 34,
                        weight: .medium
                    )
                )
                .foregroundStyle(.white)

                Text(selectedPlan.priceSuffix)
                    .font(.system(size: 11))
                    .foregroundStyle(
                        Color.white.opacity(0.48)
                    )

                // Struck-through "buy monthly instead" comparison, computed
                // from the real monthly product price (not a fixed figure).
                if selectedPlan == .annual,
                   let wasPrice = annualComparedToMonthlyPriceText {

                    Text(wasPrice)
                        .font(.system(size: 13))
                        .foregroundStyle(
                            Color.white.opacity(0.35)
                        )
                        .strikethrough(
                            true,
                            color: Color.white.opacity(0.35)
                        )
                }
            }
            .padding(.top, 4)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(
                    Color.white.opacity(0.46)
                )
                .padding(.top, 7)

            Divider()
                .overlay(
                    Color.white.opacity(0.11)
                )
                .padding(.vertical, 17)

            LazyVGrid(
                columns: [
                    GridItem(
                        .flexible(),
                        alignment: .leading
                    ),
                    GridItem(
                        .flexible(),
                        alignment: .leading
                    )
                ],
                alignment: .leading,
                spacing: 15
            ) {

                featureRow(
                    "Summarise",
                    enabled: true
                )

                featureRow(
                    "Draft",
                    enabled: true
                )

                featureRow(
                    "Templates",
                    enabled: true
                )

                featureRow(
                    "Reader",
                    enabled: true
                )

                featureRow(
                    "Notebook",
                    enabled: true
                )

                featureRow(
                    "All Premium Tools",
                    enabled: true
                )
            }

            // Same guaranteed gap as the free card, so both bottom
            // boxes line up and neither looks cramped.
            Spacer(minLength: 22)

            Button {

                Task {
                    await purchase()
                }

            } label: {

                Group {

                    if storeKit.isPurchasing {

                        ProgressView()
                            .controlSize(.small)

                    } else {

                        Text(purchaseButtonTitle)
                            .font(
                                .system(
                                    size: 13,
                                    weight: .semibold
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                storeKit.product(
                    for: selectedPlan
                ) == nil
                    ? figmaBlue.opacity(0.45)
                    : figmaBlue
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .disabled(
                storeKit.product(
                    for: selectedPlan
                ) == nil ||
                storeKit.isPurchasing
            )

            if let trial =
                storeKit.freeTrialText(
                    for: selectedPlan
                ) {

                Text(
                    "Then \(storeKit.displayPrice(for: selectedPlan)) \(selectedPlan.priceSuffix). We'll remind you two days before it renews."
                )
                .font(.system(size: 9))
                .foregroundStyle(
                    Color.white.opacity(0.40)
                )
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 9)
                .accessibilityLabel(
                    "\(trial). Then \(storeKit.displayPrice(for: selectedPlan)) \(selectedPlan.priceSuffix)."
                )
            }
        }
        .padding(20)
        .frame(
            width: Layout.premiumCardWidth,
            height: Layout.cardHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(
                cornerRadius: Layout.cardRadius,
                style: .continuous
            )
            .fill(premiumBackground)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: Layout.cardRadius,
                style: .continuous
            )
            .stroke(
                figmaBlue.opacity(0.80),
                lineWidth: 1
            )
        )
        // Corner-ribbon RECOMMENDED tag, pinned to the card itself rather
        // than laid out inline, so it sits flush at the top-right edge.
        .overlay(alignment: .topTrailing) {
            if selectedPlan == .annual {
                Text("RECOMMENDED")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(figmaBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(
        _ text: String,
        enabled: Bool
    ) -> some View {

        HStack(spacing: 9) {

            Image(
                systemName: enabled
                    ? "checkmark"
                    : "xmark"
            )
            .font(
                .system(
                    size: 9,
                    weight: .bold
                )
            )
            .foregroundStyle(
                enabled
                    ? figmaBlue
                    : Color.white.opacity(0.25)
            )
            .frame(width: 12)

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(
                    enabled
                        ? Color.white.opacity(0.76)
                        : Color.white.opacity(0.29)
                )
                .lineLimit(1)
        }
    }

    // MARK: - Footer

    private var footer: some View {

        HStack(spacing: 16) {

            Label(
                "Covers all your Macs",
                systemImage: "display"
            )
            .foregroundStyle(.green)

            Label(
                "Cancel anytime",
                systemImage: "checkmark.seal.fill"
            )
            .foregroundStyle(.green)

            Spacer()

            Link(
                "Privacy",
                destination: URL(
                    string: "https://sites.google.com/view/app-for-netflix/privacy-policy"
                )!
            )
            .foregroundStyle(Color.white.opacity(0.62))

            Link(
                "Terms",
                destination: URL(
                    string: "https://sites.google.com/view/app-for-netflix/terms-of-use"
                )!
            )
            .foregroundStyle(Color.white.opacity(0.62))

            Button("Restore purchase") {

                Task {

                    statusMessage = nil

                    await storeKit.restorePurchases()

                    if storeKit.entitlementState == .premium {

                        onPremiumActivated()

                    } else {

                        statusMessage =
                            "No active Premium purchase was found."
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                Color.white.opacity(0.62)
            )

       
        }
        .font(.system(size: 10))
        .overlay(
            alignment: .top
        ) {

            VStack(spacing: 2) {

                if let statusMessage {

                    Text(statusMessage)
                        .font(.system(size: 9))
                        .foregroundStyle(
                            Color.white.opacity(0.60)
                        )
                }

                if let error = storeKit.errorMessage {

                    Text(error)
                        .font(.system(size: 9))
                        .foregroundStyle(.red)

                    Button("Retry loading prices") {
                        Task { await storeKit.loadProducts() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(figmaBlue)
                    .disabled(storeKit.isLoadingProducts)
                }
            }
            .offset(y: -16)
        }
    }

    // MARK: - Pricing helpers

    /// "SAVE X%" badge text on the Annual tab, computed from real monthly
    /// vs. annual StoreKit pricing when both products are loaded; falls
    /// back to the previous static copy until pricing has loaded.
    private var annualSaveBadgeText: String {
        guard
            let monthly = storeKit.rawPrice(for: .monthly),
            let annual = storeKit.rawPrice(for: .annual),
            monthly > 0
        else {
            return "SAVE 48%"
        }
        let fullYear = monthly * 12
        guard fullYear > 0 else { return "SAVE 48%" }
        let savings = (fullYear - annual) / fullYear
        let percent = Int((NSDecimalNumber(decimal: savings).doubleValue * 100).rounded())
        return "SAVE \(max(percent, 0))%"
    }

    /// What a year would cost paying month-to-month, struck through next to
    /// the discounted annual price — derived from the real monthly price.
    private var annualComparedToMonthlyPriceText: String? {
        storeKit.annualComparedToMonthlyPrice()
    }

    // MARK: - Subtitle

    private var subtitle: String {

        if let trial =
            storeKit.freeTrialText(
                for: selectedPlan
            ) {

            return "\(trial.capitalized). Cancel anytime."
        }

        switch selectedPlan {

        case .monthly:
            return "Premium tools billed monthly. Cancel anytime."

        case .annual:
            if let monthly = storeKit.annualMonthlyEquivalentPrice() {
                return "Works out at \(monthly) a month. Cancel anytime."
            }
            return "Premium tools billed yearly. Cancel anytime."

        case .lifetime:
            return "One-time purchase. No recurring subscription."
        }
    }

    // MARK: - Purchase Button

    private var purchaseButtonTitle: String {

        if let trial =
            storeKit.freeTrialText(
                for: selectedPlan
            ) {

            return "Start \(trial)"
        }

        switch selectedPlan {

        case .monthly, .annual:
            return "Continue"

        case .lifetime:
            return "Unlock lifetime"
        }
    }

    // MARK: - Purchase

    private func purchase() async {

        statusMessage = nil

        guard let outcome =
            await storeKit.purchase(
                selectedPlan
            )
        else {
            return
        }

        switch outcome {

        case .purchased:
            if storeKit.entitlementState == .premium {
                onPremiumActivated()
            } else {
                statusMessage =
                    "Your purchase was verified, but Premium is not active yet. Try Restore Purchase."
            }

        case .pending:

            statusMessage =
                "Purchase is pending approval."

        case .cancelled:

            break
        }
    }

   
}
