import Foundation
import Observation

@MainActor
@Observable
public final class LyricsState {
    public static let shared = LyricsState()
    public var lines: [LRCLine] = []
    public var activeIndex: Int? = nil
    public var hasLyrics: Bool { !lines.isEmpty }
    
    private init() {}
    
    public func load(for url: URL) {
        lines = LRCParser.load(for: url)
        activeIndex = nil
    }
    
    public func update(currentTime: TimeInterval) {
        activeIndex = LRCParser.activeIndex(in: lines, at: currentTime)
    }
    
    public func clear() {
        lines = []
        activeIndex = nil
    }
}
