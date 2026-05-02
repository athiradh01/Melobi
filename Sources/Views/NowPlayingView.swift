import SwiftUI
import AppKit
import GRDB
import Observation

// MARK: - Full Screen Now Playing View
struct NowPlayingView: View {
    @Environment(AudioEngine.self) var engine
    @Environment(LyricsState.self) var lyrics
    @Environment(LibraryStore.self) var library
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isVinylStyle") private var isVinylStyle: Bool = true
    
    let db: DatabasePool
    
    private var t: Theme { Theme(scheme: colorScheme) }
    private var isAudiobook: Bool { engine.currentAudiobook != nil }
    
    var body: some View {
        Group {
            if isAudiobook {
                audiobookLayout
            } else {
                musicLayout
            }
        }
        .background(t.isGlassmorphic ? Color.clear : t.surface)
    }
    
    // MARK: - Audiobook Layout
    @ViewBuilder
    private var audiobookLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left Column: Cover Art + Info
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(t.primaryDim.opacity(0.15))
                            .blur(radius: 40)
                            .offset(y: 16)
                            
                        ArtworkView(
                            path: engine.currentAudiobook?.artworkPath,
                            size: 380,
                            cornerRadius: 16
                        )
                    }
                    .frame(width: 380, height: 380)
                    .padding(.bottom, 24)
                    
                    Text(engine.currentAudiobook?.title ?? "Unknown Title")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                        .tracking(-1.5)
                        .lineLimit(2)
                        
                    Text("Narrated by \(engine.currentAudiobook?.author ?? "Unknown")")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(t.primary)
                        .tracking(-0.3)
                        .padding(.bottom, 8)
                        
                    HStack(spacing: 12) {
                        if let book = engine.currentAudiobook {
                            Text("Audiobook")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(t.surfaceContainerHighest)
                                .foregroundStyle(t.onSurfaceVariant)
                                .clipShape(Capsule())
                                
                            Text("\(formatTime(Double(book.durationMs ?? 0) / 1000)) Total")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(t.surfaceContainerHighest)
                                .foregroundStyle(t.onSurfaceVariant)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                    
                    Spacer()
                }
                .padding(.horizontal, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right Column: Chapter List
                ChapterListPanel(db: db, chapters: engine.chapters)
                    .frame(width: 450, alignment: .top)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom: Custom Audiobook Control Bar
            AudiobookPlayerBar()
                .frame(height: 120)
        }
    }
    
    // MARK: - Music Layout
    @ViewBuilder
    private var musicLayout: some View {
        HStack(spacing: 0) {
            // Left Column
            VStack(spacing: 32) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            engine.isNowPlayingViewActive = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(t.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(t.surfaceContainerHighest.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.leading, 24)
                
                Spacer()
                
                if isVinylStyle {
                    VinylView(
                        artworkPath: engine.currentTrack?.artworkPath,
                        isPlaying: engine.isPlaying,
                        size: 380
                    )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(t.primaryDim.opacity(0.15))
                            .blur(radius: 40)
                            .offset(y: 16)
                            
                        ArtworkView(
                            path: engine.currentTrack?.artworkPath,
                            size: 380,
                            cornerRadius: 16
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .frame(width: 380, height: 380)
                }
                
                VStack(spacing: 10) {
                    Text(engine.currentTrack?.title ?? "No Track Playing")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                        .tracking(-0.8)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        
                    Text(engine.currentTrack?.artist ?? "")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(t.primaryDim.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        
                    // Artwork Style Toggle
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isVinylStyle.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isVinylStyle {
                                Image(systemName: "square.fill")
                                    .font(.system(size: 11))
                            } else {
                                ZStack {
                                    // Flat Vinyl Disc
                                    Circle()
                                        .fill(t.primary)
                                        .frame(width: 12, height: 12)
                                    // Spindle Hole
                                    Circle()
                                        .fill(t.surfaceContainerHighest.opacity(0.8))
                                        .frame(width: 3, height: 3)
                                    // Tonearm Line
                                    Capsule()
                                        .fill(t.primary)
                                        .frame(width: 1.5, height: 7)
                                        .rotationEffect(.degrees(20))
                                        .offset(x: 5, y: -4)
                                    // Tonearm Pivot
                                    Circle()
                                        .fill(t.primary)
                                        .frame(width: 3, height: 3)
                                        .offset(x: 6.5, y: -6.5)
                                }
                                .frame(width: 14, height: 14)
                            }
                            Text(isVinylStyle ? "Square Cover" : "Vinyl Disc")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(t.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(t.surfaceContainerHighest.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity)
            
            // Right Column
            VStack(alignment: .leading, spacing: 0) {
                LyricsPanel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Audiobook Player Bar
struct AudiobookPlayerBar: View {
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var isCurrentChapterCompleted = false
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress Bar
            VStack(spacing: 4) {
                HStack {
                    Text(formatTime(isDragging ? dragValue : engine.currentChapterTime))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(t.onSurfaceVariant)
                        .tracking(1)
                    Spacer()
                    Text(formatTime(engine.currentChapterDuration))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(t.onSurfaceVariant)
                        .tracking(1)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(t.secondaryContainer)
                            .frame(height: 6)
                        
                        let progress = engine.currentChapterDuration > 0
                            ? (isDragging ? dragValue : engine.currentChapterTime) / engine.currentChapterDuration
                            : 0
                            
                        Capsule()
                            .fill(t.primary)
                            .frame(width: max(0, geo.size.width * min(1, progress)), height: 6)
                    }
                    .frame(height: 12)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let ratio = max(0, min(1, value.location.x / geo.size.width))
                                dragValue = ratio * engine.currentChapterDuration
                            }
                            .onEnded { _ in
                                let targetTime = (engine.currentChapter.map { Double($0.startTimeMs) / 1000.0 } ?? 0) + dragValue
                                engine.seek(to: targetTime)
                                isDragging = false
                            }
                    )
                }
                .frame(height: 12)
            }
            .padding(.horizontal, 48)
            
            HStack {
                // Left side details
                HStack(spacing: 12) {
                    ArtworkView(path: engine.currentAudiobook?.artworkPath, size: 52, cornerRadius: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOW PLAYING")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(t.onSurfaceVariant)
                        Text(engine.currentChapter?.title ?? engine.currentAudiobook?.title ?? "Loading...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(t.onSurface)
                            .lineLimit(1)
                    }
                    
                    // Mark as Completed button
                    Button {
                        markCurrentChapterCompleted()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isCurrentChapterCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 12, weight: .bold))
                            Text(isCurrentChapterCompleted ? "Done" : "Mark Done")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(isCurrentChapterCompleted ? .green : t.onSurfaceVariant)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isCurrentChapterCompleted ? Color.green.opacity(0.12) : t.surfaceContainerHighest)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 360, alignment: .leading)
                
                Spacer()
                
                // Playback Controls
                HStack(spacing: 32) {
                    Button { engine.previousChapter() } label: {
                        Image(systemName: "backward.end")
                            .font(.system(size: 24))
                            .foregroundStyle(t.onSurfaceVariant)
                    }.buttonStyle(.plain)
                    
                    Button { engine.skipBackward(15) } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 20))
                            .foregroundStyle(t.onSurfaceVariant)
                    }.buttonStyle(.plain)
                    
                    Button { engine.togglePlayPause() } label: {
                        ZStack {
                            Circle()
                                .fill(t.primary)
                                .frame(width: 64, height: 64)
                                .shadow(color: t.primary.opacity(0.3), radius: 12, y: 4)
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(t.onPrimary)
                        }
                    }.buttonStyle(.plain)
                    
                    Button { engine.skipForward(15) } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 20))
                            .foregroundStyle(t.onSurfaceVariant)
                    }.buttonStyle(.plain)
                    
                    Button { engine.nextChapter() } label: {
                        Image(systemName: "forward.end")
                            .font(.system(size: 24))
                            .foregroundStyle(t.onSurfaceVariant)
                    }.buttonStyle(.plain)
                }
                
                Spacer()
                
                // Right side utils
                HStack(spacing: 24) {
                    // Volume Control
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 14))
                            .foregroundStyle(t.onSurfaceVariant)
                        Slider(
                            value: Binding(get: { Double(engine.volume) }, set: { engine.volume = Float($0) }),
                            in: 0...1
                        )
                        .frame(width: 80)
                        .tint(t.primary)
                    }
                    
                    // Speed Control
                    Menu {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0], id: \.self) { rate in
                            Button("\(String(format: rate == 1.0 ? "%.0f" : "%.2g", rate))x") {
                                engine.playbackRate = Float(rate)
                            }
                        }
                    } label: {
                        Text("\(String(format: engine.playbackRate == 1.0 ? "%.0f" : "%.2g", engine.playbackRate))x")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(t.onSurface)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(t.surfaceContainerHighest)
                            .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    
                    // Close Audiobook Player button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            engine.isNowPlayingViewActive = false
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(t.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 300, alignment: .trailing)
            }
            .padding(.horizontal, 48)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .background(t.surface.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(t.outlineVariant.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
        .onAppear { refreshCompletionState() }
        .onChange(of: engine.currentChapterIndex) { _, _ in refreshCompletionState() }
    }
    
    private func refreshCompletionState() {
        guard let book = engine.currentAudiobook, let chIdx = engine.currentChapterIndex else {
            isCurrentChapterCompleted = false
            return
        }
        guard let db = AppDatabase.shared.dbWriter else { return }
        let map = LibraryStore.shared.chapterProgressMap(for: book, db: db)
        isCurrentChapterCompleted = map[chIdx]?.isCompleted == true
    }

    private func markCurrentChapterCompleted() {
        guard let book = engine.currentAudiobook, let chIdx = engine.currentChapterIndex else { return }
        guard let db = AppDatabase.shared.dbWriter else { return }
        let newState = !isCurrentChapterCompleted
        LibraryStore.shared.saveChapterProgress(
            for: book, chapterIndex: chIdx,
            progressMs: 0, isCompleted: newState, db: db
        )
        isCurrentChapterCompleted = newState
    }
}
