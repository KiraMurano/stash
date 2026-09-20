import AppKit
import Combine
import Foundation

/// The whole of updating, as a handful of states the screen and the menu read.
///
/// The first check waits for the app to settle: on the very first launch that means the tour has
/// been walked through and Accessibility access is granted, so nothing competes with getting
/// started. After that it is once a day, and the menu can ask at any time.
@MainActor
final class UpdateController: ObservableObject {
    /// The release itself is kept beside the state, not inside it: downloading, installing and
    /// failed all still need to name the version and its notes.
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case downloading(Double)
        case installing
        case failed(UpdateError)
    }

    static let releasesPage = URL(string: "https://github.com/KiraMurano/stash/releases")!
    private static let seenVersionKey = "SeenUpdateVersion"

    @Published private(set) var state: State
    @Published private(set) var release: Release?
    @Published private(set) var isPresented = false
    private(set) var isArmed = false

    private let environment: UpdateEnvironment
    private let checker: any UpdateChecking
    private let downloader: any UpdateDownloading
    private let defaults: UserDefaults
    private let schedule: UpdateSchedule
    private let now: () -> Date
    private let isReady: @MainActor () -> Bool
    private let installStep: @MainActor (URL) throws -> Void
    private let quit: @MainActor () -> Void
    private var timers: [Timer] = []

    init(
        environment: UpdateEnvironment,
        checker: any UpdateChecking,
        downloader: any UpdateDownloading,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        isReady: @escaping @MainActor () -> Bool,
        install: (@MainActor (URL) throws -> Void)? = nil,
        quit: @escaping @MainActor () -> Void = { NSApp.terminate(nil) },
        // The snapshots put the screen straight into a state; the app leaves both alone.
        release: Release? = nil,
        state: State = .idle
    ) {
        self.release = release
        self.state = state
        self.environment = environment
        self.checker = checker
        self.downloader = downloader
        self.defaults = defaults
        self.schedule = UpdateSchedule(defaults: defaults)
        self.now = now
        self.isReady = isReady
        // By default the image is verified here, while the app is still on screen and can say so;
        // the install script checks it again once the app is gone.
        self.installStep = install ?? { dmg in
            if let requirement = environment.requirement {
                try Codesign.verify(dmg, requirement: requirement, deep: false)
            }
            try UpdateInstaller.launch(dmg: dmg, environment: environment)
        }
        self.quit = quit
    }

    // MARK: What the menu and the screen read

    var canSelfUpdate: Bool {
        environment.canSelfUpdate
    }

    var currentVersion: AppVersion? {
        environment.currentVersion
    }

    var isAutomatic: Bool {
        get { schedule.isAutomatic }
        set {
            objectWillChange.send()
            schedule.isAutomatic = newValue
        }
    }

    /// The orange dot on the status item: a release is waiting and its screen has not been opened.
    var isBadgeVisible: Bool {
        guard let release else { return false }
        return defaults.string(forKey: Self.seenVersionKey) != release.version.description
    }

    // MARK: Checking

    /// Called at launch, when access changes and when the tour closes. It arms the timers once
    /// per session, and only when the app has nothing more pressing to show.
    func armIfReady() {
        guard !isArmed, canSelfUpdate, schedule.isAutomatic, isReady() else { return }
        isArmed = true

        timers.append(Timer.scheduledTimer(withTimeInterval: UpdateSchedule.launchDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: UpdateSchedule.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        })
    }

    private func checkIfDue() {
        guard schedule.isDue(now: now()) else { return }
        Task { await check(manual: false) }
    }

    /// The menu item.
    func checkNow() {
        Task { await check(manual: true) }
    }

    func check(manual: Bool) async {
        guard canSelfUpdate else { return }
        // A check while something is already happening would throw that away.
        switch state {
        case .idle, .upToDate, .available, .failed: break
        case .checking, .downloading, .installing: return
        }

        state = .checking
        schedule.lastCheck = now()

        do {
            let latest = try await checker.latestRelease()
            if let latest, environment.isNewer(latest) {
                release = latest
                state = .available
            } else {
                release = nil
                state = .upToDate
            }
        } catch let error as UpdateError {
            // An automatic check that failed says nothing: the next one is in a day.
            state = manual ? .failed(error) : .idle
        } catch {
            state = manual ? .failed(.network) : .idle
        }
    }

    // MARK: The screen

    /// Opening the screen counts as having seen this version, so the dot goes out even if the
    /// answer is "Later".
    func present() {
        if let release {
            defaults.set(release.version.description, forKey: Self.seenVersionKey)
        }
        isPresented = true
    }

    func close() {
        isPresented = false
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(Self.releasesPage)
    }

    // MARK: Installing

    func install() {
        Task { await runInstall() }
    }

    func runInstall() async {
        guard let release else { return }
        guard environment.isDestinationWritable else {
            state = .failed(.notWritable)
            return
        }

        state = .downloading(0)

        do {
            let dmg = try await downloader.download(release) { [weak self] progress in
                Task { @MainActor in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(progress)
                }
            }
            state = .installing
            try installStep(dmg)
            quit()
        } catch let error as UpdateError {
            state = .failed(error)
        } catch {
            state = .failed(.network)
        }
    }
}
