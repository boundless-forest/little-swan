import Foundation
import LittleSwanCore

func testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt() {
    let messages = PromptBuilder.messages(input: "这个功能以后会支持吗？", style: .natural)

    precondition(messages.count == 2)
    precondition(messages[0].role == "system")
    precondition(messages[0].content.contains("Detect the user's input language automatically."))
    precondition(messages[0].content.contains("Rewrite or translate the user's text into English only."))
    precondition(messages[0].content.contains(WritingStyle.natural.instruction))
    precondition(messages[1] == DeepSeekMessage(role: "user", content: "这个功能以后会支持吗？"))
}

func testDefaultConfigurationUsesDeepSeekPro() {
    let configuration = AppConfiguration.default

    precondition(configuration.provider.name == "DeepSeek")
    precondition(configuration.provider.baseURL == "https://api.deepseek.com")
    precondition(configuration.provider.model == "deepseek-v4-pro")
    precondition(configuration.provider.apiKey.isEmpty)
    precondition(configuration.debounceMilliseconds == 700)
    precondition(configuration.defaultWritingStyle == .natural)
    precondition(configuration.panelContentSize == PanelPresentation.defaultContentSize)
    precondition(configuration.sourceEnglishLayout == .horizontal)
    precondition(configuration.toggleShortcut == KeyboardShortcutConfiguration.defaultToggleShortcut)
    precondition(configuration.toggleShortcut.displayString == "⌃L")
}

