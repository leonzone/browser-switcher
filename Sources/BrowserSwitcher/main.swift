import AppKit
import BrowserSwitcherCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let system = MacBrowserSystem()
    private lazy var service = BrowserService(system: system)
    private let ruleStore = RuleStore()
    private var config = RoutingConfig()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var browsers: [Browser] = []
    private var resultMessage: String?
    private var rulesWindow: RulesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = makeStatusIcon()
        statusItem.button?.setAccessibilityLabel("DogSwitch 默认浏览器切换器")
        statusItem.button?.toolTip = "DogSwitch"
        menu.delegate = self
        statusItem.menu = menu
        reloadConfig()
        rebuildMenu()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        reloadConfig()
        let router = Router(rules: config.rules, fallbackBundleID: config.fallbackBundleID)
        for url in urls {
            route(url, with: router)
        }
    }

    private func route(_ url: URL, with router: Router) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        var bundleID = router.resolve(url)
        var appURL = system.applicationURL(bundleID: bundleID)
        if appURL == nil, bundleID != router.fallbackBundleID {
            bundleID = router.fallbackBundleID
            appURL = system.applicationURL(bundleID: bundleID)
        }
        guard let appURL else {
            resultMessage = "无法打开链接：未找到目标浏览器"
            rebuildMenu()
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: appURL,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard error != nil else { return }
            Task { @MainActor in
                self.resultMessage = "打开链接失败"
                self.rebuildMenu()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        reloadConfig()
        rebuildMenu()
    }

    private func reloadConfig() {
        config = ruleStore.load()
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
        if bundleID == Router.selfBundleID { return "DogSwitch" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func stateDescription(_ state: DefaultState) -> String {
        "HTTP：\(displayName(state.http))\nHTTPS：\(displayName(state.https))"
    }

    private func browserIcon(_ browser: Browser) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: browser.url.path)
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }

    private func rebuildMenu() {
        browsers = service.browsers()
        let state = service.defaults()
        let selfIsDefault = state.matches(Router.selfBundleID)
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

        let makeDefault = NSMenuItem(title: "将 DogSwitch 设为默认浏览器",
                                     action: #selector(makeDefaultBrowser), keyEquivalent: "")
        makeDefault.target = self
        makeDefault.state = selfIsDefault ? .on : .off
        makeDefault.isEnabled = !service.isSwitching && !selfIsDefault
        menu.addItem(makeDefault)
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
            item.image = browserIcon(browser)
            menu.addItem(item)
        }
        if browsers.isEmpty { addLabel("未发现支持的浏览器") }
        menu.addItem(.separator())

        let fallbackItem = NSMenuItem(title: "未匹配链接的浏览器", action: nil, keyEquivalent: "")
        let fallbackMenu = NSMenu()
        for (index, browser) in browsers.enumerated() {
            let item = NSMenuItem(title: browser.name, action: #selector(selectFallback(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = config.fallbackBundleID == browser.bundleID ? .on : .off
            item.image = browserIcon(browser)
            fallbackMenu.addItem(item)
        }
        if browsers.isEmpty {
            let empty = NSMenuItem(title: "未发现支持的浏览器", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            fallbackMenu.addItem(empty)
        }
        fallbackItem.submenu = fallbackMenu
        menu.addItem(fallbackItem)

        let rulesItem = NSMenuItem(title: "路由规则…", action: #selector(openRules), keyEquivalent: "")
        rulesItem.target = self
        menu.addItem(rulesItem)

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

    @objc private func makeDefaultBrowser() {
        guard let url = system.applicationURL(bundleID: Router.selfBundleID) else {
            resultMessage = "未找到 DogSwitch 安装位置"
            rebuildMenu()
            return
        }
        performSwitch(to: Browser(name: "DogSwitch", bundleID: Router.selfBundleID, url: url))
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard browsers.indices.contains(sender.tag), !service.isSwitching else { return }
        performSwitch(to: browsers[sender.tag])
    }

    private func performSwitch(to browser: Browser) {
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

    @objc private func selectFallback(_ sender: NSMenuItem) {
        guard browsers.indices.contains(sender.tag) else { return }
        config.fallbackBundleID = browsers[sender.tag].bundleID
        ruleStore.save(config)
        rebuildMenu()
    }

    @objc private func openRules() {
        if rulesWindow == nil {
            rulesWindow = RulesWindowController(store: ruleStore) { [weak self] in
                self?.browsers ?? []
            }
            rulesWindow?.onChange = { [weak self] in
                self?.reloadConfig()
                self?.rebuildMenu()
            }
        }
        rulesWindow?.show()
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
