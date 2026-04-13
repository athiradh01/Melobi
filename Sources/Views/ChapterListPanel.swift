import SwiftUI
import GRDB

// MARK: - Chapter List Panel (Audiobook right side)
struct ChapterListPanel: View {
    @Environment(AudioEngine.self) var engine
    @Environment(LibraryStore.self) var library
    @Environment(\.colorScheme) var colorScheme

    let db: DatabasePool
    let chapters: [Chapter]

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

                                ChapterRow(
                                    chapter: chapter,
                                    index: index,
                                    isActive: isActive,
                                    isPast: isPast,
                                    duration: duration,
                                    onTap: {
                                        let seconds = Double(chapter.startTimeMs) / 1000.0
                                        engine.seek(to: seconds)
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
    }
}

// MARK: - Chapter Row matched to Tailwind
private struct ChapterRow: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(AudioEngine.self) var engine
    let chapter: Chapter
    let index: Int
    let isActive: Bool
    let isPast: Bool
    let duration: Double
    let onTap: () -> Void

    @State private var isHovered = false

    private var t: Theme { Theme(scheme: colorScheme) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left icon/number
                Group {
                    if isActive {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(t.primary)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isHovered ? t.primary : t.outlineVariant)
                            .frame(width: 24)
                    }
                }

                // Title + Status
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title ?? "Chapter \(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(t.onSurface)
                        .lineLimit(1)
                    
                    Text(statusLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(t.onSurfaceVariant.opacity(isActive ? 0.8 : 0.6))
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
        if isActive { return "Current Chapter" }
        if isPast {
            // Can calculate actually percent completion if we wanted, but let's say "Completed" for simplicity or simulate it.
            return "Completed"
        }
        return "Locked"
    }
}

