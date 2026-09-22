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
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let view = NSGlassEffectView()
            view.style = nsGlassStyle
            view.cornerRadius = cornerRadius
            view.tintColor = .clear
            return view
        }
        #endif

        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .inactive
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), let glassView = view as? NSGlassEffectView {
            glassView.style = nsGlassStyle
            glassView.cornerRadius = cornerRadius
            glassView.tintColor = .clear
            return
        }
        #endif

        if let visualEffectView = view as? NSVisualEffectView {
            visualEffectView.material = .underWindowBackground
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .inactive
        }
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    private var nsGlassStyle: NSGlassEffectView.Style {
        switch style {
        case .regular:
            return .regular
        case .clear:
            return .clear
        }
    }
    #endif
}
