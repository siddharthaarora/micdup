#!/usr/bin/env swift
// Generates MicDup AppIcon.icns — black rounded-rect with white microphone.
// Usage: swift generate_icon.swift <output_dir>

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Black rounded-rect background
    let radius = size * 0.2
    let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    bg.fill()

    // Subtle dark border
    NSColor(white: 0.2, alpha: 1.0).setStroke()
    bg.lineWidth = size * 0.01
    bg.stroke()

    // White microphone — scaled to icon size
    let cx = size / 2
    let cy = size / 2
    let scale = size / 512.0
    NSColor.white.setFill()
    NSColor.white.setStroke()

    // Mic head — capsule
    let headW = 120 * scale
    let headH = 180 * scale
    let headRect = NSRect(
        x: cx - headW / 2,
        y: cy + 10 * scale,
        width: headW,
        height: headH
    )
    let head = NSBezierPath(roundedRect: headRect, xRadius: headW / 2, yRadius: headW / 2)
    head.fill()

    // Cradle arc
    let cradle = NSBezierPath()
    cradle.lineWidth = 22 * scale
    cradle.lineCapStyle = .round
    cradle.appendArc(
        withCenter: NSPoint(x: cx, y: cy + 10 * scale),
        radius: 100 * scale,
        startAngle: 200,
        endAngle: 340,
        clockwise: false
    )
    cradle.stroke()

    // Vertical stem
    let stem = NSBezierPath()
    stem.lineWidth = 22 * scale
    stem.lineCapStyle = .round
    stem.move(to: NSPoint(x: cx, y: cy - 90 * scale))
    stem.line(to: NSPoint(x: cx, y: cy - 50 * scale))
    stem.stroke()

    // Horizontal base
    let base = NSBezierPath()
    base.lineWidth = 22 * scale
    base.lineCapStyle = .round
    base.move(to: NSPoint(x: cx - 70 * scale, y: cy - 105 * scale))
    base.line(to: NSPoint(x: cx + 70 * scale, y: cy - 105 * scale))
    base.stroke()

    image.unlockFocus()
    return image
}

// Create .iconset directory
let iconsetPath = "\(outputDir)/AppIcon.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all required sizes
let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in specs {
    let img = drawIcon(size: size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    let path = "\(iconsetPath)/\(name)"
    try! data.write(to: URL(fileURLWithPath: path))
}

// Convert iconset to icns
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetPath, "-o", "\(outputDir)/AppIcon.icns"]
try! proc.run()
proc.waitUntilExit()

// Clean up iconset
try? fm.removeItem(atPath: iconsetPath)

if proc.terminationStatus == 0 {
    print("Generated \(outputDir)/AppIcon.icns")
} else {
    print("iconutil failed with status \(proc.terminationStatus)")
    exit(1)
}
