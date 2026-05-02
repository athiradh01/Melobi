import SwiftUI
import AppKit
import GRDB
import Observation

// MARK: - Sidebar Section
enum AppSection: String, CaseIterable {
    case home = "Home"
    case music = "Library"
    case audiobooks = "Audiobooks"
    case likedSongs = "Liked Songs"
    case playlists = "Playlists"
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .music: return "music.note.list"
        case .audiobooks: return "book.closed"
        case .likedSongs: return "heart"
        case .playlists: return "music.note.list"
        }
    }
    var filledIcon: String {
        switch self {
        case .home: return "house.fill"
        case .music: return "music.note.list"
        case .audiobooks: return "book.closed.fill"
        case .likedSongs: return "heart.fill"
        case .playlists: return "music.note.list"
        }
    }
    
    /// Sections that appear as the main nav items
    static var mainCases: [AppSection] { [.home, .music, .audiobooks] }
}

// MARK: - Sort Options
enum SortOption: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case dateAdded = "Date Added"
    case duration = "Duration"
}



// MARK: - Main Content View
struct ContentView: View {
    @State private var section: AppSection = .home
    @State private var library = LibraryStore.shared
    @State private var engine = AudioEngine.shared
    @State private var lyrics = LyricsState.shared
    @State private var themeManager = ThemeManager.shared
    @State private var sortOption: SortOption = .dateAdded
    @State private var sortAscending = false
    @State private var selectedPlaylist: Playlist?
    @State private var showNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    @Environment(\.colorScheme) var systemScheme
    
    let db: DatabasePool
    
    private var activeScheme: ColorScheme { themeManager.overrideScheme ?? systemScheme }
    private var t: Theme { Theme(scheme: activeScheme, lightPalette: themeManager.activeLightTheme.theme, darkPalette: themeManager.activeDarkTheme.theme) }
    
    /// Sorted tracks matching the library's current display order
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
            sidebar
            
            ZStack(alignment: .bottom) {
                // Luminous Audio ambient gradient blobs
                if t.isGlassmorphic {
                    ambientBlobs
                }
                
                // Main content — instant section switch, child animations preserved
                mainContent
                    .animation(.none, value: section)
                    .background(t.isGlassmorphic ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial.opacity(0)))
                    .background(t.isGlassmorphic ? Color.clear : t.background)
                
