import Testing
@testable import BufferJournal

struct WordmarkStoryboardTests {
    /// Ширины букв, похожие на настоящие: самый узкий набор вдвое короче самого широкого.
    private static let factors: [Double] = [1.0, 0.55, 1.05, 0.62, 0.86, 0.94, 1.12]

    private func widths(for letters: [WordmarkLetter]) -> [[Double]] {
        letters.enumerated().map { index, letter in
            let own = 30.0 + Double(index)
            return Self.factors.map { letter.hasAlternates ? own * $0 : own }
        }
    }

    private func storyboard(seed: UInt64) -> (WordmarkStoryboard, SeededGenerator) {
        let letters = WordmarkStoryboard.letters
        var rng = SeededGenerator(seed: seed)
        let board = WordmarkStoryboard(letters: letters, widths: widths(for: letters), rng: &rng)
        return (board, rng)
    }

    /// Когда ни одна форма не влезает в границы, берётся та, что промахивается меньше всех, —
    /// поэтому запас есть с обеих сторон. Клипает только перебор сверху: слово стоит по центру,
    /// и строка уже положенного просто уже. Сверху держим 4 %, снизу — лишь бы не разъехалось.
    @Test func theLineNeverGrowsPastItsColumn() {
        var (board, rng) = storyboard(seed: 1)
        let base = board.width(of: board.letters.indices.map { _ in 0 })
        let changeable = board.letters.indices.filter { board.letters[$0].hasAlternates }

        for round in 0..<400 {
            _ = board.glitch(of: changeable[round % changeable.count], using: &rng)
            let width = board.width(of: board.sets)
            #expect(width <= base * WordmarkStoryboard.widest * 1.04)
            #expect(width >= base * 0.8)
        }
    }

    @Test func aLetterNeverComesBackToTheFormItLeft() {
        var (board, rng) = storyboard(seed: 2)
        let changeable = board.letters.indices.filter { board.letters[$0].hasAlternates }

        for round in 0..<200 {
            let index = changeable[round % changeable.count]
            let was = board.sets[index]
            let steps = board.glitch(of: index, using: &rng)
            #expect(steps.last?.mark.set != was)
        }
    }

    @Test func theDotKeepsTheFontsOwnForm() {
        var (board, rng) = storyboard(seed: 3)
        let dot = board.letters.firstIndex { $0.character == "." }!

        #expect(board.glitch(of: dot, using: &rng).isEmpty)
        #expect(board.sets[dot] == 0)
    }

    @Test func everyGlitchEndsInRest() {
        var (board, rng) = storyboard(seed: 4)
        let steps = board.glitch(of: 0, using: &rng)
        let rest = steps.last!

        #expect(rest.mark == WordmarkMark(set: rest.mark.set))
        #expect(WordmarkStoryboard.letterRest.contains(rest.duration))
    }

    @Test func theSameSeedGivesTheSameRun() {
        var (first, firstRNG) = storyboard(seed: 5)
        var (second, secondRNG) = storyboard(seed: 5)

        #expect(first.sets == second.sets)
        #expect(first.glitch(of: 0, using: &firstRNG) == second.glitch(of: 0, using: &secondRNG))
    }

    @Test func aLineGlitchLeavesTheLettersAlone() {
        var (board, rng) = storyboard(seed: 6)
        let before = board.sets

        let steps = board.lineGlitch(using: &rng)
        #expect(board.sets == before)
        #expect((steps.last?.duration ?? 0) >= WordmarkStoryboard.lineRest.lowerBound)
    }
}
