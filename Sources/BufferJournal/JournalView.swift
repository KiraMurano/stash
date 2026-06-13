import AppKit
import SwiftUI

struct JournalView: View {
    private enum Layout {
        static let width: CGFloat = 380
        static let height: CGFloat = 400
        static let minWidth: CGFloat = 360
        static let minHeight: CGFloat = 360
        static let cornerRadius: CGFloat = 24
        static let headerHeight: CGFloat = 68
        static let contentInset: CGFloat = 16
        static let rowSpacing: CGFloat = 8
    }

    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var settings: AppSettings
    let onSelect: (ClipboardEntry) -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedID: ClipboardEntry.ID?
    @State private var previewEntry: ClipboardEntry?
    @State private var isClearConfirmationShown = false
    @State private var entryPendingDeletion: ClipboardEntry?
    @State private var isHeaderTrashHovered = false
    @State private var isHeaderCloseHovered = false
    @State private var toastMessage: String?
    @State private var toastToken = UUID()

    private var entries: [ClipboardEntry] {
        store.entries
    }

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            palette.windowBackground
            WindowDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if entries.isEmpty {
                emptyState
            } else {
                entriesList
            }

            header
                .frame(maxHeight: .infinity, alignment: .top)
                .zIndex(5)

            if isClearConfirmationShown || entryPendingDeletion != nil {
                ZStack {
                    GlassBackdrop(cornerRadius: Layout.cornerRadius, palette: palette)

                    DeleteConfirmationOverlay(
                        title: isClearConfirmationShown ? "Clear history?" : "Delete clip?",
                        message: isClearConfirmationShown ? "All saved clips will be removed." : "This clip will be removed.",
                        actionTitle: isClearConfirmationShown ? "Clear" : "Delete",
                        onCancel: {
                            isClearConfirmationShown = false
                            entryPendingDeletion = nil
                        },
                        onConfirm: {
                            if isClearConfirmationShown {
                                store.clear()
                                isClearConfirmationShown = false
                            } else if let entryPendingDeletion {
                                store.remove(entryPendingDeletion)
                                self.entryPendingDeletion = nil
                            }
                        }
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(20)
            }

            if
                let previewEntry,
                let previewImage = store.image(for: previewEntry)
            {
                ImagePreviewOverlay(
                    image: previewImage,
                    onPaste: {
                        select(previewEntry)
                    },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            self.previewEntry = nil
                        }
                    }
                )
                .transition(.opacity.animation(.easeOut(duration: 0.16)))
                .zIndex(25)
            }

            if let toastMessage {
                ToastOverlay(message: toastMessage)
                    .padding(.bottom, 18)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.width, minHeight: Layout.minHeight, idealHeight: Layout.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .onChange(of: entries) { entries in
            if let selectedID, !entries.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
        }
        .animation(.easeOut(duration: 0.16), value: selectedID)
        .animation(.easeOut(duration: 0.16), value: isClearConfirmationShown)
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Buffer Journal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .overlay(WindowDragHandle())

                Text("\(entries.count)/20")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .overlay(WindowDragHandle())
            }

            Spacer()

            HeaderIconButton(
                systemName: "trash",
                isHovered: isHeaderTrashHovered,
                palette: palette,
                action: {
                    isClearConfirmationShown = true
                }
            )
            .onHover { isHeaderTrashHovered = $0 }
            .help("Clear history")

