import Foundation

enum CommandAction: String {
    case submit, cancel, accept, reject, undo, clearAll
}

enum ParseResult {
    case command(CommandAction)
    case text(String)
}

struct CommandParser {
    private let commands: [String: CommandAction] = [
        // Submit (Enter)
        "send": .submit, "submit": .submit, "enter": .submit,
        "sent": .submit, "sand": .submit, "cent": .submit,
        "go ahead": .submit, "confirm": .submit,
        // Cancel (Ctrl+C)
        "cancel": .cancel, "cancel that": .cancel,
        // Accept (y + Enter)
        "yes": .accept, "yeah": .accept, "approve": .accept,
        // Reject (n + Enter)
        "nope": .reject, "deny": .reject, "reject": .reject,
        // Undo (Option+Backspace = delete word)
        "undo": .undo, "oops": .undo, "backspace": .undo,
        // Clear all (Cmd+A, Backspace)
        "clear all": .clearAll, "erase all": .clearAll, "delete all": .clearAll,
    ]

    // Single words that are safe to match even within short phrases
    private let singleWordCommands: [String: CommandAction] = [
        "send": .submit, "submit": .submit, "enter": .submit,
        "sent": .submit, "sand": .submit, "cent": .submit,
        "confirm": .submit,
        "cancel": .cancel,
        "yes": .accept, "yeah": .accept, "approve": .accept,
        "nope": .reject, "deny": .reject, "reject": .reject,
        "undo": .undo, "oops": .undo, "backspace": .undo,
    ]

    func parse(_ text: String) -> ParseResult {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match on full text (handles multi-word commands)
        if let action = commands[normalized] {
            return .command(action)
        }

        // For short transcriptions (1-3 words), check individual words
        // Whisper often adds filler like "Send it." or "Please enter."
        let words = normalized.split(separator: " ").map(String.init)
        if words.count <= 3 {
            for word in words {
                if let action = singleWordCommands[word] {
                    return .command(action)
                }
            }
        }

        return .text(text)
    }
}
