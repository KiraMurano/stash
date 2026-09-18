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
        static let rowHeight: CGFloat = 50
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
    @State private var query = ""
    @State private var keyboardScrollTarget: ClipboardEntry.ID?
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
                                onChanged: { translation in
                                    let start = sidebarDragStartWidth ?? width
                                    sidebarDragStartWidth = start
                                    storedSidebarWidth = Double(clampedSidebarWidth(start + translation, in: geometry.size.width))
                                },
                                onEnded: { sidebarDragStartWidth = nil }
                            )
                            .offset(x: 4)
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
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)

                Text("Stash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text("\(store.entries.count)/20")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.textTertiary)

                Spacer()

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
            .overlay(alignment: .bottom) {
                // Shadow under the header once the list scrolls beneath it.
                LinearGradient(colors: [palette.shadow(0.14), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 8)
                    .offset(y: 8)
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

    private var entryList: some View {
        ScrollViewReader { proxy in
        List {
            // Headers are plain rows: List section headers on macOS are sticky and draw their own bar.
            ForEach(sections, id: \.title) { section in
                Text(section.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .padding(.leading, 8)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .moveDisabled(true)

                ForEach(section.entries) { entry in
                    row(entry)
                        .id(entry.id)
                }
                .onMove(perform: section.isPinned ? { movePinned(in: section.entries, from: $0, to: $1) } : nil)
            }

            // Bottom inset so the last row does not touch the panel edge.
            Color.clear
                .frame(height: 8)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .moveDisabled(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ScrollOffsetObserver { isListScrolled = $0 })
        .environment(\.defaultMinListRowHeight, 20)
        .onChange(of: keyboardScrollTarget) { target in
            guard let target else { return }
            proxy.scrollTo(target)
            keyboardScrollTarget = nil
        }
        }
    }

    private func row(_ entry: ClipboardEntry) -> some View {
        EntryRow(
            entry: entry,
            thumbnail: store.image(for: entry),
            fileIcon: store.fileIcon(for: entry),
            title: rowTitle(entry),
            subtitle: rowSubtitle(entry),
            isSelected: entry.id == selectedEntry?.id,
            isCurrent: store.currentClipboardFingerprint == entry.fingerprint,
            palette: palette,
            quickPasteTitle: settings.pasteOnSelection ? l10n("Paste", "Вставить") : l10n("Copy", "Скопировать"),
            onQuickPaste: { select(entry) }
        )
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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

                    Text("· \(timeTitle(entry.createdAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)

                    if store.currentClipboardFingerprint == entry.fingerprint {
                        Text(l10n("in clipboard", "в буфере"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.accentText)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
                    .padding(.horizontal, 16)
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
                action: {
                    if !store.togglePin(entry) {
                        showToast(l10n("Up to 10 pinned clips", "Максимум 10 закрепов"))
                    }
                }
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
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(ThemePalette.orange, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            palette.separator.frame(height: 1)
        }
    }

    // MARK: Data

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

    private func movePinned(in entries: [ClipboardEntry], from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first, entries.indices.contains(sourceIndex) else { return }
        let sourceID = entries[sourceIndex].id

        if destination >= entries.count {
            guard let last = entries.last, last.id != sourceID else { return }
            store.movePinnedEntry(sourceID: sourceID, to: last.id, afterTarget: true)
        } else {
            let target = entries[destination]
            guard target.id != sourceID else { return }
            store.movePinnedEntry(sourceID: sourceID, to: target.id, afterTarget: false)
        }
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
        guard let rep = store.image(for: entry)?.representations.first, rep.pixelsWide > 0 else { return nil }
        return "\(rep.pixelsWide)×\(rep.pixelsHigh)"
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
            keyboardScrollTarget = entries[next].id
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

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            thumb
                .frame(width: 36, height: 36)
                .background(palette.placeholderBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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

            if isHovered {
                Button(action: onQuickPaste) {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(ThemePalette.orange, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(quickPasteTitle)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                VStack(spacing: 6) {
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(palette.accentText)
                    }
                    if isCurrent {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: JournalView.Layout.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.accentSoft : (isHovered ? palette.controlHoverBackground : .clear))
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(ThemePalette.orange)
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .offset(x: -6)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: 13, weight: isSelected || !entry.isText ? .semibold : .regular))
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
    }
}

/// Invisible 8 pt strip over the divider: resize cursor on hover, drag changes the list width.
private struct SidebarResizeHandle: View {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    @State private var isHovered = false

    var body: some View {
        Color.clear
            .frame(width: 8)
            .frame(maxHeight: .infinity)
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
                    .onChanged { onChanged($0.translation.width) }
                    .onEnded { _ in onEnded() }
            )
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

/// Reports whether the enclosing list has scrolled away from the top.
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

private struct GlassIconButton: View {
    let systemName: String
    var isDestructive = false
    var tint: Color?
    let help: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(isHovered ? palette.controlHoverBackground : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }

    private var iconColor: Color {
        if isDestructive, isHovered {
            return .red.opacity(0.86)
        }
        if let tint {
            return tint
        }
        return palette.iconOpacity(isHovered ? 0.82 : 0.55)
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(Color.red.opacity(isConfirmHovered ? 0.95 : 0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
