import Foundation

public enum SourceEnglishLayout: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case horizontal
    case vertical

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .horizontal:
            "Horizontal"
        case .vertical:
            "Vertical"
        }
    }
}
