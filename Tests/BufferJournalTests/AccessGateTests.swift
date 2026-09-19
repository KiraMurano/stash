import Testing
@testable import BufferJournal

/// Stand-in for the system permission.
@MainActor
private final class FakeAccess {
    var granted = false
    var requests = 0

    var access: AccessibilityAccess {
        AccessibilityAccess(
            isGranted: { [unowned self] in granted },
            request: { [unowned self] in requests += 1 }
        )
    }
}

@MainActor
struct AccessGateTests {
    @Test func readsThePermissionWhenCreated() {
        let fake = FakeAccess()
        fake.granted = true
        #expect(AccessGate(access: fake.access).isGranted)
    }

    @Test func refreshPicksUpAGrant() {
        let fake = FakeAccess()
        let gate = AccessGate(access: fake.access)
        var changes = 0
        gate.onChange = { changes += 1 }
        #expect(!gate.isGranted)

        fake.granted = true
        #expect(gate.refresh())
        #expect(gate.isGranted)
        #expect(changes == 1)

        gate.refresh()
        #expect(changes == 1)
    }

    @Test func requestAsksTheSystem() {
        let fake = FakeAccess()
        AccessGate(access: fake.access).request()
        #expect(fake.requests == 1)
    }

    @Test func doesNotPollWithAccess() {
        let fake = FakeAccess()
        fake.granted = true
        let gate = AccessGate(access: fake.access)
        gate.setPolling(true)
        #expect(!gate.isPolling)
    }

    @Test func stopsPollingOnceAccessAppears() {
        let fake = FakeAccess()
        let gate = AccessGate(access: fake.access)
        gate.setPolling(true)
        #expect(gate.isPolling)

        fake.granted = true
        gate.refresh()
        #expect(!gate.isPolling)
    }

    @Test func stopsPollingWhenTurnedOff() {
        let fake = FakeAccess()
        let gate = AccessGate(access: fake.access)
        gate.setPolling(true)
        gate.setPolling(false)
        #expect(!gate.isPolling)
    }
}
