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

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var sourceDrafts: [SourceDraft]
    @Published private(set) var selectedSourceDraftID: UUID

    private let configStore: ConfigStore
    private let sourceDraftStore: SourceDraftStore?
    private let client: DeepSeekClient
    private var translationTask: Task<Void, Never>?
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

        configStore.$configuration
            .map(\.defaultWritingStyle)
            .removeDuplicates()
            .sink { [weak self] style in
                self?.selectedStyle = style
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
        inputText = ""
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
        selectedSourceDraftID = draft.id
        outputText = ""
        errorMessage = nil
        isLoading = false
        inputText = draft.text
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
