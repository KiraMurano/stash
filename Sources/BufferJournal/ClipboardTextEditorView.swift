import AppKit
import SwiftUI

struct ClipboardTextEditorView: View {
    let title: String
    let initialText: String
    @ObservedObject var settings: AppSettings
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n
    @FocusState private var isEditorFocused: Bool
    @State private var text: String
    @State private var isCancelHovered = false
    @State private var isSaveHovered = false

    init(
        title: String,
        initialText: String,
        settings: AppSettings,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.initialText = initialText
        self.settings = settings
        self.onCancel = onCancel
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n("Edit text", "Редактирование текста"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            TextEditor(text: $text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(10)
                .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(palette.borderSelected.opacity(0.55), lineWidth: 1)
                )
                .padding(.horizontal, 18)

            HStack(spacing: 10) {
                Spacer()

                Button(action: onCancel) {
                    Text(l10n("Cancel", "Отмена"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 92, height: 34)
                        .background(palette.controlHoverBackground.opacity(isCancelHovered ? 1 : 0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { isCancelHovered = $0 }

                Button {
                    onSave(text)
                } label: {
                    Text(l10n("Save", "Сохранить"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 34)
                        .background(saveBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .onHover { isSaveHovered = $0 }
            }
            .padding(18)
        }
        .frame(minWidth: 420, minHeight: 260)
        .background(palette.windowBackground)
        .preferredColorScheme(settings.themeMode.colorScheme)
        .environment(\.l10n, settings.l10n)
        .onAppear {
            DispatchQueue.main.async {
                isEditorFocused = true
            }
        }
        .onExitCommand(perform: onCancel)
    }

    private var saveBackground: Color {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return palette.iconOpacity(0.16)
        }

        return Color.accentColor.opacity(isSaveHovered ? 0.92 : 0.82)
    }
}

final class TextEditWindowSession {
    let window: NSWindow
    let delegate: TextEditWindowDelegate

    init(window: NSWindow, delegate: TextEditWindowDelegate) {
        self.window = window
        self.delegate = delegate
    }
}

final class TextEditWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
