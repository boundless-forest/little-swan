import AppKit
import Combine
import Foundation
import LittleSwanCore

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText = "" {
        didSet {
            sourceDraftStore?.updateSelectedDraftText(inputText)
            scheduleTranslation()
        }
    }

    @Published var outputText = ""
    @Published var selectedStyle: WritingStyle {
        didSet { scheduleTranslation() }
    }
    @Published private(set) var sourceEnglishLayout: SourceEnglishLayout

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sourceSuggestion = ""
    @Published var isCompletingSource = false
    @Published private(set) var sourceDrafts: [SourceDraft]
    @Published private(set) var selectedSourceDraftID: UUID

    private let configStore: ConfigStore
    private let sourceDraftStore: SourceDraftStore?
    private let client: DeepSeekClient
    private var translationTask: Task<Void, Never>?
    private var sourceCompletionTask: Task<Void, Never>?
    private var sourceCompletionRequestID = UUID()
    private var sourceSelectionRange = NSRange(location: 0, length: 0)
    private var suppressNextSourceCompletion = false
    private var cancellables = Set<AnyCancellable>()

    init(
        configStore: ConfigStore,
        sourceDraftStore: SourceDraftStore? = nil,
        client: DeepSeekClient = DeepSeekClient()
    ) {
        self.configStore = configStore
        self.sourceDraftStore = sourceDraftStore
        self.client = client
        let initialDraftCollection = sourceDraftStore?.collection ?? .default
        sourceDrafts = initialDraftCollection.drafts
        selectedSourceDraftID = initialDraftCollection.selectedDraftID
        inputText = initialDraftCollection.selectedDraft?.text ?? ""
        selectedStyle = configStore.configuration.defaultWritingStyle
        sourceEnglishLayout = configStore.configuration.sourceEnglishLayout

        configStore.$configuration
            .map(\.defaultWritingStyle)
            .removeDuplicates()
            .sink { [weak self] style in
                self?.selectedStyle = style
            }
            .store(in: &cancellables)

        configStore.$configuration
            .map(\.sourceEnglishLayout)
            .removeDuplicates()
            .sink { [weak self] layout in
                self?.sourceEnglishLayout = layout
            }
            .store(in: &cancellables)

        sourceDraftStore?.$collection
            .sink { [weak self] collection in
                self?.sourceDrafts = collection.drafts
                self?.selectedSourceDraftID = collection.selectedDraftID
            }
            .store(in: &cancellables)
    }

    func copyOutput() {
        guard !outputText.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }

    func clearInput() {
        sourceCompletionTask?.cancel()
        sourceCompletionRequestID = UUID()
        sourceSuggestion = ""
        isCompletingSource = false
        inputText = ""
    }

    func selectSourceDraft(_ id: UUID) {
        guard selectedSourceDraftID != id else { return }
        dismissSourceCompletion()
        sourceDraftStore?.updateSelectedDraftText(inputText)
        sourceDraftStore?.selectDraft(id: id)

        guard let draft = sourceDraftStore?.selectedDraft ?? sourceDrafts.first(where: { $0.id == id }) else {
            return
        }

        applySelectedDraft(draft)
    }

    func sourceDraftLabel(for draft: SourceDraft, fallbackIndex: Int) -> String {
        draft.displayTitle(fallbackIndex: fallbackIndex)
    }

    private func applySelectedDraft(_ draft: SourceDraft) {
        selectedSourceDraftID = draft.id
        outputText = ""
        errorMessage = nil
        isLoading = false
        inputText = draft.text
    }

    func updateSourceEditorState(
        text: String,
        selectedRange: NSRange,
        hasMarkedText: Bool
    ) {
        sourceSelectionRange = selectedRange

        if inputText != text {
            inputText = text
        }

        scheduleSourceCompletion(
            selectedRange: selectedRange,
            hasMarkedText: hasMarkedText
        )
    }

    func acceptSourceCompletion() -> Int? {
        guard !sourceSuggestion.isEmpty else { return nil }

        let acceptedSuggestion = SourceCompletionAcceptance.acceptedPrefix(from: sourceSuggestion)
        guard !acceptedSuggestion.isEmpty else { return nil }

        let result = SourceCompletionInsertion.insert(
            suggestion: acceptedSuggestion,
            into: inputText,
            utf16Location: sourceSelectionRange.location
        )

        suppressNextSourceCompletion = true
        sourceCompletionTask?.cancel()
        sourceCompletionRequestID = UUID()
        sourceSuggestion = ""
        isCompletingSource = false
        inputText = result.text
        sourceSelectionRange = NSRange(location: result.newUTF16Location, length: 0)

        return result.newUTF16Location
    }

    func dismissSourceCompletion() {
        sourceCompletionTask?.cancel()
        sourceCompletionRequestID = UUID()
        sourceSuggestion = ""
        isCompletingSource = false
    }

    func retryNow() {
        translateNow(input: inputText, style: selectedStyle)
    }

    private func scheduleSourceCompletion(selectedRange: NSRange, hasMarkedText: Bool) {
        sourceCompletionTask?.cancel()
        sourceCompletionRequestID = UUID()
        sourceSuggestion = ""
        isCompletingSource = false

        guard !suppressNextSourceCompletion else {
            suppressNextSourceCompletion = false
            return
        }

        guard !hasMarkedText else { return }
        guard selectedRange.length == 0 else { return }
        guard !inputText.isEmpty else { return }
        guard configStore.isConfigured else { return }

        let snapshot = inputText
        let cursorLocation = selectedRange.location
        let parts = SourceCompletionInsertion.split(
            text: snapshot,
            utf16Location: cursorLocation
        )
        let configuration = configStore.configuration.provider
        guard SourceCompletionEligibility.shouldRequest(prefix: parts.prefix, suffix: parts.suffix) else { return }

        let requestID = sourceCompletionRequestID
        isCompletingSource = true
        sourceCompletionTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(SourceCompletionDefaults.debounceMilliseconds))
                let suggestion = try await self?.client.completeSourceInput(
                    prefix: parts.prefix,
                    suffix: parts.suffix,
                    configuration: configuration
                )

                await MainActor.run {
                    guard let self else { return }
                    guard !Task.isCancelled else { return }
                    guard self.sourceCompletionRequestID == requestID else { return }
                    guard self.inputText == snapshot else { return }
                    guard self.sourceSelectionRange.location == cursorLocation,
                          self.sourceSelectionRange.length == 0 else { return }

                    self.sourceSuggestion = suggestion ?? ""
                    self.isCompletingSource = false
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self, self.sourceCompletionRequestID == requestID else { return }
                    self.isCompletingSource = false
                }
            } catch let error as URLError where error.code == .cancelled {
                await MainActor.run { [weak self] in
                    guard let self, self.sourceCompletionRequestID == requestID else { return }
                    self.isCompletingSource = false
                }
            } catch DeepSeekClientError.missingAPIKey {
                await MainActor.run { [weak self] in
                    guard let self, self.sourceCompletionRequestID == requestID else { return }
                    self.isCompletingSource = false
                }
            } catch {
                LittleSwanLogger.sourceCompletion.error(
                    "Source completion failed: \(error.localizedDescription, privacy: .public); prefixUTF16=\((parts.prefix as NSString).length, privacy: .public); suffixUTF16=\((parts.suffix as NSString).length, privacy: .public)"
                )
                await MainActor.run { [weak self] in
                    guard let self, self.sourceCompletionRequestID == requestID else { return }
                    guard self.inputText == snapshot else { return }
                    guard self.sourceSelectionRange.location == cursorLocation,
                          self.sourceSelectionRange.length == 0 else { return }
                    self.isCompletingSource = false
                    self.sourceSuggestion = ""
                }
            }
        }
    }

    private func scheduleTranslation() {
        translationTask?.cancel()

        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            outputText = ""
            errorMessage = nil
            isLoading = false
            return
        }

        let debounce = max(configStore.configuration.debounceMilliseconds, 250)
        let style = selectedStyle

        translationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(debounce))
            } catch {
                return
            }

            await self?.translate(input: trimmedInput, style: style)
        }
    }

    private func translateNow(input: String, style: WritingStyle) {
        translationTask?.cancel()

        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        translationTask = Task { [weak self] in
            await self?.translate(input: trimmedInput, style: style)
        }
    }

    private func translate(input: String, style: WritingStyle) async {
        guard configStore.isConfigured else {
            outputText = ""
            errorMessage = DeepSeekClientError.missingAPIKey.localizedDescription
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await client.rewriteEnglish(
                input: input,
                style: style,
                configuration: configStore.configuration.provider
            )

            guard !Task.isCancelled else { return }

            outputText = result
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
