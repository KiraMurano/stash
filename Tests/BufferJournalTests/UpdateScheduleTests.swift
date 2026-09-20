import Foundation
import Testing
@testable import BufferJournal

struct UpdateScheduleTests {
    private func freshDefaults() -> UserDefaults {
        let name = "UpdateScheduleTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func automaticChecksAreOnForANewInstall() {
        #expect(UpdateSchedule(defaults: freshDefaults()).isAutomatic)
    }

    @Test func theChoiceMadeBeforeIsKept() {
        let defaults = freshDefaults()
        defaults.set(false, forKey: "CheckForUpdatesAutomatically")
        #expect(!UpdateSchedule(defaults: defaults).isAutomatic)
    }

    @Test func switchingItOffIsSaved() {
        let defaults = freshDefaults()
        let schedule = UpdateSchedule(defaults: defaults)
        schedule.isAutomatic = false
        #expect(defaults.bool(forKey: "CheckForUpdatesAutomatically") == false)
    }

    @Test func aCheckIsDueWhenThereHasNeverBeenOne() {
        #expect(UpdateSchedule(defaults: freshDefaults()).isDue(now: Date()))
    }

    @Test func aCheckIsNotDueWithinTheDay() {
        let schedule = UpdateSchedule(defaults: freshDefaults())
        let now = Date()
        schedule.lastCheck = now
        #expect(!schedule.isDue(now: now.addingTimeInterval(60 * 60)))
    }

    @Test func aCheckIsDueAfterTheDay() {
        let schedule = UpdateSchedule(defaults: freshDefaults())
        let now = Date()
        schedule.lastCheck = now
        #expect(schedule.isDue(now: now.addingTimeInterval(UpdateSchedule.interval + 1)))
    }

    @Test func aClockMovedBackwardsDoesNotLockChecksOut() {
        // Часы переставили назад: отметка из будущего не должна запереть проверки навсегда.
        let schedule = UpdateSchedule(defaults: freshDefaults())
        let now = Date()
        schedule.lastCheck = now.addingTimeInterval(10 * UpdateSchedule.interval)
        #expect(schedule.isDue(now: now))
    }

    @Test func switchedOffItIsNeverDue() {
        let schedule = UpdateSchedule(defaults: freshDefaults())
        schedule.isAutomatic = false
        #expect(!schedule.isDue(now: Date()))
    }
}
