import AppKit
import Combine
import Foundation

@MainActor
final class AIToolsViewModel: ObservableObject {
    enum State: Equatable { case idle, loading, success, empty, failure(String) }

    @Published var summary = ""
    @Published var draft = ""
    @Published var draftInput = ""
    @Published var draftAction: DraftAction = .generate
    @Published var suggestedReplies: [String] = []
    @Published var selectedReplyIndex = 0
    @Published var state: State = .idle
    @Published var message: String?
    @Published private(set) var isExtracting = false
    @Published private(set) var extractionMessage: String?
    private let completionService: any AICompletionService

    init(completionService: (any AICompletionService)? = nil) {
        self.completionService = completionService ?? GroqService()
    }

    func summarize(text suppliedText: String? = nil, browser: any FacebookContentProviding) async {
        state = .loading
        message = nil
        do {
            let text: String
            if let suppliedText = suppliedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                text = suppliedText
            } else {
                text = try await browser.readableText(maxCharacters: 14_000)
            }
            async let summaryRequest = completionService.complete(
                system: "Summarize the supplied Facebook content accurately and concisely in 1-2 sentences. Do not invent details. Return only the summary.",
                prompt: text,
                temperature: 0.3
            )
            async let repliesRequest = completionService.complete(
                system: "Write exactly two useful, natural replies to the supplied Facebook content. Keep each reply under 35 words. Return only the replies, one per line, prefixed exactly with REPLY:.",
                prompt: text,
                temperature: 0.45
            )

            let (generatedSummary, generatedReplies) = try await (summaryRequest, repliesRequest)
            try Task.checkCancellation()
            summary = generatedSummary
            suggestedReplies = Self.parseReplies(generatedReplies)
            selectedReplyIndex = 0
            state = summary.isEmpty ? .empty : .success
        } catch is CancellationError {
            state = .idle
        } catch FacebookBrowserError.noReadableContent {
            state = .empty
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func refineSelectedReply(_ instruction: String) async {
        guard suggestedReplies.indices.contains(selectedReplyIndex) else { return }
        state = .loading
        message = nil
        do {
            let reply = try await completionService.complete(
                system: "Rewrite the supplied reply to be \(instruction). Preserve its meaning and return only the rewritten reply.",
                prompt: suggestedReplies[selectedReplyIndex],
                temperature: 0.4
            )
            try Task.checkCancellation()
            suggestedReplies[selectedReplyIndex] = reply
            state = .success
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func extractDraftInput(from browser: any FacebookContentProviding) async {
        isExtracting = true
        extractionMessage = nil
        defer { isExtracting = false }

        do {
            draftInput = try await browser.readableText(maxCharacters: 6_000)
        } catch is CancellationError {
            return
        } catch {
            extractionMessage = error.localizedDescription
        }
    }

    func createDraft() async {
        let text = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { state = .empty; return }
        state = .loading
        message = nil
        let instruction: String
        switch draftAction {
        case .generate: instruction = "Create a polished Facebook-ready draft from the user's instructions."
        case .improve: instruction = "Improve the supplied text while preserving its meaning."
        case .rewrite: instruction = "Rewrite the supplied text clearly using fresh wording."
        case .shorten: instruction = "Make the supplied text meaningfully shorter."
        case .professional: instruction = "Rewrite the supplied text in a professional tone."
        }
        do {
            draft = try await completionService.complete(system: "\(instruction) Return only the final text.", prompt: text, temperature: 0.45)
            state = draft.isEmpty ? .empty : .success
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = "Copied to clipboard."
    }

    func insert(_ text: String, into browser: any FacebookTextInserting) async {
        message = await browser.insert(text: text)
            ? "Inserted into the active Facebook field."
            : "Select a Facebook text field first, then try again."
    }


    private static func parseReplies(_ response: String) -> [String] {
        let replies = response
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: #"^\s*(?:[-*]\s*)?(?:REPLY\s*\d*\s*:?)\s*"#,
                                          with: "",
                                          options: [.regularExpression, .caseInsensitive])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return Array(replies.prefix(2))
    }
}

private extension String {
    
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
