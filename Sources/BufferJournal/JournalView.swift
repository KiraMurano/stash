import AppKit
import SwiftUI

struct JournalView: View {
    private enum Layout {
        static let width: CGFloat = 380
        static let height: CGFloat = 400
        static let minWidth: CGFloat = 360
        static let minHeight: CGFloat = 360
        static let cornerRadius: CGFloat = 24
        static let headerTopPadding: CGFloat = 14
        static let headerTitleBlockHeight: CGFloat = 32
        static let tabSectionSpacing: CGFloat = 10
        static let tabButtonHeight: CGFloat = 28
        static let contentInset: CGFloat = 16
        static let rowSpacing: CGFloat = 8

        static var tabBarHeight: CGFloat {
            tabSectionSpacing + tabButtonHeight + tabSectionSpacing
        }

        static var topChromeHeight: CGFloat {
            headerTopPadding + headerTitleBlockHeight + tabBarHeight
        }
    }

    private enum EntryFilter: CaseIterable, Identifiable {
        case all
        case text
        case media
        case files

        var id: Self { self }

        var title: String {
            switch self {
            case .all: "Все"
            case .text: "Текст"
            case .media: "Медиа"
            case .files: "Файлы"
            }
        }
    }

    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var settings: AppSettings
    let onSelect: (ClipboardEntry) -> Void
    let onEditText: (ClipboardEntry) -> Void
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
    @State private var selectedFilter: EntryFilter = .all
    @State private var tabBarIntrinsicWidth: CGFloat = 0
    @State private var draggedPinnedEntryID: ClipboardEntry.ID?
    @State private var draggedPinnedStartY: CGFloat?
    @State private var draggedPinnedListTopY: CGFloat?
    @State private var draggedPinnedTranslation: CGFloat = 0
    @State private var rowFrames: [ClipboardEntry.ID: CGRect] = [:]

