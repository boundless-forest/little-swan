import ExpressBridgeCore
import SwiftUI

struct MainPanelView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @FocusState private var isInputFocused: Bool
    @State private var isCopyFeedbackVisible = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    var openSettings: () -> Void

    private let editorContentPadding: CGFloat = 8
    // TextEditor is backed by NSTextView, whose text container adds this default horizontal inset.
    private let textEditorLineFragmentPadding: CGFloat = 5

    var body: some View {
        VStack(spacing: 10) {
            header

            contentColumns
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(width: panelWidth, height: panelHeight)
        .onAppear {
            isInputFocused = true
        }
        .onDisappear {
            copyFeedbackTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 16, weight: .semibold))

            Text("Translate")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Picker("Style", selection: $viewModel.selectedStyle) {
                ForEach(WritingStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .help("Writing style")

            Button {
                viewModel.togglePanelExpansion()
            } label: {
                Image(systemName: expansionIconName)
            }
            .buttonStyle(.borderless)
            .help(viewModel.isPanelExpanded ? "Collapse" : "Expand")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }

    @ViewBuilder
    private var contentColumns: some View {
        HStack(spacing: 10) {
            inputEditor
            outputView
        }
    }

    private var inputEditor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Input")
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
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 14))
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .padding(editorContentPadding)

                if viewModel.inputText.isEmpty {
                    Text("Type in any language")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, editorContentPadding)
                        .padding(.leading, editorContentPadding + textEditorLineFragmentPadding)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: paneHeight)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
        .frame(maxWidth: .infinity)
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
        .frame(height: paneHeight)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        )
        .frame(maxWidth: .infinity)
    }

    private var panelWidth: CGFloat {
        viewModel.panelContentSize.width
    }

    private var panelHeight: CGFloat {
        viewModel.panelContentSize.height
    }

    private var paneHeight: CGFloat {
        contentHeight
    }

    private var contentHeight: CGFloat {
        max(110, panelHeight - 60)
    }

    private var expansionIconName: String {
        viewModel.isPanelExpanded
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
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
            return "English result will appear here"
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
