import LittleSwanCore
import SwiftUI

struct MainPanelView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @FocusState private var isInputFocused: Bool
    @State private var isCopyFeedbackVisible = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    private let editorContentPadding: CGFloat = 8
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
    }

    @ViewBuilder
    private var contentColumns: some View {
        GeometryReader { geometry in
            let shouldStackVertically = viewModel.sourceEnglishLayout == .vertical
                || geometry.size.width <= geometry.size.height

            Group {
                if shouldStackVertically {
                    VStack(spacing: 10) {
                        inputEditor
                        outputView
                    }
                } else {
                    HStack(spacing: 10) {
                        inputEditor
                        outputView
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var inputEditor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.clearInput()
                    isInputFocused = true
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.inputText.isEmpty)
                .help("Clear input")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ZStack(alignment: .topLeading) {
                SourceCompletionTextView(
                    text: $viewModel.inputText,
                    sourceSuggestion: viewModel.sourceSuggestion,
                    onEditorStateChange: { text, selectedRange, hasMarkedText in
                        viewModel.updateSourceEditorState(
                            text: text,
                            selectedRange: selectedRange,
                            hasMarkedText: hasMarkedText
                        )
                    },
                    onAcceptSuggestion: {
                        viewModel.acceptSourceCompletion()
                    },
                    onDismissSuggestion: {
                        viewModel.dismissSourceCompletion()
                    }
                )

                if viewModel.inputText.isEmpty {
                    Text("Type in any language")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, editorContentPadding)
                        .padding(.leading, editorContentPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
                }
            }

            if !viewModel.sourceSuggestion.isEmpty {
                Divider()

                HStack(spacing: 8) {
                    Text("Suggestion:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.sourceSuggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("Tab to accept")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
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

    private var outputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("English")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .opacity(isCopyFeedbackVisible ? 1 : 0)
                    .frame(width: 68, alignment: .trailing)

                Button {
                    copyOutput()
                } label: {
                    Image(systemName: isCopyFeedbackVisible ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.outputText.isEmpty)
                .help("Copy English result")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ScrollView {
                Text(outputDisplayText)
                    .font(.system(size: 14))
                    .foregroundStyle(outputForegroundStyle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
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

    private func copyOutput() {
        viewModel.copyOutput()

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

    private var outputDisplayText: String {
        if let errorMessage = viewModel.errorMessage {
            return errorMessage
        }

        if viewModel.outputText.isEmpty {
            return "Your English version will appear here"
        }

        return viewModel.outputText
    }

    private var outputForegroundStyle: Color {
        if viewModel.errorMessage != nil || viewModel.outputText.isEmpty {
            return .secondary
        }

        return .primary
    }
}


struct MainPanelTitlebarControlsView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @State private var isResetTooltipVisible = false

    var resetMainWindow: () -> Void
    var openSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Text("Style")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Style", selection: $viewModel.selectedStyle) {
                ForEach(WritingStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 128)
            .help("Writing style")

            Button {
                resetMainWindow()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("Reset window position and size")
            .onHover { isHovering in
                withAnimation(.easeOut(duration: 0.08)) {
                    isResetTooltipVisible = isHovering
                }
            }
            .overlay(alignment: .bottom) {
                if isResetTooltipVisible {
                    TooltipBubble(text: "Reset window position and size")
                        .offset(y: 30)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .zIndex(1)

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

private struct TooltipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color(nsColor: .textColor))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6))
            )
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}
