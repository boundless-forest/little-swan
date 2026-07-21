import AppKit
import LittleSwanCore
import SwiftUI

struct MainPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TranslationViewModel
    let openSettings: () -> Void

    @FocusState private var isInputFocused: Bool
    @State private var isCopyFeedbackVisible = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var isCommonPhrasePickerPresented = false
    @State private var isPolishContextPresented = false
    @State private var inputGuidanceMessage: String?
    @State private var outputGuidanceMessage: String?
    @State private var inputGuidanceTask: Task<Void, Never>?
    @State private var outputGuidanceTask: Task<Void, Never>?

    private let placeholderTopPadding: CGFloat = 2
    private let placeholderLeadingPadding: CGFloat = 8
    private let toolbarItemSpacing: CGFloat = 7
    // TextEditor is backed by NSTextView, whose text container adds this default horizontal inset.
    private let textEditorLineFragmentPadding: CGFloat = 5

    var body: some View {
        contentColumns
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LittleSwanTheme.Palette.windowCanvas)
            .tint(LittleSwanTheme.Palette.accent)
            .onAppear {
                isInputFocused = true
            }
            .onDisappear {
                copyFeedbackTask?.cancel()
                inputGuidanceTask?.cancel()
                outputGuidanceTask?.cancel()
            }
            .onChange(of: viewModel.copyFeedbackTrigger) { _, _ in
                showCopyFeedback()
            }
            .onChange(of: viewModel.inputText) { _, newValue in
                if !newValue.isEmpty {
                    inputGuidanceMessage = nil
                }
            }
            .onChange(of: viewModel.outputText) { _, newValue in
                if !newValue.isEmpty {
                    outputGuidanceMessage = nil
                }
            }
            .onChange(of: viewModel.selectedSourceDraftID) { _, _ in
                inputGuidanceMessage = nil
                isInputFocused = true
            }
    }

    private var contentColumns: some View {
        HStack(spacing: 10) {
            inputEditor
                .frame(minWidth: 0, maxWidth: .infinity)
            outputView
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputEditor: some View {
        VStack(spacing: 0) {
            HStack(spacing: toolbarItemSpacing) {
                Text("Source")
                    .font(LittleSwanTheme.Typography.sectionLabel)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                    .fixedSize()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(Array(viewModel.sourceDrafts.enumerated()), id: \.element.id) { index, draft in
                            let title = viewModel.sourceDraftLabel(for: draft, fallbackIndex: index)
                            SourceDraftChip(
                                title: title,
                                hasContent: draft.hasContent,
                                isSelected: draft.id == viewModel.selectedSourceDraftID
                            ) {
                                viewModel.selectSourceDraft(draft.id)
                                isInputFocused = true
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(minWidth: 60, maxHeight: 28)
                .layoutPriority(1)

                commonPhrasesMenu

                Button {
                    isInputFocused = true
                    guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        showInputGuidance("Type something before polishing.")
                        return
                    }

                    viewModel.polishInput()
                } label: {
                    if viewModel.isPolishingInput {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Polish", systemImage: "wand.and.stars")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(LittleSwanIconButtonStyle())
                .controlSize(.small)
                .disabled(viewModel.isPolishingInput || viewModel.pendingPolishedInput != nil)
                .configuredKeyboardShortcut(viewModel.polishInputShortcut)
                .help(polishButtonHelpText)
                .accessibilityHint(
                    viewModel.useScreenContextForPolish
                        ? "Organizes the Source and uses the locked previous window as optional writing context"
                        : "Organizes and corrects the current Source without screen context"
                )

                Button {
                    isInputFocused = true
                    guard !viewModel.inputText.isEmpty else {
                        showInputGuidance("Source is already empty.")
                        return
                    }

                    viewModel.clearInput()
                } label: {
                    Label("Clear source", systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(LittleSwanIconButtonStyle())
                .help("Clear current draft")

                Toggle(
                    "Real-time",
                    isOn: Binding(
                        get: { viewModel.isRealtimeTranslationEnabled },
                        set: { viewModel.setRealtimeTranslationEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .help("Translate automatically while typing")
                .accessibilityLabel("Real-time translation")
                .accessibilityHint("Automatically refreshes the English result after you stop typing")
            }
            .font(LittleSwanTheme.Typography.buttonLabel)
            .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(LittleSwanTheme.Palette.surfaceSubtle)

            Divider()
                .overlay(LittleSwanTheme.Palette.divider)

            if let context = viewModel.polishContext {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.and.text.magnifyingglass")
                        .foregroundStyle(LittleSwanTheme.Palette.accent)

                    Button {
                        isPolishContextPresented = true
                    } label: {
                        Text("Using \(context.displayTitle)")
                            .font(LittleSwanTheme.Typography.status)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help("Review the recognized screen context")
                    .popover(isPresented: $isPolishContextPresented, arrowEdge: .top) {
                        polishContextPreview(context)
                    }

                    Spacer(minLength: 4)

                    Text("Captured once · not saved")
                        .font(LittleSwanTheme.Typography.helper)
                        .foregroundStyle(LittleSwanTheme.Palette.textTertiary)
                        .fixedSize()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                Divider()
                    .overlay(LittleSwanTheme.Palette.divider)
            } else if let statusMessage = viewModel.polishStatusMessage {
                HStack(spacing: 7) {
                    Image(systemName: polishStatusSymbol)
                        .foregroundStyle(polishStatusColor)

                    Text(statusMessage)
                        .font(LittleSwanTheme.Typography.status)
                        .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 4)

                    if viewModel.polishNeedsScreenRecordingPermission {
                        Button("Open Settings") {
                            openScreenRecordingSettings()
                        }
                        .controlSize(.small)
                    }

                    Button {
                        viewModel.dismissPolishStatus()
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                Divider()
                    .overlay(LittleSwanTheme.Palette.divider)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputText)
                    .font(LittleSwanTheme.Typography.editorBody)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isInputFocused)
                    .padding(2)
                    .opacity(viewModel.polishAnimationFrame == nil ? 1 : 0)

                if let polishAnimationFrame = viewModel.polishAnimationFrame {
                    polishReviewOverlay(polishAnimationFrame)
                } else if viewModel.inputText.isEmpty {
                    HStack(spacing: 5) {
                        if inputGuidanceMessage != nil {
                            Image(systemName: "info.circle.fill")
                        }

                        Text(inputGuidanceMessage ?? "Type in any language")
                    }
                        .font(LittleSwanTheme.Typography.editorBody)
                        .foregroundStyle(
                            inputGuidanceMessage == nil
                                ? LittleSwanTheme.Palette.textTertiary
                                : LittleSwanTheme.Palette.accent
                        )
                        .padding(.top, placeholderTopPadding)
                        .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .littleSwanSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func polishReviewOverlay(_ frame: PolishedInputAnimation.Frame) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                highlightedPolishText(for: frame)
                    .font(LittleSwanTheme.Typography.editorBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, placeholderTopPadding + 2)
                    .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
            }

            if viewModel.pendingPolishedInput != nil {
                Divider()
                    .overlay(LittleSwanTheme.Palette.divider)

                HStack(spacing: 8) {
                    Text(
                        viewModel.polishContext.map { "Review changes using context from \($0.sourceApp)" }
                            ?? "Review polished changes"
                    )
                        .font(LittleSwanTheme.Typography.helper)
                        .foregroundStyle(LittleSwanTheme.Palette.textSecondary)

                    Spacer()

                    Button("Reject") {
                        viewModel.rejectPolishedInput()
                        isInputFocused = true
                    }

                    Button("Accept") {
                        viewModel.acceptPolishedInput()
                        isInputFocused = true
                    }
                    .buttonStyle(.bordered)
                    .tint(LittleSwanTheme.Palette.accent)
                }
                .controlSize(.small)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        }
    }

    private func highlightedPolishText(for frame: PolishedInputAnimation.Frame) -> Text {
        frame.segments.reduce(Text("")) { partialText, segment in
            partialText + highlightedPolishSegment(segment)
        }
    }

    private func polishContextPreview(_ context: ScreenContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(context.displayTitle, systemImage: "macwindow")
                .font(LittleSwanTheme.Typography.controlStrong)

            Text("Little Swan captured this window once and recognized the following text locally. The screenshot and recognized text are not stored.")
                .font(LittleSwanTheme.Typography.helper)
                .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(context.recognizedText)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(LittleSwanTheme.Palette.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact))
        }
        .padding(14)
        .frame(width: 480, height: 340)
    }

    private var polishButtonHelpText: String {
        let shortcut = viewModel.polishInputShortcut.displayString
        if viewModel.useScreenContextForPolish {
            return "Polish Source and use the locked previous window when available (\(shortcut))"
        }
        return "Polish Source without screen context (\(shortcut))"
    }

    private var polishStatusSymbol: String {
        switch viewModel.polishStatusTone {
        case .information:
            "info.circle.fill"
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        }
    }

    private var polishStatusColor: Color {
        switch viewModel.polishStatusTone {
        case .information:
            LittleSwanTheme.Palette.accent
        case .success:
            LittleSwanTheme.Palette.success
        case .warning:
            LittleSwanTheme.Palette.warning
        }
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func highlightedPolishSegment(_ segment: PolishedInputAnimation.Segment) -> Text {
        switch segment.kind {
        case .unchanged:
            return Text(segment.text)
                .foregroundColor(LittleSwanTheme.Palette.textPrimary)
        case .removed:
            return Text(segment.text)
                .foregroundColor(LittleSwanTheme.Palette.danger)
                .strikethrough(true, color: LittleSwanTheme.Palette.danger)
        case .added:
            return Text(segment.text)
                .foregroundColor(LittleSwanTheme.Palette.success)
                .underline(true, color: LittleSwanTheme.Palette.success)
        }
    }

    private var commonPhrasesMenu: some View {
        Button {
            isCommonPhrasePickerPresented.toggle()
        } label: {
            Label("Phrases", systemImage: "text.badge.plus")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(LittleSwanIconButtonStyle())
        .controlSize(.small)
        .help(
            viewModel.commonPhrases.isEmpty ? "No common phrases configured" : "Insert common phrase"
        )
        .popover(isPresented: $isCommonPhrasePickerPresented, arrowEdge: .top) {
            CommonPhrasePicker(
                phrases: viewModel.commonPhrases,
                onSelect: { phrase in
                    viewModel.insertCommonPhrase(phrase)
                    isCommonPhrasePickerPresented = false
                    isInputFocused = true
                },
                openSettings: {
                    isCommonPhrasePickerPresented = false
                    openSettings()
                }
            )
        }
    }

    private var outputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: toolbarItemSpacing) {
                Text("English result")
                    .font(LittleSwanTheme.Typography.sectionLabel)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                    .fixedSize()

                Picker("Writing style", selection: $viewModel.selectedStyle) {
                    ForEach(WritingStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .frame(width: 112)
                .accessibilityLabel("Writing style")
                .accessibilityValue(viewModel.selectedStyle.label)

                Spacer(minLength: 0)

                HStack(spacing: toolbarItemSpacing) {
                    Button {
                        guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            isInputFocused = true
                            showInputGuidance("Type something to generate an English result.")
                            return
                        }

                        viewModel.generateNow()
                    } label: {
                        GenerateActionLabel(
                            isLoading: viewModel.isLoading,
                            isUpdating: !viewModel.outputText.isEmpty,
                            shortcut: viewModel.generateTranslationShortcut.displayString,
                            contrastingColorScheme: contrastingColorScheme
                        )
                    }
                    .buttonStyle(GenerateActionButtonStyle())
                    .disabled(viewModel.isLoading)
                    .configuredKeyboardShortcut(viewModel.generateTranslationShortcut)
                    .help("Generate English result (\(viewModel.generateTranslationShortcut.displayString))")
                    .accessibilityLabel(viewModel.isOutputStale ? "Update" : "Generate")
                    .accessibilityHint(
                        "Generate English result. Shortcut: \(viewModel.generateTranslationShortcut.displayString)"
                    )
                    .fixedSize()

                    Button {
                        guard !viewModel.outputText.isEmpty else {
                            showOutputGuidance("Generate a result before copying.")
                            return
                        }

                        viewModel.copyOutput()
                    } label: {
                        Label(
                            isCopyFeedbackVisible ? "Copied" : "Copy",
                            systemImage: isCopyFeedbackVisible ? "checkmark" : "doc.on.doc"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(
                        LittleSwanIconButtonStyle(
                            feedbackColor: isCopyFeedbackVisible
                                ? LittleSwanTheme.Palette.success
                                : nil
                        )
                    )
                    .controlSize(.small)
                    .help(isCopyFeedbackVisible ? "Copied" : "Copy English result")
                    .accessibilityLabel(isCopyFeedbackVisible ? "Copied" : "Copy English result")
                }
            }
            .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(LittleSwanTheme.Palette.surfaceSubtle)

            Divider()
                .overlay(LittleSwanTheme.Palette.divider)

            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LittleSwanTheme.Palette.danger)

                    Text(errorMessage)
                        .font(LittleSwanTheme.Typography.status)
                        .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Button("Retry") {
                        viewModel.retryNow()
                    }
                    .controlSize(.small)
                    .tint(LittleSwanTheme.Palette.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                Divider()
                    .overlay(LittleSwanTheme.Palette.divider)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.outputText)
                    .font(LittleSwanTheme.Typography.editorBody)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(2)

                if viewModel.outputText.isEmpty {
                    HStack(spacing: 5) {
                        if outputGuidanceMessage != nil {
                            Image(systemName: "info.circle.fill")
                        }

                        Text(outputGuidanceMessage ?? "Your English version will appear here")
                    }
                        .font(LittleSwanTheme.Typography.editorBody)
                        .foregroundStyle(
                            outputGuidanceMessage == nil
                                ? LittleSwanTheme.Palette.textTertiary
                                : LittleSwanTheme.Palette.accent
                        )
                        .padding(.top, placeholderTopPadding)
                        .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .littleSwanSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contrastingColorScheme: ColorScheme {
        colorScheme == .dark ? .light : .dark
    }

    private func showCopyFeedback() {
        withAnimation(.easeOut(duration: 0.12)) {
            isCopyFeedbackVisible = true
        }

        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.4))

            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    isCopyFeedbackVisible = false
                }
            }
        }
    }

    private func showInputGuidance(_ message: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            inputGuidanceMessage = message
        }

        inputGuidanceTask?.cancel()
        inputGuidanceTask = Task {
            try? await Task.sleep(for: .seconds(2.4))

            await MainActor.run {
                guard inputGuidanceMessage == message else { return }
                withAnimation(.easeIn(duration: 0.2)) {
                    inputGuidanceMessage = nil
                }
            }
        }
    }

    private func showOutputGuidance(_ message: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            outputGuidanceMessage = message
        }

        outputGuidanceTask?.cancel()
        outputGuidanceTask = Task {
            try? await Task.sleep(for: .seconds(2.4))

            await MainActor.run {
                guard outputGuidanceMessage == message else { return }
                withAnimation(.easeIn(duration: 0.2)) {
                    outputGuidanceMessage = nil
                }
            }
        }
    }

}

private struct GenerateActionLabel: View {
    let isLoading: Bool
    let isUpdating: Bool
    let shortcut: String
    let contrastingColorScheme: ColorScheme

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(LittleSwanTheme.Palette.onAccent)
                        .environment(\.colorScheme, contrastingColorScheme)

                    Text(isUpdating ? "Updating…" : "Generating…")
                        .font(LittleSwanTheme.Typography.buttonLabel)
                }
                .foregroundStyle(LittleSwanTheme.Palette.onAccent)
                .frame(width: 88, height: 22)
                .background(LittleSwanTheme.Palette.accent)
            } else {
                HStack(spacing: 0) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LittleSwanTheme.Palette.onAccent)
                        .frame(width: 30, height: 22)
                        .background(LittleSwanTheme.Palette.accent)

                    Text(shortcut)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LittleSwanTheme.Palette.accent)
                        .frame(width: 58, height: 22)
                        .background(LittleSwanTheme.Palette.accentSoft)
                }
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
                .stroke(
                    LittleSwanTheme.Palette.accentBorder,
                    lineWidth: LittleSwanTheme.Stroke.regular
                )
        }
        .contentTransition(.opacity)
    }
}

