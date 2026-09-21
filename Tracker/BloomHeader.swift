import SwiftUI

/// The branded top of every screen: wordmark, a line of encouragement, and the
/// bunny with something kind to say.
struct BloomHeader: View {
    var headline: String?
    var subhead: String?
    var bubble: String
    var pose: BunnyPose = .favorites

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Bloom Day")
                        .font(BloomFont.display(28))
                        .foregroundStyle(Bloom.ink)
                    Image(systemName: "camera.macro")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Bloom.pink)
                }

                Text("A brighter you, one day at a time")
                    .font(BloomFont.note(12))
                    .foregroundStyle(Bloom.inkSoft)

                if let headline {
                    Text(headline)
                        .font(BloomFont.display(21))
                        .foregroundStyle(Bloom.ink)
                        .padding(.top, 14)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let subhead {
                    Text(subhead)
                        .font(BloomFont.note(13))
                        .foregroundStyle(Bloom.inkSoft)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)

            // Bubble above the bunny so its tail points down at them and nothing
            // covers the ears.
            VStack(alignment: .trailing, spacing: 6) {
                SpeechBubble(text: bubble)
                    .frame(maxWidth: 116)

                BunnyView(pose: pose)
                    .frame(width: 94, height: 94)
            }
            .frame(width: 124)
        }
    }
}

/// A small rotating line of encouragement. Picked from the day so it's stable
/// for the whole day rather than flickering on every redraw.
enum Encouragement {
    private static let lines = [
        "Good things take time",
        "Small tasks create big dreams",
        "Progress, not perfection",
        "One gentle step at a time",
        "You're allowed to go slowly",
        "Small steps, big days",
        "Begin where you are"
    ]

    private static let notes = [
        "A more productive you is a happier you",
        "Every finished thing is a small kindness to future you",
        "You don't have to do it all today",
        "Tiny progress is still progress",
        "Rest counts as taking care of it too"
    ]

    static func headline(for date: Date = Date()) -> String {
        lines[index(for: date, count: lines.count)]
    }

    static func note(for date: Date = Date()) -> String {
        notes[index(for: date, count: notes.count)]
    }

    private static func index(for date: Date, count: Int) -> Int {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return abs(day) % count
    }
}
