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
    
    private static let schemeKey = "app.themeScheme"
    private static let lightThemeKey = "app.lightTheme"
    
    var overrideScheme: ColorScheme? {
        didSet { saveScheme() }
    }
    var activeLightTheme: LightThemeOption {
        didSet { UserDefaults.standard.set(activeLightTheme.rawValue, forKey: Self.lightThemeKey) }
    }
    
    private init() {
        // Restore light theme
        if let raw = UserDefaults.standard.string(forKey: Self.lightThemeKey),
           let theme = LightThemeOption(rawValue: raw) {
            activeLightTheme = theme
        } else {
            activeLightTheme = .mintBreeze
        }
        // Restore dark/light override
        let schemeRaw = UserDefaults.standard.integer(forKey: Self.schemeKey)
        switch schemeRaw {
        case 1:  overrideScheme = .light
        case 2:  overrideScheme = .dark
        default: overrideScheme = nil
        }
    }
    
    private func saveScheme() {
        switch overrideScheme {
        case .light:   UserDefaults.standard.set(1, forKey: Self.schemeKey)
        case .dark:    UserDefaults.standard.set(2, forKey: Self.schemeKey)
        default:       UserDefaults.standard.set(0, forKey: Self.schemeKey)
        }
    }
    
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
    private var t: Theme { Theme(scheme: activeScheme, lightPalette: themeManager.activeLightTheme.theme) }
    
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
                // Main content — instant section switch, child animations preserved
                mainContent
                    .animation(.none, value: section)
                    .background(t.background)
                
                if engine.currentTrack != nil || engine.currentAudiobook != nil {
                    if !engine.isNowPlayingViewActive || engine.currentAudiobook == nil {
                        NowPlayingBar()
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }
                }
            }
            .background(t.background)

        }
        .background(t.background)
        .preferredColorScheme(themeManager.overrideScheme)
        .environment(library)
        .environment(engine)
        .environment(lyrics)
        .id(themeManager.activeLightTheme)
    }
    
    // MARK: - Sidebar (no Import Folder)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(themeManager.activeLightTheme.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .tracking(-0.5)
                    .lineLimit(1)
                Text("THE ETHEREAL GALLERY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(t.outlineVariant)
                    .tracking(2)
                    .lineLimit(1)
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
                                .lineLimit(1)
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
                    .background(t.surfaceContainerHigh.opacity(0.5))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Theme Palette Selector (only visible in Light Mode)
                if activeScheme != .dark {
                    Menu {
                        ForEach(LightThemeOption.allCases) { option in
                            Button(option.rawValue) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    themeManager.activeLightTheme = option
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(themeManager.activeLightTheme.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(t.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(t.surfaceContainerHigh.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 150, idealWidth: 230, maxWidth: 230)
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
                        let sorted = sortedTracks
                        engine.queue = sorted
                        engine.currentQueueIndex = sorted.firstIndex(where: { $0.id == track.id }) ?? 0
                        engine.load(track: track)
                        lyrics.load(for: URL(fileURLWithPath: track.filePath))
                        engine.play()
                    },
                    onPlayAudiobook: { book in
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
            }
        }
    }
}
