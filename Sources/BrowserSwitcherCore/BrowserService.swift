import Foundation

public struct Browser: Equatable {
    public let name: String
    public let bundleID: String
    public let url: URL

    public init(name: String, bundleID: String, url: URL) {
        self.name = name
        self.bundleID = bundleID
        self.url = url
    }
}

public enum WebScheme: String, CaseIterable {
    case http, https
}

public struct DefaultState: Equatable {
    public let http: String?
    public let https: String?

    public init(http: String?, https: String?) {
        self.http = http
        self.https = https
    }

    public func matches(_ bundleID: String) -> Bool {
        http == bundleID && https == bundleID
    }

    public subscript(scheme: WebScheme) -> String? {
        scheme == .http ? http : https
    }
}

@MainActor
public protocol BrowserSystem {
    func applicationURL(bundleID: String) -> URL?
    func defaultBundleID(for scheme: WebScheme) -> String?
    func setDefault(_ browser: Browser, for scheme: WebScheme) async throws
}

public enum SwitchResult: Equatable {
    case success
    case busy
    case unavailable
    case incomplete(DefaultState, String)
}

@MainActor
public final class BrowserService {
    public static let candidates: [(name: String, bundleID: String)] = [
        ("Google Chrome", "com.google.Chrome"),
        ("Tabbit", "com.tabbit-ai.Tabbit"),
        ("Tabbit Browser", "com.tab-browser.Tabbit"),
        ("ego lite", "com.citrolabs.ego.lite"),
        ("Safari", "com.apple.Safari")
    ]

    private let system: BrowserSystem
    public private(set) var isSwitching = false

    public init(system: BrowserSystem) {
        self.system = system
    }

    public func browsers() -> [Browser] {
        Self.candidates.compactMap { candidate in
            guard let url = system.applicationURL(bundleID: candidate.bundleID) else { return nil }
            return Browser(name: candidate.name, bundleID: candidate.bundleID, url: url)
        }
    }

    public func defaults() -> DefaultState {
        DefaultState(http: system.defaultBundleID(for: .http),
                     https: system.defaultBundleID(for: .https))
    }

    public func switchTo(_ browser: Browser) async -> SwitchResult {
        guard !isSwitching else { return .busy }
        guard let currentURL = system.applicationURL(bundleID: browser.bundleID),
              currentURL == browser.url else { return .unavailable }
        isSwitching = true
        defer { isSwitching = false }

        for scheme in WebScheme.allCases {
            if defaults()[scheme] == browser.bundleID { continue }
            do {
                try await system.setDefault(browser, for: scheme)
            } catch {
                let state = defaults()
                if state.matches(browser.bundleID) { return .success }
                return .incomplete(state, error.localizedDescription)
            }
            let state = defaults()
            guard state[scheme] == browser.bundleID else {
                return .incomplete(state, "系统未应用 \(scheme.rawValue.uppercased()) 设置，可能已取消确认。")
            }
        }

        let state = defaults()
        return state.matches(browser.bundleID)
            ? .success
            : .incomplete(state, "系统默认设置与所选浏览器不一致。")
    }
}
