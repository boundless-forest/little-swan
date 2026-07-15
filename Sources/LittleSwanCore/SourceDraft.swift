import Foundation

public struct SourceDraft: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func displayTitle(fallbackIndex: Int) -> String {
        "Draft \(fallbackIndex + 1)"
    }
}

public struct SourceDraftCollection: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let draftCount = 5

    public var version: Int
    public var selectedDraftID: UUID
    public var drafts: [SourceDraft]

    public init(
        version: Int = Self.currentVersion,
        selectedDraftID: UUID,
        drafts: [SourceDraft]
    ) {
        let normalizedDrafts = Self.normalizedDrafts(drafts)
        self.version = version
        self.drafts = normalizedDrafts

        if normalizedDrafts.contains(where: { $0.id == selectedDraftID }) {
            self.selectedDraftID = selectedDraftID
        } else {
            self.selectedDraftID = normalizedDrafts[0].id
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        let selectedDraftID = try container.decodeIfPresent(UUID.self, forKey: .selectedDraftID) ?? UUID()
        let drafts = try container.decodeIfPresent([SourceDraft].self, forKey: .drafts) ?? []

        self.init(version: version, selectedDraftID: selectedDraftID, drafts: drafts)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(selectedDraftID, forKey: .selectedDraftID)
        try container.encode(drafts, forKey: .drafts)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case selectedDraftID
        case drafts
    }

    public static var `default`: SourceDraftCollection {
        let drafts = normalizedDrafts([])
        return SourceDraftCollection(selectedDraftID: drafts[0].id, drafts: drafts)
    }

    public var selectedDraft: SourceDraft? {
        drafts.first { $0.id == selectedDraftID }
    }

    public mutating func selectDraft(id: UUID) {
        guard drafts.contains(where: { $0.id == id }) else { return }
        selectedDraftID = id
    }

    public mutating func updateSelectedDraftText(_ text: String, now: Date = Date()) {
        guard let selectedIndex = drafts.firstIndex(where: { $0.id == selectedDraftID }) else {
            let draft = SourceDraft(text: text, createdAt: now, updatedAt: now)
            drafts = Self.normalizedDrafts([draft], now: now)
            selectedDraftID = draft.id
            return
        }

        drafts[selectedIndex].text = text
        drafts[selectedIndex].updatedAt = now
    }

    private static func normalizedDrafts(_ drafts: [SourceDraft], now: Date = Date()) -> [SourceDraft] {
        var normalized = Array(drafts.prefix(draftCount))

        while normalized.count < draftCount {
            normalized.append(SourceDraft(createdAt: now, updatedAt: now))
        }

        return normalized
    }
}
