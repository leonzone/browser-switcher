import AppKit

// Renders the DMG window background: a subtle canvas with an arrow
// pointing from the app icon toward the Applications folder.
// Usage: swift render-dmg-background.swift <output.png>

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift render-dmg-background.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}

let width: CGFloat = 540
let height: CGFloat = 360

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

NSColor(calibratedRed: 0.976, green: 0.976, blue: 0.984, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Icons sit at Finder positions {140, 185} and {400, 185} in a 540x360 window.
// Finder y is measured from the top; NSImage y is measured from the bottom.
let arrowY = height - 185
let arrowColor = NSColor(calibratedWhite: 0.72, alpha: 1)

let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: 222, y: arrowY))
shaft.line(to: NSPoint(x: 306, y: arrowY))
shaft.lineWidth = 6
shaft.lineCapStyle = .round
arrowColor.setStroke()
shaft.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 292, y: arrowY + 15))
head.line(to: NSPoint(x: 312, y: arrowY))
head.line(to: NSPoint(x: 292, y: arrowY - 15))
head.lineWidth = 6
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render background\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
} catch {
    FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
