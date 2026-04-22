import Foundation
import GRDB

public enum MediaType {
    case music
    case audiobook
}

public actor LibraryScanner {
    public static let shared = LibraryScanner()
    private init() {}
    
    public let supportedMusicFormats = Set(["mp3", "flac", "aac", "m4a"])
    public let supportedAudiobookFormats = Set(["m4b", "mp4b"])
    
    public func scanFolder(at url: URL, db: DatabasePool, artworkDir: URL, as forcedMediaType: MediaType? = nil) async {
        let fm = FileManager.default
        var allURLs: [URL] = []
        
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                guard let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
                    options: [.skipsHiddenFiles]
                ) else { return }
                
                if let files = enumerator.allObjects as? [URL] {
                    allURLs.append(contentsOf: files)
                }
            } else {
                allURLs.append(url)
            }
        } else {
            return
        }
        
        var musicBatch: [Track] = []
        var audiobookBatch: [(Audiobook, [ExtractedChapter])] = []
        
        for fileURL in allURLs {
            let ext = fileURL.pathExtension.lowercased()
            let isForcedMusic = forcedMediaType == .music
            let isForcedAudiobook = forcedMediaType == .audiobook
            
            let isMusicFallback = supportedMusicFormats.contains(ext)
            let isAudiobookFallback = supportedAudiobookFormats.contains(ext)
            
            let shouldCheck = isForcedMusic || isForcedAudiobook || isMusicFallback || isAudiobookFallback
            guard shouldCheck else { continue }
            
            let meta = await MetadataExtractor.shared.extract(from: fileURL)
            
            // Save artwork to disk
            var artworkPath: String? = nil
            if let artData = meta.artworkData {
                let artFile = artworkDir.appendingPathComponent(UUID().uuidString + ".jpg")
                try? artData.write(to: artFile)
                artworkPath = artFile.path
            }
            
            let targetIsMusic = isForcedMusic || (forcedMediaType == nil && isMusicFallback)
            let targetIsAudiobook = isForcedAudiobook || (forcedMediaType == nil && isAudiobookFallback)
            
            if targetIsMusic {
                let track = Track(
                    filePath: fileURL.path,
                    title: meta.title,
                    artist: meta.artist,
                    album: meta.album,
                    artworkPath: artworkPath,
                    durationMs: meta.durationMs,
                    format: ext
                )
                musicBatch.append(track)
                if musicBatch.count >= 100 {
                    await flushMusic(&musicBatch, db: db)
                }
            } else if targetIsAudiobook {
                let audiobook = Audiobook(
                    filePath: fileURL.path,
                    title: meta.title,
                    author: meta.author ?? meta.artist,
                    artworkPath: artworkPath,
                    durationMs: meta.durationMs,
                    format: ext
                )
                audiobookBatch.append((audiobook, meta.chapters))
                if audiobookBatch.count >= 20 {
                    await flushAudiobooks(&audiobookBatch, db: db)
                }
            }
        }
        
        // Final flush
        await flushMusic(&musicBatch, db: db)
        await flushAudiobooks(&audiobookBatch, db: db)
    }
    
    private func flushMusic(_ batch: inout [Track], db: DatabasePool) async {
        let toWrite = batch
        batch.removeAll()
        _ = try? await db.write { conn in
            for var track in toWrite {
                try track.save(conn)
            }
        }
    }
    
    private func flushAudiobooks(_ batch: inout [(Audiobook, [ExtractedChapter])], db: DatabasePool) async {
        let toWrite = batch
        batch.removeAll()
        for (audiobook, chapters) in toWrite {
            _ = try? await db.write { conn in
                var saved = audiobook
                try saved.save(conn)
                guard let bookId = saved.id else { return }
                try Chapter.filter(Column("audiobookId") == bookId).deleteAll(conn)
                for chapter in chapters {
                    var ch = Chapter(
                        audiobookId: bookId,
                        title: chapter.title,
                        startTimeMs: chapter.startTimeMs,
                        index: chapter.index
                    )
                    try ch.insert(conn)
                }
            }
        }
    }
}
