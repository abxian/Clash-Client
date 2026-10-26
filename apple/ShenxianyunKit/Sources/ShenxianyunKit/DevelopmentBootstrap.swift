import Foundation

/// Debug-only isolated testing. Release builds always use the compiled production bootstrap.
/// When requested, fail closed: a malformed override or cached production endpoint cannot escape.
public enum DevelopmentBootstrap {
    public static var isolated: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["SXY_TEST_API_BASE"] != nil
        #else
        return false
        #endif
    }

    public static var api: URL {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SXY_TEST_API_BASE"] {
            if let url = URL(string: raw), permits(url) { return url }
            return URL(string: "http://127.0.0.1:1")!
        }
        #endif
        return ShenxianyunProfile.bootstrapAPI
    }

    public static func permits(_ url: URL) -> Bool {
        url.scheme == "http" && ["127.0.0.1", "localhost", "::1", "[::1]"].contains(url.host ?? "")
            && url.user == nil && url.password == nil
    }
}
