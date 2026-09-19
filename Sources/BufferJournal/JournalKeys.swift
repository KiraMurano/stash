import AppKit
import Carbon
import Combine

/// Keys the journal takes while it is open: plain Up, Down, Return (or keypad Enter) and Escape.
enum JournalKey: Equatable {
    case up
    case down
    case enter
    case escape
}

/// What the journal does with a key, given what is on screen.
enum JournalKeyAction: Equatable {
    case moveUp
    case moveDown
    case paste
    case closeDialog
    case closePanel
    case ignore

    /// A confirmation dialog takes Escape and nothing else; Return pastes only a selected clip.
    static func resolve(_ key: JournalKey, dialogShown: Bool, hasSelection: Bool) -> JournalKeyAction {
        if dialogShown {
            return key == .escape ? .closeDialog : .ignore
        }

        switch key {
        case .up: return .moveUp
        case .down: return .moveDown
        case .enter: return hasSelection ? .paste : .ignore
        case .escape: return .closePanel
        }
    }
}

/// The journal's hotkeys. While listening, plain Up, Down, Return, keypad Enter and Escape are
/// registered as global hotkeys, so macOS hands them to Stash instead of the app under the panel.
/// macOS swallows the auto-repeats of a held hotkey, so Up and Down repeat on a timer at the
/// system key-repeat rate.
@MainActor
final class JournalKeys {
    /// Listen only while Intercept Keys is on, the journal is on screen, Stash is not the active
    /// app (its clip editor needs these keys) and no menu of Stash is open (menus are walked with
    /// the arrows). Turned off, every key stays with the app the user is typing in.
    nonisolated static func shouldListen(intercepts: Bool, panelVisible: Bool, journalShown: Bool, stashActive: Bool, menuOpen: Bool) -> Bool {
        intercepts && panelVisible && journalShown && !stashActive && !menuOpen
    }

    let events = PassthroughSubject<JournalKey, Never>()

    var isListening = false {
        didSet {
            guard isListening != oldValue else { return }
            if isListening {
                register()
            } else {
                unregister()
            }
        }
    }

    private static let bindings: [(keyCode: Int, key: JournalKey)] = [
        (kVK_UpArrow, .up),
        (kVK_DownArrow, .down),
        (kVK_Return, .enter),
        (kVK_ANSI_KeypadEnter, .enter),
        (kVK_Escape, .escape),
    ]

    private let hotKeys: HotKeyController
    private var registrations: [HotKeyController.Registration] = []
    private var heldKey: JournalKey?
    private var repeatTimer: Timer?

    init(hotKeys: HotKeyController) {
        self.hotKeys = hotKeys
    }

    private func register() {
        for binding in Self.bindings {
            let key = binding.key
            let registration = hotKeys.register(
                keyCode: UInt32(binding.keyCode),
                modifiers: 0,
                onPress: { [weak self] in self?.press(key) },
                onRelease: { [weak self] in self?.release(key) }
            )
            if let registration {
                registrations.append(registration)
            }
        }
    }

    private func unregister() {
        registrations.forEach { hotKeys.unregister($0) }
        registrations = []
        stopRepeating()
    }

    private func press(_ key: JournalKey) {
        // The held key already repeats on the timer.
        guard heldKey != key else { return }
        stopRepeating()
        events.send(key)

        guard key == .up || key == .down else { return }
        heldKey = key
        repeatTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.keyRepeatDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startRepeating(key)
            }
        }
    }

    private func startRepeating(_ key: JournalKey) {
        guard heldKey == key else { return }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.keyRepeatInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.events.send(key)
            }
        }
    }

    private func release(_ key: JournalKey) {
        guard heldKey == key else { return }
        stopRepeating()
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        heldKey = nil
    }
}
