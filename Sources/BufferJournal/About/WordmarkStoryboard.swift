import Foundation

/// A letter of the wordmark. The dot has no alternate forms in the font, so it never changes.
struct WordmarkLetter: Equatable {
    let character: Character
    let hasAlternates: Bool
}

/// How one letter is drawn at a given moment: which stylistic set (0 is the font's own form,
/// 1…6 are ss01…ss06) and what a glitch leaves on it.
struct WordmarkMark: Equatable {
    var set: Int
    var dx: Double = 0
    var dy: Double = 0
    var skew: Double = 0
    /// How far the two coloured shadows move apart, in points; 0 draws none.
    var aberration: Double = 0
    var aberrationDY: Double = 0
    /// The letter is gone for this frame.
    var isDim: Bool = false
}

/// A mark and how long it holds, in seconds.
struct WordmarkStep: Equatable {
    var mark: WordmarkMark
    var duration: Double
}

/// A glitch over the whole line. It never changes the letters, only shakes the setting.
struct WordmarkLineStep: Equatable {
    var dx: Double = 0
    var dy: Double = 0
    var skew: Double = 0
    var scaleY: Double = 1
    var aberration: Double = 0
    var aberrationDY: Double = 0
    var duration: Double
}

/// Picks the forms the wordmark's letters take, and how long each frame holds.
///
/// A free choice would make the word jump about: the narrowest setting of "OZERO.DIGITAL" is
/// about half the widest. So a new form is only taken when the line stays within the width of
/// the font's own setting, and the choice is made against what the neighbours show right now.
struct WordmarkStoryboard {
    static let word = "OZERO.DIGITAL"
    /// ss01…ss06.
    static let sets = Array(1...6)
    /// Bounds of the line's width, as a share of the default setting.
    static let narrowest = 0.90
    static let widest = 1.04
    /// A letter's rest between its own substitutions.
    static let letterRest: ClosedRange<Double> = 1.6...8.5
    /// The first substitution after the screen opens — of one letter, not of the word.
    static let firstRest: ClosedRange<Double> = 0.18...0.52
    /// Rest between glitches of the whole line.
    static let lineRest: ClosedRange<Double> = 6...16

    static var letters: [WordmarkLetter] {
        word.map { WordmarkLetter(character: $0, hasAlternates: $0.isLetter) }
    }

    let letters: [WordmarkLetter]
    /// widths[letter][set], set 0…6, at the size they were measured.
    let widths: [[Double]]
    private(set) var sets: [Int]

    private let lowerWidth: Double
    private let upperWidth: Double

    init(letters: [WordmarkLetter], widths: [[Double]], rng: inout some RandomNumberGenerator) {
        self.letters = letters
        self.widths = widths
        let base = letters.indices.reduce(0.0) { $0 + widths[$1][0] }
        lowerWidth = base * Self.narrowest
        upperWidth = base * Self.widest
        sets = letters.map { _ in 0 }
        seed(using: &rng)
    }

    func width(of sets: [Int]) -> Double {
        sets.indices.reduce(0.0) { $0 + widths[$1][sets[$1]] }
    }

    /// One substitution: two to four intermediate forms, then rest in the new one. The rest is
    /// the last step's own duration — counted apart, it would be waited out twice.
    mutating func glitch(of index: Int, using rng: inout some RandomNumberGenerator) -> [WordmarkStep] {
        guard letters[index].hasAlternates else { return [] }

        let was = sets[index]
        var steps: [WordmarkStep] = []
        let hops = Int.random(in: 2...4, using: &rng)

        for hop in 0..<hops {
            let isLast = hop == hops - 1
            // On the last hop the form it came from is barred: otherwise the letter "changes"
            // into itself and the glitch is left without a reason.
            sets[index] = alternate(for: index, avoiding: isLast ? was : nil, using: &rng)
            steps.append(
                WordmarkStep(
                    mark: WordmarkMark(
                        set: sets[index],
                        dx: isLast ? 0 : .random(in: -2.5...2.5, using: &rng),
                        dy: isLast ? 0 : .random(in: -1.5...1.5, using: &rng),
                        skew: isLast ? 0 : .random(in: -12...12, using: &rng),
                        aberration: isLast
                            ? .random(in: 1...2, using: &rng)
                            : .random(in: 2...5, using: &rng),
                        aberrationDY: isLast ? 0 : .random(in: -1...1, using: &rng)
                    ),
                    duration: isLast
                        ? .random(in: 0.078...0.116, using: &rng)
                        : .random(in: 0.058...0.096, using: &rng)
                )
            )

            if !isLast, Double.random(in: 0...1, using: &rng) < 0.35 {
                steps.append(
                    WordmarkStep(
                        mark: WordmarkMark(set: sets[index], isDim: true),
                        duration: .random(in: 0.046...0.072, using: &rng)
                    )
                )
            }
        }

        steps.append(
            WordmarkStep(
                mark: WordmarkMark(set: sets[index]),
                duration: .random(in: Self.letterRest, using: &rng)
            )
        )
        return steps
    }

    /// The channels split, or the setting jolts. Either way the last step is the rest until the
    /// next glitch.
    func lineGlitch(using rng: inout some RandomNumberGenerator) -> [WordmarkLineStep] {
        let rest = WordmarkLineStep(duration: .random(in: Self.lineRest, using: &rng))

        if Bool.random(using: &rng) {
            let far = Double.random(in: 2...4.5, using: &rng)
            return [
                WordmarkLineStep(
                    dx: .random(in: -1.5...1.5, using: &rng),
                    aberration: far,
                    aberrationDY: .random(in: -1...1, using: &rng),
                    duration: .random(in: 0.105...0.160, using: &rng)
                ),
                WordmarkLineStep(aberration: -far * 0.6, duration: .random(in: 0.085...0.125, using: &rng)),
                rest,
            ]
        }

        return [
            WordmarkLineStep(
                dx: .random(in: -3...3, using: &rng),
                dy: .random(in: -2...2, using: &rng),
                skew: .random(in: -5...5, using: &rng),
                scaleY: .random(in: 0.94...1.06, using: &rng),
                duration: .random(in: 0.070...0.120, using: &rng)
            ),
            rest,
        ]
    }

    /// A new form for one letter, chosen so the line keeps its width. When nothing fits, the
    /// form that misses by the least: better to move the edge by a couple of points than to
    /// leave the letter as it was.
    private func alternate(
        for index: Int,
        avoiding avoided: Int?,
        using rng: inout some RandomNumberGenerator
    ) -> Int {
        let rest = width(of: sets) - widths[index][sets[index]]
        func miss(_ set: Int) -> Double {
            let total = rest + widths[index][set]
            return Swift.max(lowerWidth - total, total - upperWidth, 0)
        }

        let options = Self.sets.filter { $0 != sets[index] && $0 != avoided }
        let fitting = options.filter { miss($0) == 0 }
        return fitting.randomElement(using: &rng) ?? options.min { miss($0) < miss($1) }!
    }

    /// The setting the word opens in: random forms, nudged until the line fits.
    private mutating func seed(using rng: inout some RandomNumberGenerator) {
        sets = letters.map { $0.hasAlternates ? Self.sets.randomElement(using: &rng)! : 0 }
        let changeable = letters.indices.filter { letters[$0].hasAlternates }

        for _ in 0..<200 {
            let total = width(of: sets)
            guard total < lowerWidth || total > upperWidth else { break }
            let index = changeable.randomElement(using: &rng)!
            sets[index] = alternate(for: index, avoiding: nil, using: &rng)
        }
    }
}

/// SplitMix64. The tests seed it to get the same run twice; the screen seeds it from the clock.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
