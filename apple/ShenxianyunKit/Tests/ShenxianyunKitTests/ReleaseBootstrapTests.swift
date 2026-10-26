import Foundation
import XCTest
@testable import ShenxianyunKit

final class ReleaseBootstrapTests: XCTestCase {
    func testReleaseBuildIgnoresIsolatedBackendEnvironment() throws {
        #if DEBUG
        throw XCTSkip("Must run in Release with SXY_TEST_API_BASE present")
        #else
        guard ProcessInfo.processInfo.environment["SXY_TEST_API_BASE"] != nil else {
            throw XCTSkip("Set SXY_TEST_API_BASE to exercise the Release boundary")
        }
        XCTAssertFalse(DevelopmentBootstrap.isolated)
        XCTAssertEqual(DevelopmentBootstrap.api, ShenxianyunProfile.bootstrapAPI)
        #endif
    }
}
