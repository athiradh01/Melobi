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
        let lrcURL = audioURL.deletingPathExtension().appendingPathExtension("lrc")
        
        // Try UTF-8 first, then fallback encodings
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .ascii, .japaneseEUC, .shiftJIS]
        for encoding in encodings {
            if let content = try? String(contentsOf: lrcURL, encoding: encoding) {
                return parse(content)
            }
        }
        return []
    }
    
    /// Find the active line index given a current playback time.
    public static func activeIndex(in lines: [LRCLine], at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var result = 0
        for (i, line) in lines.enumerated() {
            if line.timestamp <= time { result = i }
        }
        return result
    }
}
