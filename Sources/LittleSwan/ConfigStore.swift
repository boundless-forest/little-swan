import Combine
import Foundation
import LittleSwanCore

@MainActor
final class ConfigStore: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published private(set) var lastError: String?

    private let fileURL: URL

    init(fileURL: URL = ConfigStore.defaultConfigURL()) {
        self.fileURL = fileURL
        configuration = Self.load(from: fileURL)

        // Preserve existing users' settings after the app was renamed.
        if !Self.configExists(at: fileURL), Self.decodedMigrationConfiguration() != nil {
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

        return decodedMigrationConfiguration() ?? .default
    }

    private static func decodedMigrationConfiguration() -> AppConfiguration? {
        migrationConfigURLs().lazy.compactMap { migrationURL in
            guard let data = try? Data(contentsOf: migrationURL) else {
                return nil
            }

            return try? JSONDecoder().decode(AppConfiguration.self, from: data)
        }.first
    }

    private static func configExists(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private static func migrationConfigURLs() -> [URL] {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return ["ExpressBridge", "Saywise"].map { appName in
            supportURL
                .appending(path: appName, directoryHint: .isDirectory)
                .appending(path: "config.json")
        }
    }

    private static func defaultConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appending(path: "Little Swan", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }

}
