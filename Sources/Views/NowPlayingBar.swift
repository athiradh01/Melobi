import SwiftUI
import AppKit
import GRDB

// MARK: - Now Playing Bar (Velvet Echo Glass Footer — Optimized)
struct NowPlayingBar: View {
    @Environment(AudioEngine.self) var engine
    @Environment(LyricsState.self) var lyrics
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var lastLyricsUpdate: TimeInterval = -1
    @State private var artworkAccent: Color = .clear
    @State private var lastChapterIndex: Int? = nil
    @State private var preMuteVolume: Float = 0.5
    @State private var isQueuePopoverPresented = false
    @State private var isHoveringProgress = false
    
    // Volume expansion state
    @State private var isVolumeExpanded = false
    @State private var volumeCollapseTask: Task<Void, Never>?
    
    private var t: Theme { Theme(scheme: colorScheme, lightPalette: ThemeManager.shared.activeLightTheme.theme, darkPalette: ThemeManager.shared.activeDarkTheme.theme) }
    private var currentArtworkPath: String? {
        engine.currentTrack?.artworkPath ?? engine.currentAudiobook?.artworkPath
    }
    private var trackTitle: String {
        engine.currentTrack?.title ?? engine.currentAudiobook?.title ?? "—"
    }
    private var trackArtist: String {
        engine.currentTrack?.artist ?? engine.currentAudiobook?.author ?? ""
    }
    
