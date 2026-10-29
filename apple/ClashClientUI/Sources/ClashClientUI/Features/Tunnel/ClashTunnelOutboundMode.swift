import Foundation

 
 
 
 
 
 
 
 
 
 
 
public enum ClashTunnelOutboundMode {
     
     
    public static let runtimeLayerKey = "config.runtime.flclash.v1"

     
    static let modes: Set<String> = ["rule", "global", "direct"]

     
    public static func chosen(in defaults: UserDefaults?) -> String? {
        guard let data = defaults?.data(forKey: runtimeLayerKey),
              let layer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let patchJSON = layer["patchJSON"] as? String else { return nil }
        return chosen(inPatchJSON: patchJSON)
    }

     
     
    public static func chosen(inPatchJSON patchJSON: String) -> String? {
        guard let patch = try? JSONSerialization.jsonObject(with: Data(patchJSON.utf8)) as? [String: Any],
              let mode = (patch["mode"] as? String)?.lowercased(),
              modes.contains(mode) else { return nil }
        return mode
    }

     
    public static func applyingChoice(in defaults: UserDefaults?, to yaml: String) -> String {
        chosen(in: defaults).map { applying($0, to: yaml) } ?? yaml
    }

     
     
     
    public static func applying(_ mode: String, to yaml: String) -> String {
        guard let line = topLevelModeLine(in: yaml) else { return "mode: \(mode)\n" + yaml }
        if value(of: yaml[line]).lowercased() == mode { return yaml }
        var replaced = yaml
        replaced.replaceSubrange(line, with: "mode: \(mode)")
        return replaced
    }

     
    private static func topLevelModeLine(in yaml: String) -> Range<String.Index>? {
        var start = yaml.startIndex
        while start < yaml.endIndex {
            let end = yaml[start...].firstIndex(where: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) ?? yaml.endIndex
            let line = yaml[start..<end]
            if isModeKey(line) { return start..<end }
            guard end < yaml.endIndex else { return nil }
            start = yaml.index(after: end)
        }
        return nil
    }

    private static func isModeKey(_ line: Substring) -> Bool {
        for key in ["mode", "\"mode\"", "'mode'"] where line.hasPrefix(key) {
            let rest = line.dropFirst(key.count).drop(while: { $0 == " " || $0 == "\t" })
            if rest.first == ":" { return true }
        }
        return false
    }

     
    private static func value(of line: Substring) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        var value = line[line.index(after: colon)...]
        if let comment = value.range(of: " #") { value = value[..<comment.lowerBound] }
        return value.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}