private struct GenerateActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> Body {
        Body(configuration: configuration)
    }

    fileprivate struct Body: View {
        let configuration: Configuration

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .brightness(isHovered && isEnabled ? 0.035 : 0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(isEnabled ? 1 : 0.38)
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isHovered)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.08),
                    value: configuration.isPressed
                )
        }
    }
}

private extension View {
    @ViewBuilder
    func configuredKeyboardShortcut(_ shortcut: KeyboardShortcutConfiguration) -> some View {
        if let keyEquivalent = shortcut.menuKeyEquivalent?.first,
           let modifierFlags = shortcut.menuModifierFlags {
            keyboardShortcut(
                KeyEquivalent(keyEquivalent),
                modifiers: EventModifiers(keyboardShortcutModifierFlags: modifierFlags)
            )
        } else {
            self
        }
    }
}

private extension EventModifiers {
    init(keyboardShortcutModifierFlags flags: UInt) {
        self = []
        if flags & KeyboardShortcutConfiguration.commandModifierFlag != 0 { insert(.command) }
        if flags & KeyboardShortcutConfiguration.controlModifierFlag != 0 { insert(.control) }
        if flags & KeyboardShortcutConfiguration.optionModifierFlag != 0 { insert(.option) }
        if flags & KeyboardShortcutConfiguration.shiftModifierFlag != 0 { insert(.shift) }
    }
}

