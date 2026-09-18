import AppKit
import SwiftUI

/// Split journal: a denser frosted list with orange accents on the left, the selected clip
/// in full on a lighter frosted pane on the right (concept 1.3.2.2, `.concepts/2026-09-18-journal-layout.html`).
struct JournalView: View {
    enum Layout {
        static let width: CGFloat = 640
        static let height: CGFloat = 440
        static let minWidth: CGFloat = 560
        static let minHeight: CGFloat = 360
        static let cornerRadius: CGFloat = 24
        static let sidebarWidth: CGFloat = 290
        static let sidebarMinWidth: CGFloat = 240
        static let sidebarMaxWidth: CGFloat = 440
        static let detailMinWidth: CGFloat = 300
        static let rowHeight: CGFloat = 58
        /// Transparent strip on the right and bottom of the window for the resize grip.
        static let gripMargin: CGFloat = 4
    }

    private enum EntryFilter: CaseIterable, Identifiable {
        case all
        case text
        case media
        case files

        var id: Self { self }

        func title(_ l10n: L10n) -> String {
            switch self {
            case .all: l10n("All", "Все")
            case .text: l10n("Text", "Текст")
            case .media: l10n("Images", "Картинки")
            case .files: l10n("Files", "Файлы")
            }
        }
    }

    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var settings: AppSettings
    let onSelect: (ClipboardEntry) -> Void
    let onEditText: (ClipboardEntry) -> Void
    let onPreviewImage: (ClipboardEntry) -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedID: ClipboardEntry.ID?
    @State private var selectedFilter: EntryFilter = .all
    @State private var isClearConfirmationShown = false
    @State private var entryPendingDeletion: ClipboardEntry?
    @State private var toastMessage: String?
    @State private var toastToken = UUID()
    @State private var isListScrolled = false
    @State private var draggedPinnedID: ClipboardEntry.ID?
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var query = ""
    @State private var keyboardScrollTarget: KeyboardScrollTarget?
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchEditing = false
    @State private var sidebarDragStartWidth: CGFloat?
    @AppStorage("SidebarWidth") private var storedSidebarWidth: Double = Double(Layout.sidebarWidth)

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    private var l10n: L10n {
        settings.l10n
    }

