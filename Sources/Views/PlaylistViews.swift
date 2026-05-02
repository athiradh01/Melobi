import SwiftUI
import GRDB

// MARK: - Liked Songs View
struct LikedSongsView: View {
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    var onPlayTrack: (Track, [Track]) -> Void
    
    @State private var likedList: [Track] = []
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [t.primary.opacity(0.8), t.primaryContainer],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: t.primary.opacity(0.3), radius: 16, y: 4)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Liked Songs")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                        .tracking(-0.5)
                    
                    Text("\(likedList.count) songs")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.onSurfaceVariant)
                    
                    if !likedList.isEmpty {
                        Button {
                            if let first = likedList.first {
                                onPlayTrack(first, likedList)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Play All")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(t.onPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(t.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .background(t.outlineVariant.opacity(0.3))
            
            // Track list
            if likedList.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "heart")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(t.outlineVariant.opacity(0.4))
                    Text("No liked songs yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant.opacity(0.6))
                    Text("Tap the heart icon on any track to add it here.")
                        .font(.system(size: 12))
                        .foregroundStyle(t.outlineVariant)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(likedList.enumerated()), id: \.element.id) { index, track in
                            let playing = engine.currentTrack?.id == track.id && engine.isPlaying
                            TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {
                                onPlayTrack(track, likedList)
                            }
                            .contextMenu {
                                unlikeButton(for: track)
                                addToPlaylistMenu(track: track)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .onAppear { refreshList() }
        .onChange(of: library.likedTrackIds) { _, _ in refreshList() }
    }
    
    private func refreshList() {
        likedList = library.likedTracks(db: db)
    }
    
    private func unlikeButton(for track: Track) -> some View {
        Button {
            guard let tid = track.id else { return }
            library.toggleLike(trackId: tid, db: db)
        } label: {
            Label("Unlike", systemImage: "heart.slash")
        }
    }
    
    @ViewBuilder
    private func addToPlaylistMenu(track: Track) -> some View {
        if !library.playlists.isEmpty {
            Menu("Add to Playlist") {
                ForEach(library.playlists) { playlist in
                    Button(playlist.name) {
                        guard let tid = track.id, let pid = playlist.id else { return }
                        library.addTrackToPlaylist(trackId: tid, playlistId: pid, db: db)
                    }
                }
            }
        }
    }
}

// MARK: - Playlists Overview View
struct PlaylistsOverviewView: View {
    @Environment(LibraryStore.self) var library
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    var onSelectPlaylist: (Playlist) -> Void
    
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Playlists")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(t.onSurface)
                            .tracking(-0.5)
                        Text("\(library.playlists.count) playlists")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(t.onSurfaceVariant)
                    }
                    Spacer()
                    
                    Button {
                        showNewPlaylistAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("New Playlist")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(t.onPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(t.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                
                if library.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(t.outlineVariant.opacity(0.4))
                        Text("No playlists yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(t.onSurfaceVariant.opacity(0.6))
                        Text("Create a playlist to organize your music.")
                            .font(.system(size: 12))
                            .foregroundStyle(t.outlineVariant)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    // Grid of playlist cards
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                        ForEach(library.playlists) { playlist in
                            PlaylistCard(playlist: playlist, db: db, t: t)
                                .onTapGesture {
                                    onSelectPlaylist(playlist)
                                }
                                .contextMenu {
                                    Button("Delete Playlist", role: .destructive) {
                                        library.deletePlaylist(playlist, db: db)
                                    }
                                }
                        }
                    }
                }
                
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
        }
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Create") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                if let pl = library.createPlaylist(name: name, db: db) {
                    onSelectPlaylist(pl)
                }
                newPlaylistName = ""
            }
            Button("Cancel", role: .cancel) { newPlaylistName = "" }
        } message: {
            Text("Enter a name for your new playlist.")
        }
    }
}

// MARK: - Playlist Card
struct PlaylistCard: View {
    let playlist: Playlist
    let db: DatabasePool
    let t: Theme
    @Environment(LibraryStore.self) var library
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let coverPath = library.playlistCoverArtwork(playlist, db: db)
            
            ZStack {
                ArtworkView(path: coverPath, size: 160, cornerRadius: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.4)],
                                    startPoint: .center, endPoint: .bottom
                                )
                            )
                    )
                
                if coverPath == nil {
                    // Placeholder gradient for empty playlists
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [t.primaryContainer.opacity(0.6), t.primary.opacity(0.3)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
            }
            .frame(width: 160, height: 160)
            
            Text(playlist.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(t.onSurface)
                .lineLimit(1)
            
            Text("\(library.trackCountForPlaylist(playlist, db: db)) tracks")
                .font(.system(size: 11))
                .foregroundStyle(t.onSurfaceVariant)
        }
        .frame(width: 160)
    }
}

