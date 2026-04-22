import Foundation
import AVFoundation

public struct ExtractedMetadata {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var durationMs: Int64?
    public var artworkData: Data?
    public var format: String?
    public var author: String?
    public var chapters: [ExtractedChapter] = []
}

public struct ExtractedChapter {
    public var title: String?
    public var startTimeMs: Int64
    public var index: Int
}

public actor MetadataExtractor {
    public static let shared = MetadataExtractor()
    
    private init() {}
    
    public func extract(from url: URL) async -> ExtractedMetadata {
        let asset = AVAsset(url: url)
        var meta = ExtractedMetadata()
        meta.format = url.pathExtension.lowercased()
        
        do {
            let duration = try await asset.load(.duration)
            meta.durationMs = Int64(duration.seconds * 1000)
        } catch {
            print("[MetadataExtractor] Failed to load duration: \(error)")
        }

        do {
            let commonMeta = try await asset.load(.commonMetadata)
            for item in commonMeta {
                if let key = item.commonKey {
                    switch key {
                    case .commonKeyTitle:
                        meta.title = try? await item.load(.stringValue)
                    case .commonKeyArtist:
                        meta.artist = try? await item.load(.stringValue)
                    case .commonKeyAlbumName:
                        meta.album = try? await item.load(.stringValue)
                    case .commonKeyArtwork:
                        meta.artworkData = try? await item.load(.dataValue)
                    case .commonKeyAuthor:
                        meta.author = try? await item.load(.stringValue)
                    default: break
                    }
                }
            }
        } catch {
            print("[MetadataExtractor] Failed to load common metadata: \(error)")
        }
        
        if meta.title == nil { meta.title = url.deletingPathExtension().lastPathComponent }
        
        let ext = url.pathExtension.lowercased()
        if ext == "m4b" || ext == "mp4b" {
            do {
                let locales = try await asset.load(.availableChapterLocales)
                let locale = locales.first ?? .current
                let chapterGroups = try await asset.loadChapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: [.commonKeyTitle])
                for (index, group) in chapterGroups.enumerated() {
                    var chapterTitle: String? = nil
                    for item in group.items {
                        if item.commonKey == .commonKeyTitle {
                            chapterTitle = try? await item.load(.stringValue)
                        }
                    }
                    meta.chapters.append(ExtractedChapter(
                        title: chapterTitle ?? "Chapter \(index + 1)",
                        startTimeMs: Int64(group.timeRange.start.seconds * 1000),
                        index: index
                    ))
                }
            } catch {
                print("[MetadataExtractor] Failed to load chapter metadata: \(error)")
            }
        }
        
        // If there are absolutely no chapters embedded, create a single "Full Audiobook" overarching chapter stub.
        if meta.chapters.isEmpty {
            meta.chapters.append(ExtractedChapter(
                title: "Full Audiobook",
                startTimeMs: 0,
                index: 0
            ))
        }
        
        return meta
    }
}
