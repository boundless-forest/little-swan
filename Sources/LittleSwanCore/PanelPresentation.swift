import Foundation

public enum PanelPresentation {
    // Keep geometry constants in core so window sizing and tests use the same contract.
    public static let defaultWidthPercentage = 60
    public static let defaultHeightPercentage = 12
    public static let fallbackAvailableWidth = 1_440
    public static let fallbackAvailableHeight = 900
    public static let minimumContentWidth = 520
    public static let minimumContentHeight = 120
    public static let windowFrameHeightReserve = 48
    public static let screenMargin = 12

    public static let defaultContentSize = PanelContentSizeConfiguration(
        width: width(percentage: defaultWidthPercentage),
        height: height(percentage: defaultHeightPercentage)
    )

    public static let legacyWideDefaultContentSize = PanelContentSizeConfiguration(
        width: 850,
        height: 300
    )

    public static let legacyShallowDefaultContentSize = PanelContentSizeConfiguration(
        width: 850,
        height: 120
    )

    public static let interimTallDefaultContentSize = PanelContentSizeConfiguration(
        width: 850,
        height: 228
    )

    public static func defaultContentSize(
        availableWidth: Int? = nil,
        availableHeight: Int? = nil
    ) -> PanelContentSizeConfiguration {
        clampedContentSize(
            PanelContentSizeConfiguration(
                width: width(percentage: defaultWidthPercentage, availableWidth: availableWidth),
                height: height(percentage: defaultHeightPercentage, availableHeight: availableHeight)
            ),
            availableWidth: availableWidth,
            availableHeight: availableHeight
        )
    }

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

    public static func height(percentage: Int, availableHeight: Int? = nil) -> Int {
        let usableHeight = max(
            minimumContentHeight,
            (availableHeight ?? fallbackAvailableHeight) - screenMargin * 2
        )
        let clampedPercentage = min(max(percentage, 1), 100)
        let preferredHeight = Int((Double(usableHeight) * Double(clampedPercentage) / 100).rounded())

        return min(max(preferredHeight, minimumContentHeight), usableHeight)
    }

    public static func contentSize(widthPercentage: Int) -> PanelContentSizeConfiguration {
        clampedContentSize(
            PanelContentSizeConfiguration(
                width: width(percentage: widthPercentage),
                height: height(percentage: defaultHeightPercentage)
            )
        )
    }

    public static func contentSize(legacyWidth: Int) -> PanelContentSizeConfiguration {
        clampedContentSize(
            PanelContentSizeConfiguration(
                width: legacyWidth,
                height: height(percentage: defaultHeightPercentage)
            )
        )
    }
}
