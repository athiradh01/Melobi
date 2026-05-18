import Foundation

/// Lightweight LRC formatting utilities.
/// All AI / waveform-based auto-sync code has been removed —
/// timestamp creation now happens exclusively via manual sync.
enum LRCFormatter {
    /// Converts an array of timed lyric lines to the standard `.lrc` text format.
    static func formatLRC(_ lines: [LRCLine]) -> String {
        lines.map { line in
            let cs = Int(max(line.timestamp, 0) * 100)
            return String(format: "[%02d:%02d.%02d]%@",
                          cs / 6000, (cs % 6000) / 100, cs % 100, line.text)
        }.joined(separator: "\n")
    }
}
