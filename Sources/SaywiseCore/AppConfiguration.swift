import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var debounceMilliseconds: Int
    public var defaultWritingStyle: WritingStyle
    public var panelLayout: PanelLayout
    public var panelWidth: Int

    public init(
        provider: ProviderConfiguration = .deepSeekDefault,
        debounceMilliseconds: Int = 700,
        defaultWritingStyle: WritingStyle = .natural,
        panelLayout: PanelLayout = .sideBySide,
        panelWidth: Int = PanelPresentation.defaultWidth
    ) {
        self.provider = provider
        self.debounceMilliseconds = debounceMilliseconds
        self.defaultWritingStyle = defaultWritingStyle
        self.panelLayout = panelLayout
        self.panelWidth = PanelPresentation.clampedWidth(panelWidth)
    }

    public static let `default` = AppConfiguration()

    private enum CodingKeys: String, CodingKey {
        case provider
        case debounceMilliseconds
        case defaultWritingStyle
        case panelLayout
        case panelWidth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        provider = try container.decode(ProviderConfiguration.self, forKey: .provider)
        debounceMilliseconds = try container.decode(Int.self, forKey: .debounceMilliseconds)
        defaultWritingStyle = try container.decodeIfPresent(WritingStyle.self, forKey: .defaultWritingStyle) ?? .natural
        panelLayout = try container.decodeIfPresent(PanelLayout.self, forKey: .panelLayout) ?? .sideBySide
        panelWidth = PanelPresentation.clampedWidth(
            try container.decodeIfPresent(Int.self, forKey: .panelWidth) ?? PanelPresentation.defaultWidth
        )
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
        self.model = model
    }

    public static let deepSeekDefault = ProviderConfiguration(
        name: "DeepSeek",
        baseURL: "https://api.deepseek.com",
        apiKey: "",
        model: "deepseek-v4-flash"
    )
}
