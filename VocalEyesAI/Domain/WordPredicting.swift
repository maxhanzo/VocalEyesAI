import Foundation

protocol WordPredicting: Sendable {
    func predictions(for prefix: String) async -> [String]
}

struct LocalWordPredictor: WordPredicting {
    private let words: [String]

    init(words: [String] = [
        "a", "about", "and", "are", "be", "can", "care", "do", "dog",
        "hello", "help", "home", "how", "i", "is", "love", "me", "my",
        "no", "please", "thank", "thanks", "the", "there", "this", "to",
        "want", "we", "what", "yes", "you"
    ]) {
        self.words = words
    }

    func predictions(for prefix: String) async -> [String] {
        let normalizedPrefix = prefix.lowercased()
        guard !normalizedPrefix.isEmpty else {
            return []
        }

        return words
            .filter { $0.hasPrefix(normalizedPrefix) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs < rhs
                }
                return lhs.count < rhs.count
            }
            .prefix(5)
            .map { String($0) }
    }
}
