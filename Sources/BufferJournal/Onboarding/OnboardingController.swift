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
    @Published private(set) var slides: [OnboardingSlide] = OnboardingSlides.all
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

    /// Opens the tutorial on its first slide.
    func present(replay: Bool) {
        if isPresented, !isAccessOnly {
            // The menu item during the first showing restarts it; closing still marks it seen.
            isReplay = isReplay && replay
        } else {
            isReplay = replay
            isAccessOnly = false
            slides = OnboardingSlides.all
            isPresented = true
        }
        index = 0
        run += 1
    }

    /// The access screen: Stash has no Accessibility access, so there is no journal to show.
    /// It is never part of the tour — with access there is nothing to ask for.
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
        // A replay from the menu and the access screen record nothing.
        if !isReplay, !isAccessOnly {
            defaults.set(Self.currentVersion, forKey: Self.seenVersionKey)
        }
        // Without access there is no journal to fall back to: the tour hands over to the access
        // screen, the same screen the panel puts up on its own later.
        if !isAccessOnly, !access.isGranted {
            presentAccessOnly()
            return
        }
        isPresented = false
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

}
