import Foundation

// Swift 5.7 (the newest compiler that runs on macOS 12) has no `MainActor.assumeIsolated`; it
// arrived with Swift 5.9. This does the same: it insists on the main thread, then runs the
// closure as if it were isolated to the main actor.
extension MainActor {
    static func assumeIsolated<T>(_ operation: @MainActor () throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .onQueue(.main))
        return try withoutActuallyEscaping(operation) { escaping in
            try unsafeBitCast(escaping, to: (() throws -> T).self)()
        }
    }
}
