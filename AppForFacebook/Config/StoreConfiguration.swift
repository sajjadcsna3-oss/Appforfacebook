import Foundation

/// StoreKit configuration loaded from StoreProducts.plist.
enum StoreConfiguration {
    static let monthlyProductID = productID(forKey: "MonthlyProductID")
    static let annualProductID = productID(forKey: "AnnualProductID")
    static let lifetimeProductID = productID(forKey: "LifetimeProductID")

    private static let values: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "StoreProducts", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let values = plist as? [String: String]
        else {
            assertionFailure("Missing Config/StoreProducts.plist from the app bundle.")
            return [:]
        }

        return values
    }()

    private static func productID(forKey key: String) -> String {
        guard let value = values[key] else {
            assertionFailure("Missing StoreKit configuration for \(key).")
            return ""
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
