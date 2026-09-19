import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class JournalPanelController {
    private enum Constants {
        static let size = NSSize(
            width: JournalView.Layout.width + JournalView.Layout.gripMargin,
            height: JournalView.Layout.height + JournalView.Layout.gripMargin
        )
        static let savedOriginXKey = "JournalPanelOriginX"
        static let savedOriginYKey = "JournalPanelOriginY"
        static let savedWidthKey = "JournalPanelWidth"
        static let savedHeightKey = "JournalPanelHeight"
        static let minSize = NSSize(
            width: JournalView.Layout.minWidth + JournalView.Layout.gripMargin,
            height: JournalView.Layout.minHeight + JournalView.Layout.gripMargin
        )
    }

    private let store: ClipboardHistoryStore
    private let writer: ClipboardWriter
    private let settings: AppSettings
    private let keys: JournalKeys
    private var panel: NSPanel?
    private var textEditSessions: [ClipboardEntry.ID: TextEditWindowSession] = [:]
    private var isPanelVisible = false
    private var isMenuOpen = false
    private var activationObservers: [NSObjectProtocol] = []

    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, hotKeys: HotKeyController) {
        self.store = store
        self.writer = writer
        self.settings = settings
        keys = JournalKeys(hotKeys: hotKeys)

        // The clip editor activates Stash and needs the arrows, Return and Esc for itself.
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateKeys()
                }
            }
            activationObservers.append(observer)
        }
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
        // Never key: typing stays with the app under the panel; the journal's keys come as hotkeys.
        panel.orderFrontRegardless()
        isPanelVisible = true
        updateKeys()

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

        isPanelVisible = false
        updateKeys()
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

    /// The menu bar menu walks its items with the arrows, so the journal lets go of them meanwhile.
    func setMenuOpen(_ isOpen: Bool) {
        isMenuOpen = isOpen
        updateKeys()
    }

    private func updateKeys() {
        keys.isListening = JournalKeys.shouldListen(
            panelVisible: isPanelVisible,
            journalShown: true,
            stashActive: NSApp.isActive,
            menuOpen: isMenuOpen
        )
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let contentView = JournalView(
            store: store,
            settings: settings,
            keyEvents: keys.events,
            onPaste: { [weak self] entry in
                self?.paste(entry) ?? false
            },
            onCopy: { [weak self] entry in
                self?.copy(entry)
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
        // The view clips itself to the rounded panel; the transparent margin must stay unclipped for the grip.
        hostingView.layer?.masksToBounds = false
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
        panel.animationBehavior = .none
        panel.minSize = Constants.minSize
        // Stash stays inactive while the panel is open; without this its tooltips never show.
        panel.allowsToolTipsWhenApplicationIsInactive = true

        self.panel = panel
        return panel
    }

    /// Pastes the clip into the app under the panel and returns whether it did.
    func paste(_ entry: ClipboardEntry) -> Bool {
        perform { [writer] in writer.paste(entry) }
        return true
    }

    func copy(_ entry: ClipboardEntry) {
        perform { [writer] in writer.copy(entry) }
    }

    /// Runs a paste or copy, closing the panel first when Close After Selection is on.
    private func perform(_ action: @escaping @MainActor @Sendable () -> Void) {
        if settings.closeAfterSelection {
            close(completion: action)
        } else {
            action()
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

/// Never key: the keyboard stays with the app the user is typing in, even after a click.
private final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
