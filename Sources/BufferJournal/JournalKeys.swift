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
