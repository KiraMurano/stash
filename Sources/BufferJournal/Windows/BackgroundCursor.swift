import Darwin
import Foundation

/// Lets Stash change the pointer while another app is frontmost. The journal never becomes key
/// and never activates Stash, and macOS ignores cursor changes from an app in the background —
/// so without this the resize cursors over the divider and the corner never show.
///
/// A private window server switch, looked up at run time: if a macOS release drops it, the
/// cursors stay plain and nothing else breaks.
enum BackgroundCursor {
    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    static func enable() {
        guard
            let connectionSymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_CGSDefaultConnection"),
            let propertySymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetConnectionProperty")
        else { return }

        let defaultConnection = unsafeBitCast(connectionSymbol, to: DefaultConnection.self)
        let setProperty = unsafeBitCast(propertySymbol, to: SetConnectionProperty.self)
        let connection = defaultConnection()
        _ = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }
}
