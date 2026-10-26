import Foundation

 
 
extension ClashAppIdentifiers {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let appGroupContainer: URL? = {
        #if DEBUG && targetEnvironment(simulator)
        // Unsigned, loopback-only UI QA has no App Group entitlement. Keep its files
        // in this process's sandbox; this does not test sharing with the VPN extension.
        if ProcessInfo.processInfo.environment["SXY_TEST_API_BASE"] != nil {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ShenxianyunIsolatedQA", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                return root
            } catch { return nil }
        }
        #endif
        let root = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
#if os(tvOS)
        return root?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
#else
        return root
#endif
    }()
}
