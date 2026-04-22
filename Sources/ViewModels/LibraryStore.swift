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
    
    // Cached filtered results — avoid recomputing on every body eval
    public var filteredTracks: [Track] = []
    public var filteredAudiobooks: [Audiobook] = []
    
    private var trackObservation: AnyDatabaseCancellable?
    private var audiobookObservation: AnyDatabaseCancellable?
    private var lastResumeWrite: Date = .distantPast
    
    private init() {}
    
    public func startObserving(db: DatabasePool) {
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
        if searchQuery.isEmpty {
            filteredTracks = tracks
            filteredAudiobooks = audiobooks
        } else {
            let q = searchQuery
            filteredTracks = tracks.filter {
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
            let url = URL(fileURLWithPath: audiobook.filePath)
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
        _ = try? db.write { conn in
            var pos = ResumePosition(audiobookId: abId, positionMs: positionMs, lastPlayedAt: Date())
            try pos.save(conn)
        }
    }
    
    public func deleteTrack(_ track: Track, db: DatabasePool) {
        guard track.id != nil else { return }
        _ = try? db.write { conn in
            try track.delete(conn)
        }
    }
    
    public func deleteTracks(_ tracks: [Track], db: DatabasePool) {
        let ids = tracks.compactMap { $0.id }
        guard !ids.isEmpty else { return }
        try? db.write { conn in
            for track in tracks {
                try track.delete(conn)
            }
        }
    }
    
    public func deleteAudiobook(_ audiobook: Audiobook, db: DatabasePool) {
        guard let id = audiobook.id else { return }
        try? db.write { conn in
            // Delete chapters first
            try Chapter.filter(Column("audiobookId") == id).deleteAll(conn)
            // Delete resume position
            try ResumePosition.filter(Column("audiobookId") == id).deleteAll(conn)
            try audiobook.delete(conn)
        }
    }
}
