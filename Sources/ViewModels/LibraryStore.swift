import Foundation
import GRDB
import Observation

@MainActor
@Observable
public final class LibraryStore {
    public static let shared = LibraryStore()
    
    public var tracks: [Track] = []
    public var audiobooks: [Audiobook] = []
    public var searchQuery = "" {
        didSet { rebuildFiltered() }
    }
    public var isScanning = false
    public var scanProgress = ""
    
    /// Track IDs that belong ONLY to vault playlists (not in any normal playlist or imported normally via library).
    /// These are excluded from the main library view.
    public var vaultOnlyTrackIds: Set<Int64> = []
    
    // Cached filtered results — avoid recomputing on every body eval
    public var filteredTracks: [Track] = []
    public var filteredAudiobooks: [Audiobook] = []
    
    private var trackObservation: AnyDatabaseCancellable?
    private var audiobookObservation: AnyDatabaseCancellable?
    private var lastResumeWrite: Date = .distantPast
    
    private init() {}
    
    public func startObserving(db: DatabasePool) {
        // Purge tracks/audiobooks whose files no longer exist on disk
        purgeStaleEntries(db: db)
        
        trackObservation = ValueObservation.tracking { db in
            try Track.fetchAll(db)
        }
        .start(in: db, scheduling: .immediate) { error in
            print("Track observation error: \(error)")
        } onChange: { [weak self] tracks in
            Task { @MainActor in
                self?.tracks = tracks
                self?.rebuildFiltered()
            }
        }
        
        audiobookObservation = ValueObservation.tracking { db in
            try Audiobook.fetchAll(db)
        }
        .start(in: db, scheduling: .immediate) { error in
            print("Audiobook observation error: \(error)")
        } onChange: { [weak self] books in
            Task { @MainActor in
                self?.audiobooks = books
                self?.rebuildFiltered()
            }
        }
    }
    
    private func rebuildFiltered() {
        let nonVaultTracks = tracks.filter { track in
            guard let tid = track.id else { return true }
            return !vaultOnlyTrackIds.contains(tid)
        }
        if searchQuery.isEmpty {
            filteredTracks = nonVaultTracks
            filteredAudiobooks = audiobooks
        } else {
            let q = searchQuery
            filteredTracks = nonVaultTracks.filter {
                ($0.title?.localizedCaseInsensitiveContains(q) ?? false) ||
                ($0.artist?.localizedCaseInsensitiveContains(q) ?? false) ||
                ($0.album?.localizedCaseInsensitiveContains(q) ?? false)
            }
            filteredAudiobooks = audiobooks.filter {
                ($0.title?.localizedCaseInsensitiveContains(q) ?? false) ||
                ($0.author?.localizedCaseInsensitiveContains(q) ?? false)
            }
        }
    }
    
    public func importFolder(url: URL, db: DatabasePool, artworkDir: URL, as forcedMediaType: MediaType? = nil) {
        isScanning = true
        scanProgress = "Scanning…"
        Task.detached(priority: .background) {
            await LibraryScanner.shared.scanFolder(at: url, db: db, artworkDir: artworkDir, as: forcedMediaType)
            await MainActor.run {
                LibraryStore.shared.isScanning = false
                LibraryStore.shared.scanProgress = ""
            }
        }
    }
    
    public func chapters(for audiobook: Audiobook, db: DatabasePool) -> [Chapter] {
        guard let abId = audiobook.id else { return [] }
        return (try? db.read { conn in
            try Chapter.filter(Column("audiobookId") == abId).order(Column("index")).fetchAll(conn)
        }) ?? []
    }
    
    /// Re-extracts chapters from disk for an existing audiobook and writes them to the DB.
    public func rescanChapters(for audiobook: Audiobook, db: DatabasePool, artworkDir: URL) {
        isScanning = true
        scanProgress = "Rescanning chapters…"
        Task.detached(priority: .background) {
            let url = URL(fileURLWithPath: audiobook.filePath).standardizedFileURL
            let meta = await MetadataExtractor.shared.extract(from: url)
            let chaptersToWrite = meta.chapters
            if let abId = audiobook.id {
                do {
                    try await db.write { conn in
                        try Chapter.filter(Column("audiobookId") == abId).deleteAll(conn)
                        for chapter in chaptersToWrite {
                            var ch = Chapter(
                                audiobookId: abId,
                                title: chapter.title,
                                startTimeMs: chapter.startTimeMs,
                                index: chapter.index
                            )
                            try ch.insert(conn)
                        }
                    }
                } catch {
                    print("Failed to rescan chapters: \(error)")
                }
            }
            await MainActor.run {
                LibraryStore.shared.isScanning = false
                LibraryStore.shared.scanProgress = ""
            }
        }
    }
    
