import Foundation

/// A line of the release text on the update screen.
struct ReleaseNote: Equatable, Identifiable {
    enum Kind: Equatable {
        /// A line that began with "- " or "* ": it gets the orange marker.
        case item
        /// Everything else, including headings stripped of their hashes.
        case paragraph
    }

    let id: Int
    let kind: Kind
    let text: String
}

/// Splits the release text into lines Stash can draw. AttributedString(markdown:) does bold,
/// italics and links but not bulleted lists, so the markers are ours and the list is cut here.
enum ReleaseNotes {
    static func parse(_ body: String) -> [ReleaseNote] {
        var notes: [ReleaseNote] = []

        for rawLine in body.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            var kind = ReleaseNote.Kind.paragraph
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                kind = .item
                line.removeFirst(2)
            } else if line.hasPrefix("#") {
                line = String(line.drop(while: { $0 == "#" }))
            }

            line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            notes.append(ReleaseNote(id: notes.count, kind: kind, text: line))
        }

        return notes
    }
}