    private var trackInfoView: some View {
        HStack(spacing: 10) {
            ArtworkView(path: currentArtworkPath, size: 44, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: trackTitle, font: .system(size: 13, weight: .bold))
                    .foregroundStyle(t.onSurface)
                if let err = engine.error {
                    Text(err)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text(trackArtist)
                        .font(.system(size: 11))
                        .foregroundStyle(t.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 160, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    engine.isNowPlayingViewActive.toggle()
                }
            }
            
            // Like button
            if engine.currentTrack != nil {
                let isLiked = engine.currentTrack?.id.map { LibraryStore.shared.isTrackLiked(trackId: $0) } ?? false
                Button {
                    guard let tid = engine.currentTrack?.id, let db = AppDatabase.shared.dbWriter else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        LibraryStore.shared.toggleLike(trackId: tid, db: db)
                    }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundStyle(isLiked ? Color(r: 255, g: 60, b: 80) : t.onSurfaceVariant.opacity(0.6))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// Whether the engine is currently playing an audiobook with chapters
    private var isAudiobookWithChapters: Bool {
        engine.currentAudiobook != nil && !engine.chapters.isEmpty
    }
    
    /// The displayed current time — chapter-relative for audiobooks, absolute for music
    private var displayCurrentTime: Double {
        isAudiobookWithChapters ? engine.currentChapterTime : engine.currentTime
    }
    
    /// The displayed duration — chapter duration for audiobooks, full track for music
    private var displayDuration: Double {
        isAudiobookWithChapters ? engine.currentChapterDuration : engine.duration
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            HStack(spacing: 10) {
                Text(formatTime(isDragging ? dragValue : displayCurrentTime))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(t.isGlassmorphic ? Color.white.opacity(0.1) : t.secondaryContainer)
                            .frame(height: (isHoveringProgress || isDragging) ? 8 : 4)
                        
                        let progress = displayDuration > 0
                            ? (isDragging ? dragValue : displayCurrentTime) / displayDuration
                            : 0
                        Capsule()
                            .fill(
                                t.isGlassmorphic
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [t.primary, t.secondary],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(t.primary)
                            )
                            .frame(width: geo.size.width * max(0, min(1, progress)), height: (isHoveringProgress || isDragging) ? 8 : 4)
                            .shadow(color: t.isGlassmorphic ? t.primary.opacity(0.5) : Color.clear, radius: 8, x: 0, y: 0)
                    }
                    .frame(height: geo.size.height)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isHoveringProgress = hovering
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let ratio = max(0, min(1, value.location.x / geo.size.width))
                                dragValue = ratio * displayDuration
                            }
                            .onEnded { _ in
                                if isAudiobookWithChapters {
                                    // Convert chapter-relative drag to absolute seek position
                                    let chapterStart = engine.currentChapter.map { Double($0.startTimeMs) / 1000.0 } ?? 0
                                    engine.seek(to: chapterStart + dragValue)
                                } else {
                                    engine.seek(to: dragValue)
                                }
                                isDragging = false
                            }
                    )
                }
                .frame(height: 16)
                
                Text(formatTime(displayDuration))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .leading)
            }
            
            // Controls row
            HStack {
                // Left: Track info
                trackInfoView
                
                Spacer()
                
                // Center: Playback controls
                HStack(spacing: 20) {
                    Button { engine.isShuffleOn.toggle() } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13))
                            .foregroundStyle(engine.isShuffleOn ? t.primary : t.onSurfaceVariant.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    Button { engine.previous() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(t.onSurface)
                    }
                    .buttonStyle(.plain)
                    
                    Button { engine.togglePlayPause() } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    t.isGlassmorphic
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [t.primaryContainer, t.secondary.opacity(0.7)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(t.primary)
                                )
                                .frame(width: 44, height: 44)
                                .shadow(color: t.isGlassmorphic ? t.primaryContainer.opacity(0.4) : t.primary.opacity(0.2), radius: t.isGlassmorphic ? 16 : 10, y: t.isGlassmorphic ? 0 : 3)
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: engine.isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button { engine.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(t.onSurface)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        switch engine.repeatMode {
                        case .none: engine.repeatMode = .all
                        case .all:  engine.repeatMode = .one
                        case .one:  engine.repeatMode = .none
                        }
                    } label: {
                        let icon = engine.repeatMode == .one ? "repeat.1" : "repeat"
                        let tint = engine.repeatMode != .none ? t.primary : t.onSurfaceVariant.opacity(0.6)
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)

                }
                
                Spacer()
                
                // Right: Volume + speed
                HStack(spacing: 12) {
                    if engine.currentAudiobook != nil {
                        let rateLabel: String = {
                            let r = engine.playbackRate
                            return r == 1.0 ? "1x" : "\(String(format: "%.2g", r))x"
                        }()
                        Menu {
                            Button("0.5x") { engine.playbackRate = 0.5 }
                            Button("0.75x") { engine.playbackRate = 0.75 }
                            Button("1x") { engine.playbackRate = 1.0 }
                            Button("1.25x") { engine.playbackRate = 1.25 }
                            Button("1.5x") { engine.playbackRate = 1.5 }
                            Button("2x") { engine.playbackRate = 2.0 }
                            Button("3x") { engine.playbackRate = 3.0 }
                        } label: {
                            Text(rateLabel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(t.primary)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(t.primaryContainer.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        .menuStyle(.borderlessButton).fixedSize()
                    }
                    
                    let volumeState = engine.volume == 0 ? 0 : (engine.volume < 0.3 ? 1 : (engine.volume < 0.7 ? 2 : 3))
                    let iconName = engine.volume == 0 ? "speaker.slash.fill" : (engine.volume < 0.3 ? "speaker.wave.1.fill" : (engine.volume < 0.7 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"))
                    
                    if isVolumeExpanded {
                        HStack(spacing: 8) {
                            Image(systemName: iconName)
                                .font(.system(size: 14))
                                .foregroundStyle(t.onSurfaceVariant)
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.snappy(duration: 0.3), value: volumeState)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if engine.volume > 0 {
                                        preMuteVolume = engine.volume
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            engine.volume = 0
                                        }
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            engine.volume = preMuteVolume > 0 ? preMuteVolume : 0.5
                                        }
                                    }
                                    resetVolumeTimer()
                                }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(t.primary.opacity(0.3))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(t.primary)
                                        .frame(width: geo.size.width * CGFloat(max(0, min(1, engine.volume))), height: 4)
                                }
                                .frame(height: geo.size.height)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            volumeCollapseTask?.cancel()
                                            let ratio = max(0, min(1, value.location.x / geo.size.width))
                                            engine.volume = Float(ratio)
                                        }
                                        .onEnded { _ in
                                            resetVolumeTimer()
                                        }
                                )
                            }
                            .frame(width: 80, height: 14)
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: iconName)
                                .font(.system(size: 14))
                                .foregroundStyle(t.onSurfaceVariant)
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.snappy(duration: 0.3), value: volumeState)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isVolumeExpanded = true
                                    }
                                    resetVolumeTimer()
                                }
                            
                            // Queue Button
                            Button {
                                isQueuePopoverPresented.toggle()
                            } label: {
                                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(t.onSurface)
                                    .frame(width: 32, height: 32)
                                    .background(isQueuePopoverPresented ? t.primary.opacity(0.2) : t.surfaceContainerLow)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                            .popover(isPresented: $isQueuePopoverPresented, arrowEdge: .bottom) {
                                QueuePopoverView()
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background {
            let isDark = colorScheme == .dark
            let gradStart = artworkAccent.opacity(isDark ? 0.5 : 0.28)
            let gradMid   = artworkAccent.opacity(isDark ? 0.18 : 0.10)
            ZStack {
                if artworkAccent != .clear {
                    LinearGradient(
                        colors: [gradStart, gradMid, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .animation(.easeInOut(duration: 0.6), value: artworkAccent)
                }
                
                if t.isGlassmorphic {
                    // Glass card background
                    Color.white.opacity(0.06)
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                t.isGlassmorphic
                ? AnyView(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.03)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                : AnyView(EmptyView())
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(
            color: t.isGlassmorphic
                ? t.primaryContainer.opacity(0.15)
                : (artworkAccent == .clear ? t.primaryDim.opacity(0.10) : artworkAccent.opacity(0.18)),
            radius: t.isGlassmorphic ? 20 : 24, x: 0, y: 0
        )

        .onChange(of: currentArtworkPath) { _, path in
            extractColor(from: path)
        }
        .onAppear { extractColor(from: currentArtworkPath) }
        .onChange(of: engine.currentTime) { _, newTime in
            // Only update lyrics every 0.4s to reduce UI churn
            if abs(newTime - lastLyricsUpdate) >= 0.4 {
                lastLyricsUpdate = newTime
                lyrics.update(currentTime: newTime)
            }
            
            // Auto-save chapter progress for audiobooks
            if let book = engine.currentAudiobook, let chIdx = engine.currentChapterIndex,
               let db = AppDatabase.shared.dbWriter {
                let chapterTimeMs = Int64(engine.currentChapterTime * 1000)
                
                // Detect chapter transition — mark previous chapter as completed
                if let prevIdx = lastChapterIndex, prevIdx != chIdx {
                    LibraryStore.shared.saveChapterProgress(
                        for: book, chapterIndex: prevIdx,
                        progressMs: 0, isCompleted: true, db: db
                    )
                }
                lastChapterIndex = chIdx
                
                // Save current chapter progress (throttled inside LibraryStore)
                LibraryStore.shared.saveChapterProgress(
                    for: book, chapterIndex: chIdx,
                    progressMs: chapterTimeMs, isCompleted: false, db: db
                )
            }
        }
    }

    
    // MARK: - Dominant color extraction from artwork
    private func extractColor(from path: String?) {
        guard let path, let image = NSImage(contentsOfFile: path) else {
            withAnimation(.easeInOut(duration: 0.4)) { artworkAccent = .clear }
            return
        }
        Task.detached(priority: .utility) {
            let color = extractDominantColor(from: image)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) { artworkAccent = color }
            }
        }
    }
    
    private func resetVolumeTimer() {
        volumeCollapseTask?.cancel()
        volumeCollapseTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isVolumeExpanded = false
                }
            }
        }
    }
}

