import Foundation
import XCTest
@testable import ShenxianyunKit

private final class RouteHTTP: ShenxianyunHTTPClient, @unchecked Sendable {
    let primaryStatus: Int
    let cancel: Bool
    private let lock = NSLock()
    private var captured: [URLRequest] = []
    init(status: Int, cancel: Bool = false) { primaryStatus = status; self.cancel = cancel }
    var requests: [URLRequest] { lock.withLock { captured } }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock { captured.append(request) }
        if cancel { throw URLError(.cancelled) }
        let status = request.url!.host == "ll.sxnn.de" ? 200 : primaryStatus
        let data = Data("{\"ok\":true,\"success\":true}".utf8)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

final class RouteRecoveryTests: XCTestCase {
    let primary = URL(string: "https://api.sxnn.de:5443")!
    func testOfficial5xxUsesFixedRelayAndPreservesCodeInBodyOnly() async throws {
        let http = RouteHTTP(status: 502)
        let response = try await APITransport(http: http).sendWithFailover(
            bases: [primary], path: "/api/update-state/fixture")
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(http.requests.count, 2)
        let relay = try XCTUnwrap(http.requests.last)
        XCTAssertEqual(relay.url?.absoluteString, "https://ll.sxnn.de/v1/client/sxnn/state")
        XCTAssertEqual(relay.httpMethod, "POST")
        let data = try XCTUnwrap(relay.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(body["code"], "fixture")
        XCTAssertNil(relay.value(forHTTPHeaderField: "Authorization"))
    }
    func testDenialsConsumedTicketsAndRateLimitsNeverRetry() async throws {
        for status in [200, 400, 401, 403, 404, 410, 426, 429] {
            let http = RouteHTTP(status: status)
            let response = try await APITransport(http: http).sendWithFailover(
                bases: [primary], path: "/api/import/exchange", method: "POST", body: ["ticket":"fixture"])
            XCTAssertEqual(response.status, status)
            XCTAssertEqual(http.requests.count, 1)
        }
    }
    func testPresenceFallbackKeepsDeviceAuthentication() async throws {
        let http = RouteHTTP(status: 503)
        _ = try await APITransport(http: http).heartbeat(deviceToken: "fixture-token", bases: [primary])
        XCTAssertEqual(http.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertEqual(http.requests.last?.url?.path, "/v1/client/sxnn/heartbeat")
    }
    func testNonOfficialHostsAndUnlistedOperationsCannotUseRelay() {
        XCTAssertNil(APITransport.relayRoute(bases: [URL(string: "https://custom.invalid")!],
            path: "/api/verify", method: "POST", body: ["code":"fixture"]))
        XCTAssertNil(APITransport.relayRoute(bases: [primary], path: "/api/v2/client/traffic", method: "POST", body: [:]))
        XCTAssertNil(APITransport.relayRoute(bases: [primary], path: "/api/endpoints", method: "GET", body: nil))
        XCTAssertNil(APITransport.relayRoute(bases: [primary], path: "/api/update-state/fixture/other", method: "GET", body: nil))
    }
    func testURLSessionCancellationDoesNotBecomeAnotherRoute() async throws {
        let http = RouteHTTP(status: 502, cancel: true)
        do {
            _ = try await APITransport(http: http).sendWithFailover(bases: [primary], path: "/api/verify", method: "POST")
            XCTFail("cancel must propagate")
        } catch is CancellationError { }
        XCTAssertEqual(http.requests.count, 1)
    }
}
