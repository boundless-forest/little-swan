import Foundation

public enum PanelPresentation {
    // Keep geometry constants in core so window sizing and tests use the same contract.
    public static let defaultWidthPercentage = 60
    public static let fallbackAvailableWidth = 1_440
    public static let fallbackAvailableHeight = 900
    public static let minimumContentWidth = 520
    public static let minimumContentHeight = 240
    public static let defaultContentHeight = 300
    public static let windowFrameHeightReserve = 48
    public static let screenMargin = 12

    public static let defaultContentSize = PanelContentSizeConfiguration(
        width: width(percentage: defaultWidthPercentage),
        height: defaultContentHeight
    )

    public static func clampedContentSize(
        _ preferredSize: PanelContentSizeConfiguration,
        availableWidth: Int? = nil,
        availableHeight: Int? = nil
    ) -> PanelContentSizeConfiguration {
        let usableWidth = max(
            minimumContentWidth,
            (availableWidth ?? fallbackAvailableWidth) - screenMargin * 2
        )
        let usableHeight = max(
            minimumContentHeight,
            (availableHeight ?? fallbackAvailableHeight) - screenMargin * 2
        )

        return PanelContentSizeConfiguration(
            width: min(max(preferredSize.width, minimumContentWidth), usableWidth),
            height: min(max(preferredSize.height, minimumContentHeight), usableHeight)
        )
    }

    public static func width(percentage: Int, availableWidth: Int? = nil) -> Int {
        // Percentages apply to the usable area inside the screen margin, not the raw screen width.
        // This keeps the settings label intuitive while still preserving the minimum content width.
        let usableWidth = max(
            minimumContentWidth,
            (availableWidth ?? fallbackAvailableWidth) - screenMargin * 2
        )
        let clampedPercentage = min(max(percentage, 1), 100)
        let preferredWidth = Int((Double(usableWidth) * Double(clampedPercentage) / 100).rounded())

        return min(max(preferredWidth, minimumContentWidth), usableWidth)
    }

    public static func contentSize(widthPercentage: Int) -> PanelContentSizeConfiguration {
        clampedContentSize(
            PanelContentSizeConfiguration(
                width: width(percentage: widthPercentage),
                height: defaultContentHeight
            )
        )
    }

    public static func contentSize(legacyWidth: Int) -> PanelContentSizeConfiguration {
        clampedContentSize(
            PanelContentSizeConfiguration(
                width: legacyWidth,
                height: defaultContentHeight
            )
        )
    }
}