    private var filteredEntries: [ClipboardEntry] {
        let byType: [ClipboardEntry] = switch selectedFilter {
        case .all: store.entries
        case .text: store.entries.filter(\.isText)
        case .media: store.entries.filter(\.isImage)
        case .files: store.entries.filter(\.isFile)
        }

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return byType }
        return byType.filter { matches($0, needle) }
    }

    /// Entries in the order the list shows them (pinned first, then by day), for arrow navigation.
    private var orderedEntries: [ClipboardEntry] {
        sections.flatMap(\.entries)
    }

    /// The explicit selection when it is still visible, otherwise the first clip of the filter.
    private var selectedEntry: ClipboardEntry? {
        filteredEntries.first { $0.id == selectedID } ?? orderedEntries.first
    }

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .regular, cornerRadius: Layout.cornerRadius)

            GeometryReader { geometry in
                let width = sidebarWidth(in: geometry.size.width)

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: width)
                        .background(palette.sidebarTint)
                        .overlay(alignment: .trailing) {
                            palette.separator.frame(width: 1)
                        }
                        .overlay(alignment: .trailing) {
                            SidebarResizeHandle(
                                palette: palette,
                                onChanged: { translation in
                                    let start = sidebarDragStartWidth ?? width
                                    sidebarDragStartWidth = start
                                    storedSidebarWidth = Double(clampedSidebarWidth(start + translation, in: geometry.size.width))
                                },
                                onEnded: { sidebarDragStartWidth = nil }
                            )
                            // Hit area spans 4 pt left of the divider to 10 pt right of it, so the
                            // border and the grab mark light up and drag as one.
                            .offset(x: 10)
                        }
                        .zIndex(1)

                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.detailTint)
                }
            }

            if isClearConfirmationShown || entryPendingDeletion != nil {
                ZStack {
                    palette.dialogBackdrop
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isClearConfirmationShown = false
                            entryPendingDeletion = nil
                        }

                    DeleteConfirmationOverlay(
                        title: isClearConfirmationShown ? l10n("Clear history?", "Очистить историю?") : l10n("Delete clip?", "Удалить клип?"),
                        message: isClearConfirmationShown
                            ? l10n("Unpinned clips will be removed. Pinned clips stay saved.", "Незакреплённые клипы будут удалены. Закреплённые останутся.")
                            : l10n("This clip will be removed.", "Этот клип будет удалён."),
                        actionTitle: isClearConfirmationShown ? l10n("Clear", "Очистить") : l10n("Delete", "Удалить"),
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

            if let toastMessage {
                ToastOverlay(message: toastMessage)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }
        }
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.width, minHeight: Layout.minHeight, idealHeight: Layout.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        // The grip hugs the rounded corner from outside: anchored to the panel's corner square
        // and nudged out so its strokes sit just past the curve, in a thin transparent margin.
        .overlay(alignment: .bottomTrailing) {
            WindowResizeGrip(palette: palette, cornerRadius: Layout.cornerRadius, margin: Layout.gripMargin)
                .offset(x: Layout.gripMargin, y: Layout.gripMargin)
        }
        .padding(.trailing, Layout.gripMargin)
        .padding(.bottom, Layout.gripMargin)
        .animation(.easeOut(duration: 0.16), value: isClearConfirmationShown)
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .environment(\.l10n, l10n)
        .background(
            KeyboardMonitor(
                onKey: handleKey,
                onBecomeKey: { isSearchFocused = true },
                onEditingChanged: { isSearchEditing = $0 }
            )
        )
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Logo.iconFrame, height: Logo.iconFrame)
                    .overlay(WindowDragHandle())

                Text("Stash")
                    .font(.system(size: Logo.fontSize, weight: .heavy))
                    .foregroundStyle(palette.textPrimary)
                    // Center on the capital letters, not on the line box, so "S" lines up with the icon.
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - Logo.capHeight / 2 }
                    .overlay(WindowDragHandle())

                Spacer()

                Text("\(store.entries.count)/20")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.textTertiary)
                    .overlay(WindowDragHandle())

                GlassIconButton(
                    systemName: "trash",
                    isDestructive: true,
                    help: l10n("Clear history", "Очистить историю"),
                    action: { isClearConfirmationShown = true }
                )
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(WindowDragHandle())

            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .background(WindowDragHandle())

            TypeSegmentedControl(
                titles: EntryFilter.allCases.map { $0.title(l10n) },
                selectedIndex: EntryFilter.allCases.firstIndex(of: selectedFilter) ?? 0,
                palette: palette,
                onSelect: { index in
                    withAnimation(.easeOut(duration: 0.22)) {
                        selectedFilter = EntryFilter.allCases[index]
                    }
                }
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .background(WindowDragHandle())
            .overlay(alignment: .bottom) {
                // Shadow under the header once the list scrolls beneath it.
                LinearGradient(
                    stops: [
                        .init(color: palette.shadow(0.08), location: 0),
                        .init(color: palette.shadow(0.03), location: 0.45),
                        .init(color: palette.shadow(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .frame(height: 20)
                    .offset(y: 20)
                    .opacity(isListScrolled ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: isListScrolled)
                    .allowsHitTesting(false)
            }
            .zIndex(1)

            if filteredEntries.isEmpty {
                Text(emptyStateMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WindowDragHandle())
            } else {
                entryList
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            TextField(l10n("Search", "Поиск"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(palette.textPrimary)
                .focused($isSearchFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
                .help(l10n("Clear search", "Очистить поиск"))
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSearchEditing ? ThemePalette.orange : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.12), value: isSearchEditing)
    }

    private static let listBottomID = "list-bottom"

    /// Title sized by eye against the icon tile (the system draws it on ~71% of the frame);
    /// the cap height is still used to centre "Stash" on its capitals.
    private enum Logo {
        static let iconFrame: CGFloat = 32
        static let fontSize: CGFloat = 28
        static let capHeight = NSFont.systemFont(ofSize: fontSize, weight: .heavy).capHeight
    }

    /// A plain scroll view with a stack of fixed-height rows. History holds at most 20 clips, so
    /// nothing needs to be lazy; AppKit's List re-measured and re-used cells, which made scrolling
    /// jumpy and inserts snap.
    private var entryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sections, id: \.title) { section in
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.textTertiary)
                            .padding(.leading, 8)
                            .padding(.top, 6)
                            .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
                            .id(section.title)

                        ForEach(section.entries) { entry in
                            row(entry, pinned: section.isPinned ? section.entries : nil)
                                .id(entry.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: -10)),
                                        removal: .opacity.combined(with: .scale(scale: 0.96))
                                    )
                                )
                        }
                    }

                    Color.clear
                        .frame(height: 8)
                        .id(Self.listBottomID)
                }
                .padding(.horizontal, 6)
            }
            .background(ScrollOffsetObserver { isListScrolled = $0 })
            // New clips arrive from the pasteboard monitor outside any transaction: animate inserts,
            // removals and reorders here so rows slide apart and the new one fades in.
            .animation(.easeOut(duration: 0.3), value: store.entries.map(\.id))
            .onChange(of: keyboardScrollTarget) { target in
                guard let target else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    switch target {
                    case let .entry(id): proxy.scrollTo(id)
                    case .top: if let first = sections.first { proxy.scrollTo(first.title, anchor: .top) }
                    case .bottom: proxy.scrollTo(Self.listBottomID, anchor: .bottom)
                    }
                }
                keyboardScrollTarget = nil
            }
        }
    }

    private func row(_ entry: ClipboardEntry, pinned: [ClipboardEntry]?) -> some View {
        EntryRow(
            entry: entry,
            thumbnail: store.thumbnail(for: entry),
            fileIcon: store.fileIcon(for: entry),
            title: rowTitle(entry),
            subtitle: rowSubtitle(entry),
            isSelected: entry.id == selectedEntry?.id,
            isCurrent: store.currentClipboardFingerprint == entry.fingerprint,
            palette: palette,
            quickPasteTitle: settings.pasteOnSelection ? l10n("Paste", "Вставить") : l10n("Copy", "Скопировать"),
            onQuickPaste: { select(entry) },
            onExpand: expandAction(for: entry),
            onTogglePin: { togglePin(entry) },
            onDelete: { entryPendingDeletion = entry }
        )
        .offset(y: draggedPinnedID == entry.id ? draggedRowOffset(in: pinned ?? []) : 0)
        .shadow(color: draggedPinnedID == entry.id ? palette.shadow(0.18) : .clear, radius: 10, y: 4)
        .zIndex(draggedPinnedID == entry.id ? 1 : 0)
        .gesture(pinnedDragGesture(for: entry, in: pinned ?? []), including: pinned == nil ? .subviews : .all)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedID = entry.id
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { select(entry) })
        .help(l10n("Double-click to paste", "Двойной клик — вставить"))
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let entry = selectedEntry {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(entry.isFile ? entry.title(l10n) : kindTitle(entry))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .overlay(WindowDragHandle())

                    Text("· \(timeTitle(entry.createdAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .overlay(WindowDragHandle())

                    if store.currentClipboardFingerprint == entry.fingerprint {
                        Text(l10n("in clipboard", "в буфере"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.accentText)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(WindowDragHandle())
                    }

                    Spacer()

                    GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
                }
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .padding(.top, 10)
                .background(WindowDragHandle())

                stage(for: entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, entry.isText ? 0 : 16)
                    .padding(.vertical, 12)

                HStack(spacing: 12) {
                    Text(l10n("Size", "Размер"))
                        .foregroundStyle(palette.textTertiary)
                    Text(metaTitle(entry))
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                actionBar(for: entry)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(palette.textTertiary)
                Text(l10n("Nothing copied yet", "Пока ничего не скопировано"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WindowDragHandle())
            .overlay(alignment: .topTrailing) {
                GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
                    .padding(10)
            }
        }
    }

    @ViewBuilder
    private func stage(for entry: ClipboardEntry) -> some View {
        switch entry.payload {
        case let .text(text):
            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(palette.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Insets live inside the scroll view so the scroller gets its own lane on the right.
                    .padding(.leading, 16)
                    .padding(.trailing, 22)
                    .background(ScrollBarAppearanceSetter(colorScheme: colorScheme))
            }

        case .image:
            if let image = store.image(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: palette.shadow(0.18), radius: 10, y: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onPreviewImage(entry) }
                    .help(l10n("Open in Preview", "Открыть в Просмотре"))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.placeholderBackground)
            }

        case .file:
            VStack(spacing: 10) {
                Group {
                    if let icon = store.fileIcon(for: entry) {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(width: 72, height: 72)

                Text(entry.title(l10n))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func actionBar(for entry: ClipboardEntry) -> some View {
        HStack(spacing: 6) {
            if entry.isText {
                GlassIconButton(systemName: "pencil", help: l10n("Edit text", "Редактировать"), action: { onEditText(entry) })
            }

            if entry.isImage {
                GlassIconButton(systemName: "arrow.up.left.and.arrow.down.right", help: l10n("Open in Preview", "Открыть в Просмотре"), action: { onPreviewImage(entry) })
            }

            GlassIconButton(
                systemName: entry.isPinned ? "pin.fill" : "pin",
                tint: entry.isPinned ? palette.accentText : nil,
                help: entry.isPinned ? l10n("Unpin clip", "Открепить") : l10n("Pin clip", "Закрепить"),
                action: { togglePin(entry) }
            )

            GlassIconButton(
                systemName: "trash",
                isDestructive: true,
                help: l10n("Delete clip", "Удалить"),
                action: { entryPendingDeletion = entry }
            )

            Spacer()

            Button {
                select(entry)
            } label: {
                HStack(spacing: 6) {
                    Text(settings.pasteOnSelection ? l10n("Paste", "Вставить") : l10n("Copy", "Скопировать"))
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 28)
            }
            .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            palette.separator.frame(height: 1)
        }
    }

    // MARK: Data

    private enum KeyboardScrollTarget: Equatable {
        case entry(ClipboardEntry.ID)
        case top
        case bottom
    }

    private struct EntrySection {
        let title: String
        let entries: [ClipboardEntry]
        let isPinned: Bool
    }

    private var sections: [EntrySection] {
        let calendar = Calendar.current
        var result: [EntrySection] = []
        let pinned = filteredEntries.filter(\.isPinned)
        if !pinned.isEmpty {
            result.append(EntrySection(title: l10n("Pinned", "Закреплённые"), entries: pinned, isPinned: true))
        }

        let rest = filteredEntries.filter { !$0.isPinned }
        let today = rest.filter { calendar.isDateInToday($0.createdAt) }
        let yesterday = rest.filter { calendar.isDateInYesterday($0.createdAt) }
        let earlier = rest.filter { !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt) }
        for (title, entries) in [(l10n("Today", "Сегодня"), today), (l10n("Yesterday", "Вчера"), yesterday), (l10n("Earlier", "Раньше"), earlier)] where !entries.isEmpty {
            result.append(EntrySection(title: title, entries: entries, isPinned: false))
        }
        return result
    }

    // MARK: Pinned drag

    /// Rows have one fixed height, so the drop slot is the start index plus whole rows dragged.
    private func pinnedDragGesture(for entry: ClipboardEntry, in pinned: [ClipboardEntry]) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if draggedPinnedID == nil {
                    draggedPinnedID = entry.id
                    dragStartIndex = pinned.firstIndex { $0.id == entry.id } ?? 0
                }
                guard draggedPinnedID == entry.id else { return }
                dragTranslation = value.translation.height

                guard let current = pinned.firstIndex(where: { $0.id == entry.id }) else { return }
                let slots = Int((dragTranslation / Layout.rowHeight).rounded())
                let target = min(max(dragStartIndex + slots, 0), pinned.count - 1)
                guard target != current else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    store.movePinnedEntry(sourceID: entry.id, to: pinned[target].id, afterTarget: target > current)
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    draggedPinnedID = nil
                    dragTranslation = 0
                }
            }
    }

    /// The dragged row follows the pointer; once it has moved slots in the data, the layout already
    /// shifted it, so subtract those whole rows.
    private func draggedRowOffset(in pinned: [ClipboardEntry]) -> CGFloat {
        guard let id = draggedPinnedID, let current = pinned.firstIndex(where: { $0.id == id }) else { return 0 }
        return dragTranslation - CGFloat(current - dragStartIndex) * Layout.rowHeight
    }

    private func kindTitle(_ entry: ClipboardEntry) -> String {
        switch entry.payload {
        case .text: l10n("Text", "Текст")
        case .image: l10n("Image", "Изображение")
        case .file: l10n("File", "Файл")
        }
    }

    private func rowTitle(_ entry: ClipboardEntry) -> String {
        switch entry.payload {
        case let .text(text):
            // Collapse whitespace so two lines show real content, not blank lines.
            let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return collapsed.isEmpty ? l10n("Empty text", "Пустой текст") : collapsed
        case .image:
            return kindTitle(entry)
        case .file:
            return entry.title(l10n)
        }
    }

    private func rowSubtitle(_ entry: ClipboardEntry) -> String {
        let time = timeTitle(entry.createdAt)
        switch entry.payload {
        case .text: return time
        case .image: return [pixelSize(of: entry), time].compactMap { $0 }.joined(separator: " · ")
        case .file: return "\(entry.subtitle(l10n)) · \(time)"
        }
    }

    private func sidebarWidth(in totalWidth: CGFloat) -> CGFloat {
        clampedSidebarWidth(CGFloat(storedSidebarWidth), in: totalWidth)
    }

    private func clampedSidebarWidth(_ width: CGFloat, in totalWidth: CGFloat) -> CGFloat {
        let upper = max(Layout.sidebarMinWidth, min(Layout.sidebarMaxWidth, totalWidth - Layout.detailMinWidth))
        return min(max(width, Layout.sidebarMinWidth), upper)
    }

    private func metaTitle(_ entry: ClipboardEntry) -> String {
        switch entry.payload {
        case .text, .file:
            return entry.subtitle(l10n)
        case .image:
            var parts: [String] = []
            if let size = pixelSize(of: entry) {
                parts.append(size)
            }
            if
                let url = store.imageURL(for: entry),
                let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
            {
                parts.append("PNG")
                parts.append(ByteCountFormatter.string(fromByteCount: bytes.int64Value, countStyle: .file))
            }
            return parts.joined(separator: " · ")
        }
    }

    private func pixelSize(of entry: ClipboardEntry) -> String? {
        guard let size = store.pixelSize(for: entry) else { return nil }
        return "\(Int(size.width))×\(Int(size.height))"
    }

    private func timeTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return DateFormatter.entryTime.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return l10n("yesterday", "вчера") + ", " + DateFormatter.entryTime.string(from: date)
        }
        let locale = Locale(identifier: settings.language.resolved == .russian ? "ru_RU" : "en_US")
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    private var emptyStateMessage: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return l10n("Nothing found", "Ничего не найдено")
        }
        if store.entries.isEmpty {
            return l10n("No saved clips", "Нет сохранённых клипов")
        }

        switch selectedFilter {
        case .all: return l10n("No saved clips", "Нет сохранённых клипов")
        case .text: return l10n("No text", "Нет текста")
        case .media: return l10n("No images", "Нет картинок")
        case .files: return l10n("No files", "Нет файлов")
        }
    }

    private func matches(_ entry: ClipboardEntry, _ needle: String) -> Bool {
        let haystack: String = switch entry.payload {
        case let .text(text): text
        case .image: kindTitle(entry) + " " + (pixelSize(of: entry) ?? "")
        case .file: entry.title(l10n)
        }
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Arrow keys move the selection, Return pastes it, Escape clears the search or closes.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard !isClearConfirmationShown, entryPendingDeletion == nil else {
            if event.keyCode == 53 {
                isClearConfirmationShown = false
                entryPendingDeletion = nil
                return true
            }
            return false
        }

        switch event.keyCode {
        case 125, 126:
            let entries = orderedEntries
            guard !entries.isEmpty else { return true }
            let current = entries.firstIndex { $0.id == selectedEntry?.id } ?? 0
            let next = event.keyCode == 125 ? min(current + 1, entries.count - 1) : max(current - 1, 0)
            selectedID = entries[next].id
            // At the ends scroll to the header / bottom inset so the row keeps its margin.
            keyboardScrollTarget = next == 0 ? .top : (next == entries.count - 1 ? .bottom : .entry(entries[next].id))
            return true
        case 36, 76:
            if let entry = selectedEntry {
                select(entry)
            }
            return true
        case 53:
            if query.isEmpty {
                onClose()
            } else {
                query = ""
            }
            return true
        default:
            return false
        }
    }

    // MARK: Actions

    private func togglePin(_ entry: ClipboardEntry) {
        if !store.togglePin(entry) {
            showToast(l10n("Up to 10 pinned clips", "Максимум 10 закрепов"))
        }
    }

    /// Images open in Preview, files in their default app; text is already shown in full on the right.
    private func expandAction(for entry: ClipboardEntry) -> (() -> Void)? {
        switch entry.payload {
        case .text:
            return nil
        case .image:
            return { onPreviewImage(entry) }
        case .file:
            guard let url = store.fileURL(for: entry) else { return nil }
            return { NSWorkspace.shared.open(url) }
        }
    }

    private func select(_ entry: ClipboardEntry) {
        selectedID = entry.id
        if !settings.closeAfterSelection {
            showToast(settings.pasteOnSelection ? l10n("Pasted", "Вставлено") : l10n("Copied", "Скопировано"))
        }
        onSelect(entry)
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
}

