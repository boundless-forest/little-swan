import Foundation
import LittleSwanCore

func testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt() {
    let messages = PromptBuilder.messages(input: "这个功能以后会支持吗？", style: .natural)

    precondition(messages.count == 2)
    precondition(messages[0].role == "system")
    precondition(messages[0].content.contains("Detect the user's input language automatically."))
    precondition(messages[0].content.contains("Rewrite or translate the user's text into English only."))
    precondition(messages[0].content.contains("Use clear, everyday English."))
    precondition(messages[0].content.contains("Translate meaningfully instead of word by word."))
    precondition(messages[0].content.contains("Preserve the source format as closely as possible"))
    precondition(messages[0].content.contains("For code blocks, keep the same fence markers"))
    precondition(messages[0].content.contains(WritingStyle.natural.instruction))
    precondition(messages[1] == DeepSeekMessage(role: "user", content: "这个功能以后会支持吗？"))
}

func testPromptBuilderPreservesUserCodeBlockInput() {
    let input = """
    请帮我解释这个错误：

    ```swift
    print("hello")
    ```
    """
    let messages = PromptBuilder.messages(input: input, style: .professional)

    precondition(messages[0].content.contains("Preserve Markdown structure from the source"))
    precondition(messages[0].content.contains("Translate only human-readable prose around code"))
    precondition(messages[0].content.contains(WritingStyle.professional.instruction))
    precondition(messages[1] == DeepSeekMessage(role: "user", content: input))
}

func testDefaultConfigurationUsesDeepSeekFlashWithFastRealtimeDelay() {
    let configuration = AppConfiguration.default

    precondition(configuration.provider.name == "DeepSeek")
    precondition(configuration.provider.baseURL == "https://api.deepseek.com")
    precondition(configuration.provider.model == "deepseek-v4-flash")
    precondition(configuration.provider.apiKey.isEmpty)
    precondition(configuration.debounceMilliseconds == TranslationTiming.defaultRealtimeDelayMilliseconds)
    precondition(configuration.debounceMilliseconds == 200)
    precondition(configuration.defaultWritingStyle == .natural)
    precondition(configuration.panelContentSize == PanelPresentation.defaultContentSize)
    precondition(configuration.toggleShortcut == KeyboardShortcutConfiguration.defaultToggleShortcut)
    precondition(configuration.toggleShortcut.displayString == "⌃L")
    precondition(configuration.commonPhrases == CommonPhraseCollection.default)
}

func testConfigurationMigratesDeepSeekProAndLegacyDelayForSpeed() throws {
    let persistedJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-pro"
      },
      "debounceMilliseconds": 700
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: persistedJSON)

    precondition(configuration.provider.model == "deepseek-v4-flash")
    precondition(configuration.debounceMilliseconds == TranslationTiming.defaultRealtimeDelayMilliseconds)
}

func testConfigurationClampsSlowPersistedRealtimeDelay() throws {
    let persistedJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 5000
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: persistedJSON)

    precondition(configuration.debounceMilliseconds == TranslationTiming.maximumRealtimeDelayMilliseconds)
    precondition(AppConfiguration(debounceMilliseconds: 0).debounceMilliseconds == TranslationTiming.minimumRealtimeDelayMilliseconds)
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

