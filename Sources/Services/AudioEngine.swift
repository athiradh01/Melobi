import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
public final class AudioEngine: NSObject {
    public static let shared = AudioEngine()
    
    public var currentTrack: Track?
    public var currentAudiobook: Audiobook?
    public var isPlaying = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var isNowPlayingViewActive = false
    public var volume: Float = 1.0 {
        didSet { player?.volume = volume }
    }
    public var playbackRate: Float = 1.0 {
        didSet { player?.rate = isPlaying ? playbackRate : 0 }
    }
    public var isShuffleOn = false {
        didSet {
            if isShuffleOn {
                generateShuffleQueue()
            } else {
                shuffledIndices.removeAll()
            }
        }
    }
    public var repeatMode: RepeatMode = .none
    public var queue: [Track] = [] {
        didSet { 
            shuffleHistory = []
            if isShuffleOn { generateShuffleQueue() }
        }
    }
    public var currentQueueIndex: Int = 0 {
        didSet {
            if isShuffleOn {
                shuffledIndices.removeAll { $0 == currentQueueIndex }
            }
        }
    }
    public var error: String?
    
    public var shuffledIndices: [Int] = []
    
    private func generateShuffleQueue() {
        guard !queue.isEmpty else {
            shuffledIndices = []
            return
        }
        var indices = Array(0..<queue.count)
        indices.removeAll { $0 == currentQueueIndex }
        indices.shuffle()
        shuffledIndices = indices
    }
    
    /// Called when an audiobook's last chapter finishes playing. Receives (audiobook, lastChapterIndex).
    public var onChapterCompleted: ((Audiobook, Int) -> Void)?
    
    /// Called whenever a new track is loaded, with the file path. Use for lyrics auto-load.
    public var onTrackChanged: ((String) -> Void)?
    
    // Audiobook chapter support
    public var chapters: [Chapter] = []
    
    public var currentChapter: Chapter? {
        guard let idx = currentChapterIndex else { return nil }
        return chapters[idx]
    }
    
    public var currentChapterIndex: Int? {
        guard !chapters.isEmpty else { return nil }
        let ms = Int64(currentTime * 1000)
        return chapters.lastIndex(where: { $0.startTimeMs <= ms })
    }
    
    public var currentChapterTime: TimeInterval {
        guard let chapter = currentChapter else { return currentTime }
        return max(0, currentTime - Double(chapter.startTimeMs) / 1000.0)
    }
    
    public var currentChapterDuration: TimeInterval {
        guard let idx = currentChapterIndex else { return duration }
        let currentStart = Double(chapters[idx].startTimeMs) / 1000.0
        let nextStart: Double
        if idx + 1 < chapters.count {
            nextStart = Double(chapters[idx + 1].startTimeMs) / 1000.0
        } else {
            nextStart = Double(currentAudiobook?.durationMs ?? 0) / 1000.0
        }
        return max(0, nextStart - currentStart)
    }
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    
    /// History of queue indices played during shuffle, so Previous can retrace.
    private var shuffleHistory: [Int] = []
    private var isGoingBack = false
    
    private override init() {
        super.init()
    }
    
    public func load(track: Track) {
        let url = URL(fileURLWithPath: track.filePath)
        guard FileManager.default.fileExists(atPath: track.filePath) else {
            error = "File not found: \(track.filePath)"
            return
        }
        cleanup()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        currentTrack = track
        currentAudiobook = nil
        duration = Double(track.durationMs ?? 0) / 1000.0
        currentTime = 0
        error = nil
        setupObservers()
        onTrackChanged?(track.filePath)
    }
    
    public func load(audiobook: Audiobook, resumePosition: Double = 0, chapters: [Chapter] = []) {
        let url = URL(fileURLWithPath: audiobook.filePath)
        guard FileManager.default.fileExists(atPath: audiobook.filePath) else {
            error = "File not found: \(audiobook.filePath)"
            return
        }
        cleanup()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        currentAudiobook = audiobook
        currentTrack = nil
        self.chapters = chapters
        duration = Double(audiobook.durationMs ?? 0) / 1000.0
        currentTime = resumePosition
        error = nil
        if resumePosition > 0 {
            player?.seek(to: CMTime(seconds: resumePosition, preferredTimescale: 600))
        }
        setupObservers()
    }
    
    public func play() {
        player?.playImmediately(atRate: playbackRate)
        isPlaying = true
    }
    
    public func pause() {
        player?.pause()
        isPlaying = false
    }
    
    public func togglePlayPause() {
        isPlaying ? pause() : play()
    }
    
    public func seek(to time: TimeInterval) {
        let t = max(0, min(time, duration))
        player?.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = t
    }
    
    public func playUpcoming(at upcomingIndex: Int) {
        if isShuffleOn {
            guard upcomingIndex >= 0, upcomingIndex < shuffledIndices.count else { return }
            
            if !isGoingBack {
                shuffleHistory.append(currentQueueIndex)
                if shuffleHistory.count > 200 { shuffleHistory.removeFirst() }
            }
            isGoingBack = false
            
            shuffledIndices.removeFirst(upcomingIndex)
            let nextQueueIndex = shuffledIndices.removeFirst()
            currentQueueIndex = nextQueueIndex
            load(track: queue[currentQueueIndex])
            play()
        } else {
            let nextQueueIndex = currentQueueIndex + 1 + upcomingIndex
            guard nextQueueIndex >= 0, nextQueueIndex < queue.count else { return }
            
            if !isGoingBack {
                shuffleHistory.append(currentQueueIndex)
                if shuffleHistory.count > 200 { shuffleHistory.removeFirst() }
            }
            isGoingBack = false
            
            currentQueueIndex = nextQueueIndex
            load(track: queue[currentQueueIndex])
            play()
        }
    }
    
