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

    static func removeSession(for account: FacebookAccount, retries: Int) async {
        for attempt in 0...retries {
            let error = await withCheckedContinuation { continuation in
                removeSession(for: account) { continuation.resume(returning: $0) }
            }
            if error == nil { return }
            guard attempt < retries else { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
