import SwiftUI
import AppKit

/// Simple cache for images loaded from disk to prevent redundant I/O
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 200 // Cache up to 200 images
    }
    
    func image(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }
    
    func insert(_ image: NSImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }
}

/// A view that loads an NSImage from a local file path asynchronously
struct AsyncImageLoader<Content: View, Placeholder: View>: View {
    let path: String?
    @ViewBuilder let content: (NSImage) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var loadedImage: NSImage? = nil
    
    var body: some View {
        Group {
            if let image = loadedImage {
                content(image)
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: path) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let path = path, !path.isEmpty else {
            loadedImage = nil
            return
        }
        
        // Check cache first
        if let cached = ImageCache.shared.image(for: path) {
            loadedImage = cached
            return
        }
        
        // Load in background
        Task.detached(priority: .userInitiated) {
            if let image = NSImage(contentsOfFile: path) {
                // Pre-warm the image on a background thread if needed,
                // but NSImage(contentsOfFile:) does most work lazily anyway.
                // We'll just cache it and return to main.
                await MainActor.run {
                    ImageCache.shared.insert(image, for: path)
                    // Check if the path is still relevant
                    if self.path == path {
                        self.loadedImage = image
                    }
                }
            }
        }
    }
}
