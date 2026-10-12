import Foundation
import BrowserSwitcherCore

@MainActor private var failures: [String] = []

@MainActor
private func recordFailure(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    failures.append("\(file):\(line): \(message)")
}

@MainActor
private func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value { recordFailure("Expected true", file: file, line: line) }
}

@MainActor
private func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value { recordFailure("Expected false", file: file, line: line) }
}

@MainActor
private func expectEqual<T: Equatable>(_ actual: T, _ expected: T,
                                      file: StaticString = #filePath, line: UInt = #line) {
    if actual != expected {
        recordFailure("Expected \(expected), got \(actual)", file: file, line: line)
    }
}

@MainActor
private final class FakeSystem: BrowserSystem {
    var installed: [String: URL] = [:]
    var handlers: [WebScheme: String] = [.http: "old", .https: "old"]
    var calls: [WebScheme] = []
    var action: ((Browser, WebScheme) async throws -> Void)?

    func applicationURL(bundleID: String) -> URL? { installed[bundleID] }
    func defaultBundleID(for scheme: WebScheme) -> String? { handlers[scheme] }
    func setDefault(_ browser: Browser, for scheme: WebScheme) async throws {
        calls.append(scheme)
        if let action {
            try await action(browser, scheme)
        } else {
            handlers[scheme] = browser.bundleID
        }
    }
}

final class BrowserServiceTests {
    @MainActor
    private func fixture() -> (FakeSystem, BrowserService, Browser) {
        let system = FakeSystem()
        let browser = Browser(name: "Google Chrome", bundleID: "com.google.Chrome",
                              url: URL(fileURLWithPath: "/Applications/Google Chrome.app"))
        system.installed[browser.bundleID] = browser.url
        return (system, BrowserService(system: system), browser)
    }

    @MainActor
    func testDiscoveryExcludesUnlistedApplicationsAndMissingBrowsers() async {
        let (system, service, browser) = fixture()
        system.installed["com.example.Other"] = URL(fileURLWithPath: "/Applications/Other.app")
        expectEqual(service.browsers(), [browser])
        system.installed = [:]
        expectTrue(service.browsers().isEmpty)
    }

    @MainActor
    func testBothTabbitApplicationsHaveDistinctIdentity() async {
        let (system, service, _) = fixture()
        for candidate in BrowserService.candidates where candidate.name.hasPrefix("Tabbit") {
            system.installed[candidate.bundleID] = URL(fileURLWithPath: "/Applications/\(candidate.name).app")
        }
        expectEqual(service.browsers().filter { $0.name.hasPrefix("Tabbit") }.count, 2)
    }

    @MainActor
    func testSwitchVerifiesBothProtocols() async {
        let (system, service, browser) = fixture()
        let result = await service.switchTo(browser)
        expectEqual(result, .success)
        expectEqual(system.calls, [.http, .https])
        expectTrue(service.defaults().matches(browser.bundleID))
        expectFalse(service.isSwitching)
    }

    @MainActor
    func testAlreadyDefaultDoesNotWrite() async {
        let (system, service, browser) = fixture()
        system.handlers = [.http: browser.bundleID, .https: browser.bundleID]
        let result = await service.switchTo(browser)
        expectEqual(result, .success)
        expectTrue(system.calls.isEmpty)
    }

    @MainActor
    func testMixedStateOnlyChangesRemainingProtocol() async {
        let (system, service, browser) = fixture()
        system.handlers[.http] = browser.bundleID
        expectFalse(service.defaults().matches(browser.bundleID))
        let result = await service.switchTo(browser)
        expectEqual(result, .success)
        expectEqual(system.calls, [.https])
    }

