import SwiftUI

// MARK: - Lyrics Panel (Velvet Echo Real-time Lyrics)
struct LyricsPanel: View {
    @Environment(LyricsState.self) var lyrics
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("REAL-TIME LYRICS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(t.outline)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            if lyrics.hasLyrics {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            Spacer().frame(height: 20)
                            
                            ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { index, line in
                                LyricLineView(
                                    text: line.text.isEmpty ? "♪" : line.text,
                                    isActive: index == lyrics.activeIndex,
                                    isPast: index < (lyrics.activeIndex ?? 0)
                                )
                                .id(index)
                            }
                            
                            Spacer().frame(height: 120)
                        }
                    }
                    .onChange(of: lyrics.activeIndex) { _, idx in
                        guard let idx else { return }
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                            proxy.scrollTo(idx, anchor: .center)
                        }
                    }
                }
            } else {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(t.outlineVariant.opacity(0.5))
                    Text("No synced lyrics")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.onSurfaceVariant.opacity(0.5))
                    Text("Place a .lrc file next to your audio")
                        .font(.system(size: 11))
                        .foregroundStyle(t.outline.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(t.surfaceContainerLow.opacity(0.5))
    }
}

// MARK: - Single lyric line with smooth animated transitions
private struct LyricLineView: View {
    let text: String
    let isActive: Bool
    let isPast: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        Text(text)
            .font(.system(
                size: isActive ? 24 : 16,
                weight: isActive ? .bold : .semibold
            ))
            .foregroundStyle(
                isActive
                    ? t.primary
                    : t.onSurface.opacity(isPast ? 0.18 : 0.22)
            )
            .padding(.horizontal, 24)
            .scaleEffect(isActive ? 1.0 : 0.97, anchor: .leading)
            .blur(radius: isActive ? 0 : (isPast ? 0.5 : 0))
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isActive)
            .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isPast)
    }
}
