import AppKit
import SwiftUI

enum LittleSwanTheme {
    enum Palette {
        static let brandMark = Color(nsColor: adaptive(light: 0x9C7BF6, dark: 0x9C7BF6))
        static let windowCanvas = Color(nsColor: adaptive(light: 0xF7F6FA, dark: 0x17141D))
        static let surface = Color(nsColor: adaptive(light: 0xFFFFFF, dark: 0x211D29))
        static let surfaceSubtle = Color(nsColor: adaptive(light: 0xF2F0F6, dark: 0x292431))
        static let surfaceRaised = Color(nsColor: adaptive(light: 0xFCFBFD, dark: 0x2E2837))

        static let textPrimary = Color(nsColor: adaptive(light: 0x211D29, dark: 0xF4F0F8))
        static let textSecondary = Color(nsColor: adaptive(light: 0x625C6C, dark: 0xC5BECE))
        static let textTertiary = Color(
            nsColor: adaptive(
                light: 0x777080,
                dark: 0xA8A0B3,
                highContrastLight: 0x5F5868,
                highContrastDark: 0xC8C0D0
            )
        )

        static let border = Color(
            nsColor: adaptive(
                light: 0xDED9E6,
                dark: 0x3D3648,
                highContrastLight: 0xB9B0C8,
                highContrastDark: 0x70647E
            )
        )
        static let divider = Color(
            nsColor: adaptive(
                light: 0xEAE6EF,
                dark: 0x342E3D,
                highContrastLight: 0xCFC7D9,
                highContrastDark: 0x5C5268
            )
        )

        static let accent = Color(
            nsColor: adaptive(
                light: 0x6F4BC7,
                dark: 0xB39AFB,
                highContrastLight: 0x5633AA,
                highContrastDark: 0xC9B8FF
            )
        )
        static let accentHover = Color(
            nsColor: adaptive(
                light: 0x6541B9,
                dark: 0xC1AFFE,
                highContrastLight: 0x4C299E,
                highContrastDark: 0xD4C7FF
            )
        )
        static let accentPressed = Color(
            nsColor: adaptive(
                light: 0x5F3FAE,
                dark: 0xA286EE,
                highContrastLight: 0x45258F,
                highContrastDark: 0xBBA7FF
            )
        )
        static let accentSoft = Color(
            nsColor: adaptive(
                light: 0xF1ECFD,
                dark: 0x302642,
                highContrastLight: 0xE7DDFB,
                highContrastDark: 0x413458
            )
        )
        static let accentBorder = Color(
            nsColor: adaptive(
                light: 0xCFC3F0,
                dark: 0x665389,
                highContrastLight: 0x9F8ACF,
                highContrastDark: 0x9A82C8
            )
        )
        static let onAccent = Color(nsColor: adaptive(light: 0xFFFFFF, dark: 0x17141D))

        static let success = Color(
            nsColor: adaptive(
                light: 0x2E7D57,
                dark: 0x66D19E,
                highContrastLight: 0x17633E,
                highContrastDark: 0x8BE8BA
            )
        )
        static let warning = Color(
            nsColor: adaptive(
                light: 0xA35C00,
                dark: 0xF3B85A,
                highContrastLight: 0x7B4300,
                highContrastDark: 0xFFD184
            )
        )
        static let danger = Color(
            nsColor: adaptive(
                light: 0xC23B49,
                dark: 0xFF8A94,
                highContrastLight: 0xA51F31,
                highContrastDark: 0xFFABB2
            )
        )

        // AppKit-backed controls and window chrome use the same adaptive palette as SwiftUI.
        static let appKitWindowCanvas = adaptive(light: 0xF7F6FA, dark: 0x17141D)
        static let appKitSurface = adaptive(light: 0xFFFFFF, dark: 0x211D29)
        static let appKitSurfaceSubtle = adaptive(light: 0xF2F0F6, dark: 0x292431)
        static let appKitTextPrimary = adaptive(light: 0x211D29, dark: 0xF4F0F8)
        static let appKitTextSecondary = adaptive(light: 0x625C6C, dark: 0xC5BECE)
        static let appKitTextTertiary = adaptive(
            light: 0x777080,
            dark: 0xA8A0B3,
            highContrastLight: 0x5F5868,
            highContrastDark: 0xC8C0D0
        )
        static let appKitBorder = adaptive(
            light: 0xDED9E6,
            dark: 0x3D3648,
            highContrastLight: 0xB9B0C8,
            highContrastDark: 0x70647E
        )
        static let appKitAccent = adaptive(
            light: 0x6F4BC7,
            dark: 0xB39AFB,
            highContrastLight: 0x5633AA,
            highContrastDark: 0xC9B8FF
        )
        static let appKitDanger = adaptive(
            light: 0xC23B49,
            dark: 0xFF8A94,
            highContrastLight: 0xA51F31,
            highContrastDark: 0xFFABB2
        )

