import AppKit
import SwiftUI

struct JournalView: View {
    private enum Layout {
        static let width: CGFloat = 430
        static let height: CGFloat = 470
        static let cornerRadius: CGFloat = 28
        static let headerHeight: CGFloat = 63
    }

    @ObservedObject var store: ClipboardHistoryStore
    let writer: ClipboardWriter
    let onSelect: (ClipboardEntry) -> Void
    let onClose: () -> Void

    @State private var selectedID: ClipboardEntry.ID?
    @State private var previewEntry: ClipboardEntry?
    @State private var isClearConfirmationShown = false
    @State private var entryPendingDeletion: ClipboardEntry?

    private var filteredEntries: [ClipboardEntry] {
        store.entries
    }

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .clear, cornerRadius: Layout.cornerRadius)
            Color.white.opacity(0.12)

            if filteredEntries.isEmpty {
                emptyState
                    .padding(.top, Layout.headerHeight)
            } else {
                entriesList
            }

            VStack(spacing: 0) {
                header
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                HeaderBlurBackground()
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .frame(maxHeight: .infinity, alignment: .top)

            if
                let previewEntry,
                let previewImage = store.image(for: previewEntry)
            {
                ImagePreviewOverlay(
                    image: previewImage,
                    onPaste: {
                        onSelect(previewEntry)
                    },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            self.previewEntry = nil
                        }
                    }
                )
                .transition(.opacity.animation(.easeOut(duration: 0.16)))
                .zIndex(10)
            }

            if isClearConfirmationShown || entryPendingDeletion != nil {
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
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(20)
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
        .onAppear {
            writer.requestAccessibilityIfNeeded()
            selectedID = filteredEntries.first?.id
        }
        .onChange(of: filteredEntries) { entries in
            if selectedID == nil || !entries.contains(where: { $0.id == selectedID }) {
                selectedID = entries.first?.id
            }
        }
        .animation(.easeOut(duration: 0.16), value: selectedID)
        .animation(.easeOut(duration: 0.18), value: filteredEntries)
        .animation(.easeOut(duration: 0.16), value: isClearConfirmationShown)
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Buffer Journal")
                .font(.system(size: 17, weight: .bold))

            Spacer()

            Button {
                isClearConfirmationShown = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Clear history")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.leading, 2)
    }

    private var entriesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(filteredEntries) { entry in
                        ClipboardEntryRow(
                            entry: entry,
                            image: store.image(for: entry),
                            isSelected: selectedID == entry.id,
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
                            selectedID = entry.id
                            onSelect(entry)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, Layout.headerHeight)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedID) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .onMoveCommand { direction in
            moveSelection(direction)
        }
        .onSubmit {
            if let entry = filteredEntries.first(where: { $0.id == selectedID }) {
                onSelect(entry)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("No saved clips")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

private struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    let image: NSImage?
    let isSelected: Bool
    let onPreviewImage: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isImageHovered = false
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(minHeight: rowHeight)
        .background(
            GlassSearchBackground(opacity: cardOpacity, cornerRadius: 22)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(isHovered ? 0.62 : 0.42))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .padding(.top, 8)
            .padding(.trailing, 8)
            .help("Delete clip")
        }
        .overlay(alignment: .bottomTrailing) {
            if canExpandText {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(isHovered ? 0.62 : 0.46))
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 6)
                .padding(.bottom, 4)
                .help(isExpanded ? "Collapse clip" : "Expand clip")
            }
        }
        .scaleEffect(isSelected ? 1.004 : effectiveHover ? 1.006 : 1)
        .offset(y: effectiveHover ? -1 : 0)
        .shadow(color: .black.opacity(effectiveHover ? 0.22 : 0.16), radius: effectiveHover ? 18 : 13, y: effectiveHover ? 9 : 7)
        .animation(.easeOut(duration: 0.20), value: effectiveHover)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: isExpanded)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.payload {
        case let .text(text):
            Text(previewText(text))
                .font(.system(size: 14, weight: .regular))
                .lineLimit(isExpanded ? nil : 3)
                .foregroundStyle(.black.opacity(0.86))
                .padding(.trailing, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let image {
                HStack {
                    Spacer(minLength: 0)

                    Button(action: onPreviewImage) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.white.opacity(isImageHovered ? 0.10 : 0))
                            )
                            .scaleEffect(isImageHovered ? 1.010 : 1)
                            .offset(y: isImageHovered ? -1 : 0)
                            .shadow(color: .black.opacity(isImageHovered ? 0.20 : 0), radius: isImageHovered ? 14 : 0, y: 6)
                            .animation(.easeOut(duration: 0.18), value: isImageHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isImageHovered = hovering
                    }

                    Spacer(minLength: 0)
                }
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.05))
                    .frame(maxWidth: .infinity)
                    .frame(height: 118)
            }
        }
    }

    private var cardOpacity: Double {
        if isSelected {
            return 0.14
        }

        return effectiveHover ? 0.16 : 0.08
    }

    private var effectiveHover: Bool {
        isHovered
    }

    private var rowHeight: CGFloat {
        switch entry.payload {
        case .text:
            isExpanded ? 0 : 62
        case .image:
            142
        }
    }

    private var isTextEntry: Bool {
        if case .text = entry.payload {
            return true
        }

        return false
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

private struct ImagePreviewOverlay: View {
    let image: NSImage
    let onPaste: () -> Void
    let onClose: () -> Void

    @State private var isPasteHovered = false

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .clear, cornerRadius: 28)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onTapGesture(perform: onClose)

            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 82)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {}

            VStack {
                HStack {
                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black.opacity(0.76))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.94), in: Circle())
                            .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
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
                    .foregroundStyle(.black.opacity(0.86))
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(isPasteHovered ? Color(white: 0.96) : .white, in: Capsule())
                    .shadow(color: .black.opacity(isPasteHovered ? 0.15 : 0.10), radius: isPasteHovered ? 16 : 11, y: 6)
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

private struct DeleteConfirmationOverlay: View {
    let title: String
    let message: String
    let actionTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isConfirmHovered = false
    @State private var isCancelHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.86))

                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.black.opacity(0.58))
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(.white.opacity(isCancelHovered ? 0.22 : 0.12), in: Capsule())
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
        .background(
            GlassSearchBackground(opacity: 0.18, cornerRadius: 20)
        )
        .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
    }
}

private struct GlassSearchBackground: View {
    let opacity: Double
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            NativeGlassEffectView(style: .regular, cornerRadius: cornerRadius)
            Color.white.opacity(opacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct HeaderBlurBackground: View {
    var body: some View {
        NativeGlassEffectView(style: .clear, cornerRadius: 28)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