    public func next(wrap: Bool = true) {
        guard !queue.isEmpty else { return }
        // Record current position in shuffle history before moving forward
        if isShuffleOn && !isGoingBack {
            shuffleHistory.append(currentQueueIndex)
            if shuffleHistory.count > 200 { shuffleHistory.removeFirst() }
        }
        isGoingBack = false
        
        var nextIndex = currentQueueIndex
        if isShuffleOn {
            if shuffledIndices.isEmpty {
                if wrap && queue.count > 1 {
                    generateShuffleQueue()
                    nextIndex = shuffledIndices.removeFirst()
                } else if wrap && queue.count == 1 {
                    nextIndex = currentQueueIndex
                } else {
                    isPlaying = false
                    return
                }
            } else {
                nextIndex = shuffledIndices.removeFirst()
            }
        } else {
            if currentQueueIndex + 1 < queue.count {
                nextIndex = currentQueueIndex + 1
            } else if wrap {
                nextIndex = 0
            } else {
                // End of queue and wrap is disabled - just stop
                isPlaying = false
                return
            }
        }
        
        currentQueueIndex = nextIndex
        load(track: queue[currentQueueIndex])
        play()
    }
    
    public func clearQueue() {
        queue = []
        currentQueueIndex = 0
        shuffleHistory = []
    }
    
    public func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
        } else if isShuffleOn, let lastIndex = shuffleHistory.popLast() {
            // Go back to the exact song we came from during shuffle
            isGoingBack = true
            currentQueueIndex = lastIndex
            load(track: queue[currentQueueIndex])
            play()
        } else {
            // Normal sequential backwards
            currentQueueIndex = (currentQueueIndex - 1 + queue.count) % queue.count
            load(track: queue[currentQueueIndex])
            play()
        }
    }
    
    // MARK: - Audiobook Chapter Navigation
    
    /// Seek to the next chapter, or do nothing if already at the last.
    public func nextChapter() {
        guard !chapters.isEmpty else {
            // No chapters — skip forward 30 s
            seek(to: min(currentTime + 30, duration))
            return
        }
        let ms = Int64(currentTime * 1000)
        if let next = chapters.first(where: { $0.startTimeMs > ms }) {
            seek(to: Double(next.startTimeMs) / 1000.0)
        }
    }
    
    /// Seek to the start of the current chapter; if within 3 s of its start, go to previous.
    public func previousChapter() {
        guard !chapters.isEmpty else {
            // No chapters — skip back 30 s
            seek(to: max(0, currentTime - 30))
            return
        }
        let ms = Int64(currentTime * 1000)
        // Current chapter = last chapter whose start <= currentTime
        if let idx = chapters.indices.last(where: { chapters[$0].startTimeMs <= ms }) {
            let chStart = Double(chapters[idx].startTimeMs) / 1000.0
            if currentTime - chStart > 3 {
                // Restart current chapter
                seek(to: chStart)
            } else if idx > 0 {
                // Go to previous chapter
                seek(to: Double(chapters[idx - 1].startTimeMs) / 1000.0)
            } else {
                seek(to: 0)
            }
        } else {
            seek(to: 0)
        }
    }
    
    /// Skip forward by `seconds` seconds (clamped to duration).
    public func skipForward(_ seconds: Double = 10) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    /// Skip backward by `seconds` seconds (clamped to 0).
    public func skipBackward(_ seconds: Double = 10) {
        seek(to: max(currentTime - seconds, 0))
    }
    
    private func setupObservers() {
        // Time observer — 0.5s interval is smooth enough and much lighter
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let t = time.seconds
                if t.isFinite { self.currentTime = t }
                // Update duration from item if we have it
                if let dur = self.player?.currentItem?.duration.seconds, dur.isFinite && dur > 0 {
                    self.duration = dur
                }
            }
        }
        
        // End of track observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                switch self.repeatMode {
                case .one:
                    self.seek(to: 0)
                    self.play()
                case .all:
                    self.next(wrap: true)
                case .none:
                    if self.currentAudiobook != nil {
                        // Audiobook finished — mark last chapter completed
                        if let lastChapterIdx = self.currentChapterIndex,
                           let book = self.currentAudiobook {
                            self.onChapterCompleted?(book, lastChapterIdx)
                        }
                        self.isPlaying = false
                    } else if self.isShuffleOn {
                        self.next(wrap: false)
                    } else if self.currentQueueIndex + 1 < self.queue.count {
                        self.next(wrap: false)
                    } else {
                        self.isPlaying = false
                    }
                }
            }
        }
    }
    
    private func cleanup() {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        if let end = endObserver { NotificationCenter.default.removeObserver(end) }
        timeObserver = nil
        endObserver = nil
        player = nil
    }
}

public enum RepeatMode { case none, one, all }
