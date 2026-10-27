import SwiftUI

extension Color {
    init(hex: String, alpha: Double = 1) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Цвета под фон картинок свинки: кремовый (светлая тема) и тёмно-синий (тёмная)
struct Palette {
    let dark: Bool

    var bg: Color { dark ? Color(hex: "0E1220") : Color(hex: "E8DACF") }
    var card: Color { dark ? Color.white.opacity(0.06) : Color.white.opacity(0.5) }
    var line: Color { dark ? Color.white.opacity(0.08) : Color(hex: "4A2E2A").opacity(0.1) }
    var text: Color { dark ? Color(hex: "F3EEF8") : Color(hex: "4A2E2A") }
    var sub: Color { dark ? Color(hex: "9A98B5") : Color(hex: "9C7B71") }
    var accent: Color { dark ? Color(hex: "F5B342") : Color(hex: "E8962B") }
    var pink: Color { dark ? Color(hex: "FF6FA0") : Color(hex: "E5628E") }
    var pinkSoft: Color { pink.opacity(dark ? 0.16 : 0.14) }
    var done: Color { dark ? Color(hex: "4CD964") : Color(hex: "2FA84F") }
    var minus: Color { dark ? Color(hex: "FF6B6B") : Color(hex: "D9483B") }
    var track: Color { dark ? Color.white.opacity(0.1) : Color(hex: "4A2E2A").opacity(0.12) }
    var barGradient: LinearGradient { LinearGradient(colors: [pink, accent], startPoint: .leading, endPoint: .trailing) }
}

/// Полоска прогресса
struct ProgressBar: View {
    let progress: Double
    let pal: Palette
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(pal.track)
                if progress > 0 {
                    Capsule()
                        .fill(progress >= 1 ? AnyShapeStyle(pal.done) : AnyShapeStyle(pal.barGradient))
                        .frame(width: max(height, geo.size.width * min(1, progress)))
                }
            }
        }
        .frame(height: height)
    }
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
