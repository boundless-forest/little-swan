import Foundation

public enum PanelLayout: String, CaseIterable, Codable, Identifiable, Sendable {
    case sideBySide
    case stacked

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sideBySide:
            "Left and right"
        case .stacked:
            "Top and bottom"
        }
    }
}

public enum PanelPresentation {
    // Keep geometry constants in core so window sizing and tests use the same contract.
    public static let minimumWidth = 720
    public static let defaultWidth = 860
    public static let maximumWidth = 1_200
    public static let screenMargin = 12

    public static let compactSideBySideHeight = 210
    public static let compactStackedHeight = 330
    public static let expandedSideBySideHeight = 420
    public static let expandedStackedHeight = 580

    public static func clampedWidth(_ preferredWidth: Int, availableWidth: Int? = nil) -> Int {
        let screenLimitedMaximum = availableWidth.map {
            max(320, $0 - screenMargin * 2)
        } ?? maximumWidth
        let maximum = min(maximumWidth, screenLimitedMaximum)
        let minimum = min(minimumWidth, maximum)

        return min(max(preferredWidth, minimum), maximum)
    }

    public static func height(layout: PanelLayout, isExpanded: Bool) -> Int {
        switch (layout, isExpanded) {
        case (.sideBySide, false):
            compactSideBySideHeight
        case (.sideBySide, true):
            expandedSideBySideHeight
        case (.stacked, false):
            compactStackedHeight
        case (.stacked, true):
            expandedStackedHeight
        }
    }
}
