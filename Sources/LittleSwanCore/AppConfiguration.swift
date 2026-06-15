import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var debounceMilliseconds: Int
    public var defaultWritingStyle: WritingStyle
    public var panelContentSize: PanelContentSizeConfiguration
    public var toggleShortcut: KeyboardShortcutConfiguration

    public init(
        provider: ProviderConfiguration = .deepSeekDefault,
        debounceMilliseconds: Int = TranslationTiming.defaultRealtimeDelayMilliseconds,
        defaultWritingStyle: WritingStyle = .natural,
        panelContentSize: PanelContentSizeConfiguration = PanelPresentation.defaultContentSize,
        toggleShortcut: KeyboardShortcutConfiguration = .defaultToggleShortcut
    ) {
        self.provider = provider
        self.debounceMilliseconds = TranslationTiming.clampedDebounceMilliseconds(debounceMilliseconds)
        self.defaultWritingStyle = defaultWritingStyle
        self.panelContentSize = PanelPresentation.clampedContentSize(panelContentSize)
        self.toggleShortcut = toggleShortcut
    }

    public static let `default` = AppConfiguration()

    private enum CodingKeys: String, CodingKey {
        case provider
        case debounceMilliseconds
        case defaultWritingStyle
        case panelContentSize
        case toggleShortcut
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
