#if os(iOS)
import Foundation
import MetricKit

 
 
 
 
 
 
final class TunnelMetricKitCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = TunnelMetricKitCollector()
     
    static let folder = "diagnostics/metrickit-tunnel"
     
    static let maximumFiles = 32

    private let queue = DispatchQueue(label: "tunnel.metrickit", qos: .utility)
    private var started = false

    func start() {
        queue.async { [self] in
            guard !started else { return }
            started = true
            MXMetricManager.shared.add(self)
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        queue.async { [self] in
            for payload in payloads {
                write("metric", payload.jsonRepresentation(), payload.timeStampBegin, payload.timeStampEnd)
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        queue.async { [self] in
            for payload in payloads {
                write("diagnostic", payload.jsonRepresentation(), payload.timeStampBegin, payload.timeStampEnd)
            }
        }
    }

     
     
    static func fileName(kind: String, begin: Date, end: Date, unique: String) -> String {
        "\(kind)-\(Int(begin.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))-\(unique).json"
    }

    static func periodEnd(of name: String) -> Int {
        let parts = name.split(separator: "-")
        return parts.count > 2 ? Int(parts[2]) ?? 0 : 0
    }

    private func write(_ kind: String, _ data: Data, _ begin: Date, _ end: Date) {
        guard let container = ClashAppIdentifiers.appGroupContainer else { return }
        let directory = container.appendingPathComponent(Self.folder, isDirectory: true)
        let files = FileManager.default
        try? files.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = Self.fileName(kind: kind, begin: begin, end: end, unique: String(UUID().uuidString.prefix(8)))
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
        let kept = ((try? files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .sorted { Self.periodEnd(of: $0.lastPathComponent) < Self.periodEnd(of: $1.lastPathComponent) }
        for stale in kept.dropLast(Self.maximumFiles) { try? files.removeItem(at: stale) }
    }
}
#endif