private struct CommonPhrasePicker: View {
    let phrases: [String]
    let onSelect: (String) -> Void
    let openSettings: () -> Void

    @State private var hoveredPhrase: String?

    @ViewBuilder
    var body: some View {
        if phrases.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(LittleSwanTheme.Palette.accent)

                Text("No common phrases")
                    .font(LittleSwanTheme.Typography.controlStrong)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)

                Text("Add reusable phrases in Settings.")
                    .font(LittleSwanTheme.Typography.helper)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)

                Button("Open Settings", action: openSettings)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(LittleSwanTheme.Palette.accent)
            }
            .frame(width: 280, height: 160)
            .background(LittleSwanTheme.Palette.windowCanvas)
        } else {
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(phrases, id: \.self) { phrase in
                            phraseButton(phrase)
                        }
                    }
                    .padding(6)
                }
                .frame(width: 260, height: 220)

                Divider()
                    .overlay(LittleSwanTheme.Palette.divider)

                phrasePreview
                    .frame(width: 320, height: 220)
                    .background(LittleSwanTheme.Palette.surfaceSubtle)
            }
            .background(LittleSwanTheme.Palette.windowCanvas)
            .tint(LittleSwanTheme.Palette.accent)
        }
    }

    private func phraseButton(_ phrase: String) -> some View {
        Button {
            onSelect(phrase)
        } label: {
            Text(CommonPhraseDisplay.menuTitle(for: phrase))
                .font(LittleSwanTheme.Typography.control)
                .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
                .fill(hoveredPhrase == phrase ? LittleSwanTheme.Palette.accentSoft : .clear)
        )
        .onHover { isHovering in
            if isHovering {
                hoveredPhrase = phrase
            }
        }
    }

    @ViewBuilder
    private var phrasePreview: some View {
        if let hoveredPhrase {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(LittleSwanTheme.Typography.sectionLabel)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)

                ScrollView {
                    Text(verbatim: hoveredPhrase)
                        .font(LittleSwanTheme.Typography.control)
                        .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(12)
        } else {
            ContentUnavailableView(
                "Hover to preview",
                systemImage: "text.bubble",
                description: Text("Select a phrase to insert it.")
            )
            .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
            .controlSize(.small)
            .padding(12)
        }
    }
}

