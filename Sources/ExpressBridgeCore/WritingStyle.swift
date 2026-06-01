import Foundation

public enum WritingStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case natural
    case polite
    case casual
    case professional
    case concise

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .natural:
            "Natural"
        case .polite:
            "Polite"
        case .casual:
            "Casual"
        case .professional:
            "Professional"
        case .concise:
            "Concise"
        }
    }

    public var instruction: String {
        switch self {
        case .natural:
            "Write natural, fluent English that sounds like a native speaker wrote it."
        case .polite:
            "Write polite, respectful English suitable for requests, replies, and support conversations."
        case .casual:
            "Write relaxed, friendly English suitable for forums, comments, and casual chat."
        case .professional:
            "Write clear, professional English suitable for workplace messages, GitHub issues, and support tickets."
        case .concise:
            "Write concise English. Keep the meaning, remove unnecessary words, and avoid sounding abrupt."
        }
    }
}
