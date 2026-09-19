import Combine
import Foundation

/// The tutorial's state: whether it is on screen, which slides this showing has and which one is
/// current. It also remembers that the person has seen it, and shows the access slide on its own
/// when the tutorial was seen but Stash still may not paste.
@MainActor
final class OnboardingController: ObservableObject {
    /// Bump to show the tutorial to everyone again after a big update.
    static let currentVersion = 1
    static let seenVersionKey = "OnboardingSeenVersion"

    @Published private(set) var isPresented = false
    @Published private(set) var slides: [OnboardingSlide] = OnboardingSlides.slides(hasAccess: true)
    @Published private(set) var index = 0
    /// Grows each time a slide is entered or the panel shows again; scenes restart on a change.
    @Published private(set) var run = 0
    /// A showing opened from the menu does not mark the tutorial as seen.
    private(set) var isReplay = false
    /// The access slide alone: no progress bars, and the bottom button opens System Settings.
    private(set) var isAccessOnly = false

    private let defaults: UserDefaults
    private let access: AccessGate

    init(defaults: UserDefaults = .standard, access: AccessGate) {
        self.defaults = defaults
        self.access = access
    }

    var shouldShowOnLaunch: Bool {
        defaults.integer(forKey: Self.seenVersionKey) < Self.currentVersion
    }

    var slide: OnboardingSlide {
        slides[index]
    }

    var isLast: Bool {
        index == slides.count - 1
    }

    /// Opens the tutorial on its first slide. The slide set is taken here and stays fixed until it
    /// closes, so a permission granted midway does not move the ground under the person.
    func present(replay: Bool) {
        if isPresented, !isAccessOnly {
            // The menu item during the first showing restarts it; closing still marks it seen.
            isReplay = isReplay && replay
        } else {
            isReplay = replay
            isAccessOnly = false
            slides = OnboardingSlides.slides(hasAccess: access.isGranted)
            isPresented = true
        }
        index = 0
        run += 1
    }

    /// The access slide on its own: the tutorial was seen, but Stash has no Accessibility access.
    /// With access there is nothing to ask for.
    func presentAccessOnly() {
        guard !access.isGranted else { return }
        isReplay = false
        isAccessOnly = true
        slides = [OnboardingSlides.accessSlide]
        isPresented = true
        index = 0
        run += 1
    }

    func next() {
        guard isPresented, index < slides.count - 1 else { return }
        index += 1
        run += 1
    }

    func back() {
        guard isPresented, index > 0 else { return }
        index -= 1
        run += 1
    }

    /// The bottom button: "Next", "Start" on the last slide, "Open Settings" on the lone access screen.
    func primaryAction() {
        if isAccessOnly {
            requestAccess()
        } else if isLast {
            close()
        } else {
            next()
        }
    }

    func close() {
        guard isPresented else { return }
        isPresented = false
        // A replay from the menu and the lone access screen record nothing.
        if !isReplay, !isAccessOnly {
            defaults.set(Self.currentVersion, forKey: Self.seenVersionKey)
        }
        isAccessOnly = false
    }

    /// The panel showed again: the current scene starts over.
    func restartScene() {
        guard isPresented else { return }
        run += 1
    }

    /// Asks macOS for Accessibility access; the panel drops to the normal window level on its own,
    /// so it does not cover System Settings.
    func requestAccess() {
        access.request()
    }

    /// Keys while the tutorial is open: Return goes on ("Start" on the last slide), Escape closes
    /// the tutorial but not the panel. Up and Down are none of the tutorial's business — they stay
    /// with the journal. The access slide has no keys at all: Return and Escape belong to System
    /// Settings, where the person is headed, and that slide is turned with the mouse and buttons.
    func handleKey(_ key: JournalKey) -> Bool {
        guard isPresented, !isAccessOnly, slide.kind != .access else { return false }
        switch key {
        case .enter:
            primaryAction()
            return true
        case .escape:
            close()
            return true
        case .up, .down:
            return false
        }
    }
}
