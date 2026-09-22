// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "BufferJournal",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "BufferJournal", targets: ["BufferJournal"])
    ],
    targets: [
        .executableTarget(
            name: "BufferJournal",
            path: "Sources/BufferJournal"
        ),
        .testTarget(
            name: "BufferJournalTests",
            dependencies: ["BufferJournal"],
            path: "Tests/BufferJournalTests"
        )
    ]
)
