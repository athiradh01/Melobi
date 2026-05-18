import SwiftUI
import GRDB
import AppKit
import UniformTypeIdentifiers

// MARK: - Liked Songs View
struct LikedSongsView: View {
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    var onPlayTrack: (Track, [Track]) -> Void
    
    @State private var likedList: [Track] = []
    @State private var sortBy: String = "dateAdded"
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    private var isCustomMode: Bool { sortBy == "custom" }
    
    private var sortedList: [Track] {
        switch sortBy {
        case "title": return likedList.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case "artist": return likedList.sorted { ($0.artist ?? "") < ($1.artist ?? "") }
        case "duration": return likedList.sorted { ($0.durationMs ?? 0) < ($1.durationMs ?? 0) }
        case "custom": return likedList // Use the current order (persisted sortOrder)
        case "dateAdded": return likedList // Already sorted by sortOrder from DB
        default: return likedList
        }
    }
    
    /// The list used for playback — always reflects what the user sees
    private var playbackList: [Track] {
        isCustomMode ? likedList : sortedList
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [t.primary.opacity(0.8), t.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                        HStack(spacing: 8) {
                            Button {
                                if let first = playbackList.first { onPlayTrack(first, playbackList) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill").font(.system(size: 10))
                                    Text("Play").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(t.onPrimary)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(t.primary).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                let shuffled = playbackList.shuffled()
                                if let first = shuffled.first { onPlayTrack(first, shuffled) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "shuffle").font(.system(size: 10, weight: .bold))
                                    Text("Shuffle").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundStyle(t.primary)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(t.primaryContainer.opacity(0.2)).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                // Sort menu
                Menu {
                    Button { sortBy = "custom" } label: { Label("Custom", systemImage: sortBy == "custom" ? "checkmark" : "") }
                    Divider()
                    Button { sortBy = "dateAdded" } label: { Label("Date Added", systemImage: sortBy == "dateAdded" ? "checkmark" : "") }
                    Button { sortBy = "title" } label: { Label("Title", systemImage: sortBy == "title" ? "checkmark" : "") }
                    Button { sortBy = "artist" } label: { Label("Artist", systemImage: sortBy == "artist" ? "checkmark" : "") }
                    Button { sortBy = "duration" } label: { Label("Duration", systemImage: sortBy == "duration" ? "checkmark" : "") }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background(t.surfaceContainerHighest.opacity(0.4))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider().background(t.outlineVariant.opacity(0.3))
            
            if likedList.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "heart").font(.system(size: 40, weight: .thin)).foregroundStyle(t.outlineVariant.opacity(0.4))
                    Text("No liked songs yet").font(.system(size: 14, weight: .semibold)).foregroundStyle(t.onSurfaceVariant.opacity(0.6))
                    Text("Tap the heart icon on any track to add it here.").font(.system(size: 12)).foregroundStyle(t.outlineVariant)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if isCustomMode {
                // Custom mode with drag-and-drop reordering
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(likedList.enumerated()), id: \.element.id) { index, track in
                            let playing = engine.currentTrack?.id == track.id && engine.isPlaying
                            HStack(spacing: 0) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 12))
                                    .foregroundStyle(t.outlineVariant.opacity(0.5))
                                    .frame(width: 24)
                                    .padding(.leading, 4)
                                
                                TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {
                                    onPlayTrack(track, likedList)
                                }
                            }
                            .contentShape(Rectangle())
                            .draggable(track.id.map { String($0) } ?? "") {
                                TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {}
                                    .frame(width: 400)
                                    .background(t.surfaceContainerLow.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                guard let droppedIdStr = droppedItems.first,
                                      let droppedId = Int64(droppedIdStr),
                                      let fromIndex = likedList.firstIndex(where: { $0.id == droppedId }),
                                      let toIndex = likedList.firstIndex(where: { $0.id == track.id }),
                                      fromIndex != toIndex else { return false }
                                likedList.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                                let trackIds = likedList.compactMap { $0.id }
                                library.reorderLikedTracks(trackIds: trackIds, db: db)
                                return true
                            }
                            .contextMenu {
                                unlikeButton(for: track)
                                addToPlaylistMenu(track: track)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sortedList.enumerated()), id: \.element.id) { index, track in
                            let playing = engine.currentTrack?.id == track.id && engine.isPlaying
                            TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {
                                onPlayTrack(track, sortedList)
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
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    var onSelectPlaylist: (Playlist) -> Void
    var onPlayTrack: (Track, [Track]) -> Void
    
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var showNewVaultAlert = false
    @State private var newVaultName = ""
    @State private var sortBy: String = "recent"

    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    private var sortedPlaylists: [Playlist] {
        switch sortBy {
        case "nameAZ":
            return library.playlists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case "nameZA":
            return library.playlists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case "mostTracks":
            return library.playlists.sorted { library.trackCountForPlaylist($0, db: db) > library.trackCountForPlaylist($1, db: db) }
        case "leastTracks":
            return library.playlists.sorted { library.trackCountForPlaylist($0, db: db) < library.trackCountForPlaylist($1, db: db) }
        default:
            return library.playlists
        }
    }
    
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
                    
                    // Sort menu
                    Menu {
                        Button { sortBy = "recent" } label: {
                            Label("Recent", systemImage: sortBy == "recent" ? "checkmark" : "")
                        }
                        Button { sortBy = "nameAZ" } label: {
                            Label("Name A → Z", systemImage: sortBy == "nameAZ" ? "checkmark" : "")
                        }
                        Button { sortBy = "nameZA" } label: {
                            Label("Name Z → A", systemImage: sortBy == "nameZA" ? "checkmark" : "")
                        }
                        Divider()
                        Button { sortBy = "mostTracks" } label: {
                            Label("Most Tracks", systemImage: sortBy == "mostTracks" ? "checkmark" : "")
                        }
                        Button { sortBy = "leastTracks" } label: {
                            Label("Least Tracks", systemImage: sortBy == "leastTracks" ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(t.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(t.surfaceContainerHighest.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Menu {
                        Button {
                            showNewPlaylistAlert = true
                        } label: {
                            Label("New Playlist", systemImage: "music.note.list")
                        }
                        Button {
                            showNewVaultAlert = true
                        } label: {
                            Label("New Private Vault", systemImage: "lock.shield")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("New")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(t.onPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(t.primary)
                        .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                        ForEach(sortedPlaylists) { playlist in
                            PlaylistCard(playlist: playlist, db: db, t: t, onPlayTrack: onPlayTrack)
                                .onTapGesture {
                                    onSelectPlaylist(playlist)
                                }
                                .contextMenu {
                                    Button("Open Playlist") { onSelectPlaylist(playlist) }
                                    Divider()
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
        .alert("New Private Vault", isPresented: $showNewVaultAlert) {
            TextField("Vault name", text: $newVaultName)
            Button("Create") {
                let name = newVaultName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                if let pl = library.createVaultPlaylist(name: name, db: db) {
                    onSelectPlaylist(pl)
                }
                newVaultName = ""
            }
            Button("Cancel", role: .cancel) { newVaultName = "" }
        } message: {
            Text("Songs added to a Private Vault will be hidden from your library.")
        }
    }
    
}

// MARK: - Playlist Card
struct PlaylistCard: View {
    let playlist: Playlist
    let db: DatabasePool
    let t: Theme
    var onPlayTrack: (Track, [Track]) -> Void
    @Environment(LibraryStore.self) var library
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let coverPath = library.playlistCoverArtwork(playlist, db: db)
            let trackCount = library.trackCountForPlaylist(playlist, db: db)
            
            ZStack(alignment: .bottomTrailing) {
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
                
                if trackCount > 0 && isHovered {
                    Button {
                        let tracks = library.tracksForPlaylist(playlist, db: db)
                        if let first = tracks.first {
                            onPlayTrack(first, tracks)
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(t.primary)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            }
            .frame(width: 160, height: 160)
            .onHover { isHovered = $0 }
            
            HStack(spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .lineLimit(1)
            }
            
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
    var onGoBack: (() -> Void)? = nil
    
    @State private var tracks: [Track] = []

    @State private var coverHovered = false

    @State private var sortBy: String = "order"
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    private var sortedTracks: [Track] {
        switch sortBy {
        case "title": return tracks.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case "artist": return tracks.sorted { ($0.artist ?? "") < ($1.artist ?? "") }
        case "duration": return tracks.sorted { ($0.durationMs ?? 0) < ($1.durationMs ?? 0) }
        default: return tracks // custom/order — keep playlist sortOrder
        }
    }
    
    private var isCustomMode: Bool { sortBy == "custom" }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Back button
                if let goBack = onGoBack {
                    Button { goBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(t.onSurfaceVariant)
                            .frame(width: 28, height: 28)
                            .background(t.surfaceContainerHighest.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                let coverPath = library.playlistCoverArtwork(playlist, db: db)
                ZStack {
                    if coverPath != nil {
                        ArtworkView(path: coverPath, size: 72, cornerRadius: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [t.primaryContainer.opacity(0.6), t.primary.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                            .overlay(Image(systemName: "music.note.list").font(.system(size: 24, weight: .light)).foregroundStyle(.white.opacity(0.5)))
                    }
                    
                    if coverHovered {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.black.opacity(0.45))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.9))
                            )
                    }
                }
                .shadow(color: t.primary.opacity(0.2), radius: 10, y: 3)
                .onHover { coverHovered = $0 }
                .onTapGesture { pickCoverArt() }
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(playlist.name)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(t.onSurface)
                            .tracking(-0.5)
                    }
                    
                    Text("\(tracks.count) songs")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(t.onSurfaceVariant)
                    
                    HStack(spacing: 8) {
                        if !tracks.isEmpty {
                            Button {
                                if let first = sortedTracks.first { onPlayTrack(first, sortedTracks) }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "play.fill").font(.system(size: 9))
                                    Text("Play").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(t.onPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(t.primary).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                let shuffled = sortedTracks.shuffled()
                                if let first = shuffled.first { onPlayTrack(first, shuffled) }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "shuffle").font(.system(size: 9, weight: .bold))
                                    Text("Shuffle").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(t.primary)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(t.primaryContainer.opacity(0.2)).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if playlist.isVault {
                            Button { importFilesToVault() } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.plus").font(.system(size: 9, weight: .bold))
                                    Text("Import Files").font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.orange.opacity(0.12)).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button { sortBy = "custom" } label: { Label("Custom", systemImage: sortBy == "custom" ? "checkmark" : "") }
                    Button { sortBy = "order" } label: { Label("Playlist Order", systemImage: sortBy == "order" ? "checkmark" : "") }
                    Button { sortBy = "title" } label: { Label("Title", systemImage: sortBy == "title" ? "checkmark" : "") }
                    Button { sortBy = "artist" } label: { Label("Artist", systemImage: sortBy == "artist" ? "checkmark" : "") }
                    Button { sortBy = "duration" } label: { Label("Duration", systemImage: sortBy == "duration" ? "checkmark" : "") }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background(t.surfaceContainerHighest.opacity(0.4))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider().background(t.outlineVariant.opacity(0.3))
            
            if tracks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 40, weight: .thin)).foregroundStyle(t.outlineVariant.opacity(0.4))
                    Text("This playlist is empty")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(t.onSurfaceVariant.opacity(0.6))
                    Text(playlist.isVault ? "Use \"Import Files\" to add tracks." : "Add songs from the library or now playing bar.")
                        .font(.system(size: 12)).foregroundStyle(t.outlineVariant)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if isCustomMode {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            let playing = engine.currentTrack?.id == track.id && engine.isPlaying
                            HStack(spacing: 0) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 12))
                                    .foregroundStyle(t.outlineVariant.opacity(0.5))
                                    .frame(width: 24)
                                    .padding(.leading, 4)
                                
                                TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {
                                    onPlayTrack(track, tracks)
                                }
                            }
                            .contentShape(Rectangle())
                            .draggable(track.id.map { String($0) } ?? "") {
                                TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {}
                                    .frame(width: 400)
                                    .background(t.surfaceContainerLow.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                guard let droppedIdStr = droppedItems.first,
                                      let droppedId = Int64(droppedIdStr),
                                      let fromIndex = tracks.firstIndex(where: { $0.id == droppedId }),
                                      let toIndex = tracks.firstIndex(where: { $0.id == track.id }),
                                      fromIndex != toIndex else { return false }
                                tracks.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                                if let pid = playlist.id {
                                    let trackIds = tracks.compactMap { $0.id }
                                    library.reorderPlaylistTracks(playlistId: pid, trackIds: trackIds, db: db)
                                }
                                return true
                            }
                            .contextMenu {
                                removeFromPlaylistButton(for: track)
                                likeToggleButton(for: track)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sortedTracks.enumerated()), id: \.element.id) { index, track in
                            let playing = engine.currentTrack?.id == track.id && engine.isPlaying
                            TrackRow(track: track, index: index + 1, isPlaying: playing, t: t) {
                                onPlayTrack(track, sortedTracks)
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
    
    private func pickCoverArt() {
        let panel = NSOpenPanel()
        panel.title = "Choose Cover Art"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let coversDir = appSupport.appendingPathComponent("Resonance/PlaylistCovers", isDirectory: true)
            try? FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
            let destURL = coversDir.appendingPathComponent("\(playlist.id ?? 0)_\(Int(Date().timeIntervalSince1970)).\(url.pathExtension)")
            try? FileManager.default.copyItem(at: url, to: destURL)
            library.setPlaylistCoverArt(playlist, path: destURL.path, db: db)
        }
    }
    
    private func importFilesToVault() {
        let panel = NSOpenPanel()
        panel.title = "Import Audio Files to Vault"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select audio files or folders to import into this private vault"
        guard panel.runModal() == .OK else { return }
        guard let pid = playlist.id, let artworkDir = AppDatabase.shared.artworkDirectory else { return }
        
        library.importFilesToVaultPlaylist(urls: panel.urls, playlistId: pid, db: db, artworkDir: artworkDir)
        
        // Refresh tracks after a short delay to allow import to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            refreshTracks()
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
    @State private var sortBy: String = "title"
    
    private var filteredTracks: [Track] {
        var list = library.tracks
        if !searchText.isEmpty {
            let q = searchText
            list = list.filter {
                ($0.title?.localizedCaseInsensitiveContains(q) ?? false) ||
                ($0.artist?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }
        switch sortBy {
        case "artist":
            list.sort { ($0.artist ?? "") < ($1.artist ?? "") }
        case "duration":
            list.sort { ($0.durationMs ?? 0) < ($1.durationMs ?? 0) }
        default:
            list.sort { ($0.title ?? "") < ($1.title ?? "") }
        }
        return list
    }
    
    private var existingTrackIds: Set<Int64> {
        Set(library.tracksForPlaylist(playlist, db: db).compactMap { $0.id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("Add Songs to \"\(playlist.name)\"")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .lineLimit(1)
                Spacer()
                
                Menu {
                    Button { sortBy = "title" } label: {
                        Label("Title", systemImage: sortBy == "title" ? "checkmark" : "")
                    }
                    Button { sortBy = "artist" } label: {
                        Label("Artist", systemImage: sortBy == "artist" ? "checkmark" : "")
                    }
                    Button { sortBy = "duration" } label: {
                        Label("Duration", systemImage: sortBy == "duration" ? "checkmark" : "")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant)
                        .frame(width: 26, height: 26)
                        .background(t.surfaceContainerHighest.opacity(0.4))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Button("Done") { onDismiss() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(t.primary)
            }
            .padding()
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(t.outline)
                TextField("Search tracks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(t.outline)
                    }
                    .buttonStyle(.plain)
                }
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
                            
                            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(t.primary)
                                .font(.system(size: 18))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard let tid = track.id, let pid = playlist.id else { return }
                            if alreadyAdded {
                                library.removeTrackFromPlaylist(trackId: tid, playlistId: pid, db: db)
                            } else {
                                library.addTrackToPlaylist(trackId: tid, playlistId: pid, db: db)
                            }
                        }
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
    var showHeart: Bool = true
    var onTap: () -> Void
    
    @Environment(LibraryStore.self) var library
    @State private var isHovering = false
    
    var body: some View {
        let isLiked = track.id.map { library.isTrackLiked(trackId: $0) } ?? false
        HStack(spacing: 14) {
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
            
            // Heart — always show if liked, show on hover otherwise
            if showHeart && (isLiked || isHovering) {
                Button {
                    guard let tid = track.id, let dbw = AppDatabase.shared.dbWriter else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        library.toggleLike(trackId: tid, db: dbw)
                    }
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundStyle(isLiked ? Color(red: 1, green: 0.24, blue: 0.31) : t.onSurfaceVariant.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
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
        .onHover { isHovering = $0 }
        .onTapGesture { onTap() }
    }
}
