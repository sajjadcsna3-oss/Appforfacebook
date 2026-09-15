import AppKit
import Combine
import Foundation

@MainActor
final class AIToolsViewModel: ObservableObject {
    enum State: Equatable { case idle, loading, success, empty, failure(String) }

    @Published var summary = ""
    @Published var draft = ""
    @Published var state: State = .idle
    @Published var message: String?
    private let groq = GroqService()

    func summarize(text suppliedText: String? = nil, browser: FacebookViewModel) async {
        state = .loading
        message = nil
        do {
            let text: String
            if let suppliedText = suppliedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                text = suppliedText
            } else {
                text = try await browser.readableText()
            }
            summary = try await groq.complete(
                system: "Summarize the supplied Facebook content accurately and concisely. Do not invent details. Return only the summary.",
                prompt: text,
                temperature: 0.3
            )
            state = summary.isEmpty ? .empty : .success
        } catch FacebookBrowserError.noReadableContent {
            state = .empty
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func createDraft(input: String, action: DraftAction) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { state = .empty; return }
        state = .loading
        message = nil
        let instruction: String
        switch action {
        case .generate: instruction = "Create a polished Facebook-ready draft from the user's instructions."
        case .improve: instruction = "Improve the supplied text while preserving its meaning."
        case .rewrite: instruction = "Rewrite the supplied text clearly using fresh wording."
        case .shorten: instruction = "Make the supplied text meaningfully shorter."
        case .professional: instruction = "Rewrite the supplied text in a professional tone."
        }
        do {
            draft = try await groq.complete(system: "\(instruction) Return only the final text.", prompt: text, temperature: 0.45)
            state = draft.isEmpty ? .empty : .success
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = "Copied to clipboard."
    }

    func insert(_ text: String, into browser: FacebookViewModel) async {
        message = await browser.insert(text: text)
            ? "Inserted into the active Facebook field."
            : "Select a Facebook text field first, then try again."
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
