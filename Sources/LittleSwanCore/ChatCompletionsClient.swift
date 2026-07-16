import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ChatCompletionsClientError: LocalizedError, Equatable {
    case missingAPIKey(String)
    case invalidBaseURL(String, provider: String)
    case invalidResponse(String)
    case serverError(String)
    case emptyOutput(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "Add your \(provider) API key in Settings."
        case .invalidBaseURL(let value, let provider):
            "Invalid \(provider) base URL: \(value)"
        case .invalidResponse(let provider):
            "\(provider) returned an invalid response."
        case .serverError(let message):
            message
        case .emptyOutput(let provider):
            "\(provider) returned an empty result."
        }
    }
}

public enum ProviderEndpoint {
    public static func baseURL(from value: String) -> URL? {
        guard
            let components = URLComponents(
                string: value.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            let scheme = components.scheme?.lowercased(),
            let host = components.host?.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased(),
            let url = components.url
        else {
            return nil
        }

        if scheme == "https" {
            return url
        }

        let loopbackHosts = ["localhost", "127.0.0.1", "::1"]
        return scheme == "http" && loopbackHosts.contains(host) ? url : nil
    }
}

public protocol ChatCompletionsServing: Sendable {
    func rewriteEnglish(
        input: String,
        style: WritingStyle,
        configuration: ProviderConfiguration
    ) async throws -> String

    func polishInput(
        input: String,
        screenContext: ScreenContext,
        configuration: ProviderConfiguration
    ) async throws -> String
}

/// Calls providers that implement the OpenAI-compatible chat completions API.
public final class ChatCompletionsClient: Sendable {
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
        try await complete(
            messages: PromptBuilder.messages(input: input, style: style),
            temperature: 0.35,
            trimsOutput: true,
            configuration: configuration
        )
    }

    public func polishInput(
        input: String,
        screenContext: ScreenContext,
        configuration: ProviderConfiguration
    ) async throws -> String {
        try await complete(
            messages: PromptBuilder.inputPolishMessages(
                input: input,
                screenContext: screenContext
            ),
            temperature: 0.2,
            trimsOutput: false,
            configuration: configuration
        )
    }

    public func testConnection(configuration: ProviderConfiguration) async throws {
        _ = try await complete(
            messages: [
                ChatMessage(role: "system", content: "Reply with OK."),
                ChatMessage(role: "user", content: "Connection test")
            ],
            temperature: 0,
            trimsOutput: true,
            configuration: configuration
        )
    }

    private func complete(
        messages: [ChatMessage],
        temperature: Double,
        trimsOutput: Bool,
        configuration: ProviderConfiguration
    ) async throws -> String {
        let providerName = configuration.provider.rawValue
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ChatCompletionsClientError.missingAPIKey(providerName)
        }

        let baseURLValue = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = ProviderEndpoint.baseURL(from: baseURLValue) else {
            throw ChatCompletionsClientError.invalidBaseURL(baseURLValue, provider: providerName)
        }

        let endpoint = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if configuration.provider == .openRouter {
            request.setValue("Little Swan", forHTTPHeaderField: "X-OpenRouter-Title")
        }

        request.httpBody = try encoder.encode(
            ChatCompletionRequest(
                model: configuration.model,
                messages: messages,
                // Current OpenAI reasoning models may reject non-default temperature values.
                temperature: configuration.provider == .openAI ? nil : temperature,
                stream: false
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatCompletionsClientError.invalidResponse(providerName)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(ChatCompletionErrorResponse.self, from: data) {
                throw ChatCompletionsClientError.serverError(errorResponse.error.message)
            }
            let fallback = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw ChatCompletionsClientError.serverError(fallback)
        }

        let completion = try decoder.decode(ChatCompletionResponse.self, from: data)
        let rawOutput = completion.choices.first?.message.content
        let trimmedOutput = rawOutput?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rawOutput, let trimmedOutput, !trimmedOutput.isEmpty else {
            throw ChatCompletionsClientError.emptyOutput(providerName)
        }

        return trimsOutput ? trimmedOutput : rawOutput
    }
}

extension ChatCompletionsClient: ChatCompletionsServing {}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double?
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

private struct ChatCompletionErrorResponse: Decodable {
    var error: APIError

    struct APIError: Decodable {
        var message: String
    }
}
