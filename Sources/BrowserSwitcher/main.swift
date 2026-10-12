import AppKit
import BrowserSwitcherCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let service = BrowserService(system: MacBrowserSystem())
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var browsers: [Browser] = []
    private var resultMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = makeStatusIcon()
        statusItem.button?.setAccessibilityLabel("DogSwitch 默认浏览器切换器")
        statusItem.button?.toolTip = "DogSwitch"
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        for name in ["StatusIconTemplate", "StatusIconTemplate@2x"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let representation = NSBitmapImageRep(data: data) else {
                preconditionFailure("Missing packaged menu bar icon: \(name)")
            }
            representation.size = size
            image.addRepresentation(representation)
        }
        image.isTemplate = true
        image.accessibilityDescription = "DogSwitch"
        return image
    }

    private func addLabel(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func displayName(_ bundleID: String?) -> String {
        guard let bundleID else { return "未识别" }
        if let browser = browsers.first(where: { $0.bundleID == bundleID }) { return browser.name }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func stateDescription(_ state: DefaultState) -> String {
        "HTTP：\(displayName(state.http))\nHTTPS：\(displayName(state.https))"
    }

    private func rebuildMenu() {
        browsers = service.browsers()
        let state = service.defaults()
        menu.removeAllItems()
        menu.autoenablesItems = false
        addLabel(service.isSwitching ? "正在切换，请完成系统确认…" : "默认浏览器")
        if state.http == state.https, let current = state.http {
            addLabel("当前：\(displayName(current))")
        } else {
            addLabel("HTTP：\(displayName(state.http))")
            addLabel("HTTPS：\(displayName(state.https))")
        }
        menu.addItem(.separator())
        for (index, browser) in browsers.enumerated() {
            var title = browser.name
            if !state.matches(browser.bundleID) {
                let schemes = WebScheme.allCases.filter { state[$0] == browser.bundleID }
                if !schemes.isEmpty {
                    title += "（\(schemes.map { $0.rawValue.uppercased() }.joined(separator: "、"))）"
                }
            }
            let item = NSMenuItem(title: title, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = state.matches(browser.bundleID) ? .on : .off
            item.isEnabled = !service.isSwitching && !state.matches(browser.bundleID)
            let icon = NSWorkspace.shared.icon(forFile: browser.url.path)
            icon.size = NSSize(width: 18, height: 18)
            item.image = icon
            menu.addItem(item)
        }
        if browsers.isEmpty { addLabel("未发现支持的浏览器") }
        if let resultMessage {
            menu.addItem(.separator())
            addLabel(resultMessage)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        quit.isEnabled = !service.isSwitching
        menu.addItem(quit)
        statusItem.button?.toolTip = service.isSwitching
            ? "正在切换默认浏览器，请完成系统确认"
            : "DogSwitch\n\(stateDescription(state))"
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard browsers.indices.contains(sender.tag), !service.isSwitching else { return }
        let browser = browsers[sender.tag]
        resultMessage = nil
        Task { @MainActor in
            let result = await service.switchTo(browser)
            switch result {
            case .success:
                resultMessage = "已切换为 \(browser.name)"
            case .busy:
                return
            case .unavailable:
                resultMessage = "浏览器已移动或卸载，请重新选择"
                showAlert(title: "无法切换", message: resultMessage!)
            case .incomplete(let state, let reason):
                resultMessage = "切换未完成，请查看当前设置"
                showAlert(title: "切换未完成", message: "\(reason)\n\n当前设置：\n\(stateDescription(state))")
            }
            rebuildMenu()
        }
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) {
        app.run()
    }
}