// MARK: - Row

private struct EntryRow: View {
    let entry: ClipboardEntry
    let thumbnail: NSImage?
    let fileIcon: NSImage?
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isCurrent: Bool
    let palette: ThemePalette
    let quickPasteTitle: String
    let onQuickPaste: () -> Void
    let onExpand: (() -> Void)?
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @Environment(\.l10n) private var l10n
    @State private var isHovered = false

    private static let actionSize: CGFloat = 26
    private static let actionSpacing: CGFloat = 4
    /// Space the pin/clipboard column and its HStack spacing take right of the text column.
    private static let trailingColumnWidth: CGFloat = 20

    private var actionsWidth: CGFloat {
        let count = CGFloat(onExpand == nil ? 3 : 4)
        return count * Self.actionSize + (count - 1) * Self.actionSpacing
    }

    var body: some View {
        HStack(spacing: 10) {
            thumb
                .frame(width: 42, height: 42)
                .background(palette.placeholderBackground)
                .background(palette.sidebarTint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: palette.controlShadow, radius: ThemePalette.controlShadowRadius, y: 1)

            Group {
                if entry.isText {
                    // Short text keeps its date line; text that needs two lines uses both for content.
                    ViewThatFits(in: .horizontal) {
                        VStack(alignment: .leading, spacing: 2) {
                            titleText.fixedSize(horizontal: true, vertical: false)
                            subtitleText
                        }
                        titleText.lineLimit(2)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        titleText.lineLimit(entry.isImage ? 1 : 2)
                        subtitleText
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Under the hover actions the text fades out instead of reflowing. Only the text
            // column is masked so the thumbnail's shadow is not clipped.
            .mask {
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: isHovered ? 24 : 0)
                    Color.clear
                        .frame(width: isHovered ? max(actionsWidth - Self.trailingColumnWidth, 0) : 0)
                }
            }

            VStack(spacing: 6) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
                if isCurrent {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accentText)
                }
            }
            .opacity(isHovered ? 0 : 1)
        }
        .padding(.horizontal, 8)
        // Fixed height: variable rows made the list re-measure while scrolling and jump.
        .frame(height: JournalView.Layout.rowHeight - 2)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.accentSoft : (isHovered ? palette.controlHoverBackground : .clear))
        }
        // The 1 pt gap between highlights stays visual only: the hover area covers it.
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(ThemePalette.orange)
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .offset(x: -6)
            }
        }
        .overlay(alignment: .trailing) {
            // Floats over the row so hovering never reflows the title.
            if isHovered {
                HStack(spacing: Self.actionSpacing) {
                    if let onExpand {
                        rowAction("arrow.up.left.and.arrow.down.right", help: entry.isImage ? l10n("Open in Preview", "Открыть в Просмотре") : l10n("Open", "Открыть"), action: onExpand)
                    }
                    rowAction(
                        entry.isPinned ? "pin.fill" : "pin",
                        tone: entry.isPinned ? .accent : .neutral,
                        help: entry.isPinned ? l10n("Unpin clip", "Открепить") : l10n("Pin clip", "Закрепить"),
                        action: onTogglePin
                    )
                    rowAction("trash", tone: .destructive, help: l10n("Delete clip", "Удалить"), action: onDelete)
                    rowAction("return", tone: .accent, help: quickPasteTitle, action: onQuickPaste)
                }
                .padding(.trailing, 8)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private func rowAction(
        _ systemName: String,
        tone: TranslucentButtonStyle.Tone = .neutral,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: Self.actionSize, height: Self.actionSize)
        }
        .buttonStyle(TranslucentButtonStyle(tone: tone, cornerRadius: 7))
        .help(help)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: 13, weight: entry.isText ? .regular : .semibold))
            .foregroundStyle(isSelected ? palette.accentText : palette.textPrimary)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(palette.textTertiary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var thumb: some View {
        switch entry.payload {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            }
        case .file:
            if let fileIcon {
                Image(nsImage: fileIcon)
                    .resizable()
                    .padding(4)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textSecondary)
            }
        case let .text(text):
            Text(String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
    }
}

