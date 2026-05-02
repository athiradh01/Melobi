import SwiftUI
import AppKit
import GRDB

// MARK: - Audiobooks View (Velvet Echo Desktop)
struct AudiobooksView: View {
    @Environment(LibraryStore.self) var library
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    
    @State private var selectedBook: Audiobook? = nil
    @State private var chapters: [Chapter] = []
    @State private var resumeSeconds: Double = 0
    @State private var isRescanning = false
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        HStack(spacing: 0) {
            // Book list
            VStack(spacing: 0) {
                HStack {
                    Text("\(library.filteredAudiobooks.count) Audiobooks")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(t.onSurfaceVariant)
                        .textCase(.uppercase)
                        .tracking(1)
                    Spacer()
                    Button { addAudiobook() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add Audiobook")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(t.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(t.primaryContainer.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(library.filteredAudiobooks) { book in
                            Button {
                                selectBook(book)
                            } label: {
                                HStack(spacing: 14) {
                                    ArtworkView(path: book.artworkPath, size: 48, cornerRadius: 8)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(book.title ?? "Unknown")
                                            .font(.system(size: 13, weight: selectedBook?.id == book.id ? .bold : .semibold))
                                            .foregroundStyle(selectedBook?.id == book.id ? t.primary : t.onSurface)
                                            .lineLimit(1)
                                        Text(book.author ?? "Unknown Author")
                                            .font(.system(size: 11))
                                            .foregroundStyle(t.onSurfaceVariant)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if engine.currentAudiobook?.id == book.id && engine.isPlaying {
                                        Image(systemName: "waveform")
                                            .symbolEffect(.variableColor.iterative)
                                            .font(.system(size: 13))
                                            .foregroundStyle(t.primary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(selectedBook?.id == book.id ? t.surfaceContainerLow : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    if selectedBook?.id == book.id { selectedBook = nil }
                                    // Stop playback if this audiobook is currently playing
                                    if engine.currentAudiobook?.id == book.id {
                                        engine.pause()
                                        engine.currentAudiobook = nil
                                    }
                                    library.deleteAudiobook(book, db: db)
                                } label: {
                                    Label("Remove from Library", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .frame(minWidth: 280, maxWidth: 320)
            .background(t.surface)
            
            Divider().opacity(0.1)
            
            // Detail
            if let book = selectedBook {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero
                        HStack(alignment: .top, spacing: 20) {
                            ArtworkView(path: book.artworkPath, size: 100, cornerRadius: 14)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AUDIOBOOK")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(t.primary)
                                    .tracking(2)
                                Text(book.title ?? "Unknown")
                                    .font(.system(size: 22, weight: .heavy))
                                    .foregroundStyle(t.onSurface)
                                    .tracking(-0.3)
                                Text(book.author ?? "Unknown Author")
                                    .font(.system(size: 14))
                                    .foregroundStyle(t.onSurfaceVariant)
                                Text(formatTime(Double(book.durationMs ?? 0) / 1000))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(t.outline)
                                    .monospacedDigit()
                                
                                HStack(spacing: 12) {
                                    Button {
                                        engine.load(audiobook: book, resumePosition: resumeSeconds, chapters: chapters)
                                        engine.play()
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            engine.isNowPlayingViewActive = true
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "play.fill").font(.system(size: 12))
                                            Text("Play").font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundStyle(colorScheme == .light ? t.primary : t.onPrimary)
                                        .padding(.horizontal, 20).padding(.vertical, 9)
                                        .background(colorScheme == .light ? t.primaryContainer.opacity(0.2) : t.primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if resumeSeconds > 1 {
                                        Text("Resume \(formatTime(resumeSeconds))")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(t.primary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            Spacer()
                        }
                        .padding(24)
                        
                        // Chapters
                        if !chapters.isEmpty {
                            Text("CHAPTERS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(t.onSurfaceVariant)
                                .tracking(2)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 8)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(chapters) { chapter in
                                    Button {
                                        engine.load(audiobook: book, resumePosition: Double(chapter.startTimeMs) / 1000, chapters: chapters)
                                        engine.play()
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            engine.isNowPlayingViewActive = true
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text("\(chapter.index + 1)")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(t.outlineVariant)
                                                .frame(width: 24, alignment: .trailing)
                                                .monospacedDigit()
                                            Text(chapter.title ?? "Chapter \(chapter.index + 1)")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(t.onSurface)
                                            Spacer()
                                            Text(formatTime(Double(chapter.startTimeMs) / 1000))
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundStyle(t.outline)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 9)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Spacer().frame(height: 40)
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 28, weight: .thin))
                                    .foregroundStyle(t.outlineVariant.opacity(0.5))
                                if isRescanning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Scanning for chapters…")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(t.onSurfaceVariant.opacity(0.5))
                                } else {
                                    Text("No chapters found")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(t.onSurfaceVariant.opacity(0.5))
                                    Button {
                                        if let book = selectedBook { rescanChapters(book) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 10, weight: .bold))
                                            Text("Rescan Chapters")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundStyle(t.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(t.primaryContainer.opacity(0.2))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .background(t.surface)
                .onChange(of: engine.currentTime) { _, newTime in
                    if let ab = engine.currentAudiobook {
                        library.saveResumePosition(for: ab, positionMs: Int64(newTime * 1000), db: db)
                    }
                }
                .onChange(of: library.isScanning) { _, scanning in
                    // Refresh chapters once a rescan finishes
                    if !scanning, isRescanning, let book = selectedBook {
                        let fresh = library.chapters(for: book, db: db)
                        chapters = fresh
                        isRescanning = false
                        // Update engine chapters too if this book is loaded
                        if engine.currentAudiobook?.id == book.id {
                            engine.chapters = fresh
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(t.outlineVariant.opacity(0.4))
                    Text("Select an audiobook")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(t.surface)
            }
        }
    }
    
    private func selectBook(_ book: Audiobook) {
        selectedBook = book
        let fetched = library.chapters(for: book, db: db)
        chapters = fetched
        resumeSeconds = library.resumePosition(for: book, db: db)
        // Auto-trigger rescan if no chapters found
        if fetched.isEmpty {
            rescanChapters(book)
        }
    }
    
    private func rescanChapters(_ book: Audiobook) {
        isRescanning = true
        guard let artworkDir = AppDatabase.shared.artworkDirectory else { return }
        library.rescanChapters(for: book, db: db, artworkDir: artworkDir)
    }

    private func addAudiobook() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select audiobook files or folders"
        guard panel.runModal() == .OK else { return }

        guard let artworkDir = AppDatabase.shared.artworkDirectory else { return }
        
        for url in panel.urls {
            library.importFolder(url: url, db: db, artworkDir: artworkDir, as: .audiobook)
        }
    }
}
