import LittleSwanCore
import SwiftUI

struct MainPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TranslationViewModel
    @FocusState private var isInputFocused: Bool
    @State private var isCopyFeedbackVisible = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var isCommonPhrasePickerPresented = false

    private let placeholderTopPadding: CGFloat = 2
    private let placeholderLeadingPadding: CGFloat = 8
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
            }
            .onChange(of: viewModel.copyFeedbackTrigger) { _, _ in
                showCopyFeedback()
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
            HStack(spacing: 7) {
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
                    viewModel.polishInput()
                    isInputFocused = true
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
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPolishingInput)
                .help("Polish input text")

                Button {
                    viewModel.clearInput()
                    isInputFocused = true
                } label: {
                    Label("Clear source", systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(LittleSwanIconButtonStyle())
                .disabled(viewModel.inputText.isEmpty)
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
                    Text("Type in any language")
                        .font(LittleSwanTheme.Typography.editorBody)
                        .foregroundStyle(LittleSwanTheme.Palette.textTertiary)
                        .padding(.top, placeholderTopPadding)
                        .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
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
                    Text("Review polished changes")
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
        .disabled(viewModel.commonPhrases.isEmpty)
        .help(
            viewModel.commonPhrases.isEmpty ? "No common phrases configured" : "Insert common phrase"
        )
        .popover(isPresented: $isCommonPhrasePickerPresented, arrowEdge: .top) {
            CommonPhrasePicker(phrases: viewModel.commonPhrases) { phrase in
                viewModel.insertCommonPhrase(phrase)
                isCommonPhrasePickerPresented = false
                isInputFocused = true
            }
        }
    }

    private var outputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("English result")
                    .font(LittleSwanTheme.Typography.sectionLabel)
                    .foregroundStyle(LittleSwanTheme.Palette.textPrimary)

                Text("Editable")
                    .font(LittleSwanTheme.Typography.chip)
                    .foregroundStyle(LittleSwanTheme.Palette.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LittleSwanTheme.Palette.surfaceRaised, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(LittleSwanTheme.Palette.border, lineWidth: LittleSwanTheme.Stroke.regular)
                    }

                Picker("Writing style", selection: $viewModel.selectedStyle) {
                    ForEach(WritingStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .labelsHidden()
                .frame(minWidth: 180, maxWidth: 360)
                .layoutPriority(1)
                .accessibilityLabel("Writing style")
                .accessibilityValue(viewModel.selectedStyle.label)

                Spacer(minLength: 0)

                if isCopyFeedbackVisible {
                    Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(LittleSwanTheme.Typography.status)
                        .foregroundStyle(LittleSwanTheme.Palette.success)
                        .fixedSize()
                } else if viewModel.isOutputStale {
                    Label("Out of date", systemImage: "clock.arrow.circlepath")
                        .font(LittleSwanTheme.Typography.status)
                        .foregroundStyle(LittleSwanTheme.Palette.warning)
                        .fixedSize()
                }

                HStack(spacing: 6) {
                    Button {
                        viewModel.generateNow()
                    } label: {
                        if viewModel.isLoading {
                            HStack(spacing: 5) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(LittleSwanTheme.Palette.onAccent)
                                    .environment(\.colorScheme, contrastingColorScheme)
                                Text("Generating…")
                                    .foregroundStyle(LittleSwanTheme.Palette.onAccent)
                            }
                        } else {
                            Label(viewModel.isOutputStale ? "Update" : "Generate", systemImage: "sparkles")
                                .foregroundStyle(LittleSwanTheme.Palette.onAccent)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(LittleSwanTheme.Typography.buttonLabel)
                    .tint(LittleSwanTheme.Palette.accent)
                    .controlSize(.small)
                    .disabled(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.isLoading
                    )
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Generate English result (Command-Return)")

                    Button {
                        viewModel.copyOutput()
                    } label: {
                        Label(
                            isCopyFeedbackVisible ? "Copied" : "Copy",
                            systemImage: isCopyFeedbackVisible ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(LittleSwanIconButtonStyle())
                    .disabled(viewModel.outputText.isEmpty)
                    .help("Copy English result")
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
                    Text("Your English version will appear here")
                        .font(LittleSwanTheme.Typography.editorBody)
                        .foregroundStyle(LittleSwanTheme.Palette.textTertiary)
                        .padding(.top, placeholderTopPadding)
                        .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
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

}

private struct CommonPhrasePicker: View {
    let phrases: [String]
    let onSelect: (String) -> Void

    @State private var hoveredPhrase: String?

    var body: some View {
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
