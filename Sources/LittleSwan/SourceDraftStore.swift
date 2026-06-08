import Combine
import Foundation
import LittleSwanCore

@MainActor
final class SourceDraftStore: ObservableObject {
    @Published private(set) var collection: SourceDraftCollection
    @Published private(set) var lastError: String?

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL = SourceDraftStore.defaultDraftsURL()) {
        self.fileURL = fileURL
        collection = Self.load(from: fileURL)

        if !Self.draftsExist(at: fileURL) {
            save()
        }
    }

    var drafts: [SourceDraft] {
        collection.drafts
    }

    var selectedDraftID: UUID {
        collection.selectedDraftID
    }

    var selectedDraft: SourceDraft? {
        collection.selectedDraft
    }

    func selectDraft(id: UUID) {
        collection.selectDraft(id: id)
        saveDebounced()
    }

    func updateSelectedDraftText(_ text: String) {
        guard collection.selectedDraft?.text != text else { return }
        collection.updateSelectedDraftText(text)
        saveDebounced()
    }

    func deleteDraft(id: UUID) {
        collection.deleteDraft(id: id)
        saveDebounced()
    }

    func save() {
        saveTask?.cancel()

        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(collection)
            try data.write(to: fileURL, options: [.atomic])
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func saveDebounced() {
        saveTask?.cancel()

        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private static func load(from fileURL: URL) -> SourceDraftCollection {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SourceDraftCollection.self, from: data)) ?? .default
    }

    private static func draftsExist(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private static func defaultDraftsURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appending(path: "Little Swan", directoryHint: .isDirectory)
            .appending(path: "source-drafts.json")
    }
}