/// Invisible 8 pt strip over the divider: resize cursor on hover, drag changes the list width.
private struct SidebarResizeHandle: View {
    let palette: ThemePalette
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        Color.clear
            .frame(width: 14)
            .frame(maxHeight: .infinity)
            .overlay {
                // Grab mark on the divider; turns orange while hovered or dragged.
                Capsule()
                    .fill(isHovered || isDragging ? ThemePalette.orange : palette.iconOpacity(0.22))
                    .frame(width: 4, height: 32)
                    // Just right of the 1 pt divider line, with a small gap; floats over the preview.
                    .offset(x: 2)
                    .animation(.easeOut(duration: 0.12), value: isHovered || isDragging)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                guard hovering != isHovered else { return }
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged {
                        isDragging = true
                        onChanged($0.translation.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEnded()
                    }
            )
    }
}

/// Bottom-right grip: two diagonal strokes over an AppKit view that resizes the borderless panel,
/// keeping its top-left corner in place.
private struct WindowResizeGrip: View {
    let palette: ThemePalette
    let cornerRadius: CGFloat
    let margin: CGFloat

    @State private var isHovered = false

    private static let size: CGFloat = 30
    /// Dot centre sits 4.5 pt outside the edge: half the 6 pt dot plus a 1.5 pt gap.
    private static let gap: CGFloat = 4.5

