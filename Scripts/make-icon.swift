#!/usr/bin/env swift
// Generates Resources/AppIcon.icns: a warm gradient tile with a paw print.
// Run from the repository root:  swift Scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
let output = root.appendingPathComponent("Resources/AppIcon.icns")

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("Could not create bitmap") }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("No graphics context") }
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // macOS icons sit inside a rounded square with a little breathing room.
    let inset = size * 0.06
    let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let path = NSBezierPath(roundedRect: tile, xRadius: size * 0.22, yRadius: size * 0.22)

    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 1.00, green: 0.68, blue: 0.32, alpha: 1),
        ending: NSColor(calibratedRed: 0.91, green: 0.33, blue: 0.42, alpha: 1)
    )!
    gradient.draw(in: path, angle: -65)

    // Subtle inner highlight along the top edge.
    NSColor.white.withAlphaComponent(0.18).setStroke()
    path.lineWidth = max(1, size * 0.01)
    path.stroke()

    let glyph = "🐾" as NSString
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size * 0.58)]
    let glyphSize = glyph.size(withAttributes: attributes)
    let origin = NSPoint(x: (size - glyphSize.width) / 2, y: (size - glyphSize.height) / 2 + size * 0.02)
    glyph.draw(at: origin, withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
    return png
}

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in entries {
    try render(pixels: pixels).write(to: iconset.appendingPathComponent("\(name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
try? fileManager.removeItem(at: iconset)
print("✓ Wrote \(output.path)")
