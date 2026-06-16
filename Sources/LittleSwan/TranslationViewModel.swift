import AppKit
import Combine
import Foundation
import LittleSwanCore

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText = "" {
        didSet {
            sourceDraftStore?.updateSelectedDraftText(inputText)
            cancelInputPolishIfNeededForUserEdit()
            scheduleTranslation()
        }
    }

    @Published var outputText = ""
    @Published var selectedStyle: WritingStyle {
        didSet { scheduleTranslation() }
    }

    @Published var isLoading = false
    @Published var isPolishingInput = false
    @Published var errorMessage: String?
    @Published private(set) var polishAnimationFrame: PolishedInputAnimation.Frame?
    @Published private(set) var sourceDrafts: [SourceDraft]
    @Published private(set) var selectedSourceDraftID: UUID
    @Published private(set) var commonPhrases: [String]

    private let configStore: ConfigStore
    private let sourceDraftStore: SourceDraftStore?
    private let client: DeepSeekClient
    private var translationTask: Task<Void, Never>?
    private var inputPolishTask: Task<Void, Never>?
    private var inputPolishRequestID = UUID()
    private var isApplyingPolishedInput = false
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
        commonPhrases = configStore.configuration.commonPhrases.phrases
        inputText = initialDraftCollection.selectedDraft?.text ?? ""
        selectedStyle = configStore.configuration.defaultWritingStyle

        configStore.$configuration
            .map(\.defaultWritingStyle)
            .removeDuplicates()
            .sink { [weak self] style in
                self?.selectedStyle = style
            }
            .store(in: &cancellables)

        configStore.$configuration
            .map(\.commonPhrases.phrases)
            .removeDuplicates()
            .sink { [weak self] phrases in
                self?.commonPhrases = phrases
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
        cancelInputPolish()
        inputText = ""
    }

    func polishInput() {
        inputPolishTask?.cancel()
        translationTask?.cancel()
        isLoading = false

        let originalInput = inputText
        let trimmedInput = originalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        let requestID = UUID()
        inputPolishRequestID = requestID
        isPolishingInput = true
        errorMessage = nil

        inputPolishTask = Task { [weak self] in
            await self?.polishInput(originalInput, requestID: requestID)
        }
    }

    func insertCommonPhrase(_ phrase: String) {
        inputText = CommonPhraseInsertion.appending(phrase, to: inputText)
    }

    func selectSourceDraft(_ id: UUID) {
        guard selectedSourceDraftID != id else { return }
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
        cancelInputPolish()
        selectedSourceDraftID = draft.id
        outputText = ""
        errorMessage = nil
        isLoading = false
        inputText = draft.text
    }

    private func cancelInputPolishIfNeededForUserEdit() {
        guard !isApplyingPolishedInput else { return }
        guard isPolishingInput else { return }
        cancelInputPolish()
    }

    private func cancelInputPolish() {
        inputPolishTask?.cancel()
        inputPolishRequestID = UUID()
        isPolishingInput = false
        polishAnimationFrame = nil
    }

    func retryNow() {
        translateNow(input: inputText, style: selectedStyle)
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

        let debounce = TranslationTiming.clampedDebounceMilliseconds(
            configStore.configuration.debounceMilliseconds
        )
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

    private func polishInput(_ originalInput: String, requestID: UUID) async {
        guard configStore.isConfigured else {
            errorMessage = DeepSeekClientError.missingAPIKey.localizedDescription
            isPolishingInput = false
            return
        }

        isPolishingInput = true
        errorMessage = nil
        defer {
            if inputPolishRequestID == requestID {
                isPolishingInput = false
            }
        }

        do {
            let polishedInput = try await client.polishInput(
                input: originalInput,
                configuration: configStore.configuration.provider
            )

            guard !Task.isCancelled else { return }
            guard inputText == originalInput else { return }

            await animatePolishedInput(
                from: originalInput,
                to: polishedInput,
                requestID: requestID
            )
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            guard inputText == originalInput else { return }
            errorMessage = error.localizedDescription
        }

        isPolishingInput = false
    }

    private func animatePolishedInput(
        from originalInput: String,
        to polishedInput: String,
        requestID: UUID
    ) async {
        let frames = PolishedInputAnimation.highlightedFrames(original: originalInput, polished: polishedInput)
        guard !frames.isEmpty else { return }

        for frame in frames {
            guard !Task.isCancelled else { return }
            guard inputPolishRequestID == requestID else { return }

            polishAnimationFrame = frame

            do {
                try await Task.sleep(for: .milliseconds(45))
            } catch {
                return
            }
        }

        guard !Task.isCancelled else { return }
        guard inputPolishRequestID == requestID else { return }

        polishAnimationFrame = nil
        isApplyingPolishedInput = true
        defer { isApplyingPolishedInput = false }
        inputText = polishedInput
    }
}
