import Foundation

public struct BuildInformation: Equatable, Sendable {
    public static let repositoryURL = URL(string: "https://github.com/boundless-forest/little-swan")!

    public let version: String
    public let buildNumber: String
    public let gitCommit: String?
    public let gitCommitDate: Date?
    public let isDirtyBuild: Bool

    public init(infoDictionary: [String: Any]) {
        version = Self.stringValue(
            forKey: "CFBundleShortVersionString",
            in: infoDictionary,
            fallback: "Development"
        )
        buildNumber = Self.stringValue(
            forKey: "CFBundleVersion",
            in: infoDictionary,
            fallback: "Local"
        )

        let commit = Self.stringValue(forKey: "LittleSwanGitCommit", in: infoDictionary)
        gitCommit = Self.isValidGitCommit(commit) ? commit : nil

        let commitDate = Self.stringValue(forKey: "LittleSwanGitCommitDate", in: infoDictionary)
        gitCommitDate = commitDate.flatMap(ISO8601DateFormatter().date(from:))
        isDirtyBuild = Self.boolValue(forKey: "LittleSwanGitDirty", in: infoDictionary)
    }

    public init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    public var shortGitCommit: String? {
        gitCommit.map { String($0.prefix(7)) }
    }

    public var displayedGitCommit: String {
        guard let shortGitCommit else { return "Unavailable" }
        return isDirtyBuild ? "\(shortGitCommit) (modified)" : shortGitCommit
    }

    public var releaseNotesURL: URL? {
        guard version != "Development" else { return nil }
        return Self.repositoryURL
            .appending(path: "releases")
            .appending(path: "tag")
            .appending(path: "v\(version)")
    }

    public var commitURL: URL? {
        guard let gitCommit else { return nil }
        return Self.repositoryURL.appending(path: "commit").appending(path: gitCommit)
    }

    private static func stringValue(
        forKey key: String,
        in dictionary: [String: Any],
        fallback: String? = nil
    ) -> String? {
        let value = dictionary[key].map { String(describing: $0) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return fallback }
        return value
    }

    private static func stringValue(
        forKey key: String,
        in dictionary: [String: Any],
        fallback: String
    ) -> String {
        stringValue(forKey: key, in: dictionary, fallback: Optional(fallback)) ?? fallback
    }

    private static func boolValue(forKey key: String, in dictionary: [String: Any]) -> Bool {
        if let value = dictionary[key] as? Bool {
            return value
        }
        guard let value = stringValue(forKey: key, in: dictionary) else { return false }
        return ["1", "true", "yes"].contains(value.lowercased())
    }

    private static func isValidGitCommit(_ value: String?) -> Bool {
        guard let value, (7...64).contains(value.count) else { return false }
        return value.allSatisfy(\.isHexDigit)
    }
}
