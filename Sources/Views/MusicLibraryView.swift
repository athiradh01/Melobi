import SwiftUI
import AppKit
import GRDB

// MARK: - Music Library View
struct MusicLibraryView: View {
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(LyricsState.self) var lyrics
    @Environment(\.colorScheme) var colorScheme
    @Binding var sortOption: SortOption
    @Binding var sortAscending: Bool
    let db: DatabasePool
    
    @State private var isSelectMode = false
    @State private var selectedTrackIds: Set<Int64> = []
    @State private var showDeleteConfirmation = false
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    private var sortedTracks: [Track] {
        let tracks = library.filteredTracks
        switch sortOption {
        case .title:
            return tracks.sorted { ($0.title ?? "").localizedCompare($1.title ?? "") == (sortAscending ? .orderedAscending : .orderedDescending) }
        case .artist:
            return tracks.sorted { ($0.artist ?? "").localizedCompare($1.artist ?? "") == (sortAscending ? .orderedAscending : .orderedDescending) }
        case .dateAdded:
            return sortAscending ? tracks.sorted { $0.dateAdded < $1.dateAdded } : tracks.sorted { $0.dateAdded > $1.dateAdded }
        case .duration:
            return sortAscending ? tracks.sorted { ($0.durationMs ?? 0) < ($1.durationMs ?? 0) } : tracks.sorted { ($0.durationMs ?? 0) > ($1.durationMs ?? 0) }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Track list
            VStack(spacing: 0) {
                // Header with sort + add
                headerBar
                
                // Selection bar (visible when in select mode)
                if isSelectMode {
                    selectionBar
                }
                
                // Track list
                ScrollView {
                    let tracks = sortedTracks
                    LazyVStack(spacing: 0) {
                        ForEach(tracks) { track in
                            if isSelectMode {
                                // Select mode — tap to toggle selection
                                Button {
                                    toggleSelection(track)
                                } label: {
                                    HStack(spacing: 0) {
                                        // Selection indicator
                                        ZStack {
                                            Circle()
                                                .strokeBorder(isSelected(track) ? t.primary : t.outlineVariant, lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                            if isSelected(track) {
                                                Circle()
                                                    .fill(t.primary)
                                                    .frame(width: 22, height: 22)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .padding(.leading, 16)
                                        .padding(.trailing, 4)
                                        .animation(.easeInOut(duration: 0.15), value: isSelected(track))
                                        
                                        TrackRow(
                                            track: track,
                                            isCurrent: engine.currentTrack?.id == track.id,
                                            isPlaying: engine.currentTrack?.id == track.id && engine.isPlaying
                                        )
                                    }
                                    .background(isSelected(track) ? t.primaryContainer.opacity(0.15) : Color.clear)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Normal mode — tap to play
                                Button {
                                    engine.queue = tracks
                                    engine.currentQueueIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                                    engine.load(track: track)
                                    lyrics.load(for: URL(fileURLWithPath: track.filePath))
                                    engine.play()
                                } label: {
                                    TrackRow(
                                        track: track,
                                        isCurrent: engine.currentTrack?.id == track.id,
                                        isPlaying: engine.currentTrack?.id == track.id && engine.isPlaying
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        removeSingleTrack(track)
                                    } label: {
                                        Label("Remove from Library", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .frame(minWidth: 340)
            .background(t.surface)
            
        }
        .alert("Remove \(selectedTrackIds.count) track\(selectedTrackIds.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                deleteSelectedTracks()
            }
        } message: {
            Text("This will remove the selected tracks from your library. The files on disk will not be deleted.")
        }
    }
    
    // MARK: - Selection helpers
    
    private func isSelected(_ track: Track) -> Bool {
        guard let id = track.id else { return false }
        return selectedTrackIds.contains(id)
    }
    
    private func toggleSelection(_ track: Track) {
        guard let id = track.id else { return }
        if selectedTrackIds.contains(id) {
            selectedTrackIds.remove(id)
        } else {
            selectedTrackIds.insert(id)
        }
    }
    
    private func selectAll() {
        selectedTrackIds = Set(sortedTracks.compactMap { $0.id })
    }
    
    private func deselectAll() {
        selectedTrackIds.removeAll()
    }
    
    private func removeSingleTrack(_ track: Track) {
        // Stop playback if this track is currently playing
        if engine.currentTrack?.id == track.id {
            engine.pause()
            engine.currentTrack = nil
        }
        // Remove from queue
        engine.queue.removeAll { $0.id == track.id }
        library.deleteTrack(track, db: db)
    }
    
    private func deleteSelectedTracks() {
        let tracks = sortedTracks.filter { track in
            guard let id = track.id else { return false }
            return selectedTrackIds.contains(id)
        }
        for track in tracks {
            removeSingleTrack(track)
        }
        selectedTrackIds.removeAll()
        isSelectMode = false
    }
    
    // MARK: - Selection Bar
    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedTrackIds.count) selected")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(t.primary)
            
            Spacer()
            
            Button {
                if selectedTrackIds.count == sortedTracks.count {
                    deselectAll()
                } else {
                    selectAll()
                }
            } label: {
                Text(selectedTrackIds.count == sortedTracks.count ? "Deselect All" : "Select All")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(t.primary)
            }
            .buttonStyle(.plain)
            
            Button {
                guard !selectedTrackIds.isEmpty else { return }
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .bold))
                    Text("Remove")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(selectedTrackIds.isEmpty ? t.outlineVariant : .red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedTrackIds.isEmpty ? t.surfaceContainerLow : Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedTrackIds.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(t.primaryContainer.opacity(0.1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("\(library.filteredTracks.count) Tracks")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(t.onSurfaceVariant)
                .textCase(.uppercase)
                .tracking(1)
            
            Spacer()
            
            // Select mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSelectMode.toggle()
                    if !isSelectMode {
                        selectedTrackIds.removeAll()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSelectMode ? "xmark" : "checkmark.circle")
                        .font(.system(size: 10, weight: .bold))
                    Text(isSelectMode ? "Cancel" : "Select")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isSelectMode ? .red : t.onSurfaceVariant)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelectMode ? Color.red.opacity(0.1) : t.surfaceContainerLow)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Sort
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        if sortOption == option { sortAscending.toggle() }
                        else { sortOption = option; sortAscending = true }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                    Text(sortOption.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(t.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(t.primaryContainer.opacity(0.2))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            // Add Songs button
            Button { addSongs() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add Songs")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(t.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(t.primaryContainer.opacity(0.2))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // MARK: - Add Songs
    private func addSongs() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select audio files or folders"
        guard panel.runModal() == .OK else { return }
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Resonance")
        let artworkDir = appDir.appendingPathComponent("Artwork")
        try? FileManager.default.createDirectory(at: artworkDir, withIntermediateDirectories: true)
        
        for url in panel.urls {
            library.importFolder(url: url, db: db, artworkDir: artworkDir, as: .music)
        }
    }
}

// MARK: - Vinyl Record View
struct VinylView: View {
    let artworkPath: String?
    let isPlaying: Bool
    var size: CGFloat = 180
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Shadow
            Circle()
                .fill(.black.opacity(0.1))
                .frame(width: size + 8, height: size + 8)
                .blur(radius: 15)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(r: 30, g: 30, b: 35), Color(r: 12, g: 12, b: 15)],
                            center: .center, startRadius: 0, endRadius: size / 2
                        )
                    )
                
                // Grooves
                ForEach([0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.82, 0.92], id: \.self) { r in
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                        .frame(width: size * r, height: size * r)
                }
                
                // Bright rings
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: size * 0.2, height: size * 0.2)
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    .frame(width: size * 0.48, height: size * 0.48)
                
                // Center art
                AsyncImageLoader(path: artworkPath) { img in
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size * 0.36, height: size * 0.36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(r: 12, g: 12, b: 15), lineWidth: 3))
                } placeholder: {
                    Circle()
                        .fill(Color(r: 50, g: 50, b: 70))
                        .frame(width: size * 0.36, height: size * 0.36)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: size * 0.08))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
                
                // Spindle
                Circle()
                    .fill(Color(r: 12, g: 12, b: 15))
                    .frame(width: 8, height: 8)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .onAppear {
            updateRotation()
        }
        .onChange(of: isPlaying) { _, _ in
            updateRotation()
        }
    }
    
    private func updateRotation() {
        if isPlaying {
            // Start spinning from current rotation to rotation + 360
            // Repeat forever
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation += 360
            }
        } else {
            // Stop spinning where it is
            withAnimation(.default) {
                // To freeze it, we'd need to capture the current state,
                // but for simple cases, just removing the animation is fine.
                // However, without a TimelineView or custom animatable modifier, 
                // freezing mid-air is tricky in pure SwiftUI. 
                // For now, let's at least stop the re-renders.
            }
        }
    }
}

// MARK: - Track Row (No numbers)
struct TrackRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(path: track.artworkPath, size: 42, cornerRadius: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? track.filePath.split(separator: "/").last.map(String.init) ?? "Unknown")
                    .font(.system(size: 13, weight: isCurrent ? .bold : .semibold))
                    .foregroundStyle(isCurrent ? t.primary : t.onSurface)
                    .lineLimit(1)
                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 11))
                    .foregroundStyle(t.onSurfaceVariant)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative)
                    .font(.system(size: 13))
                    .foregroundStyle(t.primary)
            }
            
            Text(formatTime(Double(track.durationMs ?? 0) / 1000))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(t.outline)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(isCurrent ? t.surfaceContainerLow : Color.clear)
        .contentShape(Rectangle())
    }
}