                if engine.currentTrack != nil || engine.currentAudiobook != nil {
                    if !engine.isNowPlayingViewActive || engine.currentAudiobook == nil {
                        NowPlayingBar()
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }
                }
            }
            .background(t.isGlassmorphic ? Color.clear : Color.clear)
            .background(.ultraThinMaterial)
            .background(t.background)

        }
        .background(t.isGlassmorphic ? Color.clear : Color.clear)
        .background(.ultraThinMaterial)
        .background(t.background)
        .preferredColorScheme(themeManager.overrideScheme)
        .environment(library)
        .environment(engine)
        .environment(lyrics)
        .id(themeManager.activeLightTheme)
    }
    
    // MARK: - Ambient Gradient Blobs (for Luminous Audio)
    private var ambientBlobs: some View {
        ZStack {
            // Electric Violet blob — top-left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [t.primaryContainer.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -180, y: -120)
                .blur(radius: 60)
            
            // Cyan blob — bottom-right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [t.secondary.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 250, y: 200)
                .blur(radius: 50)
            
            // Pink accent blob — center-bottom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [t.tertiary.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 50, y: 280)
                .blur(radius: 40)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Sidebar (no Import Folder)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeScheme == .dark ? themeManager.activeDarkTheme.rawValue : themeManager.activeLightTheme.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .tracking(-0.5)
                    .lineLimit(1)
                Text(t.isGlassmorphic ? "LUMINOUS AUDIO" : "THE ETHEREAL GALLERY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(t.isGlassmorphic ? t.primary.opacity(0.6) : t.outlineVariant)
                    .tracking(2)
                    .lineLimit(1)
                    .shadow(color: t.isGlassmorphic ? t.primaryContainer.opacity(0.5) : Color.clear, radius: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
            
            // Nav items
            VStack(spacing: 2) {
                ForEach(AppSection.mainCases, id: \.self) { sec in
                    sidebarButton(for: sec)
                }
            }
            .padding(.horizontal, 12)
            .onChange(of: section) { _, _ in
                deactivateSearch()
                selectedPlaylist = nil
            }
            
            // MARK: - Your Music section
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR MUSIC")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(t.outlineVariant)
                    .tracking(2)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                
                // Liked Songs
                sidebarButton(for: .likedSongs)
                
                // Playlists header + create
                HStack {
                    Text("PLAYLISTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(t.outlineVariant)
                        .tracking(2)
                    Spacer()
                    Button {
                        showNewPlaylistAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(t.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 6)
                
                // Playlist items
                ForEach(library.playlists) { playlist in
                    Button {
                        selectedPlaylist = playlist
                        section = .playlists
                        if engine.isNowPlayingViewActive {
                            engine.isNowPlayingViewActive = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 13))
                                .frame(width: 20)
                            Text(playlist.name)
                                .font(.system(size: 12, weight: (section == .playlists && selectedPlaylist?.id == playlist.id) ? .bold : .medium))
                                .lineLimit(1)
                            Spacer()
                        }
                        .foregroundStyle((section == .playlists && selectedPlaylist?.id == playlist.id) ? t.primary : t.onSurfaceVariant)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background {
                            if section == .playlists && selectedPlaylist?.id == playlist.id {
                                sidebarSelectionBackground
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete Playlist", role: .destructive) {
                            if selectedPlaylist?.id == playlist.id {
                                selectedPlaylist = nil
                                section = .home
                            }
                            library.deletePlaylist(playlist, db: db)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
                TextField("Playlist name", text: $newPlaylistName)
                Button("Create") {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    if let pl = library.createPlaylist(name: name, db: db) {
                        selectedPlaylist = pl
                        section = .playlists
                    }
                    newPlaylistName = ""
                }
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
            } message: {
                Text("Enter a name for your new playlist.")
            }

            Spacer()
            
            // Theme toggle & palette selector
            HStack(spacing: 8) {
                // Light/Dark toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        themeManager.toggle(current: activeScheme)
                    }
                } label: {
                    ZStack {
                        Image(systemName: activeScheme == .dark ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(activeScheme == .dark ? Color.orange : t.primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 32, height: 32)
                    .background(
                        t.isGlassmorphic
                            ? AnyShapeStyle(Color.white.opacity(0.06))
                            : AnyShapeStyle(t.surfaceContainerHigh.opacity(0.5))
                    )
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Theme Palette Selector (dynamically changes based on active mode)
                Menu {
                    if activeScheme == .dark {
                        ForEach(DarkThemeOption.allCases) { option in
                            Button(option.rawValue) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    themeManager.activeDarkTheme = option
                                }
                            }
                        }
                    } else {
                        ForEach(LightThemeOption.allCases) { option in
                            Button(option.rawValue) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    themeManager.activeLightTheme = option
                                }
                            }
                        }
                    }
                } label: {
                    Text(activeScheme == .dark ? themeManager.activeDarkTheme.rawValue : themeManager.activeLightTheme.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(t.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(
                            t.isGlassmorphic
                                ? AnyShapeStyle(Color.white.opacity(0.06))
                                : AnyShapeStyle(t.surfaceContainerHigh.opacity(0.5))
                        )
                        .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 150, idealWidth: 230, maxWidth: 230)
        .background {
            if t.isGlassmorphic {
                // Glass sidebar with subtle violet gradient bleed
                ZStack {
                    Color.black.opacity(0.5)
                    LinearGradient(
                        colors: [t.primaryContainer.opacity(0.08), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .background(.ultraThinMaterial)
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    t.sidebarBg
                }
            }
        }
    }
    
    // MARK: - Search helpers
    private func deactivateSearch() {
        withAnimation(.easeInOut(duration: 0.15)) {
            library.searchQuery = ""
        }
    }
    
    // MARK: - Main Content (no animation)
    @ViewBuilder
    private var mainContent: some View {
        if engine.isNowPlayingViewActive {
            NowPlayingView(db: db)
        } else {
            switch section {
            case .home:
                HomeView(
                    onNavigateToLibrary: { section = .music },
                    onPlayTrack: { track in
                        playTrack(track, from: sortedTracks)
                    },
                    onPlayAudiobook: { book in
                        deactivateSearch()
                        let chapters = library.chapters(for: book, db: db)
                        let resumePos = library.resumePosition(for: book, db: db)
                        engine.load(audiobook: book, resumePosition: resumePos, chapters: chapters)
                        engine.play()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            engine.isNowPlayingViewActive = true
                        }
                    },
                    db: db
                )
            case .music:
                MusicLibraryView(sortOption: $sortOption, sortAscending: $sortAscending, db: db)
            case .audiobooks:
                AudiobooksView(db: db)
            case .likedSongs:
                LikedSongsView(db: db, onPlayTrack: { track, queue in
                    playTrack(track, from: queue)
                })
            case .playlists:
                if let playlist = selectedPlaylist {
                    PlaylistDetailView(playlist: playlist, db: db, onPlayTrack: { track, queue in
                        playTrack(track, from: queue)
                    })
                } else {
                    PlaylistsOverviewView(db: db, onSelectPlaylist: { playlist in
                        selectedPlaylist = playlist
                    })
                }
            }
        }
    }
    
    private func playTrack(_ track: Track, from queue: [Track]) {
        deactivateSearch()
        engine.queue = queue
        engine.currentQueueIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        engine.load(track: track)
        lyrics.load(for: URL(fileURLWithPath: track.filePath))
        engine.play()
    }
    
    // MARK: - Sidebar Helpers
    
    private func sidebarButton(for sec: AppSection) -> some View {
        Button {
            section = sec
            if sec != .playlists { selectedPlaylist = nil }
            if engine.isNowPlayingViewActive {
                engine.isNowPlayingViewActive = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section == sec && (sec != .playlists || selectedPlaylist == nil) ? sec.filledIcon : sec.icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                Text(sec.rawValue)
                    .font(.system(size: 13, weight: (section == sec && (sec != .playlists || selectedPlaylist == nil)) ? .bold : .medium))
                    .lineLimit(1)
                Spacer()
                if sec == .likedSongs {
                    Text("\(library.likedTrackIds.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(t.outlineVariant)
                }
            }
            .foregroundStyle((section == sec && (sec != .playlists || selectedPlaylist == nil)) ? t.primary : t.onSurfaceVariant)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background {
                if section == sec && (sec != .playlists || selectedPlaylist == nil) {
                    sidebarSelectionBackground
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var sidebarSelectionBackground: some View {
        if t.isGlassmorphic {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: t.primaryContainer.opacity(0.15), radius: 12, x: 0, y: 0)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(t.surfaceContainer)
        }
    }
}