            HeaderIconButton(
                systemName: "xmark",
                isHovered: isHeaderCloseHovered,
                palette: palette,
                action: onClose
            )
            .onHover { isHeaderCloseHovered = $0 }
            .help("Close")
        }
        .padding(.horizontal, Layout.contentInset)
        .frame(height: Layout.headerHeight)
        .background {
            ZStack {
                NativeGlassEffectView(style: .regular, cornerRadius: 0)
                WindowDragHandle()
            }
        }
    }

    private var entriesList: some View {
        ScrollView {
            ZStack(alignment: .top) {
                WindowDragHandle()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Layout.minHeight)

                VStack(spacing: Layout.rowSpacing) {
                    ForEach(entries) { entry in
                        ClipboardEntryRow(
                            entry: entry,
                            image: store.image(for: entry),
                            isSelected: selectedID == entry.id,
                            isCurrent: store.currentClipboardFingerprint == entry.fingerprint,
                            onPreviewImage: {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    previewEntry = entry
                                }
                            },
                            onDelete: {
                                entryPendingDeletion = entry
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            select(entry)
                        }
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, Layout.contentInset)
                .padding(.top, Layout.headerHeight + Layout.rowSpacing)
                .padding(.bottom, Layout.rowSpacing)
            }
        }
        .background(ScrollBarAppearanceSetter(colorScheme: colorScheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onMoveCommand { direction in
            moveSelection(direction)
        }
        .onSubmit {
            if let entry = entries.first(where: { $0.id == selectedID }) {
                select(entry)
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No saved clips")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragHandle())
    }

    private func select(_ entry: ClipboardEntry) {
        selectedID = entry.id
        showToast()
        onSelect(entry)
    }

    private func showToast() {
        guard !settings.closeAfterSelection else { return }

        let token = UUID()
        toastToken = token
        toastMessage = settings.pasteOnSelection ? "Pasted" : "Copied"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard toastToken == token else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                toastMessage = nil
            }
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !entries.isEmpty else { return }
        let currentIndex = entries.firstIndex { $0.id == selectedID } ?? 0

        switch direction {
        case .down:
            selectedID = entries[min(currentIndex + 1, entries.count - 1)].id
        case .up:
            selectedID = entries[max(currentIndex - 1, 0)].id
        default:
            break
        }
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let isHovered: Bool
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if systemName == "trash", isHovered {
            return .red.opacity(0.86)
        }

        return palette.iconOpacity(isHovered ? 0.82 : 0.52)
    }
}

private struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    let image: NSImage?
    let isSelected: Bool
    let isCurrent: Bool
    let onPreviewImage: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isDeleteHovered = false
    @State private var isExpandHovered = false
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(minHeight: rowHeight)
        .background {
            CardBackground(isSelected: isSelected, palette: palette)
        }
        .overlay(alignment: .topLeading) {
            if isCurrent {
                Image(systemName: "clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.iconOpacity(0.48))
                    .frame(width: 22, height: 22)
                    .padding(.top, 8)
                    .padding(.leading, 8)
                    .help("Current clipboard")
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDeleteHovered ? Color.red.opacity(0.86) : palette.iconOpacity(0.46))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .onHover { isDeleteHovered = $0 }
            .padding(.top, 8)
            .padding(.trailing, 8)
            .help("Delete clip")
        }
        .overlay(alignment: .bottom) {
            if canExpandText && !isExpanded {
                ExpandFadeOverlay(palette: palette)
                    .frame(height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if canExpandText {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.iconOpacity(isExpandHovered ? 0.78 : 0.50))
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .onHover { isExpandHovered = $0 }
                .padding(.trailing, 6)
                .padding(.bottom, 4)
                .help(isExpanded ? "Collapse clip" : "Expand clip")
            }
        }
        .shadow(color: palette.shadow(isHovered ? 0.10 : 0.06), radius: isHovered ? 10 : 6, y: isHovered ? 5 : 2)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.payload {
        case let .text(text):
            Text(previewText(text))
                .font(.system(size: 14, weight: .regular))
                .lineLimit(isExpanded ? nil : 3)
                .foregroundStyle(palette.textPrimary)
                .padding(.leading, isCurrent ? 18 : 0)
                .padding(.trailing, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

        case .image:
            if let image {
                Button(action: onPreviewImage) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: imageHeight)
                        .padding(.leading, isCurrent ? 18 : 0)
                        .padding(.trailing, 28)
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.placeholderBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .padding(.leading, isCurrent ? 18 : 0)
                    .padding(.trailing, 28)
            }
        }
    }

    private var rowHeight: CGFloat {
        switch entry.payload {
        case .text:
            62
        case .image:
            134
        }
    }

    private var imageHeight: CGFloat {
        118
    }

    private var canExpandText: Bool {
        guard case let .text(text) = entry.payload else {
            return false
        }

        let value = previewText(text)
        return value.contains("\n") || value.count > 135
    }

    private func previewText(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Empty text" : value
    }
}

private struct CardBackground: View {
    let isSelected: Bool
    let palette: ThemePalette

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? palette.borderSelected : palette.border, lineWidth: 1)
            )
    }
}

private struct ImagePreviewOverlay: View {
    let image: NSImage
    let onPaste: () -> Void
    let onClose: () -> Void

    @State private var isPasteHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            palette.modalBackground
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onTapGesture(perform: onClose)

            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture(perform: onClose)