// MARK: - Playlist Detail View
struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    var onPlayTrack: (Track, [Track]) -> Void
    
    @State private var tracks: [Track] = []
    @State private var showAddTracksSheet = false
    @State private var isRenaming = false
    @State private var renameText = ""
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                let coverPath = library.playlistCoverArtwork(playlist, db: db)
                
                ZStack {
                    if coverPath != nil {
                        ArtworkView(path: coverPath, size: 80, cornerRadius: 14)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [t.primaryContainer.opacity(0.6), t.primary.opacity(0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    }
                }
                .shadow(color: t.primary.opacity(0.2), radius: 12, y: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                        .tracking(-0.5)
                    
                    Text("\(tracks.count) songs")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.onSurfaceVariant)
                    
                    HStack(spacing: 8) {
                        if !tracks.isEmpty {
                            Button {
                                if let first = tracks.first {
                                    onPlayTrack(first, tracks)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Play All")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(t.onPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(t.primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            showAddTracksSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Add Songs")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(t.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(t.primaryContainer.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .background(t.outlineVariant.opacity(0.3))
            
            // Track list
            if tracks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundStyle(t.outlineVariant.opacity(0.4))
                    Text("This playlist is empty")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant.opacity(0.6))
                    Text("Tap \"Add Songs\" to get started.")
                        .font(.system(size: 12))
                        .foregroundStyle(t.outlineVariant)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            let playing = engine.currentTrack?.id == track.id && engine.isPlaying
                            TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {
                                onPlayTrack(track, tracks)
                            }
                            .contextMenu {
                                removeFromPlaylistButton(for: track)
                                likeToggleButton(for: track)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .onAppear { refreshTracks() }
        .onChange(of: playlist.id) { _, _ in refreshTracks() }
        .sheet(isPresented: $showAddTracksSheet) {
            AddTracksSheet(playlist: playlist, db: db, t: t, onDismiss: {
                showAddTracksSheet = false
                refreshTracks()
            })
        }
    }
    
    private func refreshTracks() {
        tracks = library.tracksForPlaylist(playlist, db: db)
    }
    
    private func removeFromPlaylistButton(for track: Track) -> some View {
        Button(role: .destructive) {
            guard let tid = track.id, let pid = playlist.id else { return }
            library.removeTrackFromPlaylist(trackId: tid, playlistId: pid, db: db)
            refreshTracks()
        } label: {
            Label("Remove from Playlist", systemImage: "minus.circle")
        }
    }
    
    private func likeToggleButton(for track: Track) -> some View {
        let isLiked = track.id.map { library.isTrackLiked(trackId: $0) } ?? false
        return Button {
            guard let tid = track.id else { return }
            library.toggleLike(trackId: tid, db: db)
        } label: {
            Label(isLiked ? "Unlike" : "Like", systemImage: isLiked ? "heart.slash" : "heart")
        }
    }
}

// MARK: - Add Tracks Sheet
struct AddTracksSheet: View {
    let playlist: Playlist
    let db: DatabasePool
    let t: Theme
    var onDismiss: () -> Void
    
    @Environment(LibraryStore.self) var library
    @State private var searchText = ""
    
    private var filteredTracks: [Track] {
        if searchText.isEmpty {
            return library.tracks
        }
        let q = searchText
        return library.tracks.filter {
            ($0.title?.localizedCaseInsensitiveContains(q) ?? false) ||
            ($0.artist?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }
    
    /// Track IDs already in the playlist
    private var existingTrackIds: Set<Int64> {
        Set(library.tracksForPlaylist(playlist, db: db).compactMap { $0.id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Songs to \"\(playlist.name)\"")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(t.onSurface)
                Spacer()
                Button("Done") { onDismiss() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(t.primary)
            }
            .padding()
            
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(t.outline)
                TextField("Search tracks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(t.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredTracks) { track in
                        let alreadyAdded = track.id.map { existingTrackIds.contains($0) } ?? false
                        
                        HStack(spacing: 12) {
                            ArtworkView(path: track.artworkPath, size: 38, cornerRadius: 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title ?? "Unknown")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(t.onSurface)
                                    .lineLimit(1)
                                Text(track.artist ?? "Unknown Artist")
                                    .font(.system(size: 10))
                                    .foregroundStyle(t.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                            Spacer()
                            
                            if alreadyAdded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(t.primary)
                                    .font(.system(size: 18))
                            } else {
                                Button {
                                    if let tid = track.id, let pid = playlist.id {
                                        library.addTrackToPlaylist(trackId: tid, playlistId: pid, db: db)
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(t.primary)
                                        .font(.system(size: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .frame(width: 500, height: 500)
        .background(t.surface)
    }
}

// MARK: - Shared Track Row
struct TrackRow: View {
    let track: Track
    let index: Int
    let isPlaying: Bool
    let t: Theme
    var onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Track number / now playing indicator
            ZStack {
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(t.primary)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                } else {
                    Text("\(index)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)
                }
            }
            .frame(width: 28)
            
            ArtworkView(path: track.artworkPath, size: 40, cornerRadius: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.system(size: 13, weight: isPlaying ? .bold : .semibold))
                    .foregroundStyle(isPlaying ? t.primary : t.onSurface)
                    .lineLimit(1)
                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 11))
                    .foregroundStyle(t.onSurfaceVariant)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let album = track.album, !album.isEmpty {
                Text(album)
                    .font(.system(size: 11))
                    .foregroundStyle(t.outlineVariant)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)
            }
            
            Text(formatTime(Double(track.durationMs ?? 0) / 1000))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(t.outlineVariant)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(isHovering ? t.surfaceContainerLow.opacity(0.5) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture { onTap() }
    }
}
