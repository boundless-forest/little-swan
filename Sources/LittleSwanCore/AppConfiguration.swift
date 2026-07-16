import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var providerConfigurations: [String: ProviderConfiguration]
    public var debounceMilliseconds: Int
    public var realtimeTranslationEnabled: Bool
    public var copyGeneratedResultToClipboard: Bool
    public var defaultWritingStyle: WritingStyle
    public var panelContentSize: PanelContentSizeConfiguration
    public var toggleShortcut: KeyboardShortcutConfiguration
    public var resetWindowShortcut: KeyboardShortcutConfiguration
    public var generateTranslationShortcut: KeyboardShortcutConfiguration
    public var polishInputShortcut: KeyboardShortcutConfiguration
    public var commonPhrases: CommonPhraseCollection

    public init(
        provider: ProviderConfiguration = .deepSeekDefault,
        providerConfigurations: [String: ProviderConfiguration]? = nil,
        debounceMilliseconds: Int = TranslationTiming.defaultRealtimeDelayMilliseconds,
        realtimeTranslationEnabled: Bool = true,
        copyGeneratedResultToClipboard: Bool = true,
        defaultWritingStyle: WritingStyle = .spoken,
        panelContentSize: PanelContentSizeConfiguration = PanelPresentation.defaultContentSize,
        toggleShortcut: KeyboardShortcutConfiguration = .defaultToggleShortcut,
        resetWindowShortcut: KeyboardShortcutConfiguration = .defaultResetWindowShortcut,
        generateTranslationShortcut: KeyboardShortcutConfiguration = .defaultGenerateTranslationShortcut,
        polishInputShortcut: KeyboardShortcutConfiguration = .defaultPolishInputShortcut,
        commonPhrases: CommonPhraseCollection = .default
    ) {
        self.provider = provider
        self.providerConfigurations = Self.normalizedProviderConfigurations(
            providerConfigurations,
            selectedProvider: provider
        )
        self.debounceMilliseconds = TranslationTiming.clampedDebounceMilliseconds(debounceMilliseconds)
        self.realtimeTranslationEnabled = realtimeTranslationEnabled
        self.copyGeneratedResultToClipboard = copyGeneratedResultToClipboard
        self.defaultWritingStyle = defaultWritingStyle
        self.panelContentSize = PanelPresentation.clampedContentSize(panelContentSize)
        self.toggleShortcut = toggleShortcut
        self.resetWindowShortcut = Self.nonConflictingResetWindowShortcut(
            resetWindowShortcut,
            toggleShortcut: toggleShortcut
        )
        self.generateTranslationShortcut = Self.nonConflictingGenerateTranslationShortcut(
            generateTranslationShortcut,
            toggleShortcut: toggleShortcut,
            resetWindowShortcut: self.resetWindowShortcut
        )
        self.polishInputShortcut = Self.nonConflictingPolishInputShortcut(
            polishInputShortcut,
            toggleShortcut: toggleShortcut,
            resetWindowShortcut: self.resetWindowShortcut,
            generateTranslationShortcut: self.generateTranslationShortcut
        )
        self.commonPhrases = commonPhrases.normalized()
    }

    public static let `default` = AppConfiguration()

    private enum CodingKeys: String, CodingKey {
        case provider
        case providerConfigurations
        case debounceMilliseconds
        case realtimeTranslationEnabled
        case copyGeneratedResultToClipboard
        case defaultWritingStyle
        case panelContentSize
        case toggleShortcut
        case resetWindowShortcut
        case generateTranslationShortcut
        case polishInputShortcut
        case commonPhrases
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case panelWidth
        case panelWidthPercentage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        let decodedProvider = try container.decode(ProviderConfiguration.self, forKey: .provider)
        provider = decodedProvider
        providerConfigurations = Self.normalizedProviderConfigurations(
            try container.decodeIfPresent(
                [String: ProviderConfiguration].self,
                forKey: .providerConfigurations
            ),
            selectedProvider: decodedProvider
        )
        debounceMilliseconds = TranslationTiming.migratedDebounceMilliseconds(
            try container.decodeIfPresent(Int.self, forKey: .debounceMilliseconds)
        )
        realtimeTranslationEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .realtimeTranslationEnabled
        ) ?? true
        copyGeneratedResultToClipboard = try container.decodeIfPresent(
            Bool.self,
            forKey: .copyGeneratedResultToClipboard
        ) ?? true
        defaultWritingStyle = try container.decodeIfPresent(WritingStyle.self, forKey: .defaultWritingStyle) ?? .spoken
        toggleShortcut = try container.decodeIfPresent(
            KeyboardShortcutConfiguration.self,
            forKey: .toggleShortcut
        ) ?? .defaultToggleShortcut
        let decodedResetWindowShortcut = try container.decodeIfPresent(
            KeyboardShortcutConfiguration.self,
            forKey: .resetWindowShortcut
        ) ?? .defaultResetWindowShortcut
        resetWindowShortcut = Self.nonConflictingResetWindowShortcut(
            decodedResetWindowShortcut,
            toggleShortcut: toggleShortcut
        )
        let decodedGenerateTranslationShortcut = try container.decodeIfPresent(
            KeyboardShortcutConfiguration.self,
            forKey: .generateTranslationShortcut
        ) ?? .defaultGenerateTranslationShortcut
        generateTranslationShortcut = Self.nonConflictingGenerateTranslationShortcut(
            decodedGenerateTranslationShortcut,
            toggleShortcut: toggleShortcut,
            resetWindowShortcut: resetWindowShortcut
        )
        let persistedPolishInputShortcut = try container.decodeIfPresent(
            KeyboardShortcutConfiguration.self,
            forKey: .polishInputShortcut
        ) ?? .defaultPolishInputShortcut
        let decodedPolishInputShortcut = persistedPolishInputShortcut == .legacyDefaultPolishInputShortcut
            ? .defaultPolishInputShortcut
            : persistedPolishInputShortcut
        polishInputShortcut = Self.nonConflictingPolishInputShortcut(
            decodedPolishInputShortcut,
            toggleShortcut: toggleShortcut,
            resetWindowShortcut: resetWindowShortcut,
            generateTranslationShortcut: generateTranslationShortcut
        )
        commonPhrases = try container.decodeIfPresent(
            CommonPhraseCollection.self,
            forKey: .commonPhrases
        )?.normalized() ?? .default

        if let contentSize = try container.decodeIfPresent(
            PanelContentSizeConfiguration.self,
            forKey: .panelContentSize
        ) {
            panelContentSize = [
                PanelPresentation.legacyWideDefaultContentSize,
                PanelPresentation.legacyShallowDefaultContentSize,
                PanelPresentation.interimTallDefaultContentSize
            ].contains(contentSize)
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

    public func configuration(for provider: AIProvider) -> ProviderConfiguration {
        providerConfigurations[provider.rawValue] ?? provider.defaultConfiguration
    }

    public mutating func selectProvider(_ selectedProvider: AIProvider) {
        providerConfigurations[provider.provider.rawValue] = provider
        provider = configuration(for: selectedProvider)
    }

    public mutating func updateSelectedProvider(_ configuration: ProviderConfiguration) {
        provider = configuration
        providerConfigurations[configuration.provider.rawValue] = configuration
    }

    private static func nonConflictingResetWindowShortcut(
        _ shortcut: KeyboardShortcutConfiguration,
        toggleShortcut: KeyboardShortcutConfiguration
    ) -> KeyboardShortcutConfiguration {
        guard shortcut.conflicts(with: toggleShortcut) else { return shortcut }
        guard KeyboardShortcutConfiguration.defaultResetWindowShortcut.conflicts(with: toggleShortcut) else {
            return .defaultResetWindowShortcut
        }
        return .fallbackResetWindowShortcut
    }

    private static func nonConflictingGenerateTranslationShortcut(
        _ shortcut: KeyboardShortcutConfiguration,
        toggleShortcut: KeyboardShortcutConfiguration,
        resetWindowShortcut: KeyboardShortcutConfiguration
    ) -> KeyboardShortcutConfiguration {
        let existingShortcuts = [toggleShortcut, resetWindowShortcut]
        guard !existingShortcuts.contains(where: shortcut.conflicts) else {
            let defaultShortcut = KeyboardShortcutConfiguration.defaultGenerateTranslationShortcut
            guard existingShortcuts.contains(where: defaultShortcut.conflicts) else {
                return defaultShortcut
            }
            return .fallbackGenerateTranslationShortcut
        }
        return shortcut
    }

    private static func nonConflictingPolishInputShortcut(
        _ shortcut: KeyboardShortcutConfiguration,
        toggleShortcut: KeyboardShortcutConfiguration,
        resetWindowShortcut: KeyboardShortcutConfiguration,
        generateTranslationShortcut: KeyboardShortcutConfiguration
    ) -> KeyboardShortcutConfiguration {
        let existingShortcuts = [toggleShortcut, resetWindowShortcut, generateTranslationShortcut]
        guard !existingShortcuts.contains(where: shortcut.conflicts) else {
            let defaultShortcut = KeyboardShortcutConfiguration.defaultPolishInputShortcut
            guard existingShortcuts.contains(where: defaultShortcut.conflicts) else {
                return defaultShortcut
            }
            return .fallbackPolishInputShortcut
        }
        return shortcut
    }

    private static func normalizedProviderConfigurations(
        _ configurations: [String: ProviderConfiguration]?,
        selectedProvider: ProviderConfiguration
    ) -> [String: ProviderConfiguration] {
        var normalized = Dictionary(
            uniqueKeysWithValues: AIProvider.allCases.map {
                ($0.rawValue, $0.defaultConfiguration)
            }
        )

        if let configurations {
            for configuration in configurations.values {
                normalized[configuration.provider.rawValue] = configuration
            }
        }
        normalized[selectedProvider.provider.rawValue] = selectedProvider
        return normalized
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

public enum CommonPhraseDisplay {
    public static let defaultMenuTitleLength = 36

    public static func menuTitle(
        for phrase: String,
        maximumLength: Int = defaultMenuTitleLength
    ) -> String {
        let fallback = "Untitled phrase"
        guard maximumLength > 1 else { return fallback }

        let firstUsefulLine = phrase
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        guard !firstUsefulLine.isEmpty else { return fallback }

        if firstUsefulLine.count <= maximumLength {
            return firstUsefulLine
        }

        return String(firstUsefulLine.prefix(maximumLength - 1)) + "…"
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

    public var provider: AIProvider {
        AIProvider(rawValue: name) ?? .deepSeek
    }

    public static let defaultModel = "deepseek-v4-flash"

    public static let deepSeekDefault = ProviderConfiguration(
        name: "DeepSeek",
        baseURL: "https://api.deepseek.com",
        apiKey: "",
        model: Self.defaultModel
    )

    public static let openAIDefault = ProviderConfiguration(
        name: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        apiKey: "",
        model: "gpt-5-mini"
    )

    public static let openRouterDefault = ProviderConfiguration(
        name: "OpenRouter",
        baseURL: "https://openrouter.ai/api/v1",
        apiKey: "",
        model: "openai/gpt-5-mini"
    )
}

public enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case deepSeek = "DeepSeek"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"

    public var id: String { rawValue }

    public var defaultConfiguration: ProviderConfiguration {
        switch self {
        case .deepSeek:
            .deepSeekDefault
        case .openAI:
            .openAIDefault
        case .openRouter:
            .openRouterDefault
        }
    }

    public var suggestedModels: [String] {
        switch self {
        case .deepSeek:
            ["deepseek-v4-flash", "deepseek-chat", "deepseek-reasoner"]
        case .openAI:
            ["gpt-5-mini", "gpt-4.1-mini", "gpt-4o-mini"]
        case .openRouter:
            ["openai/gpt-5-mini", "openai/gpt-4.1-mini", "anthropic/claude-sonnet-4"]
        }
    }
}
