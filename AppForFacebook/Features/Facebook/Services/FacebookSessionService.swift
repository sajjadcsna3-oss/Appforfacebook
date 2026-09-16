import Foundation
import WebKit

enum FacebookSessionService {
    static func removeSession(for account: FacebookAccount, completion: @escaping (Error?) -> Void = { _ in }) {
        if let sessionID = account.sessionID {
            WKWebsiteDataStore.remove(forIdentifier: sessionID, completionHandler: completion)
        } else {
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                let facebookRecords = records.filter {
                    let name = $0.displayName.lowercased()
                    return name == "facebook.com" || name.hasSuffix(".facebook.com")
                }
                guard !facebookRecords.isEmpty else { completion(nil); return }
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                     for: facebookRecords) {
                    completion(nil)
                }
            }
        }
    }
}
