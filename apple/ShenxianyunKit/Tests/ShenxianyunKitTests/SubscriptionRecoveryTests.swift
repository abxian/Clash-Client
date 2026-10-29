import Foundation
import XCTest
@testable import ShenxianyunKit

final class SubscriptionRecoveryTests: XCTestCase {
    private func setup() -> (StubHTTPClient, InMemoryStore, ShenxianyunClient) {
        let http = StubHTTPClient(), store = InMemoryStore()
        let state = ShenxianyunState(store: store)
        state.accessCode = "fixture"
        state.activation = activation()
        return (http, store, ShenxianyunClient(http: http, store: store, bootstrapAPI: URL(string: "https://fixture.invalid")!))
    }
    private func activation() -> ShenxianyunActivation {
        ShenxianyunActivation(code: "fixture", expiresAt: "2020-01-01 00:00:00", deviceToken: "fixture-token",
            subscriptionURL: URL(string: "https://fixture.invalid/managed-sub/fixture")!, deviceID: "fixture-device", limitMode: nil)
    }
    private func valid(_ http: StubHTTPClient, revision: String? = "A", version: Double = 10, expires: String = "2031-01-01 00:00:00") {
        var json: [String: Any] = ["ok": true, "update_version": version, "expires_at": expires]
        if let revision { json["subscription_revision"] = revision }
        http.stub("/api/update-state/fixture", .init(json: json))
    }
    func testExpiredThenExtendedKeepsOriginalCredentialsUntilSuccessfulApply() async throws {
        let (http, store, client) = setup()
        http.stub("/api/update-state/fixture", .init(status: 404, json: ["ok": false, "code": "expired", "message": "已到期"]))
        do { _ = try await client.checkSubscriptionState(); XCTFail() } catch {}
        let restricted = await client.accessRestriction(); XCTAssertTrue(restricted?.renewable == true)
        valid(http)
        let snapshot = try await client.checkSubscriptionState()
        XCTAssertTrue(snapshot.needsRefresh)
        XCTAssertNotNil(ShenxianyunState(store: store).restriction, "a read is not installation success")
        try await client.acknowledgeSubscriptionState(snapshot)
        let active = await client.savedActivation()
        XCTAssertEqual(active?.deviceToken, "fixture-token"); XCTAssertEqual(active?.subscriptionURL, activation().subscriptionURL)
        XCTAssertEqual(active?.expiresAt, "2031-01-01 00:00:00")
        XCTAssertNil(ShenxianyunState(store: store).restriction)
        XCTAssertFalse(http.recordedPaths().contains("/api/import/exchange"))
    }
    func testQuotaRestorationSameRevisionStillNeedsApply() async throws {
        let (http, _, client) = setup(); valid(http)
        let initial = try await client.checkSubscriptionState(); try await client.acknowledgeSubscriptionState(initial)
        http.stub("/api/update-state/fixture", .init(status: 404, json: ["ok": false, "code": "traffic_limit", "message": "额度已用完"]))
        _ = try? await client.checkSubscriptionState(); valid(http)
        let recovered = try await client.checkSubscriptionState(); XCTAssertTrue(recovered.needsRefresh)
    }
    func testOlderFileVersionUsesOpaqueRevision() async throws {
        let (http, _, client) = setup(); valid(http, version: 100)
        let first = try await client.checkSubscriptionState(); try await client.acknowledgeSubscriptionState(first)
        valid(http, revision: "B", version: 1)
        let moved = try await client.checkSubscriptionState(); XCTAssertTrue(moved.needsRefresh)
        try await client.acknowledgeSubscriptionState(moved)
        let unchanged = try await client.checkSubscriptionState(); XCTAssertFalse(unchanged.needsRefresh)
    }
    func testFailedApplyDoesNotConsumeRevision() async throws {
        let (http, _, client) = setup(); valid(http)
        let first = try await client.checkSubscriptionState(); XCTAssertTrue(first.needsRefresh)
        // Download/validation failure: the UI intentionally does not acknowledge.
        let retry = try await client.checkSubscriptionState(); XCTAssertTrue(retry.needsRefresh)
    }
    func testOldAccountCannotAcknowledgeAfterReset() async throws {
        let (http, store, client) = setup(); valid(http)
        let snapshot = try await client.checkSubscriptionState(); await client.reset()
        do { try await client.acknowledgeSubscriptionState(snapshot); XCTFail() } catch is CancellationError {} catch { XCTFail() }
        XCTAssertNil(ShenxianyunState(store: store).recovery)
        XCTAssertNil(ShenxianyunState(store: store).activation)
    }
    func testServerFailureDoesNotCreateExpiryAndRetryAfterIsRespected() async throws {
        let (http, _, client) = setup()
        http.stub("/api/update-state/fixture", .init(status: 503, json: ["ok": false], headers: ["Retry-After": "90"]))
        do { _ = try await client.checkSubscriptionState(); XCTFail() }
        catch let error as ShenxianyunError { XCTAssertEqual(error, .rateLimited(retryAfter: 90)) }
        let restriction = await client.accessRestriction(); XCTAssertNil(restriction)
    }
    func testDisabledIsNotRenewable() async throws {
        let (http, _, client) = setup()
        http.stub("/api/update-state/fixture", .init(status: 404, json: ["ok": false, "code": "code_disabled", "message": "已停用"]))
        _ = try? await client.checkSubscriptionState()
        let restriction = await client.accessRestriction(); XCTAssertFalse(restriction?.renewable ?? true)
    }
    func testLegacyEndpointAndUnlimitedExpiryRemainCompatible() async throws {
        let (http, _, client) = setup(); valid(http, revision: nil, expires: "")
        let first = try await client.checkSubscriptionState(); try await client.acknowledgeSubscriptionState(first)
        let next = try await client.checkSubscriptionState(); XCTAssertFalse(next.needsRefresh)
        let active = await client.savedActivation(); XCTAssertEqual(active?.expiresAt, "")
    }
}

