import AppKit
import BrowserSwitcherCore

@MainActor
final class MacBrowserSystem: BrowserSystem {
    private let workspace = NSWorkspace.shared

    func applicationURL(bundleID: String) -> URL? {
        // Restrict discovery to installed apps, excluding updater and automation caches.
        let roots = ["/Applications/", NSHomeDirectory() + "/Applications/",
                     "/System/Applications/",
                     "/System/Volumes/Preboot/Cryptexes/App/System/Applications/"]
        return workspace.urlsForApplications(withBundleIdentifier: bundleID).first { url in
            let path = url.standardizedFileURL.path
            return roots.contains(where: path.hasPrefix)
                && FileManager.default.fileExists(atPath: path)
                && Bundle(url: url)?.bundleIdentifier == bundleID
        }
    }

    func defaultBundleID(for scheme: WebScheme) -> String? {
        let url = URL(string: "\(scheme.rawValue)://example.com")!
        guard let appURL = workspace.urlForApplication(toOpen: url) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    func setDefault(_ browser: Browser, for scheme: WebScheme) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: scheme.rawValue) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
