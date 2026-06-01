import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var debounceMilliseconds: Int
    public var defaultWritingStyle: WritingStyle
    public var panelLayout: PanelLayout
    public var panelWidthPercentage: Int
    public var panelPosition: PanelPosition

    public init(
        provider: ProviderConfiguration = .deepSeekDefault,
        debounceMilliseconds: Int = 700,
        defaultWritingStyle: WritingStyle = .natural,
        panelLayout: PanelLayout = .sideBySide,
        panelWidthPercentage: Int = PanelPresentation.defaultWidthPercentage,
        panelPosition: PanelPosition = .center
    ) {
        self.provider = provider
        self.debounceMilliseconds = debounceMilliseconds
        self.defaultWritingStyle = defaultWritingStyle
        self.panelLayout = panelLayout
        self.panelWidthPercentage = PanelPresentation.clampedWidthPercentage(panelWidthPercentage)
        self.panelPosition = panelPosition
    }

    public static let `default` = AppConfiguration()

    private enum CodingKeys: String, CodingKey {
        case provider
        case debounceMilliseconds
        case defaultWritingStyle
        case panelLayout
        case panelWidthPercentage
        case panelPosition
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case panelWidth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        provider = try container.decode(ProviderConfiguration.self, forKey: .provider)
        debounceMilliseconds = try container.decode(Int.self, forKey: .debounceMilliseconds)
        defaultWritingStyle = try container.decodeIfPresent(WritingStyle.self, forKey: .defaultWritingStyle) ?? .natural
        panelLayout = try container.decodeIfPresent(PanelLayout.self, forKey: .panelLayout) ?? .sideBySide
        panelPosition = try container.decodeIfPresent(PanelPosition.self, forKey: .panelPosition) ?? .center

        // Older builds stored an absolute pixel width. Convert it once into the new percentage-based
        // setting so the same config scales sensibly on different displays after the rename.
        if let widthPercentage = try container.decodeIfPresent(Int.self, forKey: .panelWidthPercentage) {
            panelWidthPercentage = PanelPresentation.clampedWidthPercentage(widthPercentage)
        } else if let legacyWidth = try legacyContainer.decodeIfPresent(Int.self, forKey: .panelWidth) {
            panelWidthPercentage = PanelPresentation.widthPercentage(forLegacyWidth: legacyWidth)
        } else {
            panelWidthPercentage = PanelPresentation.defaultWidthPercentage
        }
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
