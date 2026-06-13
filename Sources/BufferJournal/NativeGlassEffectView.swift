import AppKit
import SwiftUI

struct NativeGlassEffectView: NSViewRepresentable {
    enum Style {
        case regular
        case clear
    }

    let style: Style
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let view = NSGlassEffectView()
            view.style = nsGlassStyle
            view.cornerRadius = cornerRadius
            view.tintColor = .clear
            return view
        }

        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .inactive
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if #available(macOS 26.0, *), let glassView = view as? NSGlassEffectView {
            glassView.style = nsGlassStyle
            glassView.cornerRadius = cornerRadius
            glassView.tintColor = .clear
            return
        }

        if let visualEffectView = view as? NSVisualEffectView {
            visualEffectView.material = .underWindowBackground
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .inactive
        }
    }

    @available(macOS 26.0, *)
    private var nsGlassStyle: NSGlassEffectView.Style {
        switch style {
        case .regular:
            .regular
        case .clear:
            .clear
        }
    }
}
