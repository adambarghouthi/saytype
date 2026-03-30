import Foundation

enum CommandAction: String {
    case submit, cancel, accept, reject
}

enum ParseResult {
    case command(CommandAction)
    case text(String)
}

struct CommandParser {
    private let commands: [String: CommandAction] = [
        "send": .submit, "submit": .submit, "enter": .submit, "go": .submit,
        "sent": .submit, "sand": .submit, "cent": .submit,
        "go ahead": .submit, "confirm": .submit, "done": .submit,
        "cancel": .cancel, "stop": .cancel,
        "accept": .accept, "yes": .accept, "yeah": .accept, "approve": .accept,
        "reject": .reject, "no": .reject, "nope": .reject, "deny": .reject,
    ]

    func parse(_ text: String) -> ParseResult {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))

        // Strip common prefixes
        for prefix in ["okay ", "ok ", "please ", "now "] {
            if normalized.hasPrefix(prefix) {
                normalized = String(normalized.dropFirst(prefix.count))
            }
        }

        // Exact match
        if let action = commands[normalized] {
            return .command(action)
        }

        // Fuzzy match — check if any command is close enough
        for (trigger, action) in commands {
            if levenshteinDistance(normalized, trigger) <= max(1, trigger.count / 4) {
                return .command(action)
            }
        }

        return .text(text)
    }

    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                dist[i][j] = min(
                    dist[i-1][j] + 1,
                    dist[i][j-1] + 1,
                    dist[i-1][j-1] + cost
                )
            }
        }
        return dist[a.count][b.count]
    }
}
