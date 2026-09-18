// Draws the DMG window background: white, with an orange arc from the app icon
// to the Applications folder (concept .concepts/2026-09-18-dmg-window.html, 1.1 + 2.2).
// Window content is 540×380 pt; icon centres are (140, 170) and (400, 170).
// Usage: swift Scripts/make_dmg_background.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let size = NSSize(width: 540, height: 380)
let orange = NSColor(srgbRed: 0xF4 / 255.0, green: 0x6A / 255.0, blue: 0x25 / 255.0, alpha: 1)

func render(scale: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    // The concept draws in top-left coordinates; flip y.
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: size.height - y) }
    let arc = NSBezierPath()
    arc.move(to: p(210, 128))
    arc.curve(to: p(330, 128), controlPoint1: p(245, 92), controlPoint2: p(295, 92))
    let head = NSBezierPath()
    head.move(to: p(314, 126))
    head.line(to: p(331, 130))
    head.line(to: p(330, 112))
    for path in [arc, head] {
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        orange.setStroke()
        path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try render(scale: 1).write(to: root.appendingPathComponent("Resources/DMGBackground.png"))
try render(scale: 2).write(to: root.appendingPathComponent("Resources/DMGBackground@2x.png"))
print("Resources/DMGBackground.png, Resources/DMGBackground@2x.png")