    var body: some View {
        Canvas { context, size in
            // A dot on the corner's diagonal, just outside the rounded edge.
            // The panel corner sits `margin` in from the canvas's bottom-right.
            let corner = CGPoint(x: size.width - margin, y: size.height - margin)
            let center = CGPoint(x: corner.x - cornerRadius, y: corner.y - cornerRadius)
            let distance = (cornerRadius + Self.gap) / 2.squareRoot()
            let dot = CGPoint(x: center.x + distance, y: center.y + distance)
            let diameter: CGFloat = 6
            context.fill(
                Path(ellipseIn: CGRect(x: dot.x - diameter / 2, y: dot.y - diameter / 2, width: diameter, height: diameter)),
                with: .color(isHovered ? ThemePalette.orange : palette.iconOpacity(0.22))
            )
        }
        .frame(width: Self.size, height: Self.size)
        // Near-transparent fill so the whole square takes clicks in the transparent margin.
        .background(Color.black.opacity(0.001))
        .background(WindowResizeArea())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct WindowResizeArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        GripView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class GripView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }

        override func resetCursorRects() {
            if #available(macOS 15.0, *) {
                addCursorRect(bounds, cursor: .frameResize(position: .bottomRight, directions: .all))
            } else {
                addCursorRect(bounds, cursor: .crosshair)
            }
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let startMouse = NSEvent.mouseLocation
            let startFrame = window.frame

            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type != .leftMouseUp {
                let mouse = NSEvent.mouseLocation
                let width = max(startFrame.width + mouse.x - startMouse.x, window.minSize.width)
                let height = max(startFrame.height - (mouse.y - startMouse.y), window.minSize.height)
                window.setFrame(
                    NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height),
                    display: true
                )
            }
        }
    }
}

