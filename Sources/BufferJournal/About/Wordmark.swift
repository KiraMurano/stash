import AppKit
import SwiftUI

/// "OZERO.DIGITAL" in Booker Display: the letters change their form on their own, each in its
/// own time, and every change comes as a glitch.
struct Wordmark: View {
    let size: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var glitch: WordmarkGlitch

    init(size: CGFloat, color: Color) {
        self.size = size
        self.color = color
        _glitch = StateObject(wrappedValue: WordmarkGlitch(size: size))
    }

    /// The channels of a broken screen: red and cyan, the sRGB of the oklch pair the studio's
    /// own page uses. The app's orange would read as a reflection of the button below, not as
    /// interference.
    private static let redGhost = Color(red: 0.91, green: 0.16, blue: 0.20)
    private static let cyanGhost = Color(red: 0.25, green: 0.74, blue: 0.86)

    var body: some View {
        line
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("OZERO.DIGITAL")
            .task {
                guard !reduceMotion, WordmarkFont.isAvailable else { return }
                glitch.start()
            }
            .onDisappear { glitch.stop() }
    }

    @ViewBuilder
    private var line: some View {
        if WordmarkFont.isAvailable {
            HStack(spacing: 0) {
                ForEach(Array(glitch.letters.enumerated()), id: \.offset) { index, letter in
                    letterView(letter, mark: glitch.marks[index])
                }
            }
            .offset(x: glitch.line.dx, y: glitch.line.dy)
            .scaleEffect(x: 1, y: glitch.line.scaleY)
            .transformEffect(Self.skew(glitch.line.skew))
            .shadow(color: Self.redGhost, radius: 0, x: -glitch.line.aberration, y: glitch.line.aberrationDY)
            .shadow(color: Self.cyanGhost, radius: 0, x: glitch.line.aberration, y: -glitch.line.aberrationDY)
        } else {
            // A build run without the bundle has no font to set this in; the line still has to
            // read, so it falls back to the system face and stands still.
            Text(WordmarkStoryboard.word)
                .font(.system(size: size * 0.72, weight: .semibold))
                .tracking(size * 0.02)
                .foregroundStyle(color)
        }
    }

    private func letterView(_ letter: WordmarkLetter, mark: WordmarkMark) -> some View {
        let font = WordmarkFont.font(size: size, set: mark.set)
            ?? .systemFont(ofSize: size, weight: .semibold)

        return Text(String(letter.character))
            .font(Font(font))
            .foregroundStyle(color)
            .opacity(mark.isDim ? 0 : 1)
            .shadow(color: Self.redGhost, radius: 0, x: -mark.aberration, y: mark.aberrationDY)
            .shadow(color: Self.cyanGhost, radius: 0, x: mark.aberration, y: -mark.aberrationDY)
            .offset(x: mark.dx, y: mark.dy)
            .transformEffect(Self.skew(mark.skew))
    }

    /// SwiftUI has no skew of its own; the transform does what `skewX` does in the browser.
    private static func skew(_ degrees: Double) -> CGAffineTransform {
        CGAffineTransform(a: 1, b: 0, c: CGFloat(tan(-degrees * .pi / 180)), d: 1, tx: 0, ty: 0)
    }
}

/// Runs the wordmark: one task per letter, so the word never ticks as one, and one more for the
/// glitch that goes over the whole line.
@MainActor
final class WordmarkGlitch: ObservableObject {
    let letters = WordmarkStoryboard.letters

    @Published private(set) var marks: [WordmarkMark]
    @Published private(set) var line = WordmarkLineStep(duration: 0)

    private var storyboard: WordmarkStoryboard
    private var rng: SeededGenerator
    private var tasks: [Task<Void, Never>] = []

    init(size: CGFloat) {
        var rng = SeededGenerator(seed: UInt64.random(in: UInt64.min...UInt64.max))
        let letters = WordmarkStoryboard.letters
        let storyboard = WordmarkStoryboard(
            letters: letters,
            widths: WordmarkFont.widths(of: letters, size: size),
            rng: &rng
        )

        self.rng = rng
        self.storyboard = storyboard
        marks = storyboard.sets.map { WordmarkMark(set: $0) }
    }

    func start() {
        guard tasks.isEmpty else { return }

        for index in letters.indices where letters[index].hasAlternates {
            tasks.append(Task { [weak self] in await self?.run(letter: index) })
        }
        tasks.append(Task { [weak self] in await self?.runLine() })
    }

    /// The screen is gone: nothing is counted while nobody looks.
    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func run(letter index: Int) async {
        await rest(.random(in: WordmarkStoryboard.firstRest, using: &rng))

        while !Task.isCancelled {
            for step in storyboard.glitch(of: index, using: &rng) {
                marks[index] = step.mark
                await rest(step.duration)
                if Task.isCancelled { return }
            }
        }
    }

    private func runLine() async {
        while !Task.isCancelled {
            for step in storyboard.lineGlitch(using: &rng) {
                line = step
                await rest(step.duration)
                if Task.isCancelled { return }
            }
        }
    }

    private func rest(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
