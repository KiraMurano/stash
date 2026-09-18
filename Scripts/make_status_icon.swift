// Builds the menu bar template icon from Resources/StatusIconSource.png
// (black glyph on white): dark pixels become opaque, light ones transparent,
// the glyph is cropped and scaled to 18pt tall (@1x and @2x).
// Usage: swift Scripts/make_status_icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let sourceImage = NSImage(contentsOf: root.appendingPathComponent("Resources/StatusIconSource.png"))!
let source = NSBitmapImageRep(data: sourceImage.tiffRepresentation!)!
let width = source.pixelsWide, height = source.pixelsHigh

// Luminance → alpha mask, tracking the glyph's bounding box.
let mask = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    for x in 0..<width {
        let color = source.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        let luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
        let alpha = max(0, min(1, (1 - luminance) * color.alphaComponent))
        mask.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: alpha), atX: x, y: y)
        if alpha > 0.05 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
// colorAt/setColor use top-left origin; drawing uses bottom-left.
let crop = NSRect(x: minX, y: height - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
let glyph = NSImage(size: NSSize(width: width, height: height))
glyph.addRepresentation(mask)

func render(scale: Int) -> Data {
    let pixelHeight = 18 * scale
    let pixelWidth = Int((CGFloat(pixelHeight) * crop.width / crop.height).rounded())
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    glyph.draw(in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight), from: crop, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    rep.size = NSSize(width: pixelWidth / scale, height: 18)
    return rep.representation(using: .png, properties: [:])!
}

try render(scale: 1).write(to: root.appendingPathComponent("Resources/StatusIcon.png"))
try render(scale: 2).write(to: root.appendingPathComponent("Resources/StatusIcon@2x.png"))
print("Resources/StatusIcon.png, Resources/StatusIcon@2x.png")
