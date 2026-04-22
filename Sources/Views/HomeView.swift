import SwiftUI
import AppKit
import GRDB

// MARK: - Home View
struct HomeView: View {
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme

    var onNavigateToLibrary: () -> Void
    var onPlayTrack: (Track) -> Void
    var onPlayAudiobook: (Audiobook) -> Void
    let db: DatabasePool

    @State private var albums: [AlbumInfo] = []
    @State private var randomTracks: [Track] = []

    private var t: Theme { Theme(scheme: colorScheme) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 28) {
                
                // MARK: Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(t.outline)
                    
                    SearchField(
                        text: Binding(
                            get: { library.searchQuery },
                            set: { library.searchQuery = $0 }
                        ),
                        placeholder: "Search your library...",
                        onCancel: { library.searchQuery = "" },
                        focusOnAppear: false
                    )
                    .frame(height: 24)
                    
                    if !library.searchQuery.isEmpty {
                        Button {
                            library.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(t.outline)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(t.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 8)

                // MARK: Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Made For You")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                        .tracking(-0.5)
                    Text("Your personal collection, always offline.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.onSurfaceVariant)
                }

                // MARK: Content sections
                normalContent

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .background(t.surface)
        .onAppear {
            updateAlbums()
            updateRandomTracks()
        }
        .onChange(of: library.filteredTracks) { _, _ in
            updateAlbums()
            updateRandomTracks()
        }
    }

    // MARK: - Normal home content
    @ViewBuilder
    private var normalContent: some View {
        // Hero bento — Using Recently Added and Random
        if let mostRecent = library.filteredTracks.sorted(by: { $0.dateAdded > $1.dateAdded }).first {
            HStack(spacing: 10) {
                heroCard(track: mostRecent, large: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)

                if randomTracks.count >= 2 {
                    let r0 = randomTracks[0], r1 = randomTracks[1]
                    VStack(spacing: 10) {
                        heroCard(track: r0, large: false)
                            .frame(height: 115)
                        heroCard(track: r1, large: false)
                            .frame(height: 115)
                    }
                    .frame(width: 200)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } else if let firstTrack = library.filteredTracks.first {
            heroCard(track: firstTrack, large: true)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
        } else {
            emptyState
        }

        // Recently Added
        if !library.filteredTracks.isEmpty {
            recentSection
        }

        // Random Discoveries
        if !randomTracks.isEmpty {
            randomSection
        }

        // Your Collection (Albums)
        if !albums.isEmpty {
            collectionSection
        }

        // Audiobooks
        if !library.filteredAudiobooks.isEmpty {
            audiobooksSection
        }
    }

    private func updateRandomTracks() {
        guard !library.filteredTracks.isEmpty else { 
            self.randomTracks = []
            return 
        }
        self.randomTracks = Array(library.filteredTracks.shuffled().prefix(12))
    }

    private func updateAlbums() {
        Task {
            let result = buildAlbums()
            await MainActor.run {
                self.albums = result
            }
        }
    }

    // MARK: - Hero Card
    private func heroCard(track: Track, large: Bool) -> some View {
        VStack(alignment: .leading) {
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text(large ? (track.album ?? track.title ?? "Your Library") : (track.title ?? "Track"))
                    .font(.system(size: large ? 20 : 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(large ? 2 : 1)
                    .shadow(color: t.primaryDim.opacity(0.4), radius: 25, x: 0, y: 0)
                Text(track.artist ?? "Unknown")
                    .font(.system(size: large ? 12 : 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .shadow(color: t.primaryDim.opacity(0.4), radius: 25, x: 0, y: 0)

                if large {
                    Button { onPlayTrack(track) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill").font(.system(size: 9))
                            Text("Play").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(t.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(large ? 16 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center, endPoint: .bottom
            )
        )
        .background(
            AsyncImageLoader(path: track.artworkPath) { img in
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                LinearGradient(
                    colors: [t.primaryContainer, t.primary.opacity(0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: large ? 24 : 16, style: .continuous))
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onPlayTrack(track) }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.house")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(t.outlineVariant.opacity(0.4))
            Text("No music yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(t.onSurfaceVariant.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(t.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Collection
    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Collection")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(t.onSurface)
                Spacer()
                Button { onNavigateToLibrary() } label: {
                    Text("View All")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(t.primary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(albums, id: \.name) { album in
                        VStack(alignment: .leading, spacing: 5) {
                            Color.clear
                                .frame(width: 120, height: 120)
                                .background(
                                    AsyncImageLoader(path: album.artwork) { img in
                                        Image(nsImage: img)
                                            .resizable()
                                            .interpolation(.medium)
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ZStack {
                                            t.surfaceContainerHigh
                                            Image(systemName: "music.note")
                                                .font(.system(size: 22, weight: .light))
                                                .foregroundStyle(t.primary.opacity(0.3))
                                        }
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .clipped()

                            Text(album.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(t.onSurface)
                                .lineLimit(1)
                            Text("\(album.artist) • \(album.count) tracks")
                                .font(.system(size: 10))
                                .foregroundStyle(t.onSurfaceVariant)
                                .lineLimit(1)
                        }
                        .frame(width: 120)
                        .onTapGesture {
                            if let first = album.firstTrack { onPlayTrack(first) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Recently Added
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(t.onSurface)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(library.filteredTracks.sorted { $0.dateAdded > $1.dateAdded }.prefix(8))) { track in
                        VStack(alignment: .leading, spacing: 5) {
                            ArtworkView(path: track.artworkPath, size: 120, cornerRadius: 8)
                                .onTapGesture { onPlayTrack(track) }

                            Text(track.title ?? "Unknown")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(t.onSurface)
                                .lineLimit(1)
                            Text(track.artist ?? "Unknown Artist")
                                .font(.system(size: 10))
                                .foregroundStyle(t.onSurfaceVariant)
                                .lineLimit(1)
                        }
                        .frame(width: 120)
                    }
                }
            }
        }
    }

    // MARK: - Random Section
    private var randomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Random Discoveries")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(t.onSurface)

            VStack(spacing: 0) {
                ForEach(randomTracks.prefix(6)) { track in
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
                        Text(formatTime(Double(track.durationMs ?? 0) / 1000))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(t.outline)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { onPlayTrack(track) }
                }
            }
            .background(t.surfaceContainerLow.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Audiobooks
    private var audiobooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audiobooks")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(t.onSurface)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(library.filteredAudiobooks.prefix(10)) { book in
                        VStack(alignment: .leading, spacing: 6) {
                            ArtworkView(path: book.artworkPath, size: 140, cornerRadius: 10)
                                .onTapGesture { onPlayAudiobook(book) }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title ?? "Unknown")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(t.onSurface)
                                    .lineLimit(1)
                                Text(book.author ?? "Unknown Author")
                                    .font(.system(size: 10))
                                    .foregroundStyle(t.onSurfaceVariant)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 140)
                    }
                }
            }
        }
    }

    // MARK: - Album data builder
    private struct AlbumInfo: Hashable {
        let name: String
        let artist: String
        let artwork: String?
        let count: Int
        let firstTrack: Track?

        func hash(into hasher: inout Hasher) { hasher.combine(name) }
        static func == (lhs: AlbumInfo, rhs: AlbumInfo) -> Bool { lhs.name == rhs.name }
    }

    private func buildAlbums() -> [AlbumInfo] {
        var dict: [String: (artist: String, artwork: String?, count: Int, first: Track)] = [:]
        for track in library.filteredTracks.prefix(200) {
            let album = track.album ?? "Unknown"
            if let e = dict[album] {
                dict[album] = (e.artist, e.artwork, e.count + 1, e.first)
            } else {
                dict[album] = (track.artist ?? "Unknown", track.artworkPath, 1, track)
            }
        }
        return Array(dict.map { AlbumInfo(name: $0.key, artist: $0.value.artist, artwork: $0.value.artwork, count: $0.value.count, firstTrack: $0.value.first) }
            .sorted { $0.count > $1.count }
            .prefix(10))
    }
}