    private var filteredEntries: [ClipboardEntry] {
        switch selectedFilter {
        case .all:
            store.entries
        case .text:
            store.entries.filter(\.isText)
        case .media:
            store.entries.filter(\.isImage)
        case .files:
            store.entries.filter(\.isFile)
        }
    }

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .regular, cornerRadius: Layout.cornerRadius)
            palette.windowTint
            WindowDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if filteredEntries.isEmpty {
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
                        message: isClearConfirmationShown ? "Unpinned clips will be removed. Pinned clips stay saved." : "This clip will be removed.",
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
        .onChange(of: filteredEntries) { entries in
            if let selectedID, !entries.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
        }
        .onChange(of: selectedFilter) { _ in
            if let selectedID, !filteredEntries.contains(where: { $0.id == selectedID }) {
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
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Buffer Journal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .overlay(WindowDragHandle())

                    Text("\(store.entries.count)/20")
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
            .padding(.top, Layout.headerTopPadding)

            filterTabs
                .padding(.top, Layout.tabSectionSpacing)
                .padding(.bottom, Layout.tabSectionSpacing)
        }
        .background {
            ZStack {
                NativeGlassEffectView(style: .regular, cornerRadius: 0)
                WindowDragHandle()
            }
        }
    }

    private var filterTabs: some View {
        GeometryReader { geometry in
            let shouldStretch = tabBarIntrinsicWidth > 0 && tabBarIntrinsicWidth <= geometry.size.width

            Group {
                if shouldStretch {
                    tabButtonsRow(expanded: true)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        tabButtonsRow(expanded: false)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(
                tabButtonsRow(expanded: false)
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TabBarWidthPreferenceKey.self,
                                value: proxy.size.width
                            )
                        }
                    )
            )
        }
        .frame(height: Layout.tabButtonHeight)
        .onPreferenceChange(TabBarWidthPreferenceKey.self) { width in
            tabBarIntrinsicWidth = width
        }
    }

    private func tabButtonsRow(expanded: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(EntryFilter.allCases) { filter in
                FilterTabButton(
                    title: filter.title,
                    isSelected: selectedFilter == filter,
                    isExpanded: expanded,
                    palette: palette
                ) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selectedFilter = filter
                    }
                }
            }
        }
        .padding(.horizontal, Layout.contentInset)
    }

    private var entriesList: some View {
        ScrollView {
            ZStack(alignment: .top) {
                WindowDragHandle()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Layout.minHeight)

                VStack(spacing: Layout.rowSpacing) {
                    ForEach(filteredEntries) { entry in
                        entryRow(entry)
                        .contentShape(Rectangle())
                        .background(entryFrameReader(for: entry.id))
                        .opacity(draggedPinnedEntryID == entry.id ? 0 : 1)
                        .zIndex(entry.isPinned ? 1 : 0)
                        .highPriorityGesture(pinnedDragGesture(for: entry))
                        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: filteredEntries.map(\.id))
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, Layout.contentInset)
                .padding(.top, Layout.topChromeHeight + Layout.rowSpacing)
                .padding(.bottom, Layout.rowSpacing)

                if let draggedPinnedEntry {
                    entryRow(draggedPinnedEntry, isDragging: true)
                        .padding(.horizontal, Layout.contentInset)
                        .offset(y: floatingDragY)
                        .scaleEffect(1.025)
                        .shadow(color: palette.shadow(0.14), radius: 16, y: 8)
                        .allowsHitTesting(false)
                        .zIndex(20)
                        .transition(.identity)
                }
            }
            .coordinateSpace(name: "entriesList")
        }
        .background(ScrollBarAppearanceSetter(colorScheme: colorScheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(EntryFramePreferenceKey.self) { frames in
            rowFrames = frames
        }
        .onMoveCommand { direction in
            moveSelection(direction)
        }
        .onSubmit {
            if let entry = filteredEntries.first(where: { $0.id == selectedID }) {
                select(entry)
            }
        }
    }

    private func entryRow(_ entry: ClipboardEntry, isDragging: Bool = false) -> some View {
        ClipboardEntryRow(
            entry: entry,
            image: store.image(for: entry),
            fileIcon: store.fileIcon(for: entry),
            isSelected: selectedID == entry.id,
            isCurrent: store.currentClipboardFingerprint == entry.fingerprint,
            isPinLimitReached: !entry.isPinned && store.entries.filter(\.isPinned).count >= 10,
            isDragging: isDragging,
            onSelect: {
                select(entry)
            },
            onPreviewImage: {
                withAnimation(.easeOut(duration: 0.16)) {
                    previewEntry = entry
                }
            },
            onEditText: {
                onEditText(entry)
            },
            onTogglePin: {
                if !store.togglePin(entry) {
                    showToast("Максимум 10 закрепов")
                }
            },
            onDelete: {
                entryPendingDeletion = entry
            }
        )
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(emptyStateMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowDragHandle())
    }

    private var emptyStateMessage: String {
        if store.entries.isEmpty {
            return "No saved clips"
        }

        switch selectedFilter {
        case .all:
            return "No saved clips"
        case .text:
            return "Нет текста"
        case .media:
            return "Нет медиа"
        case .files:
            return "Нет файлов"
        }
    }

    private func select(_ entry: ClipboardEntry) {
        selectedID = entry.id
        showSelectionToast()
        onSelect(entry)
    }

    private func showSelectionToast() {
        guard !settings.closeAfterSelection else { return }
        showToast(settings.pasteOnSelection ? "Pasted" : "Copied")
    }

    private func showToast(_ message: String) {
        let token = UUID()
        toastToken = token
        toastMessage = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            guard toastToken == token else { return }
            withAnimation(.easeOut(duration: 0.16)) {
                toastMessage = nil
            }
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !filteredEntries.isEmpty else { return }
        let currentIndex = filteredEntries.firstIndex { $0.id == selectedID } ?? 0

        switch direction {
        case .down:
            selectedID = filteredEntries[min(currentIndex + 1, filteredEntries.count - 1)].id
        case .up:
            selectedID = filteredEntries[max(currentIndex - 1, 0)].id
        default:
            break
        }
    }

    private func entryFrameReader(for id: ClipboardEntry.ID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: EntryFramePreferenceKey.self,
                value: [id: proxy.frame(in: .named("entriesList"))]
            )
        }
    }

    private func pinnedDragGesture(for entry: ClipboardEntry) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("entriesList"))
            .onChanged { value in
                guard entry.isPinned else { return }

                if draggedPinnedEntryID == nil {
                    let listTopY = currentListTopY
                    draggedPinnedEntryID = entry.id
                    draggedPinnedListTopY = listTopY
                    draggedPinnedStartY = layoutMinY(for: entry.id, listTopY: listTopY)
                }

                guard draggedPinnedEntryID == entry.id else { return }
                draggedPinnedTranslation = value.translation.height
                updatePinnedOrder(sourceID: entry.id, locationY: value.location.y)
            }
            .onEnded { _ in
                guard draggedPinnedEntryID == entry.id else { return }

                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    draggedPinnedStartY = layoutMinY(for: entry.id, listTopY: draggedPinnedListTopY ?? currentListTopY)
                    draggedPinnedTranslation = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    if draggedPinnedEntryID == entry.id {
                        draggedPinnedEntryID = nil
                        draggedPinnedStartY = nil
                        draggedPinnedListTopY = nil
                    }
                }
            }
    }

    private func updatePinnedOrder(sourceID: ClipboardEntry.ID, locationY: CGFloat) {
        let visiblePinnedEntries = filteredEntries.filter(\.isPinned)
        guard visiblePinnedEntries.count > 1 else { return }
        let listTopY = draggedPinnedListTopY ?? currentListTopY

        guard let sourceIndex = visiblePinnedEntries.firstIndex(where: { $0.id == sourceID }) else { return }

        for target in visiblePinnedEntries where target.id != sourceID {
            guard
                let targetIndex = visiblePinnedEntries.firstIndex(where: { $0.id == target.id }),
                let targetFrame = layoutFrame(for: target, listTopY: listTopY)
            else {
                continue
            }

            let threshold = targetFrame.height * 0.32
            let afterTarget: Bool
            if targetIndex > sourceIndex {
                guard locationY >= targetFrame.minY + threshold else { continue }
                afterTarget = true
            } else {
                guard locationY <= targetFrame.maxY - threshold else { continue }
                afterTarget = false
            }

            store.movePinnedEntry(sourceID: sourceID, to: target.id, afterTarget: afterTarget)
            return
        }
    }

    private var draggedPinnedEntry: ClipboardEntry? {
        guard let draggedPinnedEntryID else { return nil }
        return store.entries.first { $0.id == draggedPinnedEntryID }
    }

    private var floatingDragY: CGFloat {
        guard let draggedPinnedStartY else {
            return draggedPinnedTranslation
        }

        return draggedPinnedStartY + draggedPinnedTranslation
    }

    private var currentListTopY: CGFloat {
        let visibleFrames = filteredEntries.compactMap { rowFrames[$0.id]?.minY }
        return visibleFrames.min() ?? Layout.topChromeHeight + Layout.rowSpacing
    }

    private func layoutFrame(for entry: ClipboardEntry, listTopY: CGFloat) -> CGRect? {
        guard let minY = layoutMinY(for: entry.id, listTopY: listTopY) else { return nil }
        return CGRect(
            x: 0,
            y: minY,
            width: rowFrames[entry.id]?.width ?? 0,
            height: rowHeight(for: entry)
        )
    }

    private func layoutMinY(for id: ClipboardEntry.ID, listTopY: CGFloat) -> CGFloat? {
        var y = listTopY

        for entry in filteredEntries {
            if entry.id == id {
                return y
            }

            y += rowHeight(for: entry) + Layout.rowSpacing
        }

        return nil
    }

    private func rowHeight(for entry: ClipboardEntry) -> CGFloat {
        switch entry.payload {
        case .text, .file:
            return 62
        case .image:
            return 134
        }
    }
}

