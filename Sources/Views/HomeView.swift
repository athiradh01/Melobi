import SwiftUI
import AppKit
import GRDB

// MARK: - Home View (FIXED — no overlapping, images as backgrounds)
struct HomeView: View {
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    
    var onNavigateToLibrary: () -> Void
    var onPlayTrack: (Track) -> Void
    let db: DatabasePool
    
    @State private var albums: [AlbumInfo] = []
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Made For You")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                        .tracking(-0.5)
                    Text("Your personal collection, always offline.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.onSurfaceVariant)
                }
                .padding(.top, 8)
                
                // Hero bento
                if library.tracks.count >= 3 {
                    HStack(spacing: 10) {
                        heroCard(track: library.tracks[0], large: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                        
                        VStack(spacing: 10) {
                            heroCard(track: library.tracks[1], large: false)
                                .frame(height: 115)
                            heroCard(track: library.tracks[2], large: false)
                                .frame(height: 115)
                        }
                        .frame(width: 200)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else if !library.tracks.isEmpty {
                    heroCard(track: library.tracks[0], large: true)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                } else {
                    emptyState
                }
                
                // Your Collection
                if !library.tracks.isEmpty {
                    collectionSection
                }
                
                // Recently Added
                if !library.tracks.isEmpty {
                    recentSection
                }
                
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .background(t.surface)
        .onAppear { updateAlbums() }
        .onChange(of: library.tracks) { _, _ in updateAlbums() }
    }
    
    private func updateAlbums() {
        // Run in background to avoid blocking main thread if library is large
        Task {
            let result = buildAlbums()
            await MainActor.run {
                self.albums = result
            }
        }
    }
    
    // MARK: - Hero Card (image as BACKGROUND, not ZStack content)
    private func heroCard(track: Track, large: Bool) -> some View {
        // The key fix: use Color.clear for sizing, image goes in .background()
        VStack(alignment: .leading) {
            Spacer()
            
            // Text content at bottom
            VStack(alignment: .leading, spacing: 2) {
                Text(large ? (track.album ?? track.title ?? "Your Library") : (track.title ?? "Track"))
                    .font(.system(size: large ? 20 : 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(large ? 2 : 1)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                Text(track.artist ?? "Unknown")
                    .font(.system(size: large ? 12 : 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                
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
            // Gradient overlay on top of image
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center, endPoint: .bottom
            )
        )
        .background(
            // Image as background — this is the key fix for overlapping
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onPlayTrack(track) }
    }
    
    // MARK: - Empty state
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
                            // Album art — use background approach
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
            
            VStack(spacing: 0) {
                ForEach(Array(library.tracks.sorted { $0.dateAdded > $1.dateAdded }.prefix(6))) { track in
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
        for track in library.tracks.prefix(200) { // limit scan for performance
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
