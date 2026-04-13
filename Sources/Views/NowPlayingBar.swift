import SwiftUI

// MARK: - Now Playing Bar (Velvet Echo Glass Footer — Optimized)
struct NowPlayingBar: View {
    @Environment(AudioEngine.self) var engine
    @Environment(LyricsState.self) var lyrics
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var lastLyricsUpdate: TimeInterval = -1
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
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
                HStack(spacing: 10) {
                    ArtworkView(
                        path: engine.currentTrack?.artworkPath ?? engine.currentAudiobook?.artworkPath,
                        size: 44,
                        cornerRadius: 8
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.currentTrack?.title ?? engine.currentAudiobook?.title ?? "—")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(t.onSurface)
                            .lineLimit(1)
                        Text(engine.currentTrack?.artist ?? engine.currentAudiobook?.author ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(t.onSurfaceVariant)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 160, alignment: .leading)
                }
                
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
                        case .all: engine.repeatMode = .one
                        case .one: engine.repeatMode = .none
                        }
                    } label: {
                        Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 13))
                            .foregroundStyle(engine.repeatMode != .none ? t.primary : t.onSurfaceVariant.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Right: Volume + speed
                HStack(spacing: 12) {
                    if engine.currentAudiobook != nil {
                        Menu {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0], id: \.self) { rate in
                                Button("\(String(format: rate == 1.0 ? "%.0f" : "%.2g", rate))x") {
                                    engine.playbackRate = Float(rate)
                                }
                            }
                        } label: {
                            Text("\(String(format: engine.playbackRate == 1.0 ? "%.0f" : "%.2g", engine.playbackRate))x")
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
        .background(.ultraThinMaterial)
        .background(t.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .shadow(color: t.primaryDim.opacity(0.08), radius: 20, y: 8)
        .onChange(of: engine.currentTime) { _, newTime in
            // Only update lyrics every 0.4s to reduce UI churn
            if abs(newTime - lastLyricsUpdate) >= 0.4 {
                lastLyricsUpdate = newTime
                lyrics.update(currentTime: newTime)
            }
        }
    }
}
