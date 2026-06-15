import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var debounceMilliseconds: Int
    public var defaultWritingStyle: WritingStyle
    public var panelContentSize: PanelContentSizeConfiguration
    public var toggleShortcut: KeyboardShortcutConfiguration
    public var commonPhrases: CommonPhraseCollection

    public init(
        provider: ProviderConfiguration = .deepSeekDefault,
        debounceMilliseconds: Int = TranslationTiming.defaultRealtimeDelayMilliseconds,
        defaultWritingStyle: WritingStyle = .natural,
        panelContentSize: PanelContentSizeConfiguration = PanelPresentation.defaultContentSize,
        toggleShortcut: KeyboardShortcutConfiguration = .defaultToggleShortcut,
        commonPhrases: CommonPhraseCollection = .default
    ) {
        self.provider = provider
        self.debounceMilliseconds = TranslationTiming.clampedDebounceMilliseconds(debounceMilliseconds)
        self.defaultWritingStyle = defaultWritingStyle
        self.panelContentSize = PanelPresentation.clampedContentSize(panelContentSize)
        self.toggleShortcut = toggleShortcut
        self.commonPhrases = commonPhrases.normalized()
    }

    public static let `default` = AppConfiguration()

    private enum CodingKeys: String, CodingKey {
        case provider
        case debounceMilliseconds
        case defaultWritingStyle
        case panelContentSize
        case toggleShortcut
        case commonPhrases
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case panelWidth
        case panelWidthPercentage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        provider = try container.decode(ProviderConfiguration.self, forKey: .provider)
        debounceMilliseconds = TranslationTiming.migratedDebounceMilliseconds(
            try container.decodeIfPresent(Int.self, forKey: .debounceMilliseconds)
        )
        defaultWritingStyle = try container.decodeIfPresent(WritingStyle.self, forKey: .defaultWritingStyle) ?? .natural
        toggleShortcut = try container.decodeIfPresent(
            KeyboardShortcutConfiguration.self,
            forKey: .toggleShortcut
        ) ?? .defaultToggleShortcut
        commonPhrases = try container.decodeIfPresent(
            CommonPhraseCollection.self,
            forKey: .commonPhrases
        )?.normalized() ?? .default

        if let contentSize = try container.decodeIfPresent(
            PanelContentSizeConfiguration.self,
            forKey: .panelContentSize
        ) {
            panelContentSize = contentSize == PanelPresentation.legacyWideDefaultContentSize
                ? PanelPresentation.defaultContentSize
                : PanelPresentation.clampedContentSize(contentSize)
        } else if let legacyWidthPercentage = try legacyContainer.decodeIfPresent(
            Int.self,
            forKey: .panelWidthPercentage
        ) {
            panelContentSize = PanelPresentation.contentSize(widthPercentage: legacyWidthPercentage)
        } else if let legacyWidth = try legacyContainer.decodeIfPresent(Int.self, forKey: .panelWidth) {
            panelContentSize = PanelPresentation.contentSize(legacyWidth: legacyWidth)
        } else {
            panelContentSize = PanelPresentation.defaultContentSize
        }
    }
}

public struct CommonPhraseCollection: Codable, Equatable, Sendable {
    public static let maximumPhraseCount = 24
    public static let maximumPhraseLength = 10_000

    public var phrases: [String]

    public init(phrases: [String]) {
        self.phrases = Self.normalizedPhrases(phrases)
    }

    public func normalized() -> CommonPhraseCollection {
        CommonPhraseCollection(phrases: phrases)
    }

    public static func normalizedPhrases(_ phrases: [String]) -> [String] {
        var seen = Set<String>()

        return phrases.compactMap { phrase in
            let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let limited = String(trimmed.prefix(maximumPhraseLength))
            let key = limited.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return limited
        }
        .prefix(maximumPhraseCount)
        .map { $0 }
    }

    public static let `default` = CommonPhraseCollection(phrases: [
        "Thank you!",
        "Sounds good.",
        "Could you please take a look?",
        "Let me know what you think.",
        "I’ll follow up soon.",
        "Sorry for the delay.",
        "No worries.",
        "Best regards,"
    ])
}

public enum CommonPhraseInsertion {
    public static func appending(_ phrase: String, to draft: String) -> String {
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return draft }

        if draft.isEmpty || draft.hasSuffix(" ") || draft.hasSuffix("\n") {
            return draft + phrase
        }

        return draft + " " + phrase
    }
}

public enum TranslationTiming {
    public static let minimumRealtimeDelayMilliseconds = 100
    public static let maximumRealtimeDelayMilliseconds = 1_000
    public static let defaultRealtimeDelayMilliseconds = 200
    public static let legacyDefaultRealtimeDelayMilliseconds = 700

    public static func migratedDebounceMilliseconds(_ value: Int?) -> Int {
        guard let value else { return defaultRealtimeDelayMilliseconds }

        if value == legacyDefaultRealtimeDelayMilliseconds {
            return defaultRealtimeDelayMilliseconds
        }

        return clampedDebounceMilliseconds(value)
    }

    public static func clampedDebounceMilliseconds(_ value: Int) -> Int {
        min(
            max(value, minimumRealtimeDelayMilliseconds),
            maximumRealtimeDelayMilliseconds
        )
    }
}

public struct PanelContentSizeConfiguration: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct ProviderConfiguration: Codable, Equatable, Sendable {
    public var name: String
    public var baseURL: String
    public var apiKey: String
    public var model: String

    public init(
        name: String,
        baseURL: String,
        apiKey: String,
        model: String
    ) {
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = Self.developmentModelMigration(model)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        model = Self.developmentModelMigration(try container.decode(String.self, forKey: .model))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(model, forKey: .model)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case baseURL
        case apiKey
        case model
    }

    private static func developmentModelMigration(_ model: String) -> String {
        model == "deepseek-v4-pro" ? Self.defaultModel : model
    }

    public static let defaultModel = "deepseek-v4-flash"

    public static let deepSeekDefault = ProviderConfiguration(
        name: "DeepSeek",
        baseURL: "https://api.deepseek.com",
        apiKey: "",
        model: Self.defaultModel
    )
}
