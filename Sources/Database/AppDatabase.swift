import Foundation
import GRDB

public final class AppDatabase {
    public static let shared = AppDatabase()
    public var dbWriter: DatabasePool!
    
    private init() {}
    
    public func setup(in directory: URL) throws {
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
        
        return migrator
    }
}
