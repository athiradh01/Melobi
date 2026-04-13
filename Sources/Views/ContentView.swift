import SwiftUI
import AppKit
import GRDB

// MARK: - Sidebar Section
enum AppSection: String, CaseIterable {
    case home = "Home"
    case music = "Library"
    case audiobooks = "Audiobooks"
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .music: return "music.note.list"
        case .audiobooks: return "book.closed"
        }
    }
    var filledIcon: String {
        switch self {
        case .home: return "house.fill"
        case .music: return "music.note.list"
        case .audiobooks: return "book.closed.fill"
        }
    }
}

// MARK: - Sort Options
enum SortOption: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case dateAdded = "Date Added"
    case duration = "Duration"
}

// MARK: - Theme Manager
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    var overrideScheme: ColorScheme? = nil
    private init() {}
    func toggle(current: ColorScheme) {
        overrideScheme = current == .dark ? .light : .dark
    }
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
    @Environment(\.colorScheme) var systemScheme
    
    let db: DatabasePool
    
    private var activeScheme: ColorScheme { themeManager.overrideScheme ?? systemScheme }
    private var t: Theme { Theme(scheme: activeScheme) }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                sidebar
                
                // Main content — instant section switch, child animations preserved
                mainContent
                    .animation(.none, value: section)
            }
            
            if engine.currentTrack != nil || engine.currentAudiobook != nil {
                if !engine.isNowPlayingViewActive || engine.currentAudiobook == nil {
                    NowPlayingBar()
                        .padding(.horizontal, 24)
                        .padding(.leading, 230)
                        .padding(.bottom, 12)
                }
            }
        }
        .background(t.background)
        .preferredColorScheme(themeManager.overrideScheme)
        .environment(library)
        .environment(engine)
        .environment(lyrics)
    }
    
    // MARK: - Sidebar (no Import Folder)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Velvet Echo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .tracking(-0.5)
                Text("THE ETHEREAL GALLERY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(t.outlineVariant)
                    .tracking(2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
            
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(t.outline)
                TextField("Search…", text: Binding(
                    get: { library.searchQuery },
                    set: { library.searchQuery = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                if !library.searchQuery.isEmpty {
                    Button { library.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(t.outline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(t.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            
            // Nav items
            VStack(spacing: 2) {
                ForEach(AppSection.allCases, id: \.self) { sec in
                    Button {
                        section = sec
                        if engine.isNowPlayingViewActive {
                            engine.isNowPlayingViewActive = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section == sec ? sec.filledIcon : sec.icon)
                                .font(.system(size: 15))
                                .frame(width: 20)
                            Text(sec.rawValue)
                                .font(.system(size: 13, weight: section == sec ? .bold : .medium))
                            Spacer()
                        }
                        .foregroundStyle(section == sec ? t.primary : t.onSurfaceVariant)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .background(section == sec ? t.surfaceContainer : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Theme toggle — icon only (sun / crescent moon)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeManager.toggle(current: activeScheme)
                }
            } label: {
                ZStack {
                    Image(systemName: activeScheme == .dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(activeScheme == .dark ? Color.orange : t.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 36, height: 36)
                .background(t.surfaceContainerHigh.opacity(0.5))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 230)
        .background(.ultraThinMaterial)
        .background(t.sidebarBg)
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
                        section = .music
                        engine.queue = library.tracks
                        engine.currentQueueIndex = library.tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                        engine.load(track: track)
                        lyrics.load(for: URL(fileURLWithPath: track.filePath))
                        engine.play()
                    },
                    db: db
                )
            case .music:
                MusicLibraryView(sortOption: $sortOption, sortAscending: $sortAscending, db: db)
            case .audiobooks:
                AudiobooksView(db: db)
            }
        }
    }
}
