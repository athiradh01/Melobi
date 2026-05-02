import Foundation
import GRDB

public final class AppDatabase {
    public static let shared = AppDatabase()
    public private(set) var dbWriter: DatabasePool?
    
    /// The resolved writable data directory used for the database and artwork.
    public private(set) var dataDirectory: URL?
    
    /// Convenience: artwork sub-directory inside the data directory.
    public var artworkDirectory: URL? {
        guard let dir = dataDirectory else { return nil }
        let art = dir.appendingPathComponent("Artwork")
        try? FileManager.default.createDirectory(at: art, withIntermediateDirectories: true)
        return art
    }
    
    /// Convenience: lyrics sub-directory inside the data directory.
    public var lyricsDirectory: URL? {
        guard let dir = dataDirectory else { return nil }
        let lyrics = dir.appendingPathComponent("Lyrics")
        try? FileManager.default.createDirectory(at: lyrics, withIntermediateDirectories: true)
        return lyrics
    }
    
    private init() {}
    
    /// Resolve a writable data directory.
    /// Tries `~/Library/Application Support/Resonance` first; falls back to
    /// a `Database/` folder next to the running executable.
    public static func resolveDataDirectory() -> URL {
        let fm = FileManager.default
        
        // Attempt 1: Application Support (standard macOS location)
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let preferred = appSupport.appendingPathComponent("Resonance")
            try? fm.createDirectory(at: preferred, withIntermediateDirectories: true)
            // Verify we can actually write there
            let probe = preferred.appendingPathComponent(".write_test")
            if fm.createFile(atPath: probe.path, contents: Data()) {
                try? fm.removeItem(at: probe)
                return preferred
            }
        }
        
        // Attempt 2: Folder next to the executable
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .appendingPathComponent("Database")
        try? fm.createDirectory(at: execDir, withIntermediateDirectories: true)
        return execDir
    }
    
    public func setup(in directory: URL) throws {
        self.dataDirectory = directory
        let dbURL = directory.appendingPathComponent("library.sqlite")
        let dbPool = try DatabasePool(path: dbURL.path)
        self.dbWriter = dbPool
        try migrator.migrate(dbPool)
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1") { db in
            try db.create(table: "libraryFolder") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("path", .text).notNull().unique()
                t.column("lastScannedAt", .datetime)
            }
            
            try db.create(table: "track") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("filePath", .text).notNull().unique()
                t.column("title", .text)
                t.column("artist", .text)
                t.column("album", .text)
                t.column("artworkPath", .text)
                t.column("durationMs", .integer)
                t.column("format", .text)
                t.column("dateAdded", .datetime).notNull()
            }
            
            try db.create(table: "audiobook") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("filePath", .text).notNull().unique()
                t.column("title", .text)
                t.column("author", .text)
                t.column("artworkPath", .text)
                t.column("durationMs", .integer)
                t.column("format", .text)
                t.column("dateAdded", .datetime).notNull()
            }
            
            try db.create(table: "chapter") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("audiobookId", .integer).notNull().references("audiobook", onDelete: .cascade)
                t.column("title", .text)
                t.column("startTimeMs", .integer).notNull()
                t.column("index", .integer).notNull()
            }
            
            try db.create(table: "resumePosition") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("audiobookId", .integer).notNull().unique().references("audiobook", onDelete: .cascade)
                t.column("positionMs", .integer).notNull()
                t.column("lastPlayedAt", .datetime).notNull()
            }
        }
        
        migrator.registerMigration("v2") { db in
            try db.create(table: "chapterProgress") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("audiobookId", .integer).notNull().references("audiobook", onDelete: .cascade)
                t.column("chapterIndex", .integer).notNull()
                t.column("progressMs", .integer).notNull().defaults(to: 0)
                t.column("isCompleted", .boolean).notNull().defaults(to: false)
                t.column("lastUpdatedAt", .datetime).notNull()
                t.uniqueKey(["audiobookId", "chapterIndex"])
            }
        }
        
        migrator.registerMigration("v3") { db in
            try db.create(table: "playlist") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("artworkPath", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            
            try db.create(table: "playlistTrack") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("playlistId", .integer).notNull().references("playlist", onDelete: .cascade)
                t.column("trackId", .integer).notNull().references("track", onDelete: .cascade)
                t.column("sortOrder", .integer).notNull()
                t.column("addedAt", .datetime).notNull()
                t.uniqueKey(["playlistId", "trackId"])
            }
            
            try db.create(table: "likedTrack") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("trackId", .integer).notNull().unique().references("track", onDelete: .cascade)
                t.column("likedAt", .datetime).notNull()
            }
        }
        
        return migrator
    }
}
