import SwiftUI
import AppKit

// MARK: - Now Playing Bar (Velvet Echo Glass Footer — Optimized)
struct NowPlayingBar: View {
    @Environment(AudioEngine.self) var engine
    @Environment(LyricsState.self) var lyrics
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var lastLyricsUpdate: TimeInterval = -1
    @State private var artworkAccent: Color = .clear
    
    private var t: Theme { Theme(scheme: colorScheme, lightPalette: ThemeManager.shared.activeLightTheme.theme) }
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
                Text(trackArtist)
                    .font(.system(size: 11))
                    .foregroundStyle(t.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: 160, alignment: .leading)
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Progress bar
            HStack(spacing: 10) {
                Text(formatTime(isDragging ? dragValue : engine.currentTime))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(t.secondaryContainer)
                            .frame(height: 4)
                        
                        let progress = engine.duration > 0
                            ? (isDragging ? dragValue : engine.currentTime) / engine.duration
                            : 0
                        Capsule()
                            .fill(t.primary)
                            .frame(width: geo.size.width * max(0, min(1, progress)), height: 4)
                    }
                    .frame(height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let ratio = max(0, min(1, value.location.x / geo.size.width))
                                dragValue = ratio * engine.duration
                            }
                            .onEnded { _ in
                                engine.seek(to: dragValue)
                                isDragging = false
                            }
                    )
                }
                .frame(height: 16)
                
                Text(formatTime(engine.duration))
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
                                .fill(t.primary)
                                .frame(width: 44, height: 44)
                                .shadow(color: t.primary.opacity(0.2), radius: 10, y: 3)
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
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(t.onSurfaceVariant)
                    Slider(
                        value: Binding(get: { Double(engine.volume) }, set: { engine.volume = Float($0) }),
                        in: 0...1
                    )
                    .frame(width: 80)
                    .tint(t.primary)
                    
                    // Toggle for Now Playing (Lyrics/Vinyl) vs List
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            engine.isNowPlayingViewActive.toggle()
                        }
                    } label: {
                        HStack(spacing: 0) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 11))
                                .foregroundStyle(engine.isNowPlayingViewActive ? t.primary : t.onSurfaceVariant)
                                .frame(width: 28, height: 24)
                                .background(engine.isNowPlayingViewActive ? t.surfaceContainerHigh : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            
                            Image(systemName: "music.note.list")
                                .font(.system(size: 11))
                                .foregroundStyle(!engine.isNowPlayingViewActive ? t.primary : t.onSurfaceVariant)
                                .frame(width: 28, height: 24)
                                .background(!engine.isNowPlayingViewActive ? t.surfaceContainerHigh : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .padding(2)
                        .background(t.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
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
                Rectangle().fill(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: artworkAccent == .clear ? t.primaryDim.opacity(0.10) : artworkAccent.opacity(0.18), radius: 24, x: 0, y: 0)

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
