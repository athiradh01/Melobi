import SwiftUI
import GRDB

// MARK: - Chapter List Panel (Audiobook right side)
struct ChapterListPanel: View {
    @Environment(AudioEngine.self) var engine
    @Environment(LibraryStore.self) var library
    @Environment(\.colorScheme) var colorScheme

    let db: DatabasePool
    let chapters: [Chapter]

    @State private var progressMap: [Int: ChapterProgress] = [:]

    private var t: Theme { Theme(scheme: colorScheme) }

    private var activeChapterIndex: Int? {
        guard !chapters.isEmpty else { return nil }
        let ms = Int64(engine.currentTime * 1000)
        var result: Int? = nil
        for (i, ch) in chapters.enumerated() {
            if ch.startTimeMs <= ms { result = i }
        }
        return result
    }

    private func chapterDuration(index: Int) -> Double {
        let currentStart = Double(chapters[index].startTimeMs) / 1000.0
        let nextStart: Double
        if index + 1 < chapters.count {
            nextStart = Double(chapters[index + 1].startTimeMs) / 1000.0
        } else {
            nextStart = Double(engine.currentAudiobook?.durationMs ?? 0) / 1000.0
        }
        return max(0, nextStart - currentStart)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: "Chapters" & "24 Sections"
            HStack {
                Text("Chapters")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .tracking(-0.3)
                Spacer()
                
                // Show completed count
                let completedCount = progressMap.values.filter { $0.isCompleted }.count
                if completedCount > 0 {
                    Text("\(completedCount)/\(chapters.count) Done")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Text("\(chapters.count) Sections")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(t.onSurfaceVariant)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)

            if chapters.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "list.bullet")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(t.outlineVariant.opacity(0.5))
                    Text("No chapters found")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                                let isActive = index == activeChapterIndex
                                let isPast = index < (activeChapterIndex ?? 0)
                                let duration = chapterDuration(index: index)
                                let progress = progressMap[index]

                                ChapterRow(
                                    chapter: chapter,
                                    index: index,
                                    isActive: isActive,
                                    isPast: isPast,
                                    duration: duration,
                                    chapterProgress: progress,
                                    onTap: {
                                        // Resume from saved position if available
                                        let chapterStartSec = Double(chapter.startTimeMs) / 1000.0
                                        if let book = engine.currentAudiobook {
                                            let resumeMs = library.chapterResumeMs(for: book, chapterIndex: index, db: db)
                                            let resumeSec = Double(resumeMs) / 1000.0
                                            engine.seek(to: chapterStartSec + resumeSec)
                                        } else {
                                            engine.seek(to: chapterStartSec)
                                        }
                                    }
                                )
                                .id(index)
                            }
                            Spacer().frame(height: 160)
                        }
                        .padding(.horizontal, 24)
                    }
                    .onChange(of: activeChapterIndex) { _, idx in
                        if let idx {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { refreshProgress() }
        .onChange(of: engine.currentTime) { _, _ in
            // Refresh progress map periodically (every ~5 seconds is fine, the map itself is cheap)
            refreshProgress()
        }
    }
    
    private func refreshProgress() {
        guard let book = engine.currentAudiobook else { return }
        progressMap = library.chapterProgressMap(for: book, db: db)
    }
}

// MARK: - Chapter Row
private struct ChapterRow: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(AudioEngine.self) var engine
    let chapter: Chapter
    let index: Int
    let isActive: Bool
    let isPast: Bool
    let duration: Double
    let chapterProgress: ChapterProgress?
    let onTap: () -> Void

    @State private var isHovered = false

    private var t: Theme { Theme(scheme: colorScheme) }
    
    private var isCompleted: Bool {
        chapterProgress?.isCompleted == true
    }
    
    /// Progress fraction 0…1 for in-progress chapters
    private var progressFraction: Double {
        guard let cp = chapterProgress, !cp.isCompleted, duration > 0 else { return 0 }
        return min(1, Double(cp.progressMs) / 1000.0 / duration)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left icon/number
                Group {
                    if isActive {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(t.primary)
                    } else if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isHovered ? t.primary : t.outlineVariant)
                            .frame(width: 24)
                    }
                }

                // Title + Status
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title ?? "Chapter \(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isCompleted ? t.onSurfaceVariant : t.onSurface)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(statusLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(statusColor)
                        
                        // Show progress bar for in-progress chapters
                        if !isCompleted && !isActive && progressFraction > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(t.outlineVariant.opacity(0.2))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(t.primary.opacity(0.7))
                                        .frame(width: geo.size.width * progressFraction, height: 3)
                                }
                            }
                            .frame(width: 60, height: 3)
                        }
                    }
                }

                Spacer()

                // Duration
                Text(formatTime(duration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isActive ? t.primary : t.onSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                isActive
                    ? t.surfaceContainerHigh
                    : (isHovered ? t.surfaceContainerLow : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }

    private var statusLabel: String {
        if isActive { return "Now Playing" }
        if isCompleted { return "Completed ✓" }
        if isPast { return "Completed ✓" }
        if progressFraction > 0 {
            return "\(Int(progressFraction * 100))% listened"
        }
        return "Not started"
    }
    
    private var statusColor: Color {
        if isActive { return t.primary }
        if isCompleted || isPast { return .green }
        if progressFraction > 0 { return t.primary.opacity(0.7) }
        return t.onSurfaceVariant.opacity(0.5)
    }
}
