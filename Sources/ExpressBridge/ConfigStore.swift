import Combine
import Foundation
import ExpressBridgeCore

@MainActor
final class ConfigStore: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published private(set) var lastError: String?

    private let fileURL: URL

    init(fileURL: URL = ConfigStore.defaultConfigURL()) {
        self.fileURL = fileURL
        configuration = Self.load(from: fileURL)

        // Preserve existing users' settings after the app was renamed from Saywise.
        if !Self.configExists(at: fileURL), Self.configExists(at: Self.legacyConfigURL()) {
            save()
        }
    }

    var isConfigured: Bool {
        !configuration.provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let data = try JSONEncoder().encode(configuration)
            try data.write(to: fileURL, options: [.atomic])
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func load(from fileURL: URL) -> AppConfiguration {
        if let data = try? Data(contentsOf: fileURL) {
            return (try? JSONDecoder().decode(AppConfiguration.self, from: data)) ?? .default
        }

        // Read the pre-rename config as a fallback so users keep their API key and panel width.
        // The initializer saves this decoded value into the new ExpressBridge path on first launch.
        guard let data = try? Data(contentsOf: legacyConfigURL()) else {
            return .default
        }

        return (try? JSONDecoder().decode(AppConfiguration.self, from: data)) ?? .default
    }

    private static func configExists(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private static func defaultConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appending(path: "ExpressBridge", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }

    private static func legacyConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appending(path: "Saywise", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }
}