private struct EntryFramePreferenceKey: PreferenceKey {
    static let defaultValue: [ClipboardEntry.ID: CGRect] = [:]

    static func reduce(value: inout [ClipboardEntry.ID: CGRect], nextValue: () -> [ClipboardEntry.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct TabBarWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FilterTabButton: View {
    let title: String
    let isSelected: Bool
    let isExpanded: Bool
    let palette: ThemePalette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, isExpanded ? 0 : 12)
                .frame(maxWidth: isExpanded ? .infinity : nil)
                .frame(height: 28)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.cardGlassFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(palette.borderSelected.opacity(0.7), lineWidth: 1)
                            )
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(palette.controlHoverBackground)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: isExpanded ? .infinity : nil)
        .onHover { isHovered = $0 }
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
    let fileIcon: NSImage?
    let isSelected: Bool
    let isCurrent: Bool
    let isPinLimitReached: Bool
    let isDragging: Bool
    let onSelect: () -> Void
    let onPreviewImage: () -> Void
    let onEditText: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isPinHovered = false
    @State private var isEditHovered = false
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
            CardBackground(isSelected: isSelected, isDragging: isDragging, palette: palette)
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
            actionToolbar
            .padding(.top, 8)
            .padding(.trailing, 8)
            .opacity(showsRowIcons ? 1 : 0)
            .allowsHitTesting(showsRowIcons)
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
            if canExpandText && showsRowIcons {
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
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .shadow(color: palette.shadow(isHovered ? 0.10 : 0.06), radius: isHovered ? 10 : 6, y: isHovered ? 5 : 2)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: showsRowIcons)
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
                .padding(.trailing, 88)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

