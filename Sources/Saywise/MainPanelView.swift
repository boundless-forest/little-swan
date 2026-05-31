import SaywiseCore
import SwiftUI

struct MainPanelView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @FocusState private var isInputFocused: Bool

    var openSettings: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            header

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 15))
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 130)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor))
                    )

                if viewModel.inputText.isEmpty {
                    Text("Type in any language")
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
            }

            Picker("Style", selection: $viewModel.selectedStyle) {
                ForEach(WritingStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("English")
                        .font(.headline)

                    Spacer()

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Button {
                        viewModel.copyOutput()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(viewModel.outputText.isEmpty)
                }

                ZStack(alignment: .topLeading) {
                    ScrollView {
                        Text(outputDisplayText)
                            .font(.system(size: 15))
                            .foregroundStyle(outputForegroundStyle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(minHeight: 150)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor))
                    )
                }
            }
        }
        .padding(18)
        .frame(width: 520, height: 500)
        .onAppear {
            isInputFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 18, weight: .semibold))

            Text("Saywise")
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                quit()
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Quit")
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