/// Local key-down monitor for the panel's window, plus a callback when that window becomes key.
private struct KeyboardMonitor: NSViewRepresentable {
    let onKey: (NSEvent) -> Bool
    let onBecomeKey: () -> Void
    let onEditingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onKey: onKey, onBecomeKey: onBecomeKey, onEditingChanged: onEditingChanged)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKey = onKey
        context.coordinator.onBecomeKey = onBecomeKey
        context.coordinator.onEditingChanged = onEditingChanged
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        var onKey: (NSEvent) -> Bool
        var onBecomeKey: () -> Void
        var onEditingChanged: (Bool) -> Void
        weak var view: NSView?
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []

        init(onKey: @escaping (NSEvent) -> Bool, onBecomeKey: @escaping () -> Void, onEditingChanged: @escaping (Bool) -> Void) {
            self.onKey = onKey
            self.onBecomeKey = onBecomeKey
            self.onEditingChanged = onEditingChanged
        }

        private func isOwnWindow(_ object: Any?) -> Bool {
            guard let own = view?.window else { return false }
            if let window = object as? NSWindow {
                return window === own
            }
            return (object as? NSView)?.window === own
        }

        private func observe(_ name: Notification.Name, _ handler: @escaping @MainActor (Coordinator) -> Void) {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                nonisolated(unsafe) let object = notification.object
                MainActor.assumeIsolated {
                    guard let self, self.isOwnWindow(object) else { return }
                    handler(self)
                }
            }
            observers.append(token)
        }

        func start() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                nonisolated(unsafe) let event = event
                let handled = MainActor.assumeIsolated { () -> Bool in
                    guard
                        let self,
                        let window = self.view?.window,
                        event.window === window,
                        event.modifierFlags.intersection([.command, .control, .option]).isEmpty
                    else {
                        return false
                    }
                    return self.onKey(event)
                }
                return handled ? nil : event
            }
            observe(NSWindow.didBecomeKeyNotification) { $0.onBecomeKey() }
            observe(NSWindow.didResignKeyNotification) { $0.onEditingChanged(false) }
            // The search field reports real editing through the field editor, which FocusState
            // does not track reliably in a non-activating panel.
            observe(NSControl.textDidBeginEditingNotification) { $0.onEditingChanged(true) }
            observe(NSControl.textDidEndEditingNotification) { $0.onEditingChanged(false) }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            observers.forEach(NotificationCenter.default.removeObserver)
            monitor = nil
            observers = []
        }
    }
}