func testConfigurationMigratesDeepSeekFlashToProDuringDevelopment() throws {
    let persistedJSON = """
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

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: persistedJSON)

    precondition(configuration.provider.model == "deepseek-v4-pro")
}

func testSourceCompletionInsertionUsesUTF16Offsets() {
    let text = "你好🙂世界"
    let locationAfterEmoji = (text as NSString).range(of: "世界").location

    let result = SourceCompletionInsertion.insert(
        suggestion: " beautiful",
        into: text,
        utf16Location: locationAfterEmoji
    )

    precondition(result.text == "你好🙂 beautiful世界")
    precondition(result.newUTF16Location == locationAfterEmoji + (" beautiful" as NSString).length)
}

func testSourceCompletionSanitizerPreservesLeadingWhitespaceAndTrimsTrailingWhitespace() {
    let sanitized = SourceCompletionSanitizer.sanitize("  next\n\n", maxUTF16Length: 48)

    precondition(sanitized == "  next")
}

func testSourceCompletionSanitizerLimitsSuggestionToOneWord() {
    let sanitized = SourceCompletionSanitizer.sanitize("  beautiful little swan app today", maxUTF16Length: 48)

    precondition(sanitized == "  beautiful")
}

func testSourceCompletionSanitizerRejectsOpenEndedSentenceContinuations() {
    precondition(SourceCompletionSanitizer.sanitize(" and I think we should", maxUTF16Length: 48).isEmpty)
    precondition(SourceCompletionSanitizer.sanitize(" tomorrow.", maxUTF16Length: 48).isEmpty)
    precondition(SourceCompletionSanitizer.sanitize(" next\nline", maxUTF16Length: 48).isEmpty)
}

func testSourceCompletionSanitizerKeepsShortCJKContinuationsConservative() {
    precondition(SourceCompletionSanitizer.sanitize("世界你好", maxUTF16Length: 48) == "世界")
}

func testSourceCompletionAcceptanceUsesOnlyDisplayedSuggestion() {
    let accepted = SourceCompletionAcceptance.acceptedPrefix(from: "  beautiful")

    precondition(accepted == "  beautiful")
}

func testSourceCompletionEligibilityRequiresEnoughContext() {
    precondition(SourceCompletionEligibility.shouldRequest(prefix: "Hi", suffix: "") == false)
    precondition(SourceCompletionEligibility.shouldRequest(prefix: "Let's meet at", suffix: "") == true)
    precondition(SourceCompletionEligibility.shouldRequest(prefix: "Let's meet.", suffix: "") == false)
    precondition(SourceCompletionEligibility.shouldRequest(prefix: "Let's", suffix: " later") == true)
}

func testSourceCompletionAcceptanceKeepsSingleChineseToken() {
    let accepted = SourceCompletionAcceptance.acceptedPrefix(from: "世界")

    precondition(accepted == "世界")
}

func testSourceCompletionSanitizerCapsByUTF16Length() {
    let sanitized = SourceCompletionSanitizer.sanitize("abcdef", maxUTF16Length: 3)

    precondition(sanitized == "abc")
}

func testFIMCompletionRequestUsesRawPrefixSuffixDefaults() throws {
    let request = FIMCompletionRequest(
        model: "deepseek-v4-pro",
        prompt: "Hello",
        suffix: "world"
    )

    precondition(request.model == "deepseek-v4-pro")
    precondition(request.prompt == "Hello")
    precondition(request.suffix == "world")
    precondition(SourceCompletionDefaults.debounceMilliseconds == 250)
    precondition(request.maxTokens == 4)
    precondition(request.temperature == 0.25)
    precondition(request.stream == false)
    precondition(request.stop == ["\n\n"])

    let data = try JSONEncoder().encode(request)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    precondition(object?["max_tokens"] as? Int == 4)
}

func testSourceEnglishLayoutLabelsAreUserFacing() {
    precondition(SourceEnglishLayout.horizontal.label == "Horizontal")
    precondition(SourceEnglishLayout.vertical.label == "Vertical")
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
    precondition(configuration.sourceEnglishLayout == .horizontal)
}

func testConfigurationDecodesPersistedVerticalSourceEnglishLayout() throws {
    let persistedJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "sourceEnglishLayout": "vertical"
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: persistedJSON)

    precondition(configuration.sourceEnglishLayout == .vertical)
}

func testConfigurationDecodesPersistedToggleShortcut() throws {
    let persistedJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "toggleShortcut": {
        "keyCode": 49,
        "modifierFlags": 1048576
      }
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: persistedJSON)

    precondition(configuration.toggleShortcut.keyCode == 49)
    precondition(configuration.toggleShortcut.modifierFlags == KeyboardShortcutConfiguration.commandModifierFlag)
    precondition(configuration.toggleShortcut.displayString == "⌘Space")
}

func testConfigurationDecodesLegacySettingsWithDefaultToggleShortcut() throws {
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

    precondition(configuration.toggleShortcut == .defaultToggleShortcut)
}

func testKeyboardShortcutRejectsMissingModifierOrKey() {
    precondition(KeyboardShortcutConfiguration(keyCode: 37, modifierFlags: 0).isValid == false)
    precondition(KeyboardShortcutConfiguration(keyCode: nil, modifierFlags: KeyboardShortcutConfiguration.controlModifierFlag).isValid == false)
    precondition(KeyboardShortcutConfiguration.defaultToggleShortcut.isValid)
}

func testKeyboardShortcutDecodingMasksUnsupportedModifiers() throws {
    let data = """
    {
      "keyCode": 37,
      "modifierFlags": 9223372036854775808
    }
    """.data(using: .utf8)!

    let shortcut = try JSONDecoder().decode(KeyboardShortcutConfiguration.self, from: data)

    precondition(shortcut.modifierFlags == 0)
    precondition(shortcut.isValid == false)
}

func testKeyboardShortcutProvidesMenuEquivalentForDefaultToggleShortcut() {
    let shortcut = KeyboardShortcutConfiguration.defaultToggleShortcut

    precondition(shortcut.menuKeyEquivalent == "l")
    precondition(shortcut.menuModifierFlags == KeyboardShortcutConfiguration.controlModifierFlag)
}

func testKeyboardShortcutProvidesMenuEquivalentForFunctionAndArrowKeys() {
    let f1Shortcut = KeyboardShortcutConfiguration(
        keyCode: 122,
        modifierFlags: KeyboardShortcutConfiguration.controlModifierFlag
    )
    let leftArrowShortcut = KeyboardShortcutConfiguration(
        keyCode: 123,
        modifierFlags: KeyboardShortcutConfiguration.optionModifierFlag
    )

    precondition(f1Shortcut.menuKeyEquivalent == "\u{F704}")
    precondition(f1Shortcut.menuModifierFlags == KeyboardShortcutConfiguration.controlModifierFlag)
    precondition(leftArrowShortcut.menuKeyEquivalent == "\u{F702}")
    precondition(leftArrowShortcut.menuModifierFlags == KeyboardShortcutConfiguration.optionModifierFlag)
}

func testKeyboardShortcutOmitsInvalidShortcutFromMenuEquivalent() {
    let shortcut = KeyboardShortcutConfiguration(keyCode: 37, modifierFlags: 0)

    precondition(shortcut.menuKeyEquivalent == nil)
    precondition(shortcut.menuModifierFlags == nil)
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
    precondition(PanelPresentation.height(percentage: 12, availableHeight: 800) == 120)
    precondition(PanelPresentation.contentSize(widthPercentage: 60).height == PanelPresentation.defaultContentSize.height)
}

func testPanelPresentationComputesResponsiveDefaultContentSize() {
    let compactSize = PanelPresentation.defaultContentSize(availableWidth: 900, availableHeight: 700)
    let spaciousSize = PanelPresentation.defaultContentSize(availableWidth: 2_400, availableHeight: 1_200)

    precondition(compactSize.width == 526)
    precondition(compactSize.height == 120)
    precondition(spaciousSize.width == 1_426)
    precondition(spaciousSize.height == 141)
    precondition(compactSize.width > compactSize.height)
    precondition(spaciousSize.width > spaciousSize.height)
    precondition(spaciousSize.width > compactSize.width)
    precondition(spaciousSize.height > compactSize.height)
}

func testConfigurationMigratesLegacyWideDefaultPanelContentSize() throws {
    let legacyDefaultJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "panelContentSize": {
        "width": 850,
        "height": 300
      }
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyDefaultJSON)

    precondition(configuration.panelContentSize == PanelPresentation.defaultContentSize)
    precondition(configuration.sourceEnglishLayout == .horizontal)
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
    precondition(configuration.panelContentSize.height == PanelPresentation.defaultContentSize.height)
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
    precondition(configuration.panelContentSize.height == PanelPresentation.defaultContentSize.height)
}

func testConfigurationInitializerClampsPanelContentSize() {
    let configuration = AppConfiguration(
        panelContentSize: PanelContentSizeConfiguration(width: 120, height: 100)
    )

    precondition(configuration.panelContentSize.width == PanelPresentation.minimumContentWidth)
    precondition(configuration.panelContentSize.height == PanelPresentation.minimumContentHeight)
}

testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt()
testDefaultConfigurationUsesDeepSeekPro()
try testConfigurationMigratesDeepSeekFlashToProDuringDevelopment()
testSourceCompletionInsertionUsesUTF16Offsets()
testSourceCompletionSanitizerPreservesLeadingWhitespaceAndTrimsTrailingWhitespace()
testSourceCompletionSanitizerLimitsSuggestionToOneWord()
testSourceCompletionSanitizerRejectsOpenEndedSentenceContinuations()
testSourceCompletionSanitizerKeepsShortCJKContinuationsConservative()
testSourceCompletionAcceptanceUsesOnlyDisplayedSuggestion()
testSourceCompletionEligibilityRequiresEnoughContext()
testSourceCompletionAcceptanceKeepsSingleChineseToken()
testSourceCompletionSanitizerCapsByUTF16Length()
try testFIMCompletionRequestUsesRawPrefixSuffixDefaults()
testSourceEnglishLayoutLabelsAreUserFacing()
try testConfigurationDecodesLegacySettingsWithoutPanelPreferences()
try testConfigurationDecodesPersistedVerticalSourceEnglishLayout()
try testConfigurationDecodesPersistedToggleShortcut()
try testConfigurationDecodesLegacySettingsWithDefaultToggleShortcut()
testKeyboardShortcutRejectsMissingModifierOrKey()
try testKeyboardShortcutDecodingMasksUnsupportedModifiers()
testKeyboardShortcutProvidesMenuEquivalentForDefaultToggleShortcut()
testKeyboardShortcutProvidesMenuEquivalentForFunctionAndArrowKeys()
testKeyboardShortcutOmitsInvalidShortcutFromMenuEquivalent()
testPanelPresentationClampsContentSize()
testPanelPresentationConvertsLegacyPercentageWidth()
testPanelPresentationComputesResponsiveDefaultContentSize()
try testConfigurationMigratesLegacyWideDefaultPanelContentSize()
try testConfigurationClampsPersistedPanelContentSize()
try testConfigurationDecodesLegacyPanelWidthAsContentSize()
try testConfigurationDecodesLegacyPanelWidthPercentageAsContentSize()
testConfigurationInitializerClampsPanelContentSize()

print("Little Swan smoke tests passed")
