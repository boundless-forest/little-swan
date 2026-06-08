import OSLog

enum LittleSwanLogger {
    static let sourceCompletion = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LittleSwan",
        category: "SourceCompletion"
    )
}