    @MainActor
    func testCancellationStopsBeforeSecondProtocol() async {
        let (system, service, browser) = fixture()
        system.action = { _, _ in throw NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError) }
        let result = await service.switchTo(browser)
        guard case .incomplete(let state, _) = result else { return recordFailure("Expected cancellation") }
        expectEqual(state, DefaultState(http: "old", https: "old"))
        expectEqual(system.calls, [.http])
        expectFalse(service.isSwitching)
    }

    @MainActor
    func testSuccessfulCallbackWithoutActualChangeIsNotSuccess() async {
        let (system, service, browser) = fixture()
        system.action = { _, _ in }
        let result = await service.switchTo(browser)
        guard case .incomplete = result else { return recordFailure("Must verify actual defaults") }
        expectEqual(system.calls, [.http])
    }

    @MainActor
    func testPartialFailurePreservesActualStateWithoutRollback() async {
        let (system, service, browser) = fixture()
        system.action = { [unowned system] selected, scheme in
            if scheme == .https { throw NSError(domain: "Test", code: 1) }
            system.handlers[scheme] = selected.bundleID
        }
        let result = await service.switchTo(browser)
        guard case .incomplete(let state, _) = result else { return recordFailure("Expected partial failure") }
        expectEqual(state, DefaultState(http: browser.bundleID, https: "old"))
        expectEqual(system.calls, [.http, .https])
    }

    @MainActor
    func testRemovedOrMovedBrowserDoesNotWrite() async {
        let (system, service, browser) = fixture()
        system.installed = [:]
        let removed = await service.switchTo(browser)
        expectEqual(removed, .unavailable)
        system.installed[browser.bundleID] = URL(fileURLWithPath: "/Applications/Moved.app")
        let moved = await service.switchTo(browser)
        expectEqual(moved, .unavailable)
        expectTrue(system.calls.isEmpty)
    }

    @MainActor
    func testRepeatedSelectionIsRejectedWhileWaitingForSystem() async {
        let (system, service, browser) = fixture()
        var gate: CheckedContinuation<Void, Never>?
        system.action = { [unowned system] selected, scheme in
            if scheme == .http {
                await withCheckedContinuation { gate = $0 }
            }
            system.handlers[scheme] = selected.bundleID
        }
        let first = Task { await service.switchTo(browser) }
        while gate == nil { await Task.yield() }
        expectTrue(service.isSwitching)
        let second = await service.switchTo(browser)
        expectEqual(second, .busy)
        gate?.resume()
        let result = await first.value
        expectEqual(result, .success)
        expectEqual(system.calls, [.http, .https])
    }

    @MainActor
    func testUnknownDefaultsAreNotReportedAsMatching() async {
        let (system, service, browser) = fixture()
        system.handlers = [:]
        expectEqual(service.defaults(), DefaultState(http: nil, https: nil))
        expectFalse(service.defaults().matches(browser.bundleID))
    }
}

@main
struct TestRunner {
    @MainActor
    static func main() async {
        let suite = BrowserServiceTests()
        let tests: [(String, () async -> Void)] = [
            ("candidate filtering", suite.testDiscoveryExcludesUnlistedApplicationsAndMissingBrowsers),
            ("distinct Tabbit identities", suite.testBothTabbitApplicationsHaveDistinctIdentity),
            ("dual protocol switch", suite.testSwitchVerifiesBothProtocols),
            ("already default", suite.testAlreadyDefaultDoesNotWrite),
            ("mixed defaults", suite.testMixedStateOnlyChangesRemainingProtocol),
            ("cancellation", suite.testCancellationStopsBeforeSecondProtocol),
            ("readback verification", suite.testSuccessfulCallbackWithoutActualChangeIsNotSuccess),
            ("partial failure", suite.testPartialFailurePreservesActualStateWithoutRollback),
            ("removed or moved browser", suite.testRemovedOrMovedBrowserDoesNotWrite),
            ("duplicate submission", suite.testRepeatedSelectionIsRejectedWhileWaitingForSystem),
            ("unknown defaults", suite.testUnknownDefaultsAreNotReportedAsMatching)
        ]
        var passed = 0
        for (name, test) in tests {
            let before = failures.count
            await test()
            if failures.count == before {
                passed += 1
                print("PASS: \(name)")
            } else {
                print("FAIL: \(name)")
            }
        }
        failures.forEach { print($0) }
        print("\(passed)/\(tests.count) tests passed")
        exit(failures.isEmpty ? 0 : 1)
    }
}
