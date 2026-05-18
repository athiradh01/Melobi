import Foundation
import AVFoundation
import AudioToolbox
import MediaPlayer
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
        didSet {
            player?.volume = volume
            playerNode.volume = volume
        }
    }
    
    public var playbackRate: Float = 1.0 {
        didSet {
            player?.rate = isPlaying ? playbackRate : 0
            timePitchNode.rate = playbackRate
        }
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
    
    public var onChapterCompleted: ((Audiobook, Int) -> Void)?
    public var onTrackChanged: ((String) -> Void)?
    
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
    
    // MARK: - Playback Engines
    
    // AVPlayer (for EQ Off / Audiobooks)
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    
    // AVAudioEngine (for EQ Presets)
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    public let eqNode = AVAudioUnitEQ(numberOfBands: 6)
    public let limiterNode = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    ))
    private var engineTimer: Timer?
    private var activeAudioFile: AVAudioFile?
    private var engineSeekTime: TimeInterval = 0
    private var isEngineScheduled = false
    
    public var useEQEngine: Bool = false {
        didSet {
            guard oldValue != useEQEngine else { return }
            switchEngines(to: useEQEngine)
        }
    }
    
    private var shuffleHistory: [Int] = []
    private var isGoingBack = false
    
    private override init() {
        super.init()
        setupEngine()
        setupRemoteCommandCenter()
    }
    
    // MARK: - Remote Commands (Media Keys)
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.play()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.next()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.previous()
            return .success
        }
    }
    
    // MARK: - EQ Setup
    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)
        engine.attach(eqNode)
        engine.attach(limiterNode)
        
        // kLimiterParam_PreGain is 0
        AudioUnitSetParameter(limiterNode.audioUnit, 0, kAudioUnitScope_Global, 0, -3.0, 0)
        
        // Frequencies for our 6-band EQ
        let frequencies: [Float] = [60, 230, 910, 3600, 14000, 20000]
        for i in 0..<eqNode.bands.count {
            let band = eqNode.bands[i]
            band.filterType = .parametric
            band.frequency = frequencies[i]
            band.bandwidth = 1.0
            band.gain = 0.0
            band.bypass = false
        }
        
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: limiterNode, format: nil)
        engine.connect(limiterNode, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)
    }
    
    public func setEQGains(_ gains: [Float]) {
        for (i, gain) in gains.enumerated() {
            if i < eqNode.bands.count {
                eqNode.bands[i].gain = gain
            }
        }
    }
    
    // MARK: - Engine Switching
    private func switchEngines(to useEngine: Bool) {
        let savedTime = currentTime
        let wasPlaying = isPlaying
        
        if useEngine {
            // Stop AVPlayer
            player?.pause()
            cleanupPlayer()
            
            // Start Engine
            if let track = currentTrack {
                loadEngine(track: track, resumePosition: savedTime)
                if wasPlaying { playEngine() }
            }
        } else {
            // Stop Engine
            stopEngine()
            
            // Start AVPlayer
            if let track = currentTrack {
                loadPlayer(track: track, resumePosition: savedTime)
                if wasPlaying { playPlayer() }
            } else if let book = currentAudiobook {
                // Audiobooks always use AVPlayer
                loadPlayer(audiobook: book, resumePosition: savedTime, chapters: self.chapters)
                if wasPlaying { playPlayer() }
            }
        }
    }
    
    // MARK: - Core Controls
    
    public func load(track: Track) {
        currentTrack = track
        currentAudiobook = nil
        duration = Double(track.durationMs ?? 0) / 1000.0
        currentTime = 0
        error = nil
        
        if useEQEngine {
            loadEngine(track: track, resumePosition: 0)
        } else {
            loadPlayer(track: track, resumePosition: 0)
        }
        onTrackChanged?(track.filePath)
    }
    
    public func load(audiobook: Audiobook, resumePosition: Double = 0, chapters: [Chapter] = []) {
        // Audiobooks ALWAYS use AVPlayer for reliability with chapters and long durations
        useEQEngine = false 
        
        currentAudiobook = audiobook
        currentTrack = nil
        self.chapters = chapters
        duration = Double(audiobook.durationMs ?? 0) / 1000.0
        currentTime = resumePosition
        error = nil
        
        loadPlayer(audiobook: audiobook, resumePosition: resumePosition, chapters: chapters)
    }
    
    public func play() {
        useEQEngine ? playEngine() : playPlayer()
        isPlaying = true
    }
    
    public func pause() {
        useEQEngine ? pauseEngine() : pausePlayer()
        isPlaying = false
    }
    
    public func stop() {
        useEQEngine ? stopEngine() : stopPlayer()
        isPlaying = false
        currentTrack = nil
        currentTime = 0
        duration = 0
    }
    
    public func togglePlayPause() {
        isPlaying ? pause() : play()
    }
    
    public func seek(to time: TimeInterval) {
        let t = max(0, min(time, duration))
        if useEQEngine {
            seekEngine(to: t)
        } else {
            seekPlayer(to: t)
        }
        currentTime = t
    }
    
    // MARK: - AVPlayer Implementation
    
    private func loadPlayer(track: Track, resumePosition: TimeInterval) {
        let url = URL(fileURLWithPath: track.filePath)
        guard FileManager.default.fileExists(atPath: track.filePath) else {
            error = "File not found: \(track.filePath)"
            return
        }
        cleanupPlayer()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        if resumePosition > 0 {
            player?.seek(to: CMTime(seconds: resumePosition, preferredTimescale: 600))
        }
        setupPlayerObservers()
    }
    
    private func loadPlayer(audiobook: Audiobook, resumePosition: TimeInterval, chapters: [Chapter]) {
        let url = URL(fileURLWithPath: audiobook.filePath)
        guard FileManager.default.fileExists(atPath: audiobook.filePath) else {
            error = "File not found: \(audiobook.filePath)"
            return
        }
        cleanupPlayer()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        if resumePosition > 0 {
            player?.seek(to: CMTime(seconds: resumePosition, preferredTimescale: 600))
        }
        setupPlayerObservers()
    }
    
    private func playPlayer() {
        player?.playImmediately(atRate: playbackRate)
    }
    
    private func pausePlayer() {
        player?.pause()
    }
    
    private func stopPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
    
    private func seekPlayer(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func setupPlayerObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                // Only update if EQ is off (avoid conflicts)
                guard !self.useEQEngine else { return }
                
                let t = time.seconds
                if t.isFinite { self.currentTime = t }
                if let dur = self.player?.currentItem?.duration.seconds, dur.isFinite && dur > 0 {
                    self.duration = dur
                }
            }
        }
        
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard !self.useEQEngine else { return }
                self.handlePlaybackEnd()
            }
        }
    }
    
    private func cleanupPlayer() {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        if let end = endObserver { NotificationCenter.default.removeObserver(end) }
        timeObserver = nil
        endObserver = nil
        player = nil
    }
    
    // MARK: - AVAudioEngine Implementation
    
    private func loadEngine(track: Track, resumePosition: TimeInterval) {
        let url = URL(fileURLWithPath: track.filePath)
        guard FileManager.default.fileExists(atPath: track.filePath),
              let file = try? AVAudioFile(forReading: url) else {
            error = "File not found or unreadable: \(track.filePath)"
            return
        }
        
        activeAudioFile = file
        playerNode.stop()
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        engineSeekTime = resumePosition
        scheduleEngineSegment(from: resumePosition)
        setupEngineTimer()
    }
    
    private func scheduleEngineSegment(from time: TimeInterval) {
        guard let file = activeAudioFile else { return }
        
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let totalFrames = AVAudioFramePosition(file.length)
        let framesToPlay = AVAudioFrameCount(max(0, totalFrames - startFrame))
        
        playerNode.stop()
        
        if framesToPlay > 0 {
            playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: framesToPlay, at: nil) { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    // Engine playback finished
                    // Note: completion is called even when stopped manually, so we check if it actually reached the end
                    let expectedDuration = Double(framesToPlay) / sampleRate
                    let actualPlayed = self.currentTime - self.engineSeekTime
                    if actualPlayed >= expectedDuration - 0.5 {
                        self.handlePlaybackEnd()
                    }
                }
            }
            isEngineScheduled = true
        }
    }
    
    private func playEngine() {
        if !engine.isRunning { try? engine.start() }
        if !isEngineScheduled {
            scheduleEngineSegment(from: currentTime)
        }
        playerNode.play()
    }
    
    private func pauseEngine() {
        playerNode.pause()
    }
    
    private func stopEngine() {
        playerNode.stop()
        isEngineScheduled = false
        engineTimer?.invalidate()
        engineTimer = nil
    }
    
    private func seekEngine(to time: TimeInterval) {
        engineSeekTime = time
        let wasPlaying = playerNode.isPlaying
        playerNode.stop()
        scheduleEngineSegment(from: time)
        if wasPlaying {
            playerNode.play()
        }
    }
    
    private func setupEngineTimer() {
        engineTimer?.invalidate()
        engineTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.useEQEngine, self.isPlaying, self.playerNode.isPlaying else { return }
                
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
                    self.currentTime = self.engineSeekTime + elapsed
                }
            }
        }
    }
    
    // MARK: - Shared Playback Logic
    
    private func handlePlaybackEnd() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            play()
        case .all:
            next(wrap: true)
        case .none:
            if currentAudiobook != nil {
                if let lastChapterIdx = currentChapterIndex, let book = currentAudiobook {
                    onChapterCompleted?(book, lastChapterIdx)
                }
                isPlaying = false
            } else if isShuffleOn {
                next(wrap: false)
            } else if currentQueueIndex + 1 < queue.count {
                next(wrap: false)
            } else {
                isPlaying = false
            }
        }
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
            isGoingBack = true
            currentQueueIndex = lastIndex
            load(track: queue[currentQueueIndex])
            play()
        } else {
            currentQueueIndex = (currentQueueIndex - 1 + queue.count) % queue.count
            load(track: queue[currentQueueIndex])
            play()
        }
    }
    
    // MARK: - Audiobook Chapter Navigation
    
    public func nextChapter() {
        guard !chapters.isEmpty else {
            seek(to: min(currentTime + 30, duration))
            return
        }
        let ms = Int64(currentTime * 1000)
        if let next = chapters.first(where: { $0.startTimeMs > ms }) {
            seek(to: Double(next.startTimeMs) / 1000.0)
        }
    }
    
    public func previousChapter() {
        guard !chapters.isEmpty else {
            seek(to: max(0, currentTime - 30))
            return
        }
        let ms = Int64(currentTime * 1000)
        if let idx = chapters.indices.last(where: { chapters[$0].startTimeMs <= ms }) {
            let chStart = Double(chapters[idx].startTimeMs) / 1000.0
            if currentTime - chStart > 3 {
                seek(to: chStart)
            } else if idx > 0 {
                seek(to: Double(chapters[idx - 1].startTimeMs) / 1000.0)
            } else {
                seek(to: 0)
            }
        } else {
            seek(to: 0)
        }
    }
    
    public func skipForward(_ seconds: Double = 10) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    public func skipBackward(_ seconds: Double = 10) {
        seek(to: max(currentTime - seconds, 0))
    }
}

public enum RepeatMode { case none, one, all }
