import AppKit
import BrowserSwitcherCore

@MainActor
final class RulesWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let store: RuleStore
    private let browsersProvider: () -> [Browser]
    private var config: RoutingConfig
    var onChange: (() -> Void)?

    private let window: NSWindow
    private let tableView = NSTableView()

    private let enabledColumn = NSUserInterfaceItemIdentifier("enabled")
    private let patternColumn = NSUserInterfaceItemIdentifier("pattern")
    private let browserColumn = NSUserInterfaceItemIdentifier("browser")

    init(store: RuleStore, browsers: @escaping () -> [Browser]) {
        self.store = store
        self.browsersProvider = browsers
        self.config = store.load()

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "路由规则"
        window.minSize = NSSize(width: 420, height: 220)
        window.isReleasedWhenClosed = false
        window.center()

        super.init()

        window.delegate = self
        buildLayout()
    }

    func show() {
        config = store.load()
        tableView.reloadData()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        onChange?()
    }

    private func buildLayout() {
        guard let content = window.contentView else { return }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 48, width: content.bounds.width,
                                                    height: content.bounds.height - 48))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let enabled = NSTableColumn(identifier: enabledColumn)
        enabled.title = "启用"
        enabled.width = 44
        enabled.minWidth = 44
        enabled.maxWidth = 44
        enabled.isEditable = true
        let checkbox = NSButtonCell()
        checkbox.setButtonType(.switch)
        checkbox.title = ""
        checkbox.controlSize = .small
        enabled.dataCell = checkbox

        let pattern = NSTableColumn(identifier: patternColumn)
        pattern.title = "域名规则"
        pattern.width = 236
        pattern.minWidth = 120
        pattern.isEditable = true
        let textCell = NSTextFieldCell()
        textCell.isEditable = true
        textCell.isScrollable = true
        textCell.placeholderString = "example.com"
        pattern.dataCell = textCell

        let browser = NSTableColumn(identifier: browserColumn)
        browser.title = "目标浏览器"
        browser.width = 220
        browser.minWidth = 140
        browser.isEditable = true
        let popup = NSPopUpButtonCell(textCell: "", pullsDown: false)
        popup.controlSize = .small
        popup.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        browser.dataCell = popup

        tableView.addTableColumn(enabled)
        tableView.addTableColumn(pattern)
        tableView.addTableColumn(browser)
        tableView.headerView = NSTableHeaderView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 28
        tableView.usesAlternatingRowBackgroundColors = true
        scrollView.documentView = tableView
        content.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 12, y: 12, width: 26, height: 23))
        addButton.bezelStyle = .rounded
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "添加规则")
        addButton.title = ""
        addButton.target = self
        addButton.action = #selector(addRule)
        addButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        content.addSubview(addButton)

        let removeButton = NSButton(frame: NSRect(x: 42, y: 12, width: 26, height: 23))
        removeButton.bezelStyle = .rounded
        removeButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "删除规则")
        removeButton.title = ""
        removeButton.target = self
        removeButton.action = #selector(removeRule)
        removeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        content.addSubview(removeButton)

        let hint = NSTextField(labelWithString: "按顺序匹配第一条启用的规则；都不匹配的链接用菜单里选的浏览器打开")
        hint.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 84, y: 14, width: content.bounds.width - 96, height: 20)
        hint.autoresizingMask = [.width, .maxYMargin]
        content.addSubview(hint)
    }

    private func persist() {
        store.save(config)
        onChange?()
    }

    @objc private func addRule() {
        let target = browsersProvider().first?.bundleID ?? Router.defaultFallbackBundleID
        config.rules.append(RoutingRule(pattern: "example.com", browserBundleID: target))
        persist()
        tableView.reloadData()
        let row = config.rules.count - 1
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.editColumn(2, row: row, with: nil, select: true)
    }

    @objc private func removeRule() {
        let row = tableView.selectedRow
        guard config.rules.indices.contains(row) else { return }
        config.rules.remove(at: row)
        persist()
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        config.rules.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard config.rules.indices.contains(row) else { return nil }
        let rule = config.rules[row]
        switch tableColumn?.identifier {
        case enabledColumn: return NSNumber(value: rule.isEnabled)
        case patternColumn: return rule.pattern
        case browserColumn:
            let browsers = browsersProvider()
            return NSNumber(value: browsers.firstIndex { $0.bundleID == rule.browserBundleID } ?? 0)
        default: return nil
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?,
                   for tableColumn: NSTableColumn?, row: Int) {
        guard config.rules.indices.contains(row) else { return }
        switch tableColumn?.identifier {
        case enabledColumn:
            config.rules[row].isEnabled = (object as? NSNumber)?.boolValue ?? false
        case patternColumn:
            config.rules[row].pattern = (object as? String) ?? config.rules[row].pattern
        case browserColumn:
            guard let index = (object as? NSNumber)?.intValue else { return }
            let browsers = browsersProvider()
            if browsers.indices.contains(index) {
                config.rules[row].browserBundleID = browsers[index].bundleID
            }
        default:
            return
        }
        persist()
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any,
                   for tableColumn: NSTableColumn?, row: Int) {
        guard tableColumn?.identifier == browserColumn,
              config.rules.indices.contains(row),
              let popup = cell as? NSPopUpButtonCell else { return }
        let rule = config.rules[row]
        let browsers = browsersProvider()
        popup.removeAllItems()
        popup.addItems(withTitles: browsers.map(\.name))
        var index = browsers.firstIndex { $0.bundleID == rule.browserBundleID }
        if index == nil {
            popup.addItem(withTitle: rule.browserBundleID)
            index = popup.numberOfItems - 1
        }
        popup.selectItem(at: index ?? 0)
    }
}
