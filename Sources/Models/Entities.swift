import Foundation
import GRDB

public struct LibraryFolder: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var path: String
    public var lastScannedAt: Date?
    
    public init(id: Int64? = nil, path: String, lastScannedAt: Date? = nil) {
        self.id = id
        self.path = path
        self.lastScannedAt = lastScannedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct Track: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var filePath: String
    public var title: String?
    public var artist: String?
    public var album: String?
    public var artworkPath: String?
    public var durationMs: Int64?
    public var format: String?
    public var dateAdded: Date
    /// BCP-47 / ISO 639-1 language code ("en", "ja", "ml", …) detected from the track's
    /// title/artist text. `nil` means "not yet detected" (eligible for backfill).
    public var language: String?

    public init(id: Int64? = nil, filePath: String, title: String? = nil, artist: String? = nil, album: String? = nil, artworkPath: String? = nil, durationMs: Int64? = nil, format: String? = nil, dateAdded: Date = Date(), language: String? = nil) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkPath = artworkPath
        self.durationMs = durationMs
        self.format = format
        self.dateAdded = dateAdded
        self.language = language
    }

    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct Audiobook: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var filePath: String
    public var title: String?
    public var author: String?
    public var artworkPath: String?
    public var durationMs: Int64?
    public var format: String?
    public var dateAdded: Date
    
    public init(id: Int64? = nil, filePath: String, title: String? = nil, author: String? = nil, artworkPath: String? = nil, durationMs: Int64? = nil, format: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.author = author
        self.artworkPath = artworkPath
        self.durationMs = durationMs
        self.format = format
        self.dateAdded = dateAdded
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct Chapter: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var audiobookId: Int64
    public var title: String?
    public var startTimeMs: Int64
    public var index: Int
    
    public init(id: Int64? = nil, audiobookId: Int64, title: String? = nil, startTimeMs: Int64, index: Int) {
        self.id = id
        self.audiobookId = audiobookId
        self.title = title
        self.startTimeMs = startTimeMs
        self.index = index
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct ResumePosition: Codable, FetchableRecord, MutablePersistableRecord, Equatable {
    public var id: Int64?
    public var audiobookId: Int64
    public var positionMs: Int64
    public var lastPlayedAt: Date
    
    public init(id: Int64? = nil, audiobookId: Int64, positionMs: Int64, lastPlayedAt: Date = Date()) {
        self.id = id
        self.audiobookId = audiobookId
        self.positionMs = positionMs
        self.lastPlayedAt = lastPlayedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Tracks per-chapter playback progress for audiobooks.
public struct ChapterProgress: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    /// The audiobook this chapter belongs to
    public var audiobookId: Int64
    /// The chapter index within the audiobook
    public var chapterIndex: Int
    /// How far into the chapter (in ms from chapter start) the user has listened
    public var progressMs: Int64
    /// Whether the chapter has been fully listened to
    public var isCompleted: Bool
    /// Last time this record was updated
    public var lastUpdatedAt: Date
    
    public init(id: Int64? = nil, audiobookId: Int64, chapterIndex: Int, progressMs: Int64 = 0, isCompleted: Bool = false, lastUpdatedAt: Date = Date()) {
        self.id = id
        self.audiobookId = audiobookId
        self.chapterIndex = chapterIndex
        self.progressMs = progressMs
        self.isCompleted = isCompleted
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Playlist

public struct Playlist: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var name: String
    public var artworkPath: String?
    public var isVault: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: Int64? = nil, name: String, artworkPath: String? = nil, isVault: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.artworkPath = artworkPath
        self.isVault = isVault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct PlaylistTrack: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var playlistId: Int64
    public var trackId: Int64
    public var sortOrder: Int
    public var addedAt: Date
    
    public init(id: Int64? = nil, playlistId: Int64, trackId: Int64, sortOrder: Int, addedAt: Date = Date()) {
        self.id = id
        self.playlistId = playlistId
        self.trackId = trackId
        self.sortOrder = sortOrder
        self.addedAt = addedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

public struct LikedTrack: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    public var trackId: Int64
    public var likedAt: Date
    public var sortOrder: Int
    
    public init(id: Int64? = nil, trackId: Int64, likedAt: Date = Date(), sortOrder: Int = 0) {
        self.id = id
        self.trackId = trackId
        self.likedAt = likedAt
        self.sortOrder = sortOrder
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Lyrics Sync Data

/// Stores the raw sync timestamps obtained from manual or auto sync.
/// This is the permanent baseline — pre-roll adjustments produce "tune data"
/// which is saved separately in the `.lrc` file for playback.
public struct LyricsSyncData: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    public var id: Int64?
    /// The file path of the track this sync data belongs to
    public var trackFilePath: String
    /// The raw LRC content with original sync timestamps
    public var lrcContent: String
    /// The last applied pre-roll offset (in ms) so the slider can be restored
    public var preRollMs: Double
    /// "manual" or "auto"
    public var syncMethod: String
    /// When the sync was performed
    public var syncedAt: Date
    
    public init(id: Int64? = nil, trackFilePath: String, lrcContent: String, preRollMs: Double = 0, syncMethod: String, syncedAt: Date = Date()) {
        self.id = id
        self.trackFilePath = trackFilePath
        self.lrcContent = lrcContent
        self.preRollMs = preRollMs
        self.syncMethod = syncMethod
        self.syncedAt = syncedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