func testConfigurationIgnoresLegacySourceEnglishLayoutPreference() throws {
    let legacyJSON = """
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

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: legacyJSON)
    let encoded = try JSONEncoder().encode(configuration)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

    precondition(configuration.defaultWritingStyle == .natural)
    precondition(configuration.panelContentSize == PanelPresentation.defaultContentSize)
    precondition(object?["sourceEnglishLayout"] == nil)
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

func testCommonPhraseCollectionNormalizesPhrases() {
    let longPhrase = String(repeating: "x", count: CommonPhraseCollection.maximumPhraseLength + 8)
    let multiLinePhrase = """
    Please review the following plan:
    - Check the diff
    - Run the tests
    """
    let collection = CommonPhraseCollection(phrases: [
        "  Thanks!  ",
        "",
        "thanks!",
        longPhrase,
        multiLinePhrase
    ])

    precondition(CommonPhraseCollection.maximumPhraseLength >= 10_000)
    precondition(collection.phrases.count == 3)
    precondition(collection.phrases[0] == "Thanks!")
    precondition(collection.phrases[1].count == CommonPhraseCollection.maximumPhraseLength)
    precondition(collection.phrases[2].contains("- Run the tests"))
}

func testCommonPhraseInsertionAppendsWithReadableSpacing() {
    precondition(CommonPhraseInsertion.appending("Thanks!", to: "") == "Thanks!")
    precondition(CommonPhraseInsertion.appending("Thanks!", to: "Hi") == "Hi Thanks!")
    precondition(CommonPhraseInsertion.appending("Thanks!", to: "Hi ") == "Hi Thanks!")
    precondition(CommonPhraseInsertion.appending("  Thanks!  ", to: "Hi\n") == "Hi\nThanks!")
    precondition(CommonPhraseInsertion.appending("  ", to: "Hi") == "Hi")
}

func testConfigurationDecodesPersistedCommonPhrases() throws {
    let persistedJSON = """
    {
      "provider": {
        "name": "DeepSeek",
        "baseURL": "https://api.deepseek.com",
        "apiKey": "",
        "model": "deepseek-v4-flash"
      },
      "debounceMilliseconds": 700,
      "commonPhrases": {
        "phrases": ["  Thanks!  ", "", "thanks!", "I'll follow up."]
      }
    }
    """.data(using: .utf8)!

    let configuration = try JSONDecoder().decode(AppConfiguration.self, from: persistedJSON)
    let encoded = try JSONEncoder().encode(configuration)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    let commonPhrases = object?["commonPhrases"] as? [String: Any]

    precondition(configuration.commonPhrases.phrases == ["Thanks!", "I'll follow up."])
    precondition(commonPhrases?["phrases"] as? [String] == ["Thanks!", "I'll follow up."])
}

func testConfigurationDecodesLegacySettingsWithDefaultCommonPhrases() throws {
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

    precondition(configuration.commonPhrases == CommonPhraseCollection.default)
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

func testSourceDraftCollectionStartsWithThreeEmptyDrafts() {
    let collection = SourceDraftCollection.default

    precondition(collection.version == 1)
    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.drafts.count == 3)
    precondition(collection.selectedDraftID == collection.drafts[0].id)
    precondition(collection.selectedDraft?.text == "")
    precondition(collection.drafts.enumerated().allSatisfy { index, draft in
        draft.displayTitle(fallbackIndex: index) == "Draft \(index + 1)"
    })
}

func testSourceDraftCollectionUpdatesSelectedDraftText() {
    var collection = SourceDraftCollection.default
    let selectedID = collection.selectedDraftID

    collection.updateSelectedDraftText("Please rewrite this message")

    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.selectedDraftID == selectedID)
    let selectedDraft = collection.selectedDraft!
    precondition(selectedDraft.text == "Please rewrite this message")
    precondition(selectedDraft.updatedAt >= selectedDraft.createdAt)
}

func testSourceDraftCollectionCreateDraftIsStrictlyLimitedToThree() {
    var collection = SourceDraftCollection.default
    let originalIDs = collection.drafts.map(\.id)

    let returnedDraft = collection.createDraft(text: "Should not create a fourth draft")

    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.drafts.map(\.id) == originalIDs)
    precondition(returnedDraft.id == collection.selectedDraftID)
    precondition(collection.selectedDraft?.text == "")
}

func testSourceDraftCollectionNormalizesPersistedDraftsToExactlyThree() {
    let selected = SourceDraft(text: "Selected")
    let extraDrafts = [
        SourceDraft(text: "First"),
        selected,
        SourceDraft(text: "Third"),
        SourceDraft(text: "Fourth")
    ]

    let collection = SourceDraftCollection(selectedDraftID: selected.id, drafts: extraDrafts)

    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.selectedDraftID == selected.id)
    precondition(collection.selectedDraft?.text == "Selected")
    precondition(collection.drafts.map(\.text) == ["First", "Selected", "Third"])
}

func testSourceDraftCollectionPadsPersistedDraftsToExactlyThree() {
    let draft = SourceDraft(text: "Only saved draft")

    let collection = SourceDraftCollection(selectedDraftID: draft.id, drafts: [draft])

    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.selectedDraftID == draft.id)
    precondition(collection.drafts[0].text == "Only saved draft")
    precondition(collection.drafts[1].text == "")
    precondition(collection.drafts[2].text == "")
}

func testSourceDraftCollectionKeepsThreeDraftsWhenDeleting() {
    var collection = SourceDraftCollection.default
    let deletedID = collection.selectedDraftID

    collection.deleteDraft(id: deletedID)

    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.selectedDraftID != deletedID)
    precondition(!collection.drafts.contains { $0.id == deletedID })
}

func testSourceDraftCollectionSelectsNeighborWhenDeletingSelectedDraft() {
    let first = SourceDraft(text: "First")
    let second = SourceDraft(text: "Second")
    let third = SourceDraft(text: "Third")
    var collection = SourceDraftCollection(selectedDraftID: third.id, drafts: [first, second, third])

    collection.deleteDraft(id: collection.selectedDraftID)

    precondition(collection.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(collection.selectedDraftID == second.id)
    precondition(collection.selectedDraft?.text == "Second")
    precondition(collection.drafts.contains { $0.id == first.id })
    precondition(!collection.drafts.contains { $0.id == third.id })
}

func testSourceDraftCollectionLabelsStayNumbered() {
    let emptyDraft = SourceDraft(text: "")
    let titledDraft = SourceDraft(text: "\n  Email to Jane  \nMore details")
    let longDraft = SourceDraft(text: "This is a very long unfinished source draft title")

    precondition(emptyDraft.displayTitle(fallbackIndex: 0) == "Draft 1")
    precondition(titledDraft.displayTitle(fallbackIndex: 1) == "Draft 2")
    precondition(longDraft.displayTitle(fallbackIndex: 2) == "Draft 3")
}

func testSourceDraftCollectionDecodingNormalizesLegacyDraftCount() throws {
    let oneDraftJSON = """
    {
      "version": 1,
      "selectedDraftID": "11111111-1111-1111-1111-111111111111",
      "drafts": [
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "text": "Legacy one draft",
          "createdAt": "2026-06-08T00:00:00Z",
          "updatedAt": "2026-06-08T00:00:00Z"
        },
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "text": "Legacy extra draft",
          "createdAt": "2026-06-08T00:00:00Z",
          "updatedAt": "2026-06-08T00:00:00Z"
        },
        {
          "id": "33333333-3333-3333-3333-333333333333",
          "text": "Legacy third draft",
          "createdAt": "2026-06-08T00:00:00Z",
          "updatedAt": "2026-06-08T00:00:00Z"
        },
        {
          "id": "44444444-4444-4444-4444-444444444444",
          "text": "Legacy fourth draft",
          "createdAt": "2026-06-08T00:00:00Z",
          "updatedAt": "2026-06-08T00:00:00Z"
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(SourceDraftCollection.self, from: oneDraftJSON)

    precondition(decoded.drafts.count == SourceDraftCollection.maximumDraftCount)
    precondition(decoded.drafts.map(\.text) == ["Legacy one draft", "Legacy extra draft", "Legacy third draft"])
}

func testSourceDraftCollectionCodableRoundTripPreservesSelection() throws {
    let first = SourceDraft(text: "First")
    let second = SourceDraft(text: "Second")
    let third = SourceDraft(text: "Third")
    let collection = SourceDraftCollection(selectedDraftID: second.id, drafts: [first, second, third])

    let data = try JSONEncoder().encode(collection)
    let decoded = try JSONDecoder().decode(SourceDraftCollection.self, from: data)

    precondition(decoded.selectedDraftID == second.id)
    precondition(decoded.selectedDraft?.text == "Second")
    precondition(decoded.drafts.count == SourceDraftCollection.maximumDraftCount)
}

testPromptBuilderProducesEnglishOnlyNaturalRewritePrompt()
testPromptBuilderPreservesUserCodeBlockInput()
testDefaultConfigurationUsesDeepSeekFlashWithFastRealtimeDelay()
try testConfigurationMigratesDeepSeekProAndLegacyDelayForSpeed()
try testConfigurationClampsSlowPersistedRealtimeDelay()
try testConfigurationDecodesLegacySettingsWithoutPanelPreferences()
try testConfigurationIgnoresLegacySourceEnglishLayoutPreference()
try testConfigurationDecodesPersistedToggleShortcut()
try testConfigurationDecodesLegacySettingsWithDefaultToggleShortcut()
testCommonPhraseCollectionNormalizesPhrases()
testCommonPhraseInsertionAppendsWithReadableSpacing()
try testConfigurationDecodesPersistedCommonPhrases()
try testConfigurationDecodesLegacySettingsWithDefaultCommonPhrases()
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
testSourceDraftCollectionStartsWithThreeEmptyDrafts()
testSourceDraftCollectionUpdatesSelectedDraftText()
testSourceDraftCollectionCreateDraftIsStrictlyLimitedToThree()
testSourceDraftCollectionNormalizesPersistedDraftsToExactlyThree()
testSourceDraftCollectionPadsPersistedDraftsToExactlyThree()
testSourceDraftCollectionKeepsThreeDraftsWhenDeleting()
testSourceDraftCollectionSelectsNeighborWhenDeletingSelectedDraft()
testSourceDraftCollectionLabelsStayNumbered()
try testSourceDraftCollectionDecodingNormalizesLegacyDraftCount()
try testSourceDraftCollectionCodableRoundTripPreservesSelection()

print("Little Swan smoke tests passed")
