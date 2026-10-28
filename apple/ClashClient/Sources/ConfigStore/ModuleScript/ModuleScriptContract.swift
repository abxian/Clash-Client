#if os(iOS) || os(macOS)
import Foundation
import os

 
 
 
 

 
 
enum ModuleScriptPhase: String, Codable, Equatable, Sendable {
    case request
    case response

     
    var scriptType: String { self == .request ? "http-request" : "http-response" }
}

 
 
 
 
enum ModuleScriptFamily: String, CaseIterable, Codable, Equatable, Sendable {
    case surge
    case shadowrocket
    case loon
    case stash
     
     
     
    case quantumultX
}

 
 
enum ModuleScriptKind: Equatable, Sendable {
     
     
    case http(ModuleScriptPhase)
     
    case cron
     
     
    case event(String)
     
     
    case networkChanged
     
    case generic

     
    var phase: ModuleScriptPhase? {
        if case .http(let phase) = self { return phase }
        return nil
    }

     
     
     
     
    func scriptType(in family: ModuleScriptFamily) -> String {
        switch self {
        case .http(let phase): return family == .stash ? phase.rawValue : phase.scriptType
        case .cron: return "cron"
        case .event: return "event"
        case .networkChanged: return family == .loon ? "network-changed" : "event"
        case .generic: return "generic"
        }
    }
}

 
enum ModuleScriptDefaults {
     
     
     
     
     
     
     
     
     
     
     
    static func timeoutSeconds(family: ModuleScriptFamily, kind: ModuleScriptKind) -> Double {
        switch family {
        case .surge, .stash: return 5
        case .shadowrocket: return 10
        case .loon: return kind.phase != nil ? 20 : 300
        case .quantumultX: return kind.phase != nil ? quantumultXHTTPSeconds : 300
        }
    }

     
     
    static let quantumultXHTTPSeconds: Double = 10

     
     
     
     
    static let neverSeconds: Double = 1e9
}

 
 
 
 
 
 
 
struct ModuleScriptMemory: Equatable, Sendable {
     
     
    static let floorBytes: Int64 = 8 << 20
     
     
    static let bytesPerSourceByte = 4
     
     
    static let bytesPerPageByte = 40
     
    static let bytesPerReceivedByte = 3

    enum Source: Equatable, Sendable {
         
        case process
         
        case figure(Int64?)
    }

    var source: Source

    static let process = ModuleScriptMemory(source: .process)
     
    static let unjudged = ModuleScriptMemory(source: .figure(nil))

     
     
    var headroom: Int64? {
        switch source {
        case .figure(let left): return left
        case .process:
#if os(iOS)
            let left = Int64(os_proc_available_memory())
            return left > 0 ? left : nil
#else
            return nil
#endif
        }
    }

     
    var spareBytes: Int? {
        headroom.map { Int(clamping: max(0, $0 - Self.floorBytes)) }
    }

     
    func allows(_ bytes: Int) -> Bool {
        guard let spare = spareBytes else { return true }
        return bytes <= spare
    }
}

 
 
 
 
 
 
 
 
enum ModuleScriptArgument: Equatable, Sendable, ExpressibleByStringLiteral {
    case text(String)
    case object([Field])

     
    struct Field: Equatable, Sendable {
        var name: String
        var value: Value
    }

     
     
     
    enum Value: Equatable, Sendable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null
    }

     
    init(stringLiteral value: String) {
        self = .text(value)
    }
}

 
 
 
 
 
 
struct ModuleScriptLimitsTable: Equatable, Sendable {
     
    struct Host: Equatable, Sendable {
         
        var idleTrimAfter: Double
         
        var sourceCacheBytes: Int
    }

     
    struct Run: Equatable, Sendable {
         
         
         
         
        var maximumPendingRequests: Int
    }

    var tunnel: Host
    var app: Host
    var tunnelRun: Run
    var appRun: Run

