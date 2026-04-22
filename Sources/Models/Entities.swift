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
