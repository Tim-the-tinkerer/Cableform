#!/usr/bin/env swift
import AppKit

// Cream telegram form icon with crimson banner and perforation stub.

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)

// Background
NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.14, alpha: 1).setFill()
NSBezierPath(rect: rect).fill()

// Paper card
let card = NSRect(x: 140, y: 120, width: 744, height: 780)
NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.80, alpha: 1).setFill()
let cardPath = NSBezierPath(roundedRect: card, xRadius: 28, yRadius: 28)
cardPath.fill()

// Stub
let stub = NSRect(x: 140, y: 120, width: 70, height: 780)
NSColor(calibratedRed: 0.90, green: 0.84, blue: 0.70, alpha: 1).setFill()
NSBezierPath(rect: stub).fill()
NSColor(calibratedRed: 0.38, green: 0.30, blue: 0.22, alpha: 0.35).setFill()
var y: CGFloat = 160
while y < 860 {
    NSBezierPath(ovalIn: NSRect(x: 158, y: y, width: 34, height: 34)).fill()
    y += 70
}

// Banner
let banner = NSRect(x: 230, y: 720, width: 620, height: 120)
NSColor(calibratedRed: 0.55, green: 0.12, blue: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: banner, xRadius: 8, yRadius: 8).fill()

let title = "CABLE"
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 72, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.99, green: 0.95, blue: 0.88, alpha: 1),
]
let tSize = title.size(withAttributes: attrs)
title.draw(at: NSPoint(x: banner.midX - tSize.width / 2, y: banner.midY - tSize.height / 2 + 4), withAttributes: attrs)

// Ruled lines
NSColor(calibratedRed: 0.25, green: 0.32, blue: 0.55, alpha: 0.4).setStroke()
for i in 0..<5 {
    let ly = 600 - CGFloat(i) * 70
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 260, y: ly))
    p.line(to: NSPoint(x: 820, y: ly))
    p.lineWidth = 6
    p.stroke()
}

// Fake typewritten dashes of message
NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1).setFill()
let segments: [(CGFloat, CGFloat, CGFloat)] = [
    (260, 620, 280), (560, 620, 160),
    (260, 550, 420),
    (260, 480, 200), (500, 480, 240),
    (260, 410, 360),
]
for (x, ly, w) in segments {
    NSBezierPath(roundedRect: NSRect(x: x, y: ly, width: w, height: 18), xRadius: 4, yRadius: 4).fill()
}

// Crimson border
NSColor(calibratedRed: 0.55, green: 0.12, blue: 0.12, alpha: 1).setStroke()
let border = NSBezierPath(roundedRect: card.insetBy(dx: 12, dy: 12), xRadius: 20, yRadius: 20)
border.lineWidth = 10
border.stroke()

image.unlockFocus()

// Write PNG + icns set
let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Assets", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func png(_ img: NSImage) -> Data? {
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

let bigURL = outDir.appendingPathComponent("AppIcon-1024.png")
if let data = png(image) {
    try? data.write(to: bigURL)
    print("Wrote \(bigURL.path)")
}

// iconset
let iconset = outDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("diana@2x_placeholder", 0), // skip
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

for (name, px) in sizes where px > 0 {
    let scaled = NSImage(size: NSSize(width: px, height: px))
    scaled.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy, fraction: 1)
    scaled.unlockFocus()
    if let data = png(scaled) {
        try? data.write(to: iconset.appendingPathComponent(name))
    }
}

let icns = outDir.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try? proc.run()
proc.waitUntilExit()
if proc.terminationStatus == 0 {
    print("Wrote \(icns.path)")
} else {
    print("iconutil failed (status \(proc.terminationStatus)); PNG still available")
}
