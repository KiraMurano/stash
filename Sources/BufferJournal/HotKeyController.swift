import Carbon
import Foundation

/// Global hotkeys through the Carbon hotkey API: ⌥V for the journal, and the journal's own keys
/// while it is open. macOS hands a registered key to Stash instead of the frontmost app.
@MainActor
final class HotKeyController {
    struct Registration: Hashable {
        fileprivate let id: UInt32
    }

    private struct Handler {
        let ref: EventHotKeyRef
        let onPress: () -> Void
        let onRelease: (() -> Void)?
    }

    private static let signature = OSType("BJRN".fourCharCode)

    private var eventHandler: EventHandlerRef?
    private var handlers: [UInt32: Handler] = [:]
    private var nextID: UInt32 = 1

    /// Installs one Carbon handler for hotkey presses and releases; call once at launch.
    func install() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased)),
        ]

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let id = hotKeyID.id
                let isPress = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                nonisolated(unsafe) let pointer = userData
                // Carbon delivers hotkey events on the main thread.
                return MainActor.assumeIsolated {
                    let controller = Unmanaged<HotKeyController>.fromOpaque(pointer).takeUnretainedValue()
                    return controller.handle(id: id, isPress: isPress) ? noErr : OSStatus(eventNotHandledErr)
                }
            },
            eventTypes.count,
            &eventTypes,
            // Unretained: AppDelegate keeps the controller for the life of the app.
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            NSLog("BufferJournal: failed to install hotkey handler: \(status)")
        }
    }

    /// Registers a global hotkey. Returns nil, and logs, when macOS refuses the combination.
    @discardableResult
    func register(
        keyCode: UInt32,
        modifiers: UInt32,
        onPress: @escaping () -> Void,
        onRelease: (() -> Void)? = nil
    ) -> Registration? {
        // Without the handler a registered key would be taken from other apps and dropped.
        guard eventHandler != nil else { return nil }

        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            NSLog("BufferJournal: failed to register hotkey \(keyCode) with modifiers \(modifiers): \(status)")
            return nil
        }

        handlers[id] = Handler(ref: ref, onPress: onPress, onRelease: onRelease)
        return Registration(id: id)
    }

    func unregister(_ registration: Registration) {
        guard let handler = handlers.removeValue(forKey: registration.id) else { return }
        UnregisterEventHotKey(handler.ref)
    }

    private func handle(id: UInt32, isPress: Bool) -> Bool {
        guard let handler = handlers[id] else { return false }
        if isPress {
            handler.onPress()
        } else {
            handler.onRelease?()
        }
        return true
    }
}

private extension String {
    var fourCharCode: UInt32 {
        utf8.reduce(0) { result, character in
            (result << 8) + UInt32(character)
        }
    }
}
