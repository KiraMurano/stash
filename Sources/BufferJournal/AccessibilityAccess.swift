import AppKit
import ApplicationServices

/// Whether macOS lets Stash press ⌘V for the user (Accessibility access), and how to ask for it.
/// The app uses `live`; tests pass their own closures.
struct AccessibilityAccess: Sendable {
    var isGranted: @MainActor @Sendable () -> Bool
    var request: @MainActor @Sendable () -> Void

    static let live = AccessibilityAccess(
        isGranted: { AXIsProcessTrusted() },
        request: {
            // Asking puts Stash on the Accessibility list and shows the system prompt.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    )
}

/// Accessibility access as the panel sees it. Without access the panel shows the access screen;
/// while polling is on, the gate checks once a second until access appears.
@MainActor
final class AccessGate: ObservableObject {
    @Published private(set) var isGranted: Bool {
        didSet {
            if isGranted != oldValue {
                onChange?()
            }
        }
    }

    /// Called after `isGranted` changes.
    var onChange: (() -> Void)?
    private(set) var isPolling = false

    private let access: AccessibilityAccess
    private var timer: Timer?

    init(access: AccessibilityAccess = .live) {
        self.access = access
        isGranted = access.isGranted()
    }

    /// Reads the permission again and returns it. Polling stops once access is granted.
    @discardableResult
    func refresh() -> Bool {
        let granted = access.isGranted()
        // Assign only on change: every assignment would redraw the panel while polling.
        if granted != isGranted {
            isGranted = granted
        }
        if granted {
            setPolling(false)
        }
        return granted
    }

    func request() {
        access.request()
    }

    /// Checks once a second while on. There is nothing to wait for once access is granted.
    func setPolling(_ on: Bool) {
        let shouldPoll = on && !isGranted
        guard shouldPoll != isPolling else { return }
        isPolling = shouldPoll
        timer?.invalidate()
        timer = nil
        guard shouldPoll else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.refresh()
            }
        }
    }
}
