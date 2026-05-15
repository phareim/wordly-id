import XCTest
@testable import WordlyRefs

final class ReferenceRouterTests: XCTestCase {
    func test_sameSchemeAsHostNavigatesInApp() {
        var inAppCalls: [(scheme: String, id: String)] = []
        let router = ReferenceRouter(
            hostScheme: "write",
            openInApp: { scheme, id in inAppCalls.append((scheme, id)); return true },
            openURL: { _ in XCTFail("should not openURL"); return true }
        )
        let ok = router.handleTap(scheme: "write", wordlyID: "W-A-B-C")
        XCTAssertTrue(ok)
        XCTAssertEqual(inAppCalls.count, 1)
        XCTAssertEqual(inAppCalls[0].scheme, "write")
        XCTAssertEqual(inAppCalls[0].id, "W-A-B-C")
    }

    func test_differentSchemeOpensURL() {
        var urlsOpened: [URL] = []
        let router = ReferenceRouter(
            hostScheme: "write",
            openInApp: { _, _ in XCTFail("should not openInApp"); return true },
            openURL: { url in urlsOpened.append(url); return true }
        )
        let ok = router.handleTap(scheme: "do", wordlyID: "DO-A-B-C")
        XCTAssertTrue(ok)
        XCTAssertEqual(urlsOpened.count, 1)
        XCTAssertEqual(urlsOpened[0].absoluteString, "do://do/DO-A-B-C")
    }

    func test_urlIncludesPathSegmentForKindName() {
        var urlsOpened: [URL] = []
        let router = ReferenceRouter(
            hostScheme: "do",
            openInApp: { _, _ in true },
            openURL: { url in urlsOpened.append(url); return true }
        )
        _ = router.handleTap(scheme: "write", wordlyID: "W-COPPER-DRIFTING-LANTERN")
        XCTAssertEqual(urlsOpened[0].absoluteString, "write://write/W-COPPER-DRIFTING-LANTERN")
    }

    func test_failureFromOpenURLPropagates() {
        let router = ReferenceRouter(
            hostScheme: "write",
            openInApp: { _, _ in true },
            openURL: { _ in false }
        )
        XCTAssertFalse(router.handleTap(scheme: "do", wordlyID: "DO-A-B-C"))
    }
}
