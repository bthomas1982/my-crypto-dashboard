import SwiftUI

/// Murmur's visual identity — warm coral (the record dot / the intelligence)
/// against a cool signal blue (capture). Kept in one place so the app reads
/// as a single designed system, light and dark.
enum Theme {
    static let coral   = Color(hex: 0xD9482F)
    static let coralDk = Color(hex: 0xFF6A52)
    static let signal  = Color(hex: 0x2F5A7A)
    static let signalDk = Color(hex: 0x7FB2DB)

    static let good = Color(hex: 0x2F7A55)
    static let warn = Color(hex: 0xB0791E)

    /// A mono face for timestamps, labels, and data — evokes the transcript world.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension TimeInterval {
    /// 1:03:20 style clock for recording durations.
    var clockString: String {
        let total = Int(self)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
