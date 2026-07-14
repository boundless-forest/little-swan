import LittleSwanCore
import SwiftUI

struct MainPanelView: View {
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
                    .font(.caption.weight(.bold))
                    .fixedSize()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(Array(viewModel.sourceDrafts.enumerated()), id: \.element.id) { index, draft in
                            let title = viewModel.sourceDraftLabel(for: draft, fallbackIndex: index)
                            SourceDraftChip(
                                title: title,
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
                .buttonStyle(.borderless)
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
                .buttonStyle(.borderless)
                .disabled(viewModel.inputText.isEmpty)
                .help("Clear current draft")

                Toggle(
                    "Auto",
                    isOn: Binding(
                        get: { viewModel.isRealtimeTranslationEnabled },
                        set: { viewModel.setRealtimeTranslationEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .help("Translate automatically while typing")
                .accessibilityLabel("Auto translate")
                .accessibilityHint("Automatically refreshes the English result after you stop typing")
            }
            .frame(height: 34)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .focused($isInputFocused)
                    .padding(2)
                    .opacity(viewModel.polishAnimationFrame == nil ? 1 : 0)

                if let polishAnimationFrame = viewModel.polishAnimationFrame {
                    polishReviewOverlay(polishAnimationFrame)
                } else if viewModel.inputText.isEmpty {
                    Text("Type in any language")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, placeholderTopPadding)
                        .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func polishReviewOverlay(_ frame: PolishedInputAnimation.Frame) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                highlightedPolishText(for: frame)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, placeholderTopPadding + 2)
                    .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
            }

            if viewModel.pendingPolishedInput != nil {
                Divider()

                HStack(spacing: 8) {
                    Text("Review polished changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Reject") {
                        viewModel.rejectPolishedInput()
                        isInputFocused = true
                    }

                    Button("Accept") {
                        viewModel.acceptPolishedInput()
                        isInputFocused = true
                    }
                    .buttonStyle(.borderedProminent)
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
                .foregroundColor(.primary)
        case .removed:
            return Text(segment.text)
                .foregroundColor(.red)
                .strikethrough(true, color: .red)
        case .added:
            return Text(segment.text)
                .foregroundColor(.green)
                .underline(true, color: .green)
        }
    }

    private var commonPhrasesMenu: some View {
        Button {
            isCommonPhrasePickerPresented.toggle()
        } label: {
            Label("Phrases", systemImage: "text.badge.plus")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
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
                    .font(.caption.weight(.bold))

                Text("Editable")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: Capsule())

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
                        .font(.caption)
                        .foregroundStyle(.green)
                        .fixedSize()
                } else if viewModel.isOutputStale {
                    Label("Out of date", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
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
                                Text("Generating…")
                            }
                        } else {
                            Label(viewModel.isOutputStale ? "Update" : "Generate", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
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
                    .buttonStyle(.borderless)
                    .disabled(viewModel.outputText.isEmpty)
                    .help("Copy English result")
                }
            }
            .frame(height: 34)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()

            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(errorMessage)
                        .font(.caption)
                        .lineLimit(2)

                    Spacer()

                    Button("Retry") {
                        viewModel.retryNow()
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                Divider()
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.outputText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(2)

                if viewModel.outputText.isEmpty {
                    Text("Your English version will appear here")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, placeholderTopPadding)
                        .padding(.leading, placeholderLeadingPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            phrasePreview
                .frame(width: 320, height: 220)
        }
    }

    private func phraseButton(_ phrase: String) -> some View {
        Button {
            onSelect(phrase)
        } label: {
            Text(CommonPhraseDisplay.menuTitle(for: phrase))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(hoveredPhrase == phrase ? Color.accentColor.opacity(0.14) : .clear)
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(verbatim: hoveredPhrase)
                        .font(.system(size: 13))
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
            .controlSize(.small)
            .padding(12)
        }
    }
}

private struct SourceDraftChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.07))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
            .buttonStyle(.borderless)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("Reset window position and size")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("Settings")
        }
        .padding(.trailing, 8)
    }
}

struct MainPanelTitleView: View {
    private static let titleFontName = "Noteworthy"
    private static let titleFontSize: CGFloat = 14

    var body: some View {
        Text("Little Swan")
            .font(font)
            .foregroundStyle(.primary)
    }

    private var font: Font {
        if let nsFont = NSFont(name: Self.titleFontName, size: Self.titleFontSize) {
            return Font(nsFont)
        }
        return .system(size: Self.titleFontSize)
    }
}
