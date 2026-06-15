import OSLog

enum LittleSwanLogger {
    static let shortcut = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LittleSwan",
        category: "Shortcut"
    )
}
