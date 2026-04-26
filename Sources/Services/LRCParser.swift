import Foundation

public struct LRCLine: Identifiable, Equatable {
    public var id = UUID()
    public var timestamp: TimeInterval
    public var text: String
}

public struct LyricVariant: Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var lines: [LRCLine]
    
    public init(id: UUID = UUID(), name: String, lines: [LRCLine]) {
        self.id = id
        self.name = name
        self.lines = lines
    }
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
    
    /// Load all matching .lrc variants for the given audio URL.
    public static func loadVariants(for audioURL: URL) -> [LyricVariant] {
        let base = audioURL.deletingPathExtension()
        let baseName = base.lastPathComponent
        let audioDir = base.deletingLastPathComponent()
        
        var foundURLs: [URL] = []
        
        // Search in audio file directory
        if let files = try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil) {
            for file in files {
                if file.pathExtension.lowercased() == "lrc" && file.lastPathComponent.hasPrefix(baseName) {
                    foundURLs.append(file)
                }
            }
        }
        
        // Search in global lyrics directory
        if let lyricsDir = AppDatabase.shared.lyricsDirectory {
            if let files = try? FileManager.default.contentsOfDirectory(at: lyricsDir, includingPropertiesForKeys: nil) {
                for file in files {
                    if file.pathExtension.lowercased() == "lrc" && file.lastPathComponent.hasPrefix(baseName) {
                        if !foundURLs.contains(where: { $0.lastPathComponent == file.lastPathComponent }) {
                            foundURLs.append(file)
                        }
                    }
                }
            }
        }
        
        // Ensure standard lrc is first if it exists
        foundURLs.sort { u1, u2 in
            if u1.lastPathComponent.lowercased() == "\(baseName.lowercased()).lrc" { return true }
            if u2.lastPathComponent.lowercased() == "\(baseName.lowercased()).lrc" { return false }
            return u1.lastPathComponent < u2.lastPathComponent
        }
        
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .ascii, .japaneseEUC, .shiftJIS]
        var variants: [LyricVariant] = []
        
        for url in foundURLs {
            for encoding in encodings {
                if let content = try? String(contentsOf: url, encoding: encoding) {
                    let lines = parse(content)
                    if !lines.isEmpty {
                        var name = "Native"
                        let fileName = url.deletingPathExtension().lastPathComponent
                        if fileName.count > baseName.count {
                            let suffix = fileName.dropFirst(baseName.count)
                            let clean = suffix.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                            if !clean.isEmpty {
                                name = clean.capitalized
                            }
                        }
                        variants.append(LyricVariant(name: name, lines: lines))
                    }
                    break
                }
            }
        }
        
        return variants
    }
    
    /// Find the active line index given a current playback time.
    public static func activeIndex(in lines: [LRCLine], at time: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        
        // Find the index of the line whose timestamp is the largest value <= current time
        let index = lines.lastIndex(where: { $0.timestamp <= time })
        return index
    }
}