        case .image:
            if let image {
                Button(action: onPreviewImage) {
                    RoundedAspectFitImage(
                        image: image,
                        maxHeight: imageHeight,
                        cornerRadius: 8
                    )
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.placeholderBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
            }

        case .file:
            HStack(spacing: 10) {
                Group {
                    if let fileIcon {
                        Image(nsImage: fileIcon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(2)

                    Text(entry.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, isCurrent ? 18 : 0)
            .padding(.trailing, 88)
        }
    }

    private var actionToolbar: some View {
        HStack(spacing: 2) {
            if entry.isText {
                iconButton(
                    systemName: "pencil",
                    isHovered: isEditHovered,
                    help: "Edit text",
                    action: onEditText
                )
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
                .onHover { isEditHovered = $0 }
            }

            iconButton(
                systemName: "trash",
                isHovered: isDeleteHovered,
                tint: isDeleteHovered ? Color.red.opacity(0.86) : nil,
                help: "Delete clip",
                action: onDelete
            )
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .onHover { isDeleteHovered = $0 }

            iconButton(
                systemName: entry.isPinned ? "pin.fill" : "pin",
                isHovered: isPinHovered,
                tint: entry.isPinned ? palette.iconOpacity(0.82) : nil,
                help: entry.isPinned ? "Unpin clip" : (isPinLimitReached ? "Pin limit reached" : "Pin clip"),
                action: onTogglePin
            )
            .opacity(isHovered || entry.isPinned ? 1 : 0)
            .allowsHitTesting(isHovered || entry.isPinned)
            .onHover { isPinHovered = $0 }
        }
    }

    private func iconButton(
        systemName: String,
        isHovered: Bool,
        tint: Color? = nil,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint ?? palette.iconOpacity(isHovered ? 0.76 : 0.46))
                .frame(width: 28, height: 28)
                .background {
                    IconGlassBackground(cornerRadius: 8, isHighlighted: isHovered, palette: palette)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var rowHeight: CGFloat {
        return switch entry.payload {
        case .text, .file:
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

    private var showsRowIcons: Bool {
        isHovered || entry.isPinned
    }

    private func previewText(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Empty text" : value
    }
}

private struct RoundedAspectFitImage: View {
    let image: NSImage
    let maxHeight: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let fittedSize = Self.aspectFitSize(
                image.size,
                in: CGSize(width: geometry.size.width, height: maxHeight)
            )

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: fittedSize.width, height: fittedSize.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .frame(width: geometry.size.width, height: maxHeight, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight)
    }

    private static func aspectFitSize(_ imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

private struct IconGlassBackground: View {
    let cornerRadius: CGFloat
    let isHighlighted: Bool
    let palette: ThemePalette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape
                .fill(palette.iconGlassTint.opacity(isHighlighted ? 1 : 0.72))

            shape
                .stroke(palette.iconGlassBorder.opacity(isHighlighted ? 1 : 0.72), lineWidth: 1)
        }
    }
}

private struct CardBackground: View {
    let isSelected: Bool
    let isDragging: Bool
    let palette: ThemePalette

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isDragging ? palette.draggedCardBackground : palette.cardGlassFill)
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
                            .frame(width: 34, height: 34)
                            .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(isPasteHovered ? palette.cardHoverBackground : palette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(palette.modalBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(palette.borderSelected, lineWidth: 1)
            )
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

struct ThemePalette {
    let colorScheme: ColorScheme

    var isDark: Bool {
        colorScheme == .dark
    }

    var windowBackground: Color {
        isDark ? Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255) : Color(red: 0.965, green: 0.965, blue: 0.970)
    }

    var windowTint: Color {
        isDark
            ? Color(red: 34 / 255, green: 34 / 255, blue: 36 / 255).opacity(0.78)
            : Color.white.opacity(0.32)
    }

    var headerBackground: Color {
        isDark ? Color.black.opacity(0.12) : Color.white.opacity(0.18)
    }

    var cardBackground: Color {
        isDark ? Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255) : Color.white
    }

    var cardGlassFill: Color {
        isDark ? .clear : Color.white.opacity(0.70)
    }

    var draggedCardBackground: Color {
        isDark ? Color(red: 0.18, green: 0.18, blue: 0.19) : .white
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

    var iconGlassTint: Color {
        isDark ? Color.white.opacity(0.055) : Color.white.opacity(0.38)
    }

    var iconGlassBorder: Color {
        isDark ? Color.white.opacity(0.14) : Color.white.opacity(0.48)
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
        isDark ? windowTint : cardGlassFill.opacity(0.96)
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
