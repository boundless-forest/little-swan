import Foundation

public enum DeepSeekClientError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidBaseURL(String)
    case invalidResponse
    case serverError(String)
    case emptyOutput

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add your DeepSeek API key in Settings."
        case .invalidBaseURL(let value):
            "Invalid DeepSeek base URL: \(value)"
        case .invalidResponse:
            "DeepSeek returned an invalid response."
        case .serverError(let message):
            message
        case .emptyOutput:
            "DeepSeek returned an empty result."
        }
    }
}

public final class DeepSeekClient: Sendable {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    public func rewriteEnglish(
        input: String,
        style: WritingStyle,
        configuration: ProviderConfiguration
    ) async throws -> String {
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw DeepSeekClientError.missingAPIKey
        }

        guard let baseURL = URL(string: configuration.baseURL) else {
            throw DeepSeekClientError.invalidBaseURL(configuration.baseURL)
        }

        let endpoint = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            ChatCompletionRequest(
                model: configuration.model,
                messages: PromptBuilder.messages(input: input, style: style),
                temperature: 0.35,
                stream: false
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(DeepSeekErrorResponse.self, from: data) {
                throw DeepSeekClientError.serverError(errorResponse.error.message)
            }
            let fallback = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw DeepSeekClientError.serverError(fallback)
        }

        let completion = try decoder.decode(ChatCompletionResponse.self, from: data)
        let output = completion.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let output, !output.isEmpty else {
            throw DeepSeekClientError.emptyOutput
        }

        return output
    }
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var messages: [DeepSeekMessage]
    var temperature: Double
    var stream: Bool
}

private struct ChatCompletionResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }
}

private struct DeepSeekErrorResponse: Decodable {
    var error: APIError

    struct APIError: Decodable {
        var message: String
    }
}