/// Reports whether the enclosing scroll view has scrolled away from the top. SwiftUI geometry
/// preferences inside a macOS ScrollView do not update while scrolling, so watch the clip view.
private struct ScrollOffsetObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onChange = onChange
    }

    @MainActor
    final class Coordinator {
        var onChange: (Bool) -> Void
        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?
        private var lastValue = false

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
        }

        func attach(from view: NSView, attempt: Int = 0) {
            guard scrollView == nil else { return }
            guard let scrollView = Self.findScrollView(near: view) else {
                // Frames are still zero right after creation; try again once SwiftUI has laid out.
                if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak view] in
                        guard let view else { return }
                        self?.attach(from: view, attempt: attempt + 1)
                    }
                }
                return
            }
            self.scrollView = scrollView
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.report()
                }
            }
            report()
        }

        private func report() {
            guard let scrollView else { return }
            let offset = scrollView.contentView.bounds.origin.y + scrollView.contentInsets.top
            let isScrolled = offset > 1
            guard isScrolled != lastValue else { return }
            lastValue = isScrolled
            onChange(isScrolled)
        }

        /// The observer is the list's background, so the list's scroll view is the one that
        /// covers the same area of the window. Walk up and search each ancestor's subtree for it.
        private static func findScrollView(near view: NSView) -> NSScrollView? {
            guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { return nil }
            let target = view.convert(view.bounds, to: nil)

            var ancestor = view.superview
            while let current = ancestor {
                if let match = scrollView(in: current, matching: target) {
                    return match
                }
                ancestor = current.superview
            }
            return nil
        }

        private static func scrollView(in root: NSView, matching target: NSRect) -> NSScrollView? {
            for subview in root.subviews {
                if let scrollView = subview as? NSScrollView {
                    let frame = scrollView.convert(scrollView.bounds, to: nil)
                    let overlap = frame.intersection(target)
                    if !overlap.isNull, overlap.width * overlap.height >= 0.8 * target.width * target.height {
                        return scrollView
                    }
                    continue
                }
                if let match = scrollView(in: subview, matching: target) {
                    return match
                }
            }
            return nil
        }
    }
}

// MARK: - Controls

