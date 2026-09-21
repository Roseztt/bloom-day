import SwiftUI

// MARK: - Palette

/// The Bloom Day colour set. Every colour carries a dark-mode counterpart so the
/// soft pastel look holds up at night instead of glowing.
enum Bloom {
    static let background = dynamic(light: 0xFDF3F5, dark: 0x161013)
    static let backgroundTint = dynamic(light: 0xF6EEF9, dark: 0x1A1218)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x261C21)
    static let cardSoft = dynamic(light: 0xFFF8FA, dark: 0x2C2027)

    static let ink = dynamic(light: 0x5E4238, dark: 0xF4E9E5)
    static let inkSoft = dynamic(light: 0x9C8078, dark: 0xB6A29B)
    static let hairline = dynamic(light: 0xF0E3E6, dark: 0x3A2C32)

    static let pink = dynamic(light: 0xEE7D97, dark: 0xF59BB0)
    static let pinkSoft = dynamic(light: 0xFCE1E8, dark: 0x3E2029)

    static let mint = dynamic(light: 0x62B892, dark: 0x8AD3AE)
    static let mintSoft = dynamic(light: 0xE2F2E9, dark: 0x1B2E24)

    static let lavender = dynamic(light: 0x8F8CDA, dark: 0xB2AFEE)
    static let lavenderSoft = dynamic(light: 0xEAE9FA, dark: 0x221E34)

    static let peach = dynamic(light: 0xE59A4E, dark: 0xF4BA7C)
    static let peachSoft = dynamic(light: 0xFCEFDF, dark: 0x332619)

    /// Warm cream used for the encouragement notes.
    static let cream = dynamic(light: 0xFDF4E3, dark: 0x2E2619)

    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Type

/// SF Rounded throughout — it gets the soft, friendly feel of the reference
/// without bundling a font.
enum BloomFont {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// For the little encouragements. Italic stands in for the handwriting.
    static func note(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).italic()
    }
}

// MARK: - Surfaces

struct BloomCardStyle: ViewModifier {
    var padding: CGFloat
    var fill: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 12, y: 4)
    }
}

extension View {
    func bloomCard(
        padding: CGFloat = 18,
        fill: Color = Bloom.card,
        radius: CGFloat = 24
    ) -> some View {
        modifier(BloomCardStyle(padding: padding, fill: fill, radius: radius))
    }
}

/// The blush wash that sits behind every screen.
struct BloomBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Bloom.background, Bloom.backgroundTint],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Small shared pieces

/// A rounded status/count chip.
struct BloomPill: View {
    let text: String
    var tint: Color = Bloom.pink
    var fill: Color = Bloom.pinkSoft
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(BloomFont.body(size, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(fill, in: Capsule())
    }
}

/// Section header used down the left of most screens.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var symbol: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 6) {
                Text(title)
                    .font(BloomFont.display(22))
                    .foregroundStyle(Bloom.ink)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Bloom.pink)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, symbol: String? = nil) {
        self.init(title: title, symbol: symbol, trailing: { EmptyView() })
    }
}

/// A ring that fills to `progress`, used for the daily completion figure.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var tint: Color = Bloom.pink
    var track: Color = Bloom.pinkSoft

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
        }
    }
}
