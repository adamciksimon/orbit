// Renders design/AppIcon.svg into every size of the app's AppIcon asset,
// adding the soft drop shadow macOS icons carry.
//
//   swift orbit-app/scripts/render-icon.swift

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appending(path: "design/AppIcon.svg")
let output = root.appending(path: "Orbit/Assets.xcassets/AppIcon.appiconset")

guard let svg = NSImage(contentsOf: source) else {
    fatalError("Could not load \(source.path)")
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("Could not allocate a \(size)px bitmap") }

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let scale = CGFloat(size) / 1024
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    shadow.shadowBlurRadius = 24 * scale
    shadow.set()

    svg.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    let png = bitmap.representation(using: .png, properties: [:])!
    try png.write(to: output.appending(path: "icon_\(size).png"))
    print("icon_\(size).png")
}
