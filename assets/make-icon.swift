// Renders the app icon: hourglass glyph on a dark rounded rect.
// Run via `make icon` — writes assets/icon_1024.png.
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS-style rounded rect with the standard ~10% margin
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1).setFill()
path.fill()

let glyph = "⧗" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 560, weight: .medium),
    .foregroundColor: NSColor.white,
]
let glyphSize = glyph.size(withAttributes: attrs)
glyph.draw(
    at: NSPoint(x: (size - glyphSize.width) / 2, y: (size - glyphSize.height) / 2),
    withAttributes: attrs)

image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "assets/icon_1024.png"))
