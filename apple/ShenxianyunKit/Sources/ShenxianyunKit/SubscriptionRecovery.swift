import Foundation

/// Stored only after the original managed configuration has been updated.
public struct SubscriptionRecoveryRecord: Codable, Equatable, Sendable {
    public let code: String
    public let revision: String?
    public let version: Double
    public let expiresAt: String
}

public struct AccessRestriction: Codable, Equatable, Sendable {
    public let code: String
    public let reason: String
    public var renewable: Bool { ["expired", "traffic_limit"].contains(reason) }
}

/// Account identity is captured before the request; a late response cannot
/// consume a revision or replace credentials belonging to a different import.
public struct SubscriptionRecoverySnapshot: Sendable {
    public let record: SubscriptionRecoveryRecord
    public let needsRefresh: Bool
    let deviceToken: String?
}

struct SubscriptionStateWire: Decodable {
    let update_version: Double?
    let subscription_revision: String?
    let expires_at: String?
}
