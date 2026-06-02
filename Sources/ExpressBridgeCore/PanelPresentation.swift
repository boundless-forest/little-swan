import Foundation

public enum PanelPresentation {
    // Keep geometry constants in core so window sizing and tests use the same contract.
    public static let minimumWidthPercentage = 35
    public static let defaultWidthPercentage = 60
    public static let maximumWidthPercentage = 90
    public static let fallbackAvailableWidth = 1_440
    public static let minimumContentWidth = 360
    public static let screenMargin = 12

    public static let compactSideBySideHeight = 210
    public static let expandedSideBySideHeight = 420

    public static func clampedWidthPercentage(_ preferredPercentage: Int) -> Int {
        min(max(preferredPercentage, minimumWidthPercentage), maximumWidthPercentage)
    }

    public static func width(percentage: Int, availableWidth: Int? = nil) -> Int {
        // Percentages apply to the usable area inside the screen margin, not the raw screen width.
        // This keeps the settings label intuitive while still preserving the minimum content width.
        let usableWidth = max(
            minimumContentWidth,
            (availableWidth ?? fallbackAvailableWidth) - screenMargin * 2
        )
        let clampedPercentage = clampedWidthPercentage(percentage)
        let preferredWidth = Int((Double(usableWidth) * Double(clampedPercentage) / 100).rounded())

        return min(max(preferredWidth, minimumContentWidth), usableWidth)
    }

    public static func widthPercentage(forLegacyWidth legacyWidth: Int) -> Int {
        // Legacy config files only know a pixel value, so use the same fallback width that initial
        // sizing uses before AppKit can report an actual screen.
        let fallbackUsableWidth = fallbackAvailableWidth - screenMargin * 2
        let percentage = Int((Double(legacyWidth) / Double(fallbackUsableWidth) * 100).rounded())

        return clampedWidthPercentage(percentage)
    }

    public static func height(isExpanded: Bool) -> Int {
        isExpanded ? expandedSideBySideHeight : compactSideBySideHeight
    }
}
