import AppKit
import ExpressBridgeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var draft: AppConfiguration
    @State private var didSave = false
    @State private var isAPIKeyVisible = false
    @State private var selectedTab: SettingsTab = .provider
    @State private var isTabRailExpanded = true

    init(configStore: ConfigStore) {
        self.configStore = configStore
        _draft = State(initialValue: configStore.configuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            HStack(alignment: .top, spacing: 0) {
                tabRail
                    .frame(width: isTabRailExpanded ? 172 : 52)

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
        .frame(width: 720, height: 390)
    }

    private var tabRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if isTabRailExpanded {
                    Text("Categories")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isTabRailExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isTabRailExpanded ? "sidebar.left" : "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help(isTabRailExpanded ? "Collapse tabs" : "Expand tabs")
            }
            .frame(height: 24)

            ForEach(SettingsTab.allCases) { tab in
                tabButton(tab)
            }

            Spacer()
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .frame(width: 18)

                if isTabRailExpanded {
                    Text(tab.label)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: isTabRailExpanded ? .leading : .center)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(tab.label)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .provider:
            providerGroup
        case .translation:
            translationGroup
        case .panel:
            panelGroup
        }
    }

    private var providerGroup: some View {
        GroupBox("Provider") {
            VStack(alignment: .leading, spacing: 12) {
                settingsRow("Provider") {
                    Picker("Provider", selection: $draft.provider.name) {
                        Text("DeepSeek").tag("DeepSeek")
                    }
                    .disabled(true)
                    .labelsHidden()
                }

                settingsRow("Base URL") {
                    TextField("Base URL", text: $draft.provider.baseURL)
                        .textFieldStyle(.roundedBorder)
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
                    Picker("Model", selection: $draft.provider.model) {
                        Text("deepseek-v4-flash").tag("deepseek-v4-flash")
                    }
                    .disabled(true)
                    .labelsHidden()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var translationGroup: some View {
        GroupBox("Translation") {
            VStack(alignment: .leading, spacing: 12) {
                settingsRow("Realtime delay") {
                    // Debounces rapid edits: translation starts after typing stays unchanged for this delay.
                    VStack(alignment: .leading, spacing: 5) {
                        Stepper(
                            "\(draft.debounceMilliseconds) ms",
                            value: $draft.debounceMilliseconds,
                            in: 250...2000,
                            step: 50
                        )

                        Text("Translation starts after typing stays unchanged for this delay. Higher values reduce repeated requests; lower values feel more immediate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .help("Translation starts after typing stays unchanged for this delay.")
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

    private var panelGroup: some View {
        GroupBox("Panel") {
            VStack(alignment: .leading, spacing: 12) {
                settingsRow("Layout") {
                    Picker("Layout", selection: $draft.panelLayout) {
                        ForEach(PanelLayout.allCases) { layout in
                            Text(layout.label).tag(layout)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                settingsRow("Position") {
                    Picker("Position", selection: $draft.panelPosition) {
                        ForEach(PanelPosition.allCases) { position in
                            Text(position.label).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                settingsRow("Width") {
                    Stepper(
                        "\(draft.panelWidthPercentage)%",
                        value: $draft.panelWidthPercentage,
                        in: PanelPresentation.minimumWidthPercentage...PanelPresentation.maximumWidthPercentage,
                        step: 5
                    )
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
                .frame(width: 94, alignment: .leading)

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

private enum SettingsTab: String, CaseIterable, Identifiable {
    case provider
    case translation
    case panel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .provider:
            "Provider"
        case .translation:
            "Translation"
        case .panel:
            "Panel"
        }
    }

    var systemImage: String {
        switch self {
        case .provider:
            "network"
        case .translation:
            "textformat"
        case .panel:
            "macwindow"
        }
    }
}
