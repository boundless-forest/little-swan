import Foundation

public struct DeepSeekMessage: Codable, Equatable, Sendable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum PromptBuilder {
    public static func messages(input: String, style: WritingStyle) -> [DeepSeekMessage] {
        [
            DeepSeekMessage(
                role: "system",
                content: """
                You are Little Swan, a macOS writing assistant for non-native English writers.
                Detect the user's input language automatically.
                Rewrite or translate the user's text into English only.
                Preserve the user's intent and facts. Do not add unsupported claims.
                If the input is already English, improve clarity and naturalness without changing meaning.
                \(style.instruction)
                Return only the final English text, with no labels, explanations, markdown, or quotation marks.
                """
            ),
            DeepSeekMessage(role: "user", content: input)
        ]
    }
}
