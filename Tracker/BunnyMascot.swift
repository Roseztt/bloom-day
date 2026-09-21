import SwiftUI

/// The Bloom Day bunny. Each pose is one of the supplied sticker illustrations,
/// cut out of the sheet with its pastel tile background removed, so the bunny
/// sits directly on whatever card it's placed on.
enum BunnyPose: String, CaseIterable {
    case tasks
    case addTask = "add-task"
    case calendar
    case reminders
    case focus
    case study
    case sleep
    case coffeeBreak = "break"
    case goals
    case completed
    case progress
    case favorites
    case selfCare = "self-care"
    case habitTracker = "habit-tracker"
    case notes
    case plan
    case schedule
    case memories
    case ideas
    case messages
    case settings
    case todo
    case nightMode = "night-mode"
    case home

    var assetName: String { "Bunny-\(rawValue)" }
}

struct BunnyView: View {
    var pose: BunnyPose = .favorites

    var body: some View {
        Image(pose.assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// The little rounded speech bubble the bunny talks through.
struct SpeechBubble: View {
    let text: String
    var tint: Color = Bloom.ink
    var fill: Color = Bloom.card

    var body: some View {
        Text(text)
            .font(BloomFont.note(13))
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(fill, in: BubbleShape())
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(
            roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height),
            cornerRadius: min(rect.height / 2, 20),
            style: .continuous
        )

        // A small tail pointing down-left, toward the bunny.
        var tail = Path()
        let baseY = rect.maxY - 6
        tail.move(to: CGPoint(x: rect.minX + 14, y: baseY))
        tail.addQuadCurve(
            to: CGPoint(x: rect.minX + 2, y: rect.maxY + 9),
            control: CGPoint(x: rect.minX + 6, y: rect.maxY + 2)
        )
        tail.addQuadCurve(
            to: CGPoint(x: rect.minX + 30, y: baseY),
            control: CGPoint(x: rect.minX + 18, y: rect.maxY + 1)
        )
        tail.closeSubpath()

        path.addPath(tail)
        return path
    }
}

/// A sprig of leaves used as a quiet decoration on the encouragement cards.
struct SprigView: View {
    var tint: Color = Bloom.mint

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let ox = (size.width - s) / 2
            let oy = (size.height - s) / 2

            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: ox + x * s, y: oy + y * s)
            }

            var stem = Path()
            stem.move(to: point(0.5, 1.0))
            stem.addQuadCurve(to: point(0.5, 0.12), control: point(0.42, 0.55))
            context.stroke(stem, with: .color(tint), style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))

            for (y, flip) in [(0.62, false), (0.42, true), (0.24, false)] {
                var leaf = Path()
                let dx = flip ? -0.26 : 0.26
                leaf.move(to: point(0.5, y))
                leaf.addQuadCurve(to: point(0.5 + dx, y - 0.12), control: point(0.5 + dx * 0.5, y - 0.20))
                leaf.addQuadCurve(to: point(0.5, y), control: point(0.5 + dx * 0.55, y + 0.02))
                context.fill(leaf, with: .color(tint.opacity(0.85)))
            }
        }
        .accessibilityHidden(true)
    }
}
