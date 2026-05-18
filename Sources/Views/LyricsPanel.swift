import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Lyrics Panel (Velvet Echo Real-time Lyrics)
struct LyricsPanel: View {
    @Environment(LyricsState.self) var lyrics
    @Environment(AudioEngine.self) var engine
    @Environment(\.colorScheme) var colorScheme

    @State private var isAutoScrolling = true
    @State private var lastProgrammaticScrollTime: TimeInterval = 0
    @State private var showEditor = false
    
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

                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(t.primary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(lyrics.hasLyrics ? "Edit / Resync Lyrics" : "Add Lyrics")

                if lyrics.variants.count > 1 {
                    Menu {
                        ForEach(Array(lyrics.variants.enumerated()), id: \.offset) { idx, variant in
                            Button(variant.name) {
                                lyrics.activeVariantIndex = idx
                            }
                        }
                    } label: {
                        Text(lyrics.variants[lyrics.activeVariantIndex].name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(t.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(t.primaryContainer.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            if lyrics.hasLyrics {
                ScrollViewReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 22) {
                                Spacer().frame(height: 20)
                                
                                ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { index, line in
                                    LyricLineView(
                                        text: line.text.isEmpty ? "♪" : line.text,
                                        isActive: index == lyrics.activeIndex,
                                        isPast: index < (lyrics.activeIndex ?? 0)
                                    )
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        engine.seek(to: line.timestamp)
                                        isAutoScrolling = true
                                        lastProgrammaticScrollTime = Date().timeIntervalSince1970
                                    }
                                }
                                
                                Spacer().frame(height: 120)
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ScrollOffsetKey.self,
                                        value: geo.frame(in: .named("lyricsScroll")).minY
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "lyricsScroll")
                        .onPreferenceChange(ScrollOffsetKey.self) { _ in
                            let now = Date().timeIntervalSince1970
                            if now - lastProgrammaticScrollTime > 0.8 {
                                if isAutoScrolling {
                                    withAnimation(.spring) {
                                        isAutoScrolling = false
                                    }
                                }
                            }
                        }
                        .onChange(of: lyrics.activeIndex) { _, idx in
                            guard let idx, isAutoScrolling else { return }
                            lastProgrammaticScrollTime = Date().timeIntervalSince1970
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                        
                        if !isAutoScrolling {
                            Button {
                                isAutoScrolling = true
                                lastProgrammaticScrollTime = Date().timeIntervalSince1970
                                if let idx = lyrics.activeIndex {
                                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                                        proxy.scrollTo(idx, anchor: .center)
                                    }
                                }
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(t.surface)
                                    .padding(12)
                                    .background(t.primary)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                            .padding(24)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .animation(.spring(), value: isAutoScrolling)
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
                    Button { showEditor = true } label: {
                        Label("Add & Sync Lyrics", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(t.onPrimary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(t.primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(t.surfaceContainerLow.opacity(0.5))
        .sheet(isPresented: $showEditor) {
            let existingText = lyrics.hasLyrics
                ? LRCFormatter.formatLRC(lyrics.lines)
                : ""
            let trackURL = engine.currentTrack.map { URL(fileURLWithPath: $0.filePath) }
            LyricsEditorView(initialRawText: existingText, initialURL: trackURL)
        }
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