        private static func adaptive(
            light: UInt32,
            dark: UInt32,
            highContrastLight: UInt32? = nil,
            highContrastDark: UInt32? = nil
        ) -> NSColor {
            NSColor(name: nil) { appearance in
                switch appearance.bestMatch(from: [
                    .accessibilityHighContrastDarkAqua,
                    .darkAqua,
                    .accessibilityHighContrastAqua,
                    .aqua
                ]) {
                case .accessibilityHighContrastDarkAqua:
                    color(highContrastDark ?? dark)
                case .darkAqua:
                    color(dark)
                case .accessibilityHighContrastAqua:
                    color(highContrastLight ?? light)
                default:
                    color(light)
                }
            }
        }

        private static func color(_ hex: UInt32) -> NSColor {
            NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    enum Typography {
        static let brandTitle = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let sectionLabel = Font.system(size: 12, weight: .semibold)
        static let editorBody = Font.system(size: 14, weight: .regular)
        static let control = Font.system(size: 13, weight: .regular)
        static let controlStrong = Font.system(size: 13, weight: .semibold)
        static let buttonLabel = Font.system(size: 12, weight: .medium)
        static let helper = Font.system(size: 11, weight: .regular)
        static let status = Font.system(size: 11, weight: .medium)
        static let chip = Font.system(size: 11, weight: .medium)
    }

    enum Radius {
        static let compact: CGFloat = 6
        static let surface: CGFloat = 8
    }

    enum Stroke {
        static let regular: CGFloat = 1
        static let focus: CGFloat = 2
    }
}

struct LittleSwanSurfaceModifier: ViewModifier {
    var radius = LittleSwanTheme.Radius.surface

    func body(content: Content) -> some View {
        content
            .background(LittleSwanTheme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(LittleSwanTheme.Palette.border, lineWidth: LittleSwanTheme.Stroke.regular)
            }
    }
}

struct LittleSwanIconButtonStyle: ButtonStyle {
    var feedbackColor: Color?

    func makeBody(configuration: Configuration) -> Body {
        Body(configuration: configuration, feedbackColor: feedbackColor)
    }

    struct Body: View {
        let configuration: Configuration
        let feedbackColor: Color?

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: 22, height: 22)
                .background {
                    RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.compact, style: .continuous)
                        .fill(backgroundColor)
                }
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.38)
                .onHover { isHovered = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isHovered)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
        }

        private var foregroundColor: Color {
            if let feedbackColor {
                return feedbackColor
            }
            if configuration.isPressed {
                return LittleSwanTheme.Palette.accentPressed
            }
            if isHovered {
                return LittleSwanTheme.Palette.accentHover
            }
            return LittleSwanTheme.Palette.textSecondary
        }

        private var backgroundColor: Color {
            guard isEnabled else { return .clear }
            if let feedbackColor {
                return feedbackColor.opacity(isHovered ? 0.16 : 0.10)
            }
            if configuration.isPressed {
                return LittleSwanTheme.Palette.accentSoft
            }
            return isHovered ? LittleSwanTheme.Palette.accentSoft : .clear
        }
    }
}

struct LittleSwanGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(LittleSwanTheme.Typography.sectionLabel)
                .foregroundStyle(LittleSwanTheme.Palette.textPrimary)

            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(LittleSwanTheme.Palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.surface, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LittleSwanTheme.Radius.surface, style: .continuous)
                .stroke(LittleSwanTheme.Palette.border, lineWidth: LittleSwanTheme.Stroke.regular)
        }
    }
}

extension View {
    func littleSwanSurface(radius: CGFloat = LittleSwanTheme.Radius.surface) -> some View {
        modifier(LittleSwanSurfaceModifier(radius: radius))
    }
}
