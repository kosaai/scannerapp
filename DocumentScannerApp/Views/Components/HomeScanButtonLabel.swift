import SwiftUI

/// A tinted native glass control on iOS 26+, not an opaque gradient painted over glass.
struct HomeScanButtonLabel: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var glyph: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(ScannerTheme.scanInk)
            .frame(width: 68, height: 68)
    }

    var body: some View {
        if reduceTransparency || contrast == .increased {
            glyph.background(ScannerTheme.teal, in: Circle())
        } else if #available(iOS 26, *) {
            glyph.glassEffect(.regular.tint(ScannerTheme.teal).interactive(), in: .circle)
        } else {
            glyph
                .background(ScannerTheme.gradient, in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.6), lineWidth: 0.5) }
        }
    }
}
