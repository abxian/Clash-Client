import Foundation
import XCTest
@testable import ShenxianyunKit

private actor DelayedHeartbeat: ShenxianyunHTTPClient {
    private var continuation: CheckedContinuation<Void, Never>?
    private var entered = false

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        entered = true
        await withCheckedContinuation { continuation = $0 }
        return (Data(#"{"ok":true,"expires_at":"old-expiry"}"#.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func waitForRequest() async { while !entered { await Task.yield() } }
    func finish() { continuation?.resume(); continuation = nil }
}

final class LifecycleBoundaryTests: XCTestCase {
    private func activation(_ token: String) -> ShenxianyunActivation {
        .init(code: token, expiresAt: "unchanged", deviceToken: token,
              subscriptionURL: URL(string: "https://example.invalid/managed-sub/test")!,
              deviceID: "test-device", limitMode: "device")
    }

    func testLateHeartbeatCannotRestoreOldCredentialAfterImport() async throws {
        let http = DelayedHeartbeat()
        let store = InMemoryStore()
        let state = ShenxianyunState(store: store)
        state.activation = activation("old")
        let client = ShenxianyunClient(http: http, store: store)
        let request = Task { try await client.heartbeat(expectedDeviceToken: "old") }
        await http.waitForRequest()
        await client.commitImport(.managed(activation("new")), code: "new")
        await http.finish()
        do { _ = try await request.value; XCTFail("stale response must be discarded") }
        catch is CancellationError { }
        catch { XCTFail("unexpected error") }
        XCTAssertEqual(state.activation?.deviceToken, "new")
        XCTAssertEqual(state.activation?.expiresAt, "unchanged")
    }

    func testLateHeartbeatCannotUndoReset() async throws {
        let http = DelayedHeartbeat()
        let store = InMemoryStore()
        let state = ShenxianyunState(store: store)
        state.activation = activation("old")
        let client = ShenxianyunClient(http: http, store: store)
        let request = Task { try await client.heartbeat() }
        await http.waitForRequest()
        await client.reset()
        await http.finish()
        _ = try? await request.value
        XCTAssertNil(state.activation)
    }

    func testOldSessionCannotSendWithNewCredential() async throws {
        let http = StubHTTPClient()
        let store = InMemoryStore()
        let state = ShenxianyunState(store: store)
        state.activation = activation("new")
        let client = ShenxianyunClient(http: http, store: store)
        var traffic = TrafficCounter()
        traffic.advance(uploadTotal: 10, downloadTotal: 20)
        do { try await client.reportTraffic(traffic, expectedDeviceToken: "old"); XCTFail("must not send") }
        catch is CancellationError { }
        catch { XCTFail("unexpected error") }
        do { try await client.reportOffline(expectedDeviceToken: "old"); XCTFail("must not send") }
        catch is CancellationError { }
        catch { XCTFail("unexpected error") }
        XCTAssertTrue(http.recordedPaths().isEmpty)
    }

    func testAwayAndBackBetweenSamplesCannotChargeOtherProfile() {
        var usage = ScopedTunnelTrafficAccumulator(upload: 100, download: 200,
                                                   scope: .init(isCurrent: true, epoch: 1))
        usage.observe(upload: 110, download: 220, scope: .init(isCurrent: true, epoch: 1))
        usage.observe(upload: 2000, download: 4000, scope: .init(isCurrent: true, epoch: 3))
        XCTAssertEqual(usage.upload, 10)
        XCTAssertEqual(usage.download, 20)
        usage.observe(upload: 2030, download: 4050, scope: .init(isCurrent: true, epoch: 3))
        XCTAssertEqual(usage.upload, 40)
        XCTAssertEqual(usage.download, 70)
    }

    func testInactiveTrafficAndResetAreExcluded() {
        var usage = ScopedTunnelTrafficAccumulator(upload: 0, download: 0,
                                                   scope: .init(isCurrent: true, epoch: 1))
        usage.observe(upload: 100, download: 200, scope: .init(isCurrent: false, epoch: 2))
        usage.observe(upload: 300, download: 400, scope: .init(isCurrent: true, epoch: 3))
        usage.observe(upload: 10, download: 20, scope: .init(isCurrent: true, epoch: 3))
        XCTAssertEqual(usage.upload, 10)
        XCTAssertEqual(usage.download, 20)
    }

    func testIsolationOnlyPermitsUncredentialedLoopbackHTTP() {
        for text in ["https://api.sxnn.de:5443", "http://127.0.0.1.evil.invalid", "http://user:secret@127.0.0.1"] {
            XCTAssertFalse(DevelopmentBootstrap.permits(URL(string: text)!))
        }
        XCTAssertTrue(DevelopmentBootstrap.permits(URL(string: "http://127.0.0.1:1234")!))
    }
}
