import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class JournalPanelController {
    private enum Constants {
        static let size = NSSize(width: 430, height: 470)
        static let cornerRadius: CGFloat = 28
        static let savedOriginXKey = "JournalPanelOriginX"
        static let savedOriginYKey = "JournalPanelOriginY"
        static let savedWidthKey = "JournalPanelWidth"
        static let savedHeightKey = "JournalPanelHeight"
        static let minSize = NSSize(width: 360, height: 360)
    }

    private let store: ClipboardHistoryStore
    private let writer: ClipboardWriter
    private let settings: AppSettings
    private var panel: NSPanel?

    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings) {
        self.store = store
        self.writer = writer
        self.settings = settings
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        let panel = makePanelIfNeeded()
        positionIfNeeded(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func close(completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let panel, panel.isVisible else {
            completion?()
            return
        }

        savePosition(panel)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.055
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
                completion?()
            }
        }
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let contentView = JournalView(
            store: store,
            settings: settings,
            onSelect: { [weak self] entry in
                self?.handleSelection(entry)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hostingView = FirstMouseHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = Constants.cornerRadius
        hostingView.layer?.cornerCurve = CALayerCornerCurve.continuous
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.borderWidth = 0

        let panel = JournalPanel(
            contentRect: NSRect(origin: .zero, size: savedSize ?? Constants.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = Constants.minSize

        self.panel = panel
        return panel
    }

    private func handleSelection(_ entry: ClipboardEntry) {
        let performSelection: @MainActor @Sendable () -> Void = { [writer, settings] in
            if settings.pasteOnSelection {
                writer.paste(entry)
            } else {
                writer.copy(entry)
            }
        }

        if settings.closeAfterSelection {
            close(completion: performSelection)
        } else {
            performSelection()
        }
    }

    private func positionIfNeeded(_ panel: NSPanel) {
        if let savedOrigin = savedOrigin {
            panel.setFrameOrigin(validOrigin(savedOrigin, for: panel))
            return
        }

        guard let screen = NSScreen.main else {
            panel.center()
            return
        }

        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = frame.midX - panelSize.width / 2
        let y = frame.midY - panelSize.height / 2 + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private var savedOrigin: NSPoint? {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: Constants.savedOriginXKey) != nil,
            defaults.object(forKey: Constants.savedOriginYKey) != nil
        else {
            return nil
        }

        return NSPoint(
            x: defaults.double(forKey: Constants.savedOriginXKey),
            y: defaults.double(forKey: Constants.savedOriginYKey)
        )
    }

    private func savePosition(_ panel: NSPanel) {
        UserDefaults.standard.set(panel.frame.origin.x, forKey: Constants.savedOriginXKey)
        UserDefaults.standard.set(panel.frame.origin.y, forKey: Constants.savedOriginYKey)
        UserDefaults.standard.set(panel.frame.width, forKey: Constants.savedWidthKey)
        UserDefaults.standard.set(panel.frame.height, forKey: Constants.savedHeightKey)
    }

    private var savedSize: NSSize? {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: Constants.savedWidthKey) != nil,
            defaults.object(forKey: Constants.savedHeightKey) != nil
        else {
            return nil
        }

        return NSSize(
            width: max(defaults.double(forKey: Constants.savedWidthKey), Constants.minSize.width),
            height: max(defaults.double(forKey: Constants.savedHeightKey), Constants.minSize.height)
        )
    }

    private func validOrigin(_ origin: NSPoint, for panel: NSPanel) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(NSRect(origin: origin, size: panel.frame.size)) }) ?? NSScreen.main else {
            return origin
        }

        let visibleFrame = screen.visibleFrame
        let x = min(max(origin.x, visibleFrame.minX + 12), visibleFrame.maxX - panel.frame.width - 12)
        let y = min(max(origin.y, visibleFrame.minY + 12), visibleFrame.maxY - panel.frame.height - 12)
        return NSPoint(x: x, y: y)
    }
}

private final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
