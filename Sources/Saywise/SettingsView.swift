import AppKit
import SaywiseCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var draft: AppConfiguration
    @State private var didSave = false
    @State private var isAPIKeyVisible = false

    init(configStore: ConfigStore) {
        self.configStore = configStore
        _draft = State(initialValue: configStore.configuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            Form {
                Picker("Provider", selection: $draft.provider.name) {
                    Text("DeepSeek").tag("DeepSeek")
                }
                .disabled(true)

                TextField("Base URL", text: $draft.provider.baseURL)
                    .textFieldStyle(.roundedBorder)

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

                Picker("Model", selection: $draft.provider.model) {
                    Text("deepseek-v4-flash").tag("deepseek-v4-flash")
                }
                .disabled(true)

                Stepper(
                    "Realtime delay: \(draft.debounceMilliseconds) ms",
                    value: $draft.debounceMilliseconds,
                    in: 250...2000,
                    step: 50
                )
            }
            .formStyle(.grouped)

            HStack {
                if let error = configStore.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if didSave {
                    Text(savedStatusText)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reset") {
                    draft = .default
                    didSave = false
                }

                Button("Save") {
                    configStore.configuration = draft
                    configStore.save()
                    didSave = configStore.lastError == nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520, height: 360)
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

    private var savedStatusText: String {
        let trimmedKey = draft.provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedKey.isEmpty ? "Saved without API key" : "Saved API key"
    }

    private func pasteAPIKey() {
        guard let pasted = NSPasteboard.general.string(forType: .string) else { return }
        draft.provider.apiKey = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        didSave = false
    }
}