private actor SuspendedStateHTTP: ShenxianyunHTTPClient {
    var started = false
    private var continuation: CheckedContinuation<Void, Never>?
    func release() { continuation?.resume(); continuation = nil }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        started = true
        await withCheckedContinuation { continuation = $0 }
        return (Data("{\"ok\":true,\"subscription_revision\":\"late\"}".utf8),
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private actor SlowStateHTTP: ShenxianyunHTTPClient {
    var count = 0
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        count += 1
        try await Task.sleep(nanoseconds: 2_000_000_000)
        throw URLError(.timedOut)
    }
}

extension SubscriptionRecoveryTests {
    func testResponseAfterAccountChangedIsDiscarded() async throws {
        let http = SuspendedStateHTTP(), store = InMemoryStore()
        ShenxianyunState(store: store).accessCode = "fixture"
        let client = ShenxianyunClient(http: http, store: store, bootstrapAPI: URL(string: "https://fixture.invalid")!)
        let task = Task { try await client.checkSubscriptionState() }
        while !(await http.started) { await Task.yield() }
        await client.reset()
        await http.release()
        do { _ = try await task.value; XCTFail() } catch is CancellationError {} catch { XCTFail() }
        XCTAssertNil(ShenxianyunState(store: store).recovery)
    }
    func testTotalReadDeadlineCancelsSlowBodyAndDoesNotMultiplyAcrossBases() async throws {
        let http = SlowStateHTTP()
        let transport = APITransport(http: http, timeout: 0.03)
        let start = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await transport.sendWithFailover(bases: [URL(string: "https://a.invalid")!, URL(string: "https://b.invalid")!], path: "/state")
            XCTFail()
        } catch {}
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 1)
        let count = await http.count; XCTAssertEqual(count, 1)
    }
}
