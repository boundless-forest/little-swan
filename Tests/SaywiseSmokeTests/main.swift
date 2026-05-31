import Foundation
import SaywiseCore

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
    precondition(configuration.panelWidth == PanelPresentation.defaultWidth)
}

func testConfigurationDecodesLegacySettingsWithoutDefaultStyle() throws {
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
    precondition(configuration.panelWidth == PanelPresentation.defaultWidth)
}

func testPanelPresentationClampsWidth() {
    precondition(PanelPresentation.clampedWidth(500) == PanelPresentation.minimumWidth)
    precondition(PanelPresentation.clampedWidth(1_500) == PanelPresentation.maximumWidth)
    precondition(PanelPresentation.clampedWidth(900, availableWidth: 820) == 796)
    precondition(PanelPresentation.clampedWidth(900, availableWidth: 600) == 576)
}

func testPanelPresentationHeightsFollowLayoutAndExpansion() {
    precondition(PanelPresentation.height(layout: .sideBySide, isExpanded: false) == 210)
    precondition(PanelPresentation.height(layout: .sideBySide, isExpanded: true) == 420)
    precondition(PanelPresentation.height(layout: .stacked, isExpanded: false) == 330)
    precondition(PanelPresentation.height(layout: .stacked, isExpanded: true) == 580)
}

func testConfigurationClampsPersistedPanelWidth() throws {
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
      "panelWidth": 2400
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: oversizedJSON)

    precondition(configuration.defaultWritingStyle == .professional)
    precondition(configuration.panelLayout == .stacked)
    precondition(configuration.panelWidth == PanelPresentation.maximumWidth)
}

func testConfigurationInitializerClampsPanelWidth() {
    let configuration = AppConfiguration(panelWidth: 2_400)

    precondition(configuration.panelWidth == PanelPresentation.maximumWidth)
}

testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt()
testDefaultConfigurationUsesDeepSeekFlash()
try testConfigurationDecodesLegacySettingsWithoutDefaultStyle()
testPanelPresentationClampsWidth()
testPanelPresentationHeightsFollowLayoutAndExpansion()
try testConfigurationClampsPersistedPanelWidth()
testConfigurationInitializerClampsPanelWidth()

print("Saywise smoke tests passed")
