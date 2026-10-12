// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrowserSwitcher",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "BrowserSwitcher", targets: ["BrowserSwitcher"])],
    targets: [
        .target(name: "BrowserSwitcherCore"),
        .executableTarget(name: "BrowserSwitcher", dependencies: ["BrowserSwitcherCore"]),
        .executableTarget(name: "BrowserSwitcherCoreTests", dependencies: ["BrowserSwitcherCore"],
                          path: "Tests/BrowserSwitcherCoreTests")
    ]
)