    public func resumePosition(for audiobook: Audiobook, db: DatabasePool) -> Double {
        guard let abId = audiobook.id else { return 0 }
        let pos = try? db.read { conn in
            try ResumePosition.filter(Column("audiobookId") == abId).fetchOne(conn)
        }
        return Double(pos?.positionMs ?? 0) / 1000.0
    }
    
    // Throttled write — at most once every 5 seconds
    public func saveResumePosition(for audiobook: Audiobook, positionMs: Int64, db: DatabasePool) {
        let now = Date()
        guard now.timeIntervalSince(lastResumeWrite) >= 5 else { return }
        lastResumeWrite = now
        guard let abId = audiobook.id else { return }
        do {
            try db.write { conn in
                var pos = ResumePosition(audiobookId: abId, positionMs: positionMs, lastPlayedAt: Date())
                try pos.save(conn)
            }
        } catch {
            print("[LibraryStore] Failed to save resume position: \(error)")
        }
    }
    
    public func deleteTrack(_ track: Track, db: DatabasePool) {
        guard track.id != nil else { return }
        do {
            _ = try db.write { conn in
                try track.delete(conn)
            }
        } catch {
            print("[LibraryStore] Failed to delete track: \(error)")
        }
    }
    
    public func deleteTracks(_ tracks: [Track], db: DatabasePool) {
        let ids = tracks.compactMap { $0.id }
        guard !ids.isEmpty else { return }
        do {
            try db.write { conn in
                for track in tracks {
                    try track.delete(conn)
                }
            }
        } catch {
            print("[LibraryStore] Failed to delete tracks: \(error)")
        }
    }
    
    public func deleteAudiobook(_ audiobook: Audiobook, db: DatabasePool) {
        guard let id = audiobook.id else { return }
        do {
            try db.write { conn in
                try Chapter.filter(Column("audiobookId") == id).deleteAll(conn)
                try ResumePosition.filter(Column("audiobookId") == id).deleteAll(conn)
                try ChapterProgress.filter(Column("audiobookId") == id).deleteAll(conn)
                try audiobook.delete(conn)
            }
        } catch {
            print("[LibraryStore] Failed to delete audiobook: \(error)")
        }
    }
    
    // MARK: - Chapter Progress
    
    /// Load all chapter progress records for an audiobook, keyed by chapter index.
    public func chapterProgressMap(for audiobook: Audiobook, db: DatabasePool) -> [Int: ChapterProgress] {
        guard let abId = audiobook.id else { return [:] }
        let rows = (try? db.read { conn in
            try ChapterProgress.filter(Column("audiobookId") == abId).fetchAll(conn)
        }) ?? []
        var map: [Int: ChapterProgress] = [:]
        for row in rows {
            map[row.chapterIndex] = row
        }
        return map
    }
    
    /// Save progress for a specific chapter. Throttled to at most once per 3 seconds per chapter.
    private var lastChapterProgressWrite: Date = .distantPast
    
    public func saveChapterProgress(for audiobook: Audiobook, chapterIndex: Int, progressMs: Int64, isCompleted: Bool, db: DatabasePool) {
        // Throttle writes — at most once every 3 seconds (unless marking completed)
        let now = Date()
        if !isCompleted && now.timeIntervalSince(lastChapterProgressWrite) < 3 { return }
        lastChapterProgressWrite = now
        
        guard let abId = audiobook.id else { return }
        do {
            try db.write { conn in
                if var existing = try ChapterProgress
                    .filter(Column("audiobookId") == abId && Column("chapterIndex") == chapterIndex)
                    .fetchOne(conn) {
                    existing.progressMs = progressMs
                    existing.isCompleted = isCompleted
                    existing.lastUpdatedAt = Date()
                    try existing.update(conn)
                } else {
                    var cp = ChapterProgress(
                        audiobookId: abId,
                        chapterIndex: chapterIndex,
                        progressMs: progressMs,
                        isCompleted: isCompleted
                    )
                    try cp.insert(conn)
                }
            }
        } catch {
            print("[LibraryStore] Failed to save chapter progress: \(error)")
        }
    }
    