    static let iOS = ModuleScriptLimitsTable(
        tunnel: Host(idleTrimAfter: 30, sourceCacheBytes: 1 << 20),
        app: appHost,
        tunnelRun: Run(maximumPendingRequests: 8),
        appRun: Run(maximumPendingRequests: 8))

    static let macOS = ModuleScriptLimitsTable(
        tunnel: Host(idleTrimAfter: 120, sourceCacheBytes: 8 << 20),
        app: appHost,
        tunnelRun: Run(maximumPendingRequests: macRequestsAtOnce),
        appRun: Run(maximumPendingRequests: macRequestsAtOnce))

     
    private static var macRequestsAtOnce: Int {
#if arch(arm64)
        return 64
#else
        return 8
#endif
    }

     
    private static let appHost = Host(idleTrimAfter: 60, sourceCacheBytes: 8 << 20)

    static var current: ModuleScriptLimitsTable {
#if os(macOS)
        return .macOS
#else
        return .iOS
#endif
    }
}

 
 
 
 
struct ModuleScriptDeclaration: Equatable, Sendable {
    var name: String
    var kind: ModuleScriptKind
    var family: ModuleScriptFamily
     
     
     
    var scriptPath: String
     
    var sourceFile: URL
     
    var sourceSHA256: String
    var requiresBody: Bool
    var binaryBodyMode: Bool
     
     
    var timeout: Double?
     
     
     
    var argument: ModuleScriptArgument?
     
     
     
     
     
    var environmentParameters: String? = nil
     
     
     
    var trigger: String? = nil

     
    var phase: ModuleScriptPhase? { kind.phase }

     
    var timeoutSeconds: Double {
        timeout ?? ModuleScriptDefaults.timeoutSeconds(family: family, kind: kind)
    }
}

struct ModuleScriptHeader: Codable, Equatable, Hashable, Sendable {
    var name: String
    var value: String
}

struct ModuleScriptHostRequest: Equatable, Sendable {
     
     
    var id: String
    var url: String
    var method: String
    var headers: [ModuleScriptHeader]
}

struct ModuleScriptHostResponse: Equatable, Sendable {
    var status: Int
    var headers: [ModuleScriptHeader]
}

 
struct ModuleScriptEdit: Equatable, Sendable {
    var url: String?
    var status: Int?
     
    var headers: [ModuleScriptHeader]?
    var body: Data?

    init(url: String? = nil, status: Int? = nil, headers: [ModuleScriptHeader]? = nil, body: Data? = nil) {
        self.url = url
        self.status = status
        self.headers = headers
        self.body = body
    }

    var isEmpty: Bool { url == nil && status == nil && headers == nil && body == nil }
}

 
enum ModuleScriptResult: Equatable, Sendable {
     
     
    case passThrough
     
     
    case modifyRequest(ModuleScriptEdit)
     
     
    case respond(ModuleScriptEdit)
     
    case modifyResponse(ModuleScriptEdit)
     
     
    case closeConnection
     
     
     
     
    case completed(json: String?)
}

 
enum ModuleScriptStopReason: Equatable, Sendable {
     
     
    case javaScriptUnavailable(String)
     
     
     
     
    case overran(scriptName: String, sha256: String, seconds: Double)
     
    case engine(String)
}

enum ModuleScriptSkipReason: Equatable, Sendable {
    case stopped(ModuleScriptStopReason)
     
     
    case quarantined(String)
     
     
    case phaseMismatch
     
    case sourceMissing(String)
     
    case sourceMismatch(expected: String, actual: String)
     
     
    case lowMemory(neededBytes: Int, spareBytes: Int)
     
    case cancelled
}

enum ModuleScriptHostOutcome: Equatable, Sendable {
    case done(ModuleScriptResult)
     
     
     
    case aborted(message: String)
     
     
     
    case timedOut(seconds: Double)
    case skipped(ModuleScriptSkipReason)
}

