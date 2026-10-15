import Foundation

public struct RoutingRule: Codable, Equatable, Identifiable {
    public let id: UUID
    public var pattern: String
    public var browserBundleID: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), pattern: String, browserBundleID: String, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.browserBundleID = browserBundleID
        self.isEnabled = isEnabled
    }
}

public struct Router: Equatable {
    public static let selfBundleID = "io.reiserxu.BrowserSwitcher"
    public static let defaultFallbackBundleID = "com.apple.Safari"

    public var rules: [RoutingRule]
    public var fallbackBundleID: String

    public init(rules: [RoutingRule], fallbackBundleID: String) {
        self.rules = rules
        self.fallbackBundleID = fallbackBundleID
    }

    public func resolve(_ url: URL) -> String {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return fallbackBundleID }
        for rule in rules where rule.isEnabled {
            let pattern = rule.pattern.trimmingCharacters(in: .whitespaces).lowercased()
            guard !pattern.isEmpty else { continue }
            if host == pattern || host.hasSuffix("." + pattern) {
                return rule.browserBundleID == Self.selfBundleID ? fallbackBundleID : rule.browserBundleID
            }
        }
        return fallbackBundleID
    }
}

public struct RoutingConfig: Codable, Equatable {
    public var rules: [RoutingRule]
    public var fallbackBundleID: String

    public init(rules: [RoutingRule] = [], fallbackBundleID: String = Router.defaultFallbackBundleID) {
        self.rules = rules
        self.fallbackBundleID = fallbackBundleID
    }
}

public struct RuleStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.init(fileURL: support.appendingPathComponent("DogSwitch/rules.json"))
    }

    public func load() -> RoutingConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(RoutingConfig.self, from: data) else {
            return RoutingConfig()
        }
        return config
    }

    public func save(_ config: RoutingConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