private struct SourceDraftChip: View {
    let title: String
    let hasContent: Bool
    let isSelected: Bool
    let action: () -> Void

    private var contentStatus: String {
        hasContent ? "Contains content" : "Empty"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: hasContent ? "circle.fill" : "circle")
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundStyle(
                        hasContent
                            ? LittleSwanTheme.Palette.brandMark
                            : LittleSwanTheme.Palette.textTertiary.opacity(0.65)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(title)
                    .font(LittleSwanTheme.Typography.chip)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(
                    isSelected
                        ? LittleSwanTheme.Palette.accent
                        : LittleSwanTheme.Palette.textPrimary
                )
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? LittleSwanTheme.Palette.accentSoft
                                : LittleSwanTheme.Palette.surfaceRaised
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? LittleSwanTheme.Palette.accentBorder
                                : LittleSwanTheme.Palette.border,
                            lineWidth: LittleSwanTheme.Stroke.regular
                        )
                )
        }
        .buttonStyle(.plain)
        .help("\(title) — \(contentStatus)")
        .accessibilityLabel(title)
        .accessibilityValue("\(isSelected ? "Selected" : "Not selected"), \(contentStatus)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MainPanelTitlebarControlsView: View {
    @ObservedObject var viewModel: TranslationViewModel

    var resetMainWindow: () -> Void
    var openSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                resetMainWindow()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(LittleSwanIconButtonStyle())
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("Reset window position and size")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(LittleSwanIconButtonStyle())
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("Settings")
        }
        .padding(.trailing, 8)
    }
}

struct MainPanelTitleView: View {
    var body: some View {
        Text("Little Swan")
            .font(LittleSwanTheme.Typography.brandTitle)
            .foregroundStyle(LittleSwanTheme.Palette.textPrimary)
    }
}
