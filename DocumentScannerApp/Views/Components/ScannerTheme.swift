import SwiftUI
import UIKit

/// Home's semantic palette, measured from the reference; independent of persistence settings.
enum ScannerTheme {
    static let background = adaptive(light: 0xF3F7FA, dark: 0x101C22)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1C2B32)
    static let paper = adaptive(light: 0xFEFDFC, dark: 0x26363E)
    static let ink = adaptive(light: 0x0F171F, dark: 0xEDF5F7)
    static let secondary = adaptive(light: 0x65717B, dark: 0xACBBC4)
    static let scanInk = Color(red: 15 / 255, green: 23 / 255, blue: 31 / 255)
    // Darker than the decorative teal so small labels remain readable.
    static let accent = adaptive(light: 0x006F72, dark: 0x72DED1)
    static let teal = Color(red: 0, green: 148 / 255, blue: 150 / 255)
    static let mint = Color(red: 33 / 255, green: 191 / 255, blue: 160 / 255)
    static let selected = adaptive(light: 0xCBF1EE, dark: 0x244B4C)
    static let border = adaptive(light: 0xD8DFE4, dark: 0x43545D)
    static let gradient = LinearGradient(colors: [mint, teal],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}

/// A shared sampling region for adjacent controls, with no new-OS types in its API.
struct ScannerGlassGroup<Content: View>: View {
    let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private struct ScannerGlassSurface<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let shape: S
    let tint: Color
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(ScannerTheme.surface, in: shape)
                .overlay { shape.stroke(ScannerTheme.border, lineWidth: 1) }
        } else if #available(iOS 26, *) {
            if interactive {
                content.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                content.glassEffect(.regular.tint(tint), in: shape)
            }
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.55), lineWidth: 0.5) }
        }
    }
}

struct HomePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    /// Apply after sizing/padding. Content cards intentionally use paper, not glass.
    func scannerGlass<S: Shape>(in shape: S, tint: Color = .clear,
                                interactive: Bool = false) -> some View {
        modifier(ScannerGlassSurface(shape: shape, tint: tint, interactive: interactive))
    }
}