            VStack {
                HStack {
                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(palette.iconOpacity(0.76))
                            .frame(width: 32, height: 32)
                            .background(palette.cardBackground, in: Circle())
                            .shadow(color: palette.shadow(0.10), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }

                Spacer()

                Button(action: onPaste) {
                    HStack(spacing: 8) {
                        Image(systemName: "clipboard")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Вставить")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(isPasteHovered ? palette.cardHoverBackground : palette.cardBackground, in: Capsule())
                    .shadow(color: palette.shadow(isPasteHovered ? 0.15 : 0.10), radius: isPasteHovered ? 16 : 11, y: 6)
                    .scaleEffect(isPasteHovered ? 1.015 : 1)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.18)) {
                        isPasteHovered = hovering
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GlassBackdrop: View {
    let cornerRadius: CGFloat
    let palette: ThemePalette

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .regular, cornerRadius: cornerRadius)
            palette.backdropTint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

private struct DeleteConfirmationOverlay: View {
    let title: String
    let message: String
    let actionTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmHovered = false
    @State private var isCancelHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(palette.controlHoverBackground.opacity(isCancelHovered ? 1 : 0.68), in: Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.14)) {
                        isCancelHovered = hovering
                    }
                }

                Button(action: onConfirm) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.red.opacity(isConfirmHovered ? 0.92 : 0.82), in: Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.14)) {
                        isConfirmHovered = hovering
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 270)
        .background(palette.modalBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.shadow(0.16), radius: 22, y: 10)
    }
}

private struct ToastOverlay: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(palette.modalBackground, in: Capsule())
            .overlay(Capsule().stroke(palette.borderSelected, lineWidth: 1))
            .shadow(color: palette.shadow(0.12), radius: 14, y: 6)
    }
}

private struct ExpandFadeOverlay: View {
    let palette: ThemePalette

    var body: some View {
        LinearGradient(
            colors: [
                Color.clear,
                palette.expandFadeColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct ThemePalette {
    let colorScheme: ColorScheme

    var isDark: Bool {
        colorScheme == .dark
    }

    var windowBackground: Color {
        isDark ? Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255) : Color(red: 0.965, green: 0.965, blue: 0.970)
    }

    var headerBackground: Color {
        isDark ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
    }

    var cardBackground: Color {
        isDark ? Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255) : Color.white
    }

    var cardHoverBackground: Color {
        isDark ? Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255) : Color(white: 0.965)
    }

    var modalBackground: Color {
        isDark ? Color(red: 0.145, green: 0.145, blue: 0.150) : Color.white
    }

    var backdropTint: Color {
        isDark ? Color.black.opacity(0.10) : Color.white.opacity(0.08)
    }

    var controlHoverBackground: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.055)
    }

    var placeholderBackground: Color {
        isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)
    }

    var textPrimary: Color {
        isDark ? Color.white.opacity(0.90) : Color.black.opacity(0.86)
    }

    var textSecondary: Color {
        isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.58)
    }

    var textTertiary: Color {
        isDark ? Color.white.opacity(0.38) : Color.black.opacity(0.38)
    }

    var border: Color {
        isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.10)
    }

    var borderSelected: Color {
        isDark ? Color.white.opacity(0.32) : Color.black.opacity(0.24)
    }

    var separator: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    var expandFadeColor: Color {
        isDark ? cardBackground.opacity(0.94) : cardBackground.opacity(0.94)
    }

    func iconOpacity(_ opacity: Double) -> Color {
        isDark ? Color.white.opacity(opacity) : Color.black.opacity(opacity)
    }

    func shadow(_ opacity: Double) -> Color {
        Color.black.opacity(isDark ? opacity * 1.45 : opacity)
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragHandleView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragHandleView: NSView {
        override var mouseDownCanMoveWindow: Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct ScrollBarAppearanceSetter: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.postsFrameChangedNotifications = false
        DispatchQueue.main.async {
            applyAppearance(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyAppearance(from: nsView)
        }
    }

    private func applyAppearance(from view: NSView) {
        guard let scrollView = scrollView(containing: view) else {
            return
        }

        let scrollerAppearanceName: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
        let scrollerAppearance = NSAppearance(named: scrollerAppearanceName)
        let knobStyle: NSScroller.KnobStyle = colorScheme == .dark ? .dark : .light
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.appearance = scrollerAppearance
        scrollView.horizontalScroller?.appearance = scrollerAppearance
        scrollView.verticalScroller?.knobStyle = knobStyle
        scrollView.horizontalScroller?.knobStyle = knobStyle
    }

    private func scrollView(containing view: NSView) -> NSScrollView? {
        if let scrollView = view.enclosingScrollView {
            return scrollView
        }

        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = firstScrollView(in: current) {
                return scrollView
            }
            ancestor = current.superview
        }

        if let contentView = view.window?.contentView {
            return firstScrollView(in: contentView)
        }

        return nil
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }

        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) {
                return scrollView
            }
        }

        return nil
    }
}
