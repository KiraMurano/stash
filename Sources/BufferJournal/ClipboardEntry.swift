import AppKit
import CryptoKit
import Foundation

enum ClipboardPayload: Codable, Equatable {
    case text(String)
    case image(filename: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    private enum Kind: String, Codable {
        case text
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let value = try container.decode(String.self, forKey: .value)

        switch kind {
        case .text:
            self = .text(value)
        case .image:
            self = .image(filename: value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .text(value):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .image(filename):
            try container.encode(Kind.image, forKey: .kind)
            try container.encode(filename, forKey: .value)
        }
    }
}

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let payload: ClipboardPayload
    let createdAt: Date
    let fingerprint: String

    var title: String {
        switch payload {
        case let .text(text):
            let singleLine = text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return singleLine.isEmpty ? "Empty text" : singleLine
        case .image:
            return "Image"
        }
    }

    var subtitle: String {
        switch payload {
        case let .text(text):
            let count = text.count
            return "\(count) \(count == 1 ? "character" : "characters")"
        case .image:
            return DateFormatter.entryTime.string(from: createdAt)
        }
    }
}

extension ClipboardEntry {
    static func text(_ value: String) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            payload: .text(value),
            createdAt: Date(),
            fingerprint: "text:\(Self.sha256(Data(value.utf8)))"
        )
    }

    static func image(filename: String, data: Data) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            payload: .image(filename: filename),
            createdAt: Date(),
            fingerprint: "image:\(Self.sha256(data))"
        )
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

extension DateFormatter {
    static let entryTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
