import Foundation

struct GroqService {
    static let keychainService = "com.Sajjad.project.NorthwindSocial1.groq"
    static let keychainAccount = "api-key"
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "openai/gpt-oss-20b"

    func complete(system: String, prompt: String, temperature: Double = 0.45) async throws -> String {
        guard let apiKey = KeychainSecret.read(service: Self.keychainService, account: Self.keychainAccount), !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(Request(model: model, messages: [.init(role: "system", content: system), .init(role: "user", content: prompt)], temperature: temperature, maxCompletionTokens: 900))
        } catch {
            throw GroqError.requestEncoding(error.localizedDescription)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GroqError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message) ?? "Groq returned HTTP \(http.statusCode)."
                if http.statusCode == 404 && message.localizedCaseInsensitiveContains("model") {
                    throw GroqError.modelUnavailable(model)
                }
                throw GroqError.server(message)
            }
            let result = try JSONDecoder().decode(Response.self, from: data)
            guard let content = result.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else { throw GroqError.emptyResponse }
            return content
        } catch let error as GroqError { throw error }
        catch let error as URLError { throw GroqError.network(error.localizedDescription) }
        catch { throw GroqError.decoding(error.localizedDescription) }
    }

    private struct Message: Codable { let role: String; let content: String }
    private struct Request: Codable {
        let model: String; let messages: [Message]; let temperature: Double; let maxCompletionTokens: Int
        enum CodingKeys: String, CodingKey { case model, messages, temperature; case maxCompletionTokens = "max_completion_tokens" }
    }
    private struct Response: Decodable { struct Choice: Decodable { let message: Message }; let choices: [Choice] }
    private struct APIErrorEnvelope: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }
}
