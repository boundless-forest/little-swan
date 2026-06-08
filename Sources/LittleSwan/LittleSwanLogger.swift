import OSLog

enum LittleSwanLogger {
    static let sourceCompletion = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LittleSwan",
        category: "SourceCompletion"
    )

    static let shortcut = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LittleSwan",
        category: "Shortcut"
    )
}