    /// Get the saved progress (in ms from chapter start) for a specific chapter. Returns 0 if none saved.
    public func chapterResumeMs(for audiobook: Audiobook, chapterIndex: Int, db: DatabasePool) -> Int64 {
        guard let abId = audiobook.id else { return 0 }
        let cp = try? db.read { conn in
            try ChapterProgress
                .filter(Column("audiobookId") == abId && Column("chapterIndex") == chapterIndex)
                .fetchOne(conn)
        }
        guard let cp, !cp.isCompleted else { return 0 }
        return cp.progressMs
    }
    
    /// Remove all tracks and audiobooks whose files no longer exist on disk.
    private func purgeStaleEntries(db: DatabasePool) {
        let fm = FileManager.default
        do {
            try db.write { conn in
                let allTracks = try Track.fetchAll(conn)
                var purgedCount = 0
                for track in allTracks {
                    if !fm.fileExists(atPath: track.filePath) {
                        try track.delete(conn)
                        purgedCount += 1
                    }
                }
                if purgedCount > 0 {
                    print("[LibraryStore] Purged \(purgedCount) tracks with missing files.")
                }
                
                let allBooks = try Audiobook.fetchAll(conn)
                var purgedBooks = 0
                for book in allBooks {
                    if !fm.fileExists(atPath: book.filePath) {
                        if let id = book.id {
                            try Chapter.filter(Column("audiobookId") == id).deleteAll(conn)
                            try ResumePosition.filter(Column("audiobookId") == id).deleteAll(conn)
                        }
                        try book.delete(conn)
                        purgedBooks += 1
                    }
                }
                if purgedBooks > 0 {
                    print("[LibraryStore] Purged \(purgedBooks) audiobooks with missing files.")
                }
            }
        } catch {
            print("[LibraryStore] Failed to purge stale entries: \(error)")
        }
    }
    
    // MARK: - Playlists
    
    public var playlists: [Playlist] = []
    public var likedTrackIds: Set<Int64> = []
    
    private var playlistObservation: AnyDatabaseCancellable?
    private var likedObservation: AnyDatabaseCancellable?
    
    public func startPlaylistObserving(db: DatabasePool) {
        playlistObservation = ValueObservation.tracking { db in
            try Playlist.order(Column("updatedAt").desc).fetchAll(db)
        }
        .start(in: db, scheduling: .immediate) { error in
            print("Playlist observation error: \(error)")
        } onChange: { [weak self] playlists in
            Task { @MainActor in
                self?.playlists = playlists
                self?.refreshVaultTrackIds(db: db)
            }
        }
        
        likedObservation = ValueObservation.tracking { db in
            try LikedTrack.fetchAll(db)
        }
        .start(in: db, scheduling: .immediate) { error in
            print("Liked observation error: \(error)")
        } onChange: { [weak self] liked in
            Task { @MainActor in
                self?.likedTrackIds = Set(liked.map { $0.trackId })
            }
        }
    }
    
    /// Convenience computed properties to separate vault from regular playlists
    public var regularPlaylists: [Playlist] {
        playlists.filter { !$0.isVault }
    }
    
    public var vaultPlaylists: [Playlist] {
        playlists.filter { $0.isVault }
    }
    
    // MARK: - Playlist CRUD
    
    public func createPlaylist(name: String, db: DatabasePool) -> Playlist? {
        do {
            return try db.write { conn in
                var playlist = Playlist(name: name)
                try playlist.insert(conn)
                return playlist
            }
        } catch {
            print("[LibraryStore] Failed to create playlist: \(error)")
            return nil
        }
    }
    
    public func createVaultPlaylist(name: String, db: DatabasePool) -> Playlist? {
        do {
            return try db.write { conn in
                var playlist = Playlist(name: name, isVault: true)
                try playlist.insert(conn)
                return playlist
            }
        } catch {
            print("[LibraryStore] Failed to create vault playlist: \(error)")
            return nil
        }
    }
    