enum ModuleScriptAvailability: Equatable, Sendable {
    case available
    case stopped(ModuleScriptStopReason)
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
protocol ModuleScriptHosting: AnyObject, Sendable {
    func run(
        _ script: ModuleScriptDeclaration, phase: ModuleScriptPhase?,
        request: ModuleScriptHostRequest?, response: ModuleScriptHostResponse?, body: Data?
    ) async -> ModuleScriptHostOutcome
    var availability: ModuleScriptAvailability { get }
     
    func stop(_ reason: ModuleScriptStopReason)
     
     
    func trim()
     
    func metrics() -> ModuleScriptHostMetrics
}

 
struct ModuleScriptHostMetrics: Codable, Equatable, Sendable {
    struct Script: Codable, Equatable, Sendable {
        var runs = 0
        var done = 0
        var aborted = 0
        var timedOut = 0
        var skipped = 0
        var sourceBytes = 0
        var lastMilliseconds = 0
         
        var footprintDeltaPeakBytes: Int64 = 0

        enum CodingKeys: String, CodingKey {
            case runs = "runs_total"
            case done = "done_total"
            case aborted = "aborted_total"
            case timedOut = "timeout_total"
            case skipped = "skipped_total"
            case sourceBytes = "source_bytes"
            case lastMilliseconds = "last_ms"
            case footprintDeltaPeakBytes = "footprint_delta_bytes_peak"
        }
    }

    var runs = 0
    var done = 0
    var aborted = 0
    var timedOut = 0
    var skipped = 0
    var contexts = 0
    var contextsPeak = 0
    var virtualMachinesCreated = 0
    var idleTrims = 0
    var sourceCacheBytes = 0
     
    var footprintBytes: Int64 = 0
    var footprintBytesPeak: Int64 = 0
     
     
    var residueBytes: Int64?
    var storeBytes = 0
     
    var quarantined = 0
    var stopped: String?
     
    var scripts: [String: Script] = [:]

    enum CodingKeys: String, CodingKey {
        case runs = "script_runs_total"
        case done = "script_done_total"
        case aborted = "script_aborted_total"
        case timedOut = "script_timeout_total"
        case skipped = "script_skipped_total"
        case contexts = "script_contexts"
        case contextsPeak = "script_contexts_peak"
        case virtualMachinesCreated = "script_vm_created_total"
        case idleTrims = "script_idle_trims_total"
        case sourceCacheBytes = "script_source_cache_bytes"
        case footprintBytes = "script_footprint_bytes"
        case footprintBytesPeak = "script_footprint_bytes_peak"
        case residueBytes = "script_residue_bytes"
        case storeBytes = "script_store_bytes"
        case quarantined = "script_quarantined"
        case stopped = "script_stopped"
        case scripts
    }
}

 
enum ModuleScriptHeaderFolding {
     
     
    static func fold(_ headers: [ModuleScriptHeader]) -> [ModuleScriptHeader] {
        var order: [String] = []
        var folded: [String: ModuleScriptHeader] = [:]
        for header in headers {
            let key = header.name.lowercased()
            if var existing = folded[key] {
                existing.value += #", "# + header.value
                folded[key] = existing
            } else {
                order.append(key)
                folded[key] = header
            }
        }
        return order.compactMap { folded[$0] }
    }

     
     
     
     
    static func unfold(_ returned: [ModuleScriptHeader], original: [ModuleScriptHeader]) -> [ModuleScriptHeader] {
        var lines: [String: [String]] = [:]
        for header in original { lines[header.name.lowercased(), default: []].append(header.value) }
        var out: [ModuleScriptHeader] = []
        for header in returned {
            if let values = lines[header.name.lowercased()], values.count > 1,
               values.joined(separator: #", "#) == header.value {
                out.append(contentsOf: values.map { ModuleScriptHeader(name: header.name, value: $0) })
            } else {
                out.append(header)
            }
        }
        return out
    }
}
#endif
