import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var debounceMilliseconds: Int
    public var defaultWritingStyle: WritingStyle
    public var panelContentSize: PanelContentSizeConfiguration

    public init(
        provider: ProviderConfiguration = .deepSeekDefault,
        debounceMilliseconds: Int = 700,
        defaultWritingStyle: WritingStyle = .natural,
        panelContentSize: PanelContentSizeConfiguration = PanelPresentation.defaultContentSize
    ) {
        self.provider = provider
        self.debounceMilliseconds = debounceMilliseconds
        self.defaultWritingStyle = defaultWritingStyle
        self.panelContentSize = PanelPresentation.clampedContentSize(panelContentSize)
    }

    public static let `default` = AppConfiguration()

    private enum CodingKeys: String, CodingKey {
        case provider
        case debounceMilliseconds
        case defaultWritingStyle
        case panelContentSize
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case panelWidth
        case panelWidthPercentage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        provider = try container.decode(ProviderConfiguration.self, forKey: .provider)
        debounceMilliseconds = try container.decode(Int.self, forKey: .debounceMilliseconds)
        defaultWritingStyle = try container.decodeIfPresent(WritingStyle.self, forKey: .defaultWritingStyle) ?? .natural

        if let contentSize = try container.decodeIfPresent(
            PanelContentSizeConfiguration.self,
            forKey: .panelContentSize
        ) {
            panelContentSize = PanelPresentation.clampedContentSize(contentSize)
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
        self.model = model
    }

    public static let deepSeekDefault = ProviderConfiguration(
        name: "DeepSeek",
        baseURL: "https://api.deepseek.com",
        apiKey: "",
        model: "deepseek-v4-flash"
    )
}
