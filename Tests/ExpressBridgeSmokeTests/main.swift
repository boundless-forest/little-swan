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
    precondition(configuration.panelWidthPercentage == PanelPresentation.defaultWidthPercentage)
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
    precondition(configuration.panelWidthPercentage == PanelPresentation.defaultWidthPercentage)
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

func testPanelPresentationHeightsFollowExpansion() {
    precondition(PanelPresentation.height(isExpanded: false) == 210)
    precondition(PanelPresentation.height(isExpanded: true) == 420)
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
      "panelWidthPercentage": 120
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: oversizedJSON)

    precondition(configuration.defaultWritingStyle == .professional)
    precondition(configuration.panelWidthPercentage == PanelPresentation.maximumWidthPercentage)
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
      "panelWidth": 860
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyJSON)

    precondition(configuration.panelWidthPercentage == 61)
}

func testConfigurationInitializerClampsPanelWidthPercentage() {
    let configuration = AppConfiguration(panelWidthPercentage: 120)

    precondition(configuration.panelWidthPercentage == PanelPresentation.maximumWidthPercentage)
}

testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt()
testDefaultConfigurationUsesDeepSeekFlash()
try testConfigurationDecodesLegacySettingsWithoutPanelPreferences()
testPanelPresentationClampsWidthPercentage()
testPanelPresentationUsesPercentageWidth()
testPanelPresentationHeightsFollowExpansion()
try testConfigurationClampsPersistedPanelWidthPercentage()
try testConfigurationDecodesLegacyPanelWidthAsPercentage()
testConfigurationInitializerClampsPanelWidthPercentage()

print("ExpressBridge smoke tests passed")
