import Foundation

// Builds a PNG-based .icns from pre-sized PNGs, preserving their
// (pngquant-optimized) bitstreams — iconutil would re-encode them larger.
// Usage: swift build-icns.swift <output.icns> <iconset-dir>

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write("usage: swift build-icns.swift <output.icns> <iconset-dir>\n".data(using: .utf8)!)
    exit(2)
}

let outputPath = CommandLine.arguments[1]
let iconsetDir = CommandLine.arguments[2]

// icns element type -> source PNG in the iconset.
let entries: [(type: String, file: String)] = [
    ("icp4", "icon_16x16.png"),        // 16x16
    ("icp5", "icon_16x16@2x.png"),     // 32x32
    ("icp6", "icon_32x32@2x.png"),     // 64x64
    ("ic07", "icon_128x128.png"),      // 128x128
    ("ic08", "icon_128x128@2x.png"),   // 256x256
    ("ic09", "icon_256x256@2x.png"),   // 512x512
    ("ic10", "icon_512x512@2x.png"),   // 1024x1024
]

var body = Data()
for entry in entries {
    let fileURL = URL(fileURLWithPath: iconsetDir).appendingPathComponent(entry.file)
    guard let png = try? Data(contentsOf: fileURL) else {
        FileHandle.standardError.write("missing \(entry.file)\n".data(using: .utf8)!)
        exit(1)
    }
    guard let type = entry.type.data(using: .ascii), type.count == 4 else {
        FileHandle.standardError.write("bad type \(entry.type)\n".data(using: .utf8)!)
        exit(1)
    }
    var length = UInt32(8 + png.count).bigEndian
    body.append(type)
    body.append(Data(bytes: &length, count: 4))
    body.append(png)
}

var icns = Data()
icns.append("icns".data(using: .ascii)!)
var totalLength = UInt32(8 + body.count).bigEndian
icns.append(Data(bytes: &totalLength, count: 4))
icns.append(body)

do {
    try icns.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
