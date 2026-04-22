import Foundation

public struct LRCLine: Identifiable, Equatable {
    public var id = UUID()
    public var timestamp: TimeInterval
    public var text: String
}

public enum LRCParser {
    /// Parse a raw .lrc string into an array of LRCLines sorted by timestamp.
    public static func parse(_ content: String) -> [LRCLine] {
        let lines = content.components(separatedBy: .newlines)
        var result: [LRCLine] = []
        
        let pattern = #"\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\](.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        for line in lines {
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                guard match.numberOfRanges == 5 else { continue }
                let minuteStr = nsLine.substring(with: match.range(at: 1))
                let secondStr = nsLine.substring(with: match.range(at: 2))
                
                var milliseconds: TimeInterval = 0
                if match.range(at: 3).location != NSNotFound {
                    let msStr = nsLine.substring(with: match.range(at: 3))
                    if let ms = Double(msStr) {
                        // Normalize to milliseconds
                        let digits = msStr.count
                        milliseconds = ms / pow(10, Double(digits))
                    }
                }
                
                let textRange = match.range(at: 4)
                let text = textRange.location != NSNotFound ? nsLine.substring(with: textRange).trimmingCharacters(in: .whitespaces) : ""
                
                guard let minutes = Double(minuteStr), let seconds = Double(secondStr) else { continue }
                let timestamp = minutes * 60 + seconds + milliseconds
                result.append(LRCLine(timestamp: timestamp, text: text))
            }
        }
        
        return result.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Load and parse .lrc file if found alongside the audio file. Returns empty array if not found.
    public static func load(for audioURL: URL) -> [LRCLine] {
        let base = audioURL.deletingPathExtension()
        let lrcURLs = [
            base.appendingPathExtension("lrc"),
            base.appendingPathExtension("LRC")
        ]
        
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .ascii, .japaneseEUC, .shiftJIS]
        
        for url in lrcURLs {
            if FileManager.default.fileExists(atPath: url.path) {
                for encoding in encodings {
                    if let content = try? String(contentsOf: url, encoding: encoding) {
                        return parse(content)
                    }
                }
            }
        }
        return []
    }
    
    /// Find the active line index given a current playback time.
    public static func activeIndex(in lines: [LRCLine], at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        
        // Find the index of the line whose timestamp is the largest value <= current time
        let index = lines.lastIndex(where: { $0.timestamp <= time })
        return index
    }
}