/// Type filter: a track (radius 8) with a translucent orange thumb (radius 6) that slides between segments.
private struct TypeSegmentedControl: View {
    let titles: [String]
    let selectedIndex: Int
    let palette: ThemePalette
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = (geometry.size.width - 4) / CGFloat(max(titles.count, 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.segmentThumb)
                    .frame(width: segmentWidth)
                    .offset(x: segmentWidth * CGFloat(selectedIndex))
                    .padding(2)

                HStack(spacing: 0) {
                    ForEach(titles.indices, id: \.self) { index in
                        Button {
                            onSelect(index)
                        } label: {
                            Text(titles[index])
                                .font(.system(size: 11.5, weight: index == selectedIndex ? .semibold : .medium))
                                .foregroundStyle(index == selectedIndex ? palette.accentText : palette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(width: segmentWidth, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
        }
        .frame(height: 28)
        .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Translucent button: a tinted fill that deepens on hover (shadcn-style), more on press.
/// Neutral is grey, accent is orange with an orange label, destructive turns red on hover.
struct TranslucentButtonStyle: ButtonStyle {
    enum Tone {
        case neutral
        case accent
        case destructive
    }

    var tone: Tone = .neutral
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        TranslucentButtonBody(configuration: configuration, tone: tone, cornerRadius: cornerRadius)
    }

    private struct TranslucentButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let tone: Tone
        let cornerRadius: CGFloat

        @Environment(\.colorScheme) private var colorScheme
        @State private var isHovered = false

        private var palette: ThemePalette {
            ThemePalette(colorScheme: colorScheme)
        }

        var body: some View {
            configuration.label
                .foregroundStyle(foreground)
                .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }

        private var level: Double {
            configuration.isPressed ? 2 : (isHovered ? 1 : 0)
        }

        private var foreground: Color {
            switch tone {
            case .accent: palette.accentText
            case .destructive: isHovered ? Color.red.opacity(0.9) : palette.iconOpacity(0.7)
            case .neutral: palette.iconOpacity(isHovered ? 0.85 : 0.7)
            }
        }

        private var fill: Color {
            switch tone {
            case .accent:
                return ThemePalette.orange.opacity((palette.isDark ? 0.28 : 0.18) + 0.08 * level)
            case .destructive where isHovered:
                return Color.red.opacity((palette.isDark ? 0.2 : 0.12) + 0.06 * (level - 1))
            case .neutral, .destructive:
                return palette.iconOpacity((palette.isDark ? 0.10 : 0.06) + 0.05 * level)
            }
        }
    }
}

private struct GlassIconButton: View {
    let systemName: String
    var isDestructive = false
    var tint: Color?
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(TranslucentButtonStyle(tone: tint != nil ? .accent : (isDestructive ? .destructive : .neutral), cornerRadius: 8))
        .help(help)
    }
}

/// Confirmation in the split style: frosted card, 8 pt buttons, destructive action in red.
private struct DeleteConfirmationOverlay: View {
    let title: String
    let message: String
    let actionTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmHovered = false
    @State private var isCancelHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(palette.isDark ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Spacer()

                Button(action: onCancel) {
                    Text(l10n("Cancel", "Отмена"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(isCancelHovered ? palette.controlHoverBackground : palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { isCancelHovered = $0 }

                Button(action: onConfirm) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(Color.red.opacity((palette.isDark ? 0.2 : 0.12) + (isConfirmHovered ? 0.08 : 0)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { isConfirmHovered = $0 }
            }
        }
        .padding(16)
        .frame(width: 300)
        .background {
            ZStack {
                NativeGlassEffectView(style: .regular, cornerRadius: 14)
                palette.sidebarTint
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.shadow(0.22), radius: 24, y: 10)
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

struct ThemePalette {
    let colorScheme: ColorScheme

    var isDark: Bool {
        colorScheme == .dark
    }

    /// Orange from the app icon (#F46A25).
    static let orange = Color(red: 244 / 255, green: 106 / 255, blue: 37 / 255)

    /// Frosted tint over the glass for the list pane (denser) and the preview pane (lighter).
    var sidebarTint: Color {
        isDark ? Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255).opacity(0.84) : Color.white.opacity(0.82)
    }

    var detailTint: Color {
        isDark ? Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255).opacity(0.42) : Color.white.opacity(0.38)
    }

    /// Orange for text and small marks, tuned per appearance for contrast.
    var accentText: Color {
        isDark ? Color(red: 1, green: 138 / 255, blue: 76 / 255) : Color(red: 217 / 255, green: 86 / 255, blue: 26 / 255)
    }

    /// Soft orange behind the selected row.
    var accentSoft: Color {
        Self.orange.opacity(isDark ? 0.22 : 0.13)
    }

    /// One tight shadow for small raised things in rows: thumbnails and the quick-paste button.
    static let controlShadowRadius: CGFloat = 1

    var controlShadow: Color {
        shadow(0.28)
    }

    /// Dim layer behind confirmation dialogs.
    var dialogBackdrop: Color {
        Color.black.opacity(isDark ? 0.32 : 0.16)
    }

    /// Translucent orange thumb of the type filter.
    var segmentThumb: Color {
        Self.orange.opacity(isDark ? 0.28 : 0.18)
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
        let knobStyle: NSScroller.KnobStyle = colorScheme == .dark ? .light : .dark
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
