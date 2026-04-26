import Foundation
import Observation

@MainActor
@Observable
public final class LyricsState {
    public static let shared = LyricsState()
    public var variants: [LyricVariant] = []
    public var activeVariantIndex: Int = 0
    public var activeIndex: Int? = nil
    
    public var lines: [LRCLine] {
        guard variants.indices.contains(activeVariantIndex) else { return [] }
        return variants[activeVariantIndex].lines
    }
    
    /// The file path of the audio track whose lyrics are currently loaded.
    /// Used to detect when the track changes, even if two tracks share the same title.
    public private(set) var loadedForFilePath: String? = nil
    
    public var hasLyrics: Bool { !variants.isEmpty }
    
    private init() {}
    
    /// Load lyrics for the given audio URL. Uses the full file path — not the song name —
    /// so two tracks with the same title load their own individual .lrc files.
    public func load(for url: URL) {
        let path = url.path
        // Skip if already loaded for this exact file
        guard path != loadedForFilePath else { return }
        loadedForFilePath = path
        variants = LRCParser.loadVariants(for: url)
        activeVariantIndex = 0
        activeIndex = nil
    }
    
    public func update(currentTime: TimeInterval) {
        activeIndex = LRCParser.activeIndex(in: lines, at: currentTime)
    }
    
    public func clear() {
        variants = []
        activeVariantIndex = 0
        activeIndex = nil
        loadedForFilePath = nil
    }
}