// MARK: - Artwork dominant color (nonisolated, safe for detached tasks)
func extractDominantColor(from image: NSImage) -> Color {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .clear }
    let width = 20, height = 20
    guard let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return .clear }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = ctx.data else { return .clear }
    let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    let total = width * height
    for i in 0..<total {
        let base = i * 4
        r += CGFloat(ptr[base])
        g += CGFloat(ptr[base + 1])
        b += CGFloat(ptr[base + 2])
    }
    let f = CGFloat(total) * 255.0
    return Color(.sRGB, red: r/f, green: g/f, blue: b/f, opacity: 1.0)
}

// MARK: - Queue Popover View
struct QueuePopoverView: View {
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(scheme: colorScheme, lightPalette: ThemeManager.shared.activeLightTheme.theme, darkPalette: ThemeManager.shared.activeDarkTheme.theme) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Up Next")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(t.onSurface)
                .padding()
            
            Divider()
                .background(t.outlineVariant)
            
            if engine.queue.isEmpty {
                Text("Queue is empty")
                    .font(.system(size: 13))
                    .foregroundStyle(t.onSurfaceVariant)
                    .padding()
            } else {
                let upcoming: [Track] = engine.isShuffleOn 
                    ? engine.shuffledIndices.map { engine.queue[$0] }
                    : Array(engine.queue.suffix(from: min(engine.currentQueueIndex + 1, engine.queue.count)))
                
                if upcoming.isEmpty {
                    Text("No upcoming tracks")
                        .font(.system(size: 13))
                        .foregroundStyle(t.onSurfaceVariant)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(upcoming.enumerated()), id: \.offset) { index, track in
                                QueueTrackRow(track: track, index: index)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(t.surface)
    }
}

// MARK: - Queue Track Row (Interactive)
struct QueueTrackRow: View {
    let track: Track
    let index: Int
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(scheme: colorScheme, lightPalette: ThemeManager.shared.activeLightTheme.theme, darkPalette: ThemeManager.shared.activeDarkTheme.theme) }
    
    @State private var isPressed = false
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(path: track.artworkPath, size: 40, cornerRadius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(t.onSurface)
                    .lineLimit(1)
                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 12))
                    .foregroundStyle(t.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? t.primary.opacity(0.3) : (isHovering ? t.primary.opacity(0.15) : Color.clear))
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
                // Add tiny delay before action so animation completes visibly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    engine.playUpcoming(at: index)
                }
            }
        }
    }
}
