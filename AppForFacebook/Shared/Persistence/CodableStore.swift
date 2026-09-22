import Foundation

/// Small typed boundary around UserDefaults-backed JSON persistence.
/// View models own domain behavior; this type owns encoding and storage details.
struct CodableStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func load<Value: Decodable>(_ type: Value.Type = Value.self, forKey key: String) throws -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try decoder.decode(type, from: data)
    }

    func save<Value: Encodable>(_ value: Value, forKey key: String) throws {
        defaults.set(try encoder.encode(value), forKey: key)
    }

    func rawData(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func setRawData(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}