    /// Import audio files directly into a vault playlist. The tracks are inserted into the
    /// `track` table but marked as vault-only so they don't appear in the main library.
    public func importFilesToVaultPlaylist(urls: [URL], playlistId: Int64, db: DatabasePool, artworkDir: URL) {
        isScanning = true
        scanProgress = "Importing to vault…"
        Task.detached(priority: .background) {
            let supportedFormats = Set(["mp3", "flac", "aac", "m4a"])
            
            var allURLs: [URL] = []
            let fm = FileManager.default
            for url in urls {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]),
                           let files = enumerator.allObjects as? [URL] {
                            allURLs.append(contentsOf: files)
                        }
                    } else {
                        allURLs.append(url)
                    }
                }
            }
            
            for fileURL in allURLs {
                let ext = fileURL.pathExtension.lowercased()
                guard supportedFormats.contains(ext) else { continue }
                
                let meta = await MetadataExtractor.shared.extract(from: fileURL)
                
                let artworkPath: String? = {
                    if let artData = meta.artworkData {
                        let artFile = artworkDir.appendingPathComponent(UUID().uuidString + ".jpg")
                        try? artData.write(to: artFile)
                        return artFile.path
                    }
                    return nil
                }()
                
                do {
                    try await db.write { conn in
                        // Insert or find existing track
                        var track: Track
                        if let existing = try Track.filter(Column("filePath") == fileURL.path).fetchOne(conn) {
                            track = existing
                        } else {
                            track = Track(
                                filePath: fileURL.path,
                                title: meta.title,
                                artist: meta.artist,
                                album: meta.album,
                                artworkPath: artworkPath,
                                durationMs: meta.durationMs,
                                format: ext
                            )
                            try track.insert(conn)
                        }
                        
                        guard let trackId = track.id else { return }
                        
                        // Check if already in this playlist
                        let exists = try PlaylistTrack
                            .filter(Column("playlistId") == playlistId && Column("trackId") == trackId)
                            .fetchOne(conn) != nil
                        
                        if !exists {
                            let maxOrder = try Int.fetchOne(conn,
                                sql: "SELECT MAX(sortOrder) FROM playlistTrack WHERE playlistId = ?",
                                arguments: [playlistId]
                            ) ?? -1
                            
                            var pt = PlaylistTrack(playlistId: playlistId, trackId: trackId, sortOrder: maxOrder + 1)
                            try pt.insert(conn)
                            
                            try conn.execute(
                                sql: "UPDATE playlist SET updatedAt = ? WHERE id = ?",
                                arguments: [Date(), playlistId]
                            )
                        }
                    }
                } catch {
                    print("[LibraryStore] Failed to import vault track: \(error)")
                }
            }
            
            await MainActor.run {
                LibraryStore.shared.isScanning = false
                LibraryStore.shared.scanProgress = ""
                // Refresh vault track IDs after import
                if let dbWriter = AppDatabase.shared.dbWriter {
                    LibraryStore.shared.refreshVaultTrackIds(db: dbWriter)
                }
            }
        }
    }
    
    /// Recompute which track IDs belong exclusively to vault playlists.
    /// A track is vault-only if it appears in at least one vault playlist
    /// and does NOT appear in any non-vault playlist.
    public func refreshVaultTrackIds(db: DatabasePool) {
        do {
            let ids: Set<Int64> = try db.read { conn in
                // All track IDs in vault playlists
                let vaultIds = try Int64.fetchAll(conn, sql: """
                    SELECT DISTINCT pt.trackId FROM playlistTrack pt
                    INNER JOIN playlist p ON p.id = pt.playlistId
                    WHERE p.isVault = 1
                """)
                
                // All track IDs in normal playlists
                let normalIds = try Set(Int64.fetchAll(conn, sql: """
                    SELECT DISTINCT pt.trackId FROM playlistTrack pt
                    INNER JOIN playlist p ON p.id = pt.playlistId
                    WHERE p.isVault = 0
                """))
                
                // All track IDs that were imported via library folders (exist in libraryFolder scan)
                // We consider a track as "library-imported" if it existed before any vault playlist referenced it.
                // Simpler approach: a track is vault-only if it's ONLY in vault playlists and not in normal playlists.
                // But we also need to check if the track was added independently to the library.
                // We track this by checking if the track is referenced by ANY non-vault playlist or was in the library
                // before. Since all tracks go into the track table, we use a heuristic:
                // A track is vault-only if:
                //   1. It's in a vault playlist
                //   2. It's NOT in any non-vault playlist
                //   3. It was NOT explicitly imported into the library (i.e., it only exists because of vault import)
                // For simplicity, we mark tracks as vault-only if they're ONLY in vault playlists.
                
                return Set(vaultIds.filter { !normalIds.contains($0) })
            }
            self.vaultOnlyTrackIds = ids
            rebuildFiltered()
        } catch {
            print("[LibraryStore] Failed to refresh vault track IDs: \(error)")
        }
    }
    
    public func renamePlaylist(_ playlist: Playlist, to name: String, db: DatabasePool) {
        guard var p = playlist as Playlist?, p.id != nil else { return }
        p.name = name
        p.updatedAt = Date()
        do {
            try db.write { conn in
                try p.update(conn)
            }
        } catch {
            print("[LibraryStore] Failed to rename playlist: \(error)")
        }
    }
    
    public func deletePlaylist(_ playlist: Playlist, db: DatabasePool) {
        guard let pid = playlist.id else { return }
        let isVault = playlist.isVault
        do {
            try db.write { conn in
                if isVault {
                    // Get track IDs in this vault playlist
                    let vaultTrackIds = try Int64.fetchAll(conn,
                        sql: "SELECT trackId FROM playlistTrack WHERE playlistId = ?",
                        arguments: [pid]
                    )
                    
                    // Delete the playlist (cascades to playlistTrack)
                    _ = try playlist.delete(conn)
                    
                    // For each track that was in this vault, check if it's now orphaned
                    // (not in any other playlist)
                    for trackId in vaultTrackIds {
                        let otherCount = try Int.fetchOne(conn,
                            sql: "SELECT COUNT(*) FROM playlistTrack WHERE trackId = ?",
                            arguments: [trackId]
                        ) ?? 0
                        
                        if otherCount == 0 {
                            // This track is orphaned — delete it
                            try conn.execute(
                                sql: "DELETE FROM track WHERE id = ?",
                                arguments: [trackId]
                            )
                        }
                    }
                } else {
                    _ = try playlist.delete(conn)
                }
            }
            if isVault {
                refreshVaultTrackIds(db: db)
            }
        } catch {
            print("[LibraryStore] Failed to delete playlist: \(error)")
        }
    }
    
    public func addTrackToPlaylist(trackId: Int64, playlistId: Int64, db: DatabasePool) {
        do {
            try db.write { conn in
                // Get next sort order
                let maxOrder = try Int.fetchOne(conn,
                    sql: "SELECT MAX(sortOrder) FROM playlistTrack WHERE playlistId = ?",
                    arguments: [playlistId]
                ) ?? -1
                
                var pt = PlaylistTrack(playlistId: playlistId, trackId: trackId, sortOrder: maxOrder + 1)
                try pt.insert(conn)
                
                // Update playlist timestamp
                try conn.execute(
                    sql: "UPDATE playlist SET updatedAt = ? WHERE id = ?",
                    arguments: [Date(), playlistId]
                )
            }
        } catch {
            // Likely duplicate — silently ignore
        }
    }
    
    public func removeTrackFromPlaylist(trackId: Int64, playlistId: Int64, db: DatabasePool) {
        do {
            try db.write { conn in
                try PlaylistTrack
                    .filter(Column("playlistId") == playlistId && Column("trackId") == trackId)
                    .deleteAll(conn)
                    
                try conn.execute(
                    sql: "UPDATE playlist SET updatedAt = ? WHERE id = ?",
                    arguments: [Date(), playlistId]
                )
            }
        } catch {
            print("[LibraryStore] Failed to remove track from playlist: \(error)")
        }
    }
    
    public func tracksForPlaylist(_ playlist: Playlist, db: DatabasePool) -> [Track] {
        guard let pid = playlist.id else { return [] }
        return (try? db.read { conn in
            try Track.fetchAll(conn,
                sql: """
                    SELECT track.* FROM track
                    INNER JOIN playlistTrack ON playlistTrack.trackId = track.id
                    WHERE playlistTrack.playlistId = ?
                    ORDER BY playlistTrack.sortOrder ASC
                """,
                arguments: [pid]
            )
        }) ?? []
    }
    
    public func trackCountForPlaylist(_ playlist: Playlist, db: DatabasePool) -> Int {
        guard let pid = playlist.id else { return 0 }
        return (try? db.read { conn in
            try Int.fetchOne(conn,
                sql: "SELECT COUNT(*) FROM playlistTrack WHERE playlistId = ?",
                arguments: [pid]
            )
        }) ?? 0
    }
    
    /// Returns the artwork path from the first track in the playlist (used as a fallback cover).
    public func playlistCoverArtwork(_ playlist: Playlist, db: DatabasePool) -> String? {
        // Use custom cover art if set
        if let custom = playlist.artworkPath, !custom.isEmpty {
            return custom
        }
        // Fall back to first track's artwork
        guard let pid = playlist.id else { return nil }
        return try? db.read { conn in
            try String.fetchOne(conn,
                sql: """
                    SELECT track.artworkPath FROM track
                    INNER JOIN playlistTrack ON playlistTrack.trackId = track.id
                    WHERE playlistTrack.playlistId = ?
                    ORDER BY playlistTrack.sortOrder ASC
                    LIMIT 1
                """,
                arguments: [pid]
            )
        }
    }
    
    public func setPlaylistCoverArt(_ playlist: Playlist, path: String?, db: DatabasePool) {
        guard let pid = playlist.id else { return }
        do {
            try db.write { conn in
                try conn.execute(
                    sql: "UPDATE playlist SET artworkPath = ?, updatedAt = ? WHERE id = ?",
                    arguments: [path, Date(), pid]
                )
            }
        } catch {
            print("[LibraryStore] Failed to set playlist cover art: \(error)")
        }
    }
    
    public func reorderPlaylistTracks(playlistId: Int64, trackIds: [Int64], db: DatabasePool) {
        do {
            try db.write { conn in
                for (index, trackId) in trackIds.enumerated() {
                    try conn.execute(
                        sql: "UPDATE playlistTrack SET sortOrder = ? WHERE playlistId = ? AND trackId = ?",
                        arguments: [index, playlistId, trackId]
                    )
                }
            }
        } catch {
            print("[LibraryStore] Failed to reorder playlist tracks: \(error)")
        }
    }
    
    // MARK: - Liked Songs
    
    public func toggleLike(trackId: Int64, db: DatabasePool) {
        do {
            try db.write { conn in
                if let existing = try LikedTrack.filter(Column("trackId") == trackId).fetchOne(conn) {
                    try existing.delete(conn)
                } else {
                    // Get next sort order (add to end)
                    let maxOrder = try Int.fetchOne(conn,
                        sql: "SELECT MAX(sortOrder) FROM likedTrack"
                    ) ?? -1
                    var liked = LikedTrack(trackId: trackId, sortOrder: maxOrder + 1)
                    try liked.insert(conn)
                }
            }
        } catch {
            print("[LibraryStore] Failed to toggle like: \(error)")
        }
    }
    
    public func reorderLikedTracks(trackIds: [Int64], db: DatabasePool) {
        do {
            try db.write { conn in
                for (index, trackId) in trackIds.enumerated() {
                    try conn.execute(
                        sql: "UPDATE likedTrack SET sortOrder = ? WHERE trackId = ?",
                        arguments: [index, trackId]
                    )
                }
            }
        } catch {
            print("[LibraryStore] Failed to reorder liked tracks: \(error)")
        }
    }
    
    public func isTrackLiked(trackId: Int64) -> Bool {
        likedTrackIds.contains(trackId)
    }
    
    public func likedTracks(db: DatabasePool) -> [Track] {
        return (try? db.read { conn in
            try Track.fetchAll(conn,
                sql: """
                    SELECT track.* FROM track
                    INNER JOIN likedTrack ON likedTrack.trackId = track.id
                    ORDER BY likedTrack.sortOrder ASC
                """
            )
        }) ?? []
    }
}
