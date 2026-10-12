import AppKit

// Renders the DMG window background: a subtle canvas with a playful
// serpentine dashed arrow pointing from the app icon to Applications.
// Usage: swift render-dmg-background.swift <output.png>

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift render-dmg-background.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}

let width = 540
let height = 360

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write("failed to create bitmap\n".data(using: .utf8)!)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(calibratedRed: 0.976, green: 0.976, blue: 0.984, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Icons sit at Finder positions {140, 185} and {400, 185} in a 540x360 window.
// Finder y is measured from the top; bitmap y is measured from the bottom.
let arrowY = CGFloat(height) - 185
let startX: CGFloat = 216
let endX: CGFloat = 310
let amplitude: CGFloat = 12
let periods: CGFloat = 1.5
let arrowColor = NSColor(calibratedRed: 0.42, green: 0.52, blue: 0.74, alpha: 1)

// Serpentine path: sine wave sampled densely, stroked with a dash pattern.
let wave = NSBezierPath()
let steps = 120
for i in 0...steps {
    let t = CGFloat(i) / CGFloat(steps)
    let x = startX + t * (endX - startX)
    let y = arrowY + amplitude * sin(t * periods * 2 * .pi)
    if i == 0 {
        wave.move(to: NSPoint(x: x, y: y))
    } else {
        wave.line(to: NSPoint(x: x, y: y))
    }
}
wave.lineWidth = 6
wave.lineCapStyle = .round
wave.lineJoinStyle = .round
wave.setLineDash([12, 8], count: 2, phase: 0)
arrowColor.setStroke()
wave.stroke()

// Solid arrowhead pointing right at the end of the wave.
let tipY = arrowY + amplitude * sin(periods * 2 * .pi)
let head = NSBezierPath()
head.move(to: NSPoint(x: endX - 15, y: tipY + 14))
head.line(to: NSPoint(x: endX + 5, y: tipY))
head.line(to: NSPoint(x: endX - 15, y: tipY - 14))
head.lineWidth = 6
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render background\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
} catch {
    FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
