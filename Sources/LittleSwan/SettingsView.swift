import AppKit
import LittleSwanCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var draft: AppConfiguration
    @State private var didSave = false
    @State private var isAPIKeyVisible = false
    @State private var selectedTab: SettingsTab = .provider
    @State private var saveFeedbackTask: Task<Void, Never>?
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var connectionTestTask: Task<Void, Never>?
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var isRestoreConfirmationPresented = false
    @State private var isPhraseRestoreConfirmationPresented = false
    @State private var isCustomDelayVisible = false
    @State private var selectedCommonPhraseIndex = 0
    @FocusState private var isCommonPhraseEditorFocused: Bool
    @FocusState private var focusedSettingsTab: SettingsTab?

    init(configStore: ConfigStore) {
        self.configStore = configStore
        _draft = State(initialValue: configStore.configuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 0) {
                tabRail
                    .frame(width: 190)

                Divider()
                    .padding(.horizontal, 14)

                selectedTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(selectedTab)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.12), value: selectedTab)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            HStack {
                if let error = configStore.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if didSave {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Restore all defaults…") {
                    isRestoreConfirmationPresented = true
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 500)
        .onChange(of: draft) { _, _ in
            connectionTestTask?.cancel()
            connectionStatus = .idle
            scheduleAutoSave()
        }
        .onChange(of: selectedTab) { _, newTab in
            focusedSettingsTab = newTab
        }
        .onDisappear {
            saveFeedbackTask?.cancel()
            autoSaveTask?.cancel()
            connectionTestTask?.cancel()
        }
        .confirmationDialog(
            "Restore all settings to their defaults?",
            isPresented: $isRestoreConfirmationPresented
        ) {
            Button("Restore All Defaults", role: .destructive) {
                draft = defaultEditableConfiguration
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Provider settings, common phrases, translation preferences, and keyboard shortcuts will be reset.")
        }
        .confirmationDialog(
            "Restore the default common phrases?",
            isPresented: $isPhraseRestoreConfirmationPresented
        ) {
            Button("Restore Phrase Defaults", role: .destructive) {
                draft.commonPhrases = .default
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var tabRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                tabButton(tab)
            }

            Spacer()
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            focusedSettingsTab = tab
            selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .frame(width: 18)

                Text(tab.label)
                    .lineLimit(1)

                Spacer()
            }
            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .focused($focusedSettingsTab, equals: tab)
        .help(tab.label)
        .accessibilityLabel(tab.label)
        .accessibilityValue(selectedTab == tab ? "Selected" : "Not selected")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .provider:
            providerGroup
        case .translation:
            translationGroup
        case .commonPhrases:
            commonPhrasesGroup
        case .shortcuts:
            shortcutsGroup
        }
    }

    private var providerGroup: some View {
        GroupBox("Provider") {
            VStack(alignment: .leading, spacing: 12) {
                settingsRow("Provider") {
                    Picker("Provider", selection: selectedProviderBinding) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                settingsRow("Base URL") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Base URL", text: $draft.provider.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityHint("The OpenAI-compatible API endpoint for this provider")

                        if !draft.provider.baseURL.isEmpty, !isProviderBaseURLValid {
                            Label("Enter a valid HTTP or HTTPS URL.", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                settingsRow("API key") {
                    HStack(spacing: 8) {
                        apiKeyField

                        Button {
                            pasteAPIKey()
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .labelStyle(.iconOnly)
                        .help("Paste API key")

                        Button {
                            isAPIKeyVisible.toggle()
                        } label: {
                            Label(
                                isAPIKeyVisible ? "Hide" : "Show",
                                systemImage: isAPIKeyVisible ? "eye.slash" : "eye"
                            )
                        }
                        .labelStyle(.iconOnly)
                        .help(isAPIKeyVisible ? "Hide API key" : "Show API key")
                    }
                }

                settingsRow("Model") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            TextField("Model identifier", text: $draft.provider.model)
                                .textFieldStyle(.roundedBorder)

                            Menu {
                                ForEach(draft.provider.provider.suggestedModels, id: \.self) { model in
                                    Button(model) {
                                        draft.provider.model = model
                                    }
                                }
                            } label: {
                                Label("Suggested", systemImage: "chevron.down")
                            }
                            .help("Choose a suggested model")
                        }

                        if draft.provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label("Enter a model identifier.", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    Button {
                        testProviderConnection()
                    } label: {
                        if connectionStatus == .testing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Test connection", systemImage: "bolt.horizontal.circle")
                        }
                    }
                    .disabled(!canTestProviderConnection || connectionStatus == .testing)

                    connectionStatusView
                }

                Text(providerHelpText + " API keys are stored in Little Swan's local configuration file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    private var translationGroup: some View {
        GroupBox("Translation") {
            VStack(alignment: .leading, spacing: 12) {
                settingsRow("Realtime") {
                    Toggle("Translate automatically while typing", isOn: $draft.realtimeTranslationEnabled)
                        .toggleStyle(.switch)
                }

                settingsRow("Realtime delay") {
                    VStack(alignment: .leading, spacing: 7) {
                        Picker("Response speed", selection: realtimeDelayPresetBinding) {
                            ForEach(RealtimeDelayPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        if isCustomDelayVisible || RealtimeDelayPreset(milliseconds: draft.debounceMilliseconds) == .custom {
                            Stepper(
                                "Custom: \(draft.debounceMilliseconds) ms",
                                value: $draft.debounceMilliseconds,
                                in: TranslationTiming.minimumRealtimeDelayMilliseconds...TranslationTiming.maximumRealtimeDelayMilliseconds,
                                step: 50
                            )
                        }

                        Text(realtimeDelayHelpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .help("Translation starts after typing stays unchanged for this delay.")
                    .disabled(!draft.realtimeTranslationEnabled)
                }

                settingsRow("Manual generation") {
                    Toggle(
                        "Copy result to clipboard after generating",
                        isOn: $draft.copyGeneratedResultToClipboard
                    )
                    .toggleStyle(.switch)
                    .help("Copies the new English result after clicking Generate or pressing Command-Return.")
                }

                settingsRow("Default style") {
                    Picker("Default style", selection: $draft.defaultWritingStyle) {
                        ForEach(WritingStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var commonPhrasesGroup: some View {
        GroupBox("Common phrases") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text("Add one reusable phrase or text block per entry. These appear in the source header’s phrase menu and can be inserted into the current draft with one click.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Phrases")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                addCommonPhrase()
                            } label: {
                                Label("New", systemImage: "plus")
                            }
                            .controlSize(.small)
                            .disabled(draft.commonPhrases.phrases.count >= CommonPhraseCollection.maximumPhraseCount)
                            .help("Create a new common phrase")
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                if draft.commonPhrases.phrases.isEmpty {
                                    Text("No common phrases yet. Click New to add one.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 96)
                                } else {
                                    ForEach(draft.commonPhrases.phrases.indices, id: \.self) { index in
                                        commonPhraseRow(index)
                                    }
                                }
                            }
                            .padding(1)
                        }
                    }
                    .frame(width: 220)
                    .frame(minHeight: 270)

                    VStack(alignment: .leading, spacing: 6) {
                        if draft.commonPhrases.phrases.isEmpty {
                            Text("Select or add a phrase to edit it here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            HStack(spacing: 8) {
                                Text("Edit selected phrase")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button(role: .destructive) {
                                    removeSelectedCommonPhrase()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .controlSize(.small)
                                .disabled(selectedValidCommonPhraseIndex == nil)
                                .help("Delete the selected common phrase")
                            }

                            TextEditor(text: selectedCommonPhraseBinding)
                                .font(.system(size: 13))
                                .scrollContentBackground(.hidden)
                                .background(Color(nsColor: .textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(nsColor: .separatorColor))
                                )
                                .help("Paste or edit a large multi-line text block here.")
                                .focused($isCommonPhraseEditorFocused)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 270)
                }

                HStack {
                    Text(commonPhraseLimitText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Restore phrase defaults…") {
                        isPhraseRestoreConfirmationPresented = true
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func commonPhraseRow(_ index: Int) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                selectedCommonPhraseIndex = index
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if index == selectedValidCommonPhraseIndex {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }

                        Text(commonPhrasePreview(for: index))
                            .font(.system(size: 13))
                    }
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(commonPhraseDetailText(for: index))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(index == selectedValidCommonPhraseIndex ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(index == selectedValidCommonPhraseIndex ? Color.accentColor.opacity(0.35) : Color(nsColor: .separatorColor))
                )
            }
            .buttonStyle(.plain)
            .help("Select phrase \(index + 1) to edit")
            .accessibilityLabel("Phrase \(index + 1): \(commonPhrasePreview(for: index))")
            .accessibilityValue(index == selectedValidCommonPhraseIndex ? "Selected" : "Not selected")
            .accessibilityAddTraits(index == selectedValidCommonPhraseIndex ? .isSelected : [])

        }
    }

    private var shortcutsGroup: some View {
        GroupBox("Shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                settingsRow("Open / hide") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            KeyboardShortcutRecorder(shortcut: $draft.toggleShortcut)
                                .frame(width: 160, height: 28)

                            Button("Reset") {
                                draft.toggleShortcut = .defaultToggleShortcut
                            }
                        }

                        Text(toggleShortcutHelpText)
                            .font(.caption)
                            .foregroundStyle(toggleShortcutCanBeSaved ? Color.secondary : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsRow("Reset window") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            KeyboardShortcutRecorder(
                                shortcut: $draft.resetWindowShortcut,
                                accessibilityLabel: "Reset main window shortcut",
                                accessibilityHelp: "Click, then press a keyboard shortcut with at least one modifier key"
                            )
                                .frame(width: 160, height: 28)

                            Button("Reset") {
                                draft.resetWindowShortcut = .defaultResetWindowShortcut
                            }
                        }

                        Text(resetWindowShortcutHelpText)
                            .font(.caption)
                            .foregroundStyle(resetWindowShortcutCanBeSaved ? Color.secondary : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 132, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var apiKeyField: some View {
        if isAPIKeyVisible {
            TextField("API key", text: $draft.provider.apiKey)
                .textFieldStyle(.roundedBorder)
        } else {
            SecureField("API key", text: $draft.provider.apiKey)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var selectedProviderBinding: Binding<AIProvider> {
        Binding(
            get: { draft.provider.provider },
            set: { provider in
                guard provider != draft.provider.provider else { return }
                draft.updateSelectedProvider(draft.provider)
                draft.selectProvider(provider)
                isAPIKeyVisible = false
            }
        )
    }

    private var isProviderBaseURLValid: Bool {
        let value = draft.provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: value) else { return false }
        return ["http", "https"].contains(components.scheme?.lowercased() ?? "")
            && components.host != nil
    }

    private var canTestProviderConnection: Bool {
        isProviderBaseURLValid
            && !draft.provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .idle, .testing:
            EmptyView()
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private var providerHelpText: String {
        switch draft.provider.provider {
        case .deepSeek:
            "Uses DeepSeek's OpenAI-compatible API. You can enter another supported DeepSeek model identifier."
        case .openAI:
            "Uses OpenAI Chat Completions. Enter any text-capable model available to your API project."
        case .openRouter:
            "Uses OpenRouter's unified API. Model identifiers include the provider prefix, such as openai/gpt-5-mini."
        }
    }

    private var realtimeDelayPresetBinding: Binding<RealtimeDelayPreset> {
        Binding(
            get: { RealtimeDelayPreset(milliseconds: draft.debounceMilliseconds) },
            set: { preset in
                if let milliseconds = preset.milliseconds {
                    draft.debounceMilliseconds = milliseconds
                    isCustomDelayVisible = false
                } else {
                    isCustomDelayVisible = true
                }
            }
        )
    }

    private var realtimeDelayHelpText: String {
        switch RealtimeDelayPreset(milliseconds: draft.debounceMilliseconds) {
        case .fast:
            "Starts quickly after typing pauses. Best for short text, but may use more requests."
        case .balanced:
            "Balances responsiveness with fewer repeated requests."
        case .fewerRequests:
            "Waits longer after typing pauses to reduce repeated requests."
        case .custom:
            "Uses a custom delay after typing pauses."
        }
    }

    private var commonPhraseLimitText: String {
        let normalizedCount = draft.commonPhrases.normalized().phrases.count
        return "\(normalizedCount)/\(CommonPhraseCollection.maximumPhraseCount) phrases · up to \(CommonPhraseCollection.maximumPhraseLength.formatted()) characters each"
    }

    private var selectedValidCommonPhraseIndex: Int? {
        guard !draft.commonPhrases.phrases.isEmpty else { return nil }
        return min(max(selectedCommonPhraseIndex, 0), draft.commonPhrases.phrases.count - 1)
    }

    private var selectedCommonPhraseBinding: Binding<String> {
        Binding(
            get: {
                guard let index = selectedValidCommonPhraseIndex else { return "" }
                return draft.commonPhrases.phrases[index]
            },
            set: { newValue in
                guard let index = selectedValidCommonPhraseIndex else { return }
                draft.commonPhrases.phrases[index] = String(newValue.prefix(CommonPhraseCollection.maximumPhraseLength))
            }
        )
    }

    private func addCommonPhrase() {
        guard draft.commonPhrases.phrases.count < CommonPhraseCollection.maximumPhraseCount else { return }
        draft.commonPhrases.phrases.append("")
        selectedCommonPhraseIndex = draft.commonPhrases.phrases.count - 1
        DispatchQueue.main.async {
            isCommonPhraseEditorFocused = true
        }
    }

    private func removeCommonPhrase(at index: Int) {
        guard draft.commonPhrases.phrases.indices.contains(index) else { return }
        draft.commonPhrases.phrases.remove(at: index)
        selectedCommonPhraseIndex = min(selectedCommonPhraseIndex, max(draft.commonPhrases.phrases.count - 1, 0))
    }

    private func removeSelectedCommonPhrase() {
        guard let index = selectedValidCommonPhraseIndex else { return }
        removeCommonPhrase(at: index)
    }

    private func commonPhrasePreview(for index: Int) -> String {
        guard draft.commonPhrases.phrases.indices.contains(index) else { return "" }
        let phrase = draft.commonPhrases.phrases[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return "New phrase" }
        return phrase.replacingOccurrences(of: "\n", with: " ")
    }

    private func commonPhraseDetailText(for index: Int) -> String {
        guard draft.commonPhrases.phrases.indices.contains(index) else { return "" }
        let phrase = draft.commonPhrases.phrases[index]
        let lineCount = max(phrase.components(separatedBy: .newlines).count, 1)
        return "\(phrase.count.formatted()) chars · \(lineCount) line\(lineCount == 1 ? "" : "s")"
    }

    private var defaultEditableConfiguration: AppConfiguration {
        AppConfiguration(
            provider: .deepSeekDefault,
            debounceMilliseconds: TranslationTiming.defaultRealtimeDelayMilliseconds,
            realtimeTranslationEnabled: true,
            copyGeneratedResultToClipboard: true,
            defaultWritingStyle: .natural,
            panelContentSize: configStore.configuration.panelContentSize,
            toggleShortcut: .defaultToggleShortcut,
            resetWindowShortcut: .defaultResetWindowShortcut,
            commonPhrases: .default
        )
    }

    private var toggleShortcutHelpText: String {
        if shortcutsConflict {
            "Shortcut was not saved. Choose a different shortcut for each action."
        } else if draft.toggleShortcut.isValid {
            "Press this shortcut anywhere to open or hide Little Swan. Click the field, then press a new key combination."
        } else {
            "Shortcut was not saved. Include at least one modifier key."
        }
    }

    private var resetWindowShortcutHelpText: String {
        if shortcutsConflict {
            "Shortcut was not saved. Choose a different shortcut for each action."
        } else if draft.resetWindowShortcut.isValid {
            "Press this shortcut anywhere to reset the main window's position and size."
        } else {
            "Shortcut was not saved. Include at least one modifier key."
        }
    }

    private var shortcutsConflict: Bool {
        draft.toggleShortcut.conflicts(with: draft.resetWindowShortcut)
    }

    private var toggleShortcutCanBeSaved: Bool {
        draft.toggleShortcut.isValid && !shortcutsConflict
    }

    private var resetWindowShortcutCanBeSaved: Bool {
        draft.resetWindowShortcut.isValid && !shortcutsConflict
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        didSave = false
        autoSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            saveDraftImmediately()
        }
    }

    private func saveDraftImmediately() {
        var nextConfiguration = draft
        nextConfiguration.updateSelectedProvider(nextConfiguration.provider)
        nextConfiguration.panelContentSize = configStore.configuration.panelContentSize
        nextConfiguration.commonPhrases = nextConfiguration.commonPhrases.normalized()
        if !nextConfiguration.toggleShortcut.isValid {
            nextConfiguration.toggleShortcut = configStore.configuration.toggleShortcut
        }
        if !nextConfiguration.resetWindowShortcut.isValid {
            nextConfiguration.resetWindowShortcut = configStore.configuration.resetWindowShortcut
        }
        if nextConfiguration.toggleShortcut.conflicts(with: nextConfiguration.resetWindowShortcut) {
            nextConfiguration.toggleShortcut = configStore.configuration.toggleShortcut
            nextConfiguration.resetWindowShortcut = configStore.configuration.resetWindowShortcut
        }
        configStore.configuration = nextConfiguration
        configStore.save()
        didSave = configStore.lastError == nil

        saveFeedbackTask?.cancel()
        guard didSave else { return }

        saveFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(2))

            await MainActor.run {
                didSave = false
            }
        }
    }

    private func testProviderConnection() {
        guard canTestProviderConnection else { return }
        connectionTestTask?.cancel()
        connectionStatus = .testing
        let configuration = draft.provider

        connectionTestTask = Task {
            do {
                try await ChatCompletionsClient().testConnection(configuration: configuration)
                guard !Task.isCancelled else { return }
                connectionStatus = .connected
            } catch {
                guard !Task.isCancelled else { return }
                connectionStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func pasteAPIKey() {
        guard let pasted = NSPasteboard.general.string(forType: .string) else { return }
        draft.provider.apiKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum ConnectionStatus: Equatable {
    case idle
    case testing
    case connected
    case failed(String)
}

private enum RealtimeDelayPreset: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case fewerRequests
    case custom

    var id: String { rawValue }

    init(milliseconds: Int) {
        switch milliseconds {
        case 100: self = .fast
        case 200: self = .balanced
        case 600: self = .fewerRequests
        default: self = .custom
        }
    }

    var label: String {
        switch self {
        case .fast: "Fast"
        case .balanced: "Balanced"
        case .fewerRequests: "Fewer requests"
        case .custom: "Custom"
        }
    }

    var milliseconds: Int? {
        switch self {
        case .fast: 100
        case .balanced: 200
        case .fewerRequests: 600
        case .custom: nil
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case provider
    case translation
    case commonPhrases
    case shortcuts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .provider:
            "Provider"
        case .translation:
            "Translation"
        case .commonPhrases:
            "Common phrases"
        case .shortcuts:
            "Shortcuts"
        }
    }

    var systemImage: String {
        switch self {
        case .provider:
            "network"
        case .translation:
            "textformat"
        case .commonPhrases:
            "text.badge.plus"
        case .shortcuts:
            "keyboard"
        }
    }
}
