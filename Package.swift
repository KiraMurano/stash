// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BufferJournal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BufferJournal", targets: ["BufferJournal"])
    ],
    targets: [
        .executableTarget(
            name: "BufferJournal",
            path: "Sources/BufferJournal"
        )
    ]
)
