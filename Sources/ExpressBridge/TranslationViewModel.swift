import AppKit
import Combine
import Foundation
import ExpressBridgeCore

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText = "" {
        didSet { scheduleTranslation() }
    }

    @Published var outputText = ""
    @Published var selectedStyle: WritingStyle {
        didSet { scheduleTranslation() }
    }

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let configStore: ConfigStore
    private let client: DeepSeekClient
    private var translationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        configStore: ConfigStore,
        client: DeepSeekClient = DeepSeekClient()
    ) {
        self.configStore = configStore
        self.client = client
        selectedStyle = configStore.configuration.defaultWritingStyle

        configStore.$configuration
            .map(\.defaultWritingStyle)
            .removeDuplicates()
            .sink { [weak self] style in
                self?.selectedStyle = style
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
