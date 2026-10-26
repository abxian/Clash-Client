import Foundation
import XCTest
@testable import ShenxianyunKit

final class LoopbackIntegrationTests: XCTestCase {
    func testRealURLSessionImportDownloadAndTelemetryAgainstLoopbackFixture() async throws {
        guard let raw = ProcessInfo.processInfo.environment["SXY_TEST_API_BASE"],
              let base = URL(string: raw), DevelopmentBootstrap.permits(base) else {
            throw XCTSkip("Run scripts/isolated-api-fixture.py and set SXY_TEST_API_BASE to its loopback URL")
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = ShenxianyunClient(http: session, store: InMemoryStore(), bootstrapAPI: base, platform: "ios")
        let prepared = try await client.prepareImport("fixture211")
        let before = await client.savedAccessCode()
        XCTAssertNil(before)
        XCTAssertEqual(prepared.subscriptionURL.host, "127.0.0.1")
        let (data, response) = try await session.data(from: prepared.subscriptionURL)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let yaml = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(yaml.contains("proxy-groups:"))
        XCTAssertTrue(yaml.contains("MATCH,神仙云节点"))
        await client.commitImport(prepared, code: "fixture211")
        let expiry = try await client.heartbeat(expectedDeviceToken: "fixture-device-token")
        XCTAssertEqual(expiry, "2099-12-31 23:59:59")
        var counter = TrafficCounter(counterID: "fixture-counter")
        counter.advance(uploadTotal: 123, downloadTotal: 456)
        try await client.reportTraffic(counter, expectedDeviceToken: "fixture-device-token")
        try await client.reportOffline(expectedDeviceToken: "fixture-device-token")
        do {
            _ = try await client.prepareImport("bad-fixture")
            XCTFail("invalid fixture code must fail")
        } catch let error as ShenxianyunError {
            XCTAssertTrue(error.userMessage.contains("无效"))
        }
        let after = await client.savedAccessCode()
        XCTAssertEqual(after, "fixture211")
    }
}
