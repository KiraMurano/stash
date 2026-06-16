import AppKit
import CryptoKit
import Foundation

enum ClipboardPayload: Codable, Equatable {
    case text(String)
    case image(filename: String)
    case file(storedFilename: String, originalName: String, byteCount: Int64)

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
        case originalName
        case byteCount
    }

    private enum Kind: String, Codable {
        case text
        case image
        case file
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .text:
            self = .text(try container.decode(String.self, forKey: .value))
        case .image:
            self = .image(filename: try container.decode(String.self, forKey: .value))
        case .file:
            self = .file(
                storedFilename: try container.decode(String.self, forKey: .value),
                originalName: try container.decode(String.self, forKey: .originalName),
                byteCount: try container.decode(Int64.self, forKey: .byteCount)
            )
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
        case let .file(storedFilename, originalName, byteCount):
            try container.encode(Kind.file, forKey: .kind)
            try container.encode(storedFilename, forKey: .value)
            try container.encode(originalName, forKey: .originalName)
            try container.encode(byteCount, forKey: .byteCount)
        }
    }
}

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var payload: ClipboardPayload
    let createdAt: Date
    var fingerprint: String
    var isPinned: Bool
    var pinnedOrder: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case payload
        case createdAt
        case fingerprint
        case isPinned
        case pinnedOrder
    }

    init(
        id: UUID,
        payload: ClipboardPayload,
        createdAt: Date,
        fingerprint: String,
        isPinned: Bool = false,
        pinnedOrder: Int? = nil
    ) {
        self.id = id
        self.payload = payload
        self.createdAt = createdAt
        self.fingerprint = fingerprint
        self.isPinned = isPinned
        self.pinnedOrder = pinnedOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        payload = try container.decode(ClipboardPayload.self, forKey: .payload)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedOrder = try container.decodeIfPresent(Int.self, forKey: .pinnedOrder)
    }

    var title: String {
        switch payload {
        case let .text(text):
            let singleLine = text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return singleLine.isEmpty ? "Empty text" : singleLine
        case .image:
            return "Image"
        case let .file(_, originalName, _):
            return originalName
        }
    }

    var subtitle: String {
        switch payload {
        case let .text(text):
            let count = text.count
            return "\(count) \(count == 1 ? "character" : "characters")"
        case .image:
            return DateFormatter.entryTime.string(from: createdAt)
        case let .file(_, _, byteCount):
            return Self.formattedFileSize(byteCount)
        }
    }

    var isText: Bool {
        if case .text = payload { return true }
        return false
    }

    var isImage: Bool {
        if case .image = payload { return true }
        return false
    }

    var isFile: Bool {
        if case .file = payload { return true }
        return false
    }
}

extension ClipboardEntry {
    static func text(_ value: String) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            payload: .text(value),
            createdAt: Date(),
            fingerprint: Self.textFingerprint(value)
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

    static func file(storedFilename: String, originalName: String, byteCount: Int64, data: Data) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            payload: .file(
                storedFilename: storedFilename,
                originalName: originalName,
                byteCount: byteCount
            ),
            createdAt: Date(),
            fingerprint: "file:\(Self.sha256(data))"
        )
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func textFingerprint(_ value: String) -> String {
        "text:\(Self.sha256(Data(value.utf8)))"
    }

    private static func formattedFileSize(_ byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: byteCount)
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
