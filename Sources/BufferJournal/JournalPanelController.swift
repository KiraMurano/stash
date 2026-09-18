import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class JournalPanelController {
    private enum Constants {
        static let size = NSSize(width: JournalView.Layout.width, height: JournalView.Layout.height)
        static let cornerRadius: CGFloat = 28
        static let savedOriginXKey = "JournalPanelOriginX"
        static let savedOriginYKey = "JournalPanelOriginY"
        static let savedWidthKey = "JournalPanelWidth"
        static let savedHeightKey = "JournalPanelHeight"
        static let minSize = NSSize(width: JournalView.Layout.minWidth, height: JournalView.Layout.minHeight)
    }

    private let store: ClipboardHistoryStore
    private let writer: ClipboardWriter
    private let settings: AppSettings
    private var panel: NSPanel?
    private var textEditSessions: [ClipboardEntry.ID: TextEditWindowSession] = [:]

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
            onEditText: { [weak self] entry in
                self?.openTextEditor(for: entry)
            },
            onPreviewImage: { [weak self] entry in
                self?.openImagePreview(for: entry)
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
        hostingView.layer?.borderColor = nil
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

    private func openTextEditor(for entry: ClipboardEntry) {
        guard case let .text(text) = entry.payload else { return }

        if let session = textEditSessions[entry.id] {
            NSApp.activate(ignoringOtherApps: true)
            session.window.makeKeyAndOrderFront(nil)
            return
        }

        let view = ClipboardTextEditorView(
            title: entry.title(settings.l10n),
            initialText: text,
            settings: settings,
            onCancel: { [weak self] in
                self?.closeTextEditor(for: entry.id)
            },
            onSave: { [weak self] editedText in
                guard let self else { return }
                if store.updateText(for: entry, to: editedText) {
                    closeTextEditor(for: entry.id)
                }
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = settings.l10n("Edit Clip", "Редактирование")
        window.contentView = hostingView
        window.minSize = NSSize(width: 420, height: 260)
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = TextEditWindowDelegate { [weak self] in
            self?.textEditSessions[entry.id] = nil
        }
        window.delegate = delegate
        textEditSessions[entry.id] = TextEditWindowSession(window: window, delegate: delegate)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens the stored image in macOS Preview; falls back to the default app for PNG.
    private func openImagePreview(for entry: ClipboardEntry) {
        guard let url = store.imageURL(for: entry) else { return }

        let workspace = NSWorkspace.shared
        guard let previewURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            workspace.open(url)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open([url], withApplicationAt: previewURL, configuration: configuration)
    }

    private func closeTextEditor(for id: ClipboardEntry.ID) {
        guard let session = textEditSessions[id] else { return }
        session.window.close()
        textEditSessions[id] = nil
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

        let width = defaults.double(forKey: Constants.savedWidthKey)
        let height = defaults.double(forKey: Constants.savedHeightKey)

        // Sizes saved by the old single-column panel are too narrow for the split layout.
        if width < Constants.minSize.width {
            return Constants.size
        }

        return NSSize(
            width: max(width, Constants.minSize.width),
            height: max(height, Constants.minSize.height)
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
