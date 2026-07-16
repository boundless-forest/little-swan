import AppKit
import LittleSwanCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.openURL) private var openURL

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
    @State private var hoveredSettingsTab: SettingsTab?
    @FocusState private var isCommonPhraseEditorFocused: Bool

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
                    .overlay(LittleSwanTheme.Palette.divider)
                    .padding(.horizontal, 14)

                selectedTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(selectedTab)
                    .transition(selectedTabTransition)
                    .animation(selectedTabAnimation, value: selectedTab)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            if selectedTab != .about {
                HStack {
                    if let error = configStore.lastError {
                        Text(error)
                            .font(LittleSwanTheme.Typography.status)
                            .foregroundStyle(LittleSwanTheme.Palette.danger)
                            .lineLimit(1)
                    } else if didSave {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(LittleSwanTheme.Typography.status)
                            .foregroundStyle(LittleSwanTheme.Palette.success)
                    }

                    Spacer()

                    Button("Restore all defaults…") {
                        isRestoreConfirmationPresented = true
                    }
                    .buttonStyle(.borderless)
                    .font(LittleSwanTheme.Typography.buttonLabel)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 500)
        .background(LittleSwanTheme.Palette.windowCanvas)
        .font(LittleSwanTheme.Typography.control)
        .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
        .symbolRenderingMode(.hierarchical)
        .tint(LittleSwanTheme.Palette.accent)
        .groupBoxStyle(LittleSwanGroupBoxStyle())
        .onChange(of: draft) { _, _ in
            connectionTestTask?.cancel()
            connectionStatus = .idle
            scheduleAutoSave()
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
            ForEach(SettingsTab.configurationTabs) { tab in
                tabButton(tab)
            }

            Spacer()

            Divider()
                .overlay(LittleSwanTheme.Palette.divider)
                .padding(.vertical, 4)

            tabButton(.about)
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredSettingsTab == tab

        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)

                Text(tab.label)
                    .font(
                        isSelected
                            ? LittleSwanTheme.Typography.controlStrong
                            : LittleSwanTheme.Typography.control
                    )
                    .lineLimit(1)

                Spacer()
            }
            .foregroundStyle(isSelected ? LittleSwanTheme.Palette.accent : LittleSwanTheme.Palette.textPrimary)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
                    .fill(
                        isSelected
                            ? LittleSwanTheme.Palette.accentSoft
                            : (isHovered ? LittleSwanTheme.Palette.surfaceSubtle : Color.clear)
                    )
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovering in
            if isHovering {
                hoveredSettingsTab = tab
            } else if hoveredSettingsTab == tab {
                hoveredSettingsTab = nil
            }
        }
        .help(tab.label)
        .accessibilityLabel(tab.label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedTabTransition: AnyTransition {
        accessibilityReduceMotion ? .identity : .opacity
    }

    private var selectedTabAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeOut(duration: 0.12)
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
        case .about:
            aboutGroup
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
                                .font(LittleSwanTheme.Typography.status)
                                .foregroundStyle(LittleSwanTheme.Palette.danger)
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
                        .buttonStyle(LittleSwanIconButtonStyle())
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
                        .buttonStyle(LittleSwanIconButtonStyle())
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
                            .font(LittleSwanTheme.Typography.buttonLabel)
                            .help("Choose a suggested model")
                        }

                        if draft.provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label("Enter a model identifier.", systemImage: "exclamationmark.circle")
                                .font(LittleSwanTheme.Typography.status)
                                .foregroundStyle(LittleSwanTheme.Palette.danger)
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
                    .font(LittleSwanTheme.Typography.buttonLabel)
                    .disabled(!canTestProviderConnection || connectionStatus == .testing)

                    connectionStatusView
                }

                Text(providerHelpText + " API keys are stored in Little Swan's local configuration file.")
                    .font(LittleSwanTheme.Typography.helper)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
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
                        .accessibilityLabel("Translate automatically while typing")
                        .accessibilityHint("Automatically starts translation after typing pauses")
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
                            .font(LittleSwanTheme.Typography.helper)
                            .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
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
                    .accessibilityLabel("Copy result to clipboard after generating")
                    .accessibilityHint("Copies the new English result after manual generation")
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
                        .font(LittleSwanTheme.Typography.helper)
                        .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Phrases")
                                .font(LittleSwanTheme.Typography.buttonLabel)
                                .foregroundStyle(LittleSwanTheme.Palette.textSecondary)

                            Spacer()

                            Button {
                                addCommonPhrase()
                            } label: {
                                Label("New", systemImage: "plus")
                            }
                            .font(LittleSwanTheme.Typography.buttonLabel)
                            .controlSize(.small)
                            .disabled(draft.commonPhrases.phrases.count >= CommonPhraseCollection.maximumPhraseCount)
                            .help("Create a new common phrase")
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                if draft.commonPhrases.phrases.isEmpty {
                                    Text("No common phrases yet. Click New to add one.")
                                        .font(LittleSwanTheme.Typography.helper)
                                        .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                                        .frame(maxWidth: .infinity, minHeight: 96)
                                } else {
                                    ForEach(draft.commonPhrases.phrases.indices, id: \.self) { index in
                                        commonPhraseRow(index)
                                    }
                                }
                            }
                            .padding(1)
                        }
                        .background(LittleSwanTheme.Palette.surfaceSubtle)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: LittleSwanTheme.Radius.compact,
                                style: .continuous
                            )
                        )
                    }
                    .frame(width: 220)
                    .frame(minHeight: 270)

                    VStack(alignment: .leading, spacing: 6) {
                        if draft.commonPhrases.phrases.isEmpty {
                            Text("Select or add a phrase to edit it here.")
                                .font(LittleSwanTheme.Typography.helper)
                                .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .background(LittleSwanTheme.Palette.surfaceSubtle)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: LittleSwanTheme.Radius.compact,
                                        style: .continuous
                                    )
                                )
                        } else {
                            HStack(spacing: 8) {
                                Text("Edit selected phrase")
                                    .font(LittleSwanTheme.Typography.buttonLabel)
                                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)

                                Spacer()

                                Button(role: .destructive) {
                                    removeSelectedCommonPhrase()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .font(LittleSwanTheme.Typography.buttonLabel)
                                .controlSize(.small)
                                .disabled(selectedValidCommonPhraseIndex == nil)
                                .help("Delete the selected common phrase")
                            }

                            TextEditor(text: selectedCommonPhraseBinding)
                                .font(LittleSwanTheme.Typography.control)
                                .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                                .scrollContentBackground(.hidden)
                                .background(LittleSwanTheme.Palette.surfaceRaised)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: LittleSwanTheme.Radius.compact,
                                        style: .continuous
                                    )
                                )
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: LittleSwanTheme.Radius.compact,
                                        style: .continuous
                                    )
                                    .stroke(
                                        isCommonPhraseEditorFocused
                                            ? LittleSwanTheme.Palette.accent
                                            : LittleSwanTheme.Palette.border,
                                        lineWidth: isCommonPhraseEditorFocused
                                            ? LittleSwanTheme.Stroke.focus
                                            : LittleSwanTheme.Stroke.regular
                                    )
                                }
                                .help("Paste or edit a large multi-line text block here.")
                                .accessibilityLabel("Selected common phrase")
                                .accessibilityHint("Paste or edit a large multi-line text block")
                                .focused($isCommonPhraseEditorFocused)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 270)
                }

                HStack {
                    Text(commonPhraseLimitText)
                        .font(LittleSwanTheme.Typography.helper)
                        .foregroundStyle(LittleSwanTheme.Palette.textSecondary)

                    Spacer()

                    Button("Restore phrase defaults…") {
                        isPhraseRestoreConfirmationPresented = true
                    }
                    .buttonStyle(.borderless)
                    .font(LittleSwanTheme.Typography.buttonLabel)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func commonPhraseRow(_ index: Int) -> some View {
        let isSelected = index == selectedValidCommonPhraseIndex

        return HStack(alignment: .center, spacing: 6) {
            Button {
                selectedCommonPhraseIndex = index
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(LittleSwanTheme.Palette.accent)
                            .frame(width: 12)
                            .opacity(isSelected ? 1 : 0)
                            .accessibilityHidden(true)

                        Text(commonPhrasePreview(for: index))
                            .font(LittleSwanTheme.Typography.control)
                    }
                    .lineLimit(2)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(commonPhraseDetailText(for: index))
                        .font(LittleSwanTheme.Typography.helper)
                        .foregroundStyle(LittleSwanTheme.Palette.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
                        .fill(isSelected ? LittleSwanTheme.Palette.accentSoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
                        .stroke(
                            isSelected ? LittleSwanTheme.Palette.accentBorder : Color.clear,
                            lineWidth: LittleSwanTheme.Stroke.regular
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Select phrase \(index + 1) to edit")
            .accessibilityLabel("Phrase \(index + 1): \(commonPhrasePreview(for: index))")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

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
                            .font(LittleSwanTheme.Typography.buttonLabel)
                        }

                        Text(toggleShortcutHelpText)
                            .font(LittleSwanTheme.Typography.helper)
                            .foregroundStyle(
                                toggleShortcutCanBeSaved
                                    ? LittleSwanTheme.Palette.textSecondary
                                    : LittleSwanTheme.Palette.danger
                            )
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
                            .font(LittleSwanTheme.Typography.buttonLabel)
                        }

                        Text(resetWindowShortcutHelpText)
                            .font(LittleSwanTheme.Typography.helper)
                            .foregroundStyle(
                                resetWindowShortcutCanBeSaved
                                    ? LittleSwanTheme.Palette.textSecondary
                                    : LittleSwanTheme.Palette.danger
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsRow("Generate translation") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            KeyboardShortcutRecorder(
                                shortcut: $draft.generateTranslationShortcut,
                                accessibilityLabel: "Generate translation shortcut",
                                accessibilityHelp: "Click, then press a keyboard shortcut with at least one modifier key"
                            )
                                .frame(width: 160, height: 28)

                            Button("Reset") {
                                draft.generateTranslationShortcut = .defaultGenerateTranslationShortcut
                            }
                            .font(LittleSwanTheme.Typography.buttonLabel)
                        }

                        Text(generateTranslationShortcutHelpText)
                            .font(LittleSwanTheme.Typography.helper)
                            .foregroundStyle(
                                generateTranslationShortcutCanBeSaved
                                    ? LittleSwanTheme.Palette.textSecondary
                                    : LittleSwanTheme.Palette.danger
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsRow("Polish with context") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            KeyboardShortcutRecorder(
                                shortcut: $draft.polishInputShortcut,
                                accessibilityLabel: "Polish with context shortcut",
                                accessibilityHelp: "Click, then press a keyboard shortcut with at least one modifier key"
                            )
                                .frame(width: 160, height: 28)

                            Button("Reset") {
                                draft.polishInputShortcut = .defaultPolishInputShortcut
                            }
                            .font(LittleSwanTheme.Typography.buttonLabel)
                        }

                        Text(polishInputShortcutHelpText)
                            .font(LittleSwanTheme.Typography.helper)
                            .foregroundStyle(
                                polishInputShortcutCanBeSaved
                                    ? LittleSwanTheme.Palette.textSecondary
                                    : LittleSwanTheme.Palette.danger
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var aboutGroup: some View {
        let buildInformation = BuildInformation()

        return VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                Text("Little Swan")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                Text("Turn any language into natural English")
                    .font(LittleSwanTheme.Typography.control)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)

            GroupBox("Build information") {
                VStack(alignment: .leading, spacing: 12) {
                    aboutInformationRow("Version", value: buildInformation.version)
                    aboutInformationRow("Build", value: buildInformation.buildNumber)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("Git commit")
                            .font(LittleSwanTheme.Typography.buttonLabel)
                            .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                            .frame(width: 132, alignment: .leading)

                        if let commitURL = buildInformation.commitURL {
                            Button(buildInformation.displayedGitCommit) {
                                openURL(commitURL)
                            }
                            .buttonStyle(.link)
                            .help("View this commit on GitHub")
                        } else {
                            Text(buildInformation.displayedGitCommit)
                        }

                        if let gitCommit = buildInformation.gitCommit {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(gitCommit, forType: .string)
                            } label: {
                                Label("Copy full commit", systemImage: "doc.on.doc")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(LittleSwanIconButtonStyle())
                            .help("Copy full commit SHA")
                        }

                        Spacer()
                    }

                    if let gitCommitDate = buildInformation.gitCommitDate {
                        aboutInformationRow(
                            "Commit date",
                            value: gitCommitDate.formatted(
                                .dateTime.year().month(.wide).day().locale(Locale(identifier: "en_US"))
                            )
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                if let releaseNotesURL = buildInformation.releaseNotesURL {
                    Button("View release notes") {
                        openURL(releaseNotesURL)
                    }
                }

                Button("View source code") {
                    openURL(BuildInformation.repositoryURL)
                }

                Spacer()
            }
            .font(LittleSwanTheme.Typography.buttonLabel)

            Spacer()

            Text("Copyright © 2026 Bear Wang")
                .font(LittleSwanTheme.Typography.helper)
                .foregroundStyle(LittleSwanTheme.Palette.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func aboutInformationRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(LittleSwanTheme.Typography.buttonLabel)
                .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                .frame(width: 132, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(LittleSwanTheme.Typography.buttonLabel)
                .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
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
        ProviderEndpoint.baseURL(from: draft.provider.baseURL) != nil
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
                .font(LittleSwanTheme.Typography.status)
                .foregroundStyle(LittleSwanTheme.Palette.success)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(LittleSwanTheme.Typography.status)
                .foregroundStyle(LittleSwanTheme.Palette.danger)
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
            defaultWritingStyle: .spoken,
            panelContentSize: configStore.configuration.panelContentSize,
            toggleShortcut: .defaultToggleShortcut,
            resetWindowShortcut: .defaultResetWindowShortcut,
            generateTranslationShortcut: .defaultGenerateTranslationShortcut,
            polishInputShortcut: .defaultPolishInputShortcut,
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

    private var generateTranslationShortcutHelpText: String {
        if shortcutsConflict {
            "Shortcut was not saved. Choose a different shortcut for each action."
        } else if draft.generateTranslationShortcut.isValid {
            "Press this shortcut in the main window to generate or update the translation."
        } else {
            "Shortcut was not saved. Include at least one modifier key."
        }
    }

    private var polishInputShortcutHelpText: String {
        if shortcutsConflict {
            "Shortcut was not saved. Choose a different shortcut for each action."
        } else if draft.polishInputShortcut.isValid {
            "Captures the previously active window once and uses its visible text to Polish the current Source."
        } else {
            "Shortcut was not saved. Include at least one modifier key."
        }
    }

    private var shortcutsConflict: Bool {
        draft.toggleShortcut.conflicts(with: draft.resetWindowShortcut)
            || draft.toggleShortcut.conflicts(with: draft.generateTranslationShortcut)
            || draft.toggleShortcut.conflicts(with: draft.polishInputShortcut)
            || draft.resetWindowShortcut.conflicts(with: draft.generateTranslationShortcut)
            || draft.resetWindowShortcut.conflicts(with: draft.polishInputShortcut)
            || draft.generateTranslationShortcut.conflicts(with: draft.polishInputShortcut)
    }

    private var toggleShortcutCanBeSaved: Bool {
        draft.toggleShortcut.isValid && !shortcutsConflict
    }

    private var resetWindowShortcutCanBeSaved: Bool {
        draft.resetWindowShortcut.isValid && !shortcutsConflict
    }

    private var generateTranslationShortcutCanBeSaved: Bool {
        draft.generateTranslationShortcut.isValid && !shortcutsConflict
    }

    private var polishInputShortcutCanBeSaved: Bool {
        draft.polishInputShortcut.isValid && !shortcutsConflict
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
        if !nextConfiguration.generateTranslationShortcut.isValid {
            nextConfiguration.generateTranslationShortcut = configStore.configuration.generateTranslationShortcut
        }
        if !nextConfiguration.polishInputShortcut.isValid {
            nextConfiguration.polishInputShortcut = configStore.configuration.polishInputShortcut
        }
        let hasShortcutConflict = nextConfiguration.toggleShortcut.conflicts(with: nextConfiguration.resetWindowShortcut)
            || nextConfiguration.toggleShortcut.conflicts(with: nextConfiguration.generateTranslationShortcut)
            || nextConfiguration.toggleShortcut.conflicts(with: nextConfiguration.polishInputShortcut)
            || nextConfiguration.resetWindowShortcut.conflicts(with: nextConfiguration.generateTranslationShortcut)
            || nextConfiguration.resetWindowShortcut.conflicts(with: nextConfiguration.polishInputShortcut)
            || nextConfiguration.generateTranslationShortcut.conflicts(with: nextConfiguration.polishInputShortcut)
        if hasShortcutConflict {
            nextConfiguration.toggleShortcut = configStore.configuration.toggleShortcut
            nextConfiguration.resetWindowShortcut = configStore.configuration.resetWindowShortcut
            nextConfiguration.generateTranslationShortcut = configStore.configuration.generateTranslationShortcut
            nextConfiguration.polishInputShortcut = configStore.configuration.polishInputShortcut
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
    case about

    static let configurationTabs: [SettingsTab] = [
        .provider,
        .translation,
        .commonPhrases,
        .shortcuts
    ]

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
        case .about:
            "About"
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
        case .about:
            "info.circle"
        }
    }
}
