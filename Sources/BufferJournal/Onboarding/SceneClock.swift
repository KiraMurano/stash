import SwiftUI

/// Runs a scene: plays it from the moment it appears and loops it, or holds its stop frame.
struct SceneClock<Content: View>: View {
    let duration: Double
    let loops: Bool
    /// Stop frame only: "reduce motion", or the access slide once access is granted.
    let still: Bool
    @ViewBuilder let content: (SceneTime) -> Content

    @Environment(\.scenesHoldStopFrame) private var holdStopFrame
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        if still || finished || holdStopFrame {
            content(.end(of: duration))
        } else {
            TimelineView(.animation) { context in
                content(SceneLoop.time(elapsed: context.date.timeIntervalSince(start), duration: duration, loops: loops))
            }
            .task {
                // A scene that plays once stops asking for frames when it is done.
                guard !loops else { return }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                finished = true
            }
        }
    }
}

private struct HoldStopFrameKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Snapshot tests set it to see each scene's stop frame instead of its first frame.
    var scenesHoldStopFrame: Bool {
        get { self[HoldStopFrameKey.self] }
        set { self[HoldStopFrameKey.self] = newValue }
    }
}
