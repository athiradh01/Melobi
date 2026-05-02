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
    
    public init(id: Int64? = nil, filePath: String, title: String? = nil, artist: String? = nil, album: String? = nil, artworkPath: String? = nil, durationMs: Int64? = nil, format: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkPath = artworkPath
        self.durationMs = durationMs
        self.format = format
        self.dateAdded = dateAdded
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
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: Int64? = nil, name: String, artworkPath: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.artworkPath = artworkPath
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
    
    public init(id: Int64? = nil, trackId: Int64, likedAt: Date = Date()) {
        self.id = id
        self.trackId = trackId
        self.likedAt = likedAt
    }
    
    mutating public func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
