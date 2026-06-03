import Foundation
import ExpressBridgeCore

func testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt() {
    let messages = PromptBuilder.messages(input: "这个功能以后会支持吗？", style: .natural)

    precondition(messages.count == 2)
    precondition(messages[0].role == "system")
    precondition(messages[0].content.contains("Detect the user's input language automatically."))
    precondition(messages[0].content.contains("Rewrite or translate the user's text into English only."))
    precondition(messages[0].content.contains(WritingStyle.natural.instruction))
    precondition(messages[1] == DeepSeekMessage(role: "user", content: "这个功能以后会支持吗？"))
}

func testDefaultConfigurationUsesDeepSeekFlash() {
    let configuration = AppConfiguration.default

    precondition(configuration.provider.name == "DeepSeek")
    precondition(configuration.provider.baseURL == "https://api.deepseek.com")
    precondition(configuration.provider.model == "deepseek-v4-flash")
    precondition(configuration.provider.apiKey.isEmpty)
    precondition(configuration.debounceMilliseconds == 700)
    precondition(configuration.defaultWritingStyle == .natural)
    precondition(configuration.panelContentSize == PanelPresentation.defaultContentSize)
}

func testConfigurationDecodesLegacySettingsWithoutPanelPreferences() throws {
    let legacyJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyJSON)

    precondition(configuration.defaultWritingStyle == .natural)
    precondition(configuration.panelContentSize == PanelPresentation.defaultContentSize)
}

func testPanelPresentationClampsContentSize() {
    let clampedSize = PanelPresentation.clampedContentSize(
        PanelContentSizeConfiguration(width: 100, height: 100),
        availableWidth: 700,
        availableHeight: 500
    )

    precondition(clampedSize.width == PanelPresentation.minimumContentWidth)
    precondition(clampedSize.height == PanelPresentation.minimumContentHeight)
}

func testPanelPresentationConvertsLegacyPercentageWidth() {
    precondition(PanelPresentation.width(percentage: 60, availableWidth: 1_000) == 586)
    precondition(PanelPresentation.contentSize(widthPercentage: 60).height == PanelPresentation.defaultContentHeight)
}

func testConfigurationClampsPersistedPanelContentSize() throws {
    let oversizedJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "defaultWritingStyle": "professional",
      "panelContentSize": {
        "width": 120,
        "height": 100
      }
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: oversizedJSON)

    precondition(configuration.defaultWritingStyle == .professional)
    precondition(configuration.panelContentSize.width == PanelPresentation.minimumContentWidth)
    precondition(configuration.panelContentSize.height == PanelPresentation.minimumContentHeight)
}

func testConfigurationDecodesLegacyPanelWidthAsContentSize() throws {
    let legacyJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "defaultWritingStyle": "professional",
      "panelWidth": 860
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyJSON)

    precondition(configuration.panelContentSize.width == 860)
    precondition(configuration.panelContentSize.height == PanelPresentation.defaultContentHeight)
}

func testConfigurationDecodesLegacyPanelWidthPercentageAsContentSize() throws {
    let legacyJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "panelWidthPercentage": 120
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyJSON)

    precondition(configuration.panelContentSize.width == PanelPresentation.fallbackAvailableWidth - PanelPresentation.screenMargin * 2)
    precondition(configuration.panelContentSize.height == PanelPresentation.defaultContentHeight)
}

func testConfigurationInitializerClampsPanelContentSize() {
    let configuration = AppConfiguration(
        panelContentSize: PanelContentSizeConfiguration(width: 120, height: 100)
    )

    precondition(configuration.panelContentSize.width == PanelPresentation.minimumContentWidth)
    precondition(configuration.panelContentSize.height == PanelPresentation.minimumContentHeight)
}

testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt()
testDefaultConfigurationUsesDeepSeekFlash()
try testConfigurationDecodesLegacySettingsWithoutPanelPreferences()
testPanelPresentationClampsContentSize()
testPanelPresentationConvertsLegacyPercentageWidth()
try testConfigurationClampsPersistedPanelContentSize()
try testConfigurationDecodesLegacyPanelWidthAsContentSize()
try testConfigurationDecodesLegacyPanelWidthPercentageAsContentSize()
testConfigurationInitializerClampsPanelContentSize()

print("ExpressBridge smoke tests passed")
