import Foundation

/// A thin wrapper over /usr/bin/codesign. Stash is signed with a self-signed certificate, not a
/// Developer ID, so Gatekeeper knows nothing about it and `spctl` is never asked: the only
/// question that means anything here is whether a build satisfies this build's own requirement.
enum Codesign {
    private static let tool = "/usr/bin/codesign"

    /// Fails when the item does not satisfy `requirement`, and says what codesign said.
    static func verify(_ url: URL, requirement: String, deep: Bool) throws {
        var arguments = ["-v", "--strict", "-R=\(requirement)"]
        if deep {
            arguments.append("--deep")
        }
        arguments.append(url.path)

        let result = try run(arguments)
        guard result.status == 0 else {
            throw UpdateError.signature(result.output.isEmpty ? "codesign exited with \(result.status)" : result.output)
        }
    }

    /// The requirement a signed item satisfies by itself. codesign prints it as a comment —
    /// `# designated => …` — among other lines, so the marker is looked for inside the line.
    ///
    /// An ad hoc signature has nothing stable to name and yields `cdhash H"…"`, which is new with
    /// every build; a certificate yields `identifier "…" and certificate leaf H"…"`, which is not.
    /// That difference is the whole reason releases are signed with a certificate.
    static func designatedRequirement(of url: URL) throws -> String {
        let result = try run(["-d", "-r-", "--", url.path])
        guard result.status == 0 else {
            throw UpdateError.signature(result.output)
        }

        let marker = "designated =>"
        for line in result.output.split(whereSeparator: \.isNewline) {
            guard let range = line.range(of: marker) else { continue }
            return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        throw UpdateError.signature("codesign printed no designated requirement")
    }

    /// Ad hoc signing, for the tests only: the app itself is signed by `Scripts/build_app.sh`.
    static func sign(_ url: URL, identifier: String) throws {
        let result = try run(["--force", "--deep", "--sign", "-", "--identifier", identifier, url.path])
        guard result.status == 0 else {
            throw UpdateError.signature(result.output)
        }
    }

    private static func run(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments

        // codesign says most of what it has to say on stderr; both streams go into one pipe.
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
