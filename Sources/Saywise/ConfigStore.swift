import Combine
import Foundation
import SaywiseCore

@MainActor
final class ConfigStore: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published private(set) var lastError: String?

    private let fileURL: URL

    init(fileURL: URL = ConfigStore.defaultConfigURL()) {
        self.fileURL = fileURL
        configuration = Self.load(from: fileURL)
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
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }

        return (try? JSONDecoder().decode(AppConfiguration.self, from: data)) ?? .default
    }

    private static func defaultConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appending(path: "Saywise", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }
}
