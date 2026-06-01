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
    precondition(configuration.panelLayout == .sideBySide)
    precondition(configuration.panelWidthPercentage == PanelPresentation.defaultWidthPercentage)
    precondition(configuration.panelPosition == .center)
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
    precondition(configuration.panelLayout == .sideBySide)
    precondition(configuration.panelWidthPercentage == PanelPresentation.defaultWidthPercentage)
    precondition(configuration.panelPosition == .center)
}

func testPanelPresentationClampsWidthPercentage() {
    precondition(PanelPresentation.clampedWidthPercentage(20) == PanelPresentation.minimumWidthPercentage)
    precondition(PanelPresentation.clampedWidthPercentage(120) == PanelPresentation.maximumWidthPercentage)
    precondition(PanelPresentation.clampedWidthPercentage(65) == 65)
}

func testPanelPresentationUsesPercentageWidth() {
    precondition(PanelPresentation.width(percentage: 60, availableWidth: 1_000) == 586)
    precondition(PanelPresentation.width(percentage: 35, availableWidth: 600) == 360)
    precondition(PanelPresentation.width(percentage: 90, availableWidth: 600) == 518)
}

func testPanelPresentationHeightsFollowLayoutAndExpansion() {
    precondition(PanelPresentation.height(layout: .sideBySide, isExpanded: false) == 210)
    precondition(PanelPresentation.height(layout: .sideBySide, isExpanded: true) == 420)
    precondition(PanelPresentation.height(layout: .stacked, isExpanded: false) == 330)
    precondition(PanelPresentation.height(layout: .stacked, isExpanded: true) == 580)
}

func testConfigurationClampsPersistedPanelWidthPercentage() throws {
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
      "panelLayout": "stacked",
      "panelWidthPercentage": 120,
      "panelPosition": "bottomRight"
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: oversizedJSON)

    precondition(configuration.defaultWritingStyle == .professional)
    precondition(configuration.panelLayout == .stacked)
    precondition(configuration.panelWidthPercentage == PanelPresentation.maximumWidthPercentage)
    precondition(configuration.panelPosition == .bottomRight)
}

func testConfigurationDecodesLegacyPanelWidthAsPercentage() throws {
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
      "panelLayout": "stacked",
      "panelWidth": 860
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyJSON)

    precondition(configuration.panelWidthPercentage == 61)
    precondition(configuration.panelPosition == .center)
}

func testConfigurationInitializerClampsPanelWidthPercentage() {
    let configuration = AppConfiguration(panelWidthPercentage: 120, panelPosition: .bottomLeft)

    precondition(configuration.panelWidthPercentage == PanelPresentation.maximumWidthPercentage)
    precondition(configuration.panelPosition == .bottomLeft)
}

testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt()
testDefaultConfigurationUsesDeepSeekFlash()
try testConfigurationDecodesLegacySettingsWithoutPanelPreferences()
testPanelPresentationClampsWidthPercentage()
testPanelPresentationUsesPercentageWidth()
testPanelPresentationHeightsFollowLayoutAndExpansion()
try testConfigurationClampsPersistedPanelWidthPercentage()
try testConfigurationDecodesLegacyPanelWidthAsPercentage()
testConfigurationInitializerClampsPanelWidthPercentage()

print("ExpressBridge smoke tests passed")
