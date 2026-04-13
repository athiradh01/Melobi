import SwiftUI
import AppKit

// MARK: - Artwork View
struct ArtworkView: View {
    let path: String?
    var size: CGFloat = 56
    var cornerRadius: CGFloat? = nil
    @Environment(\.colorScheme) var colorScheme
    
    private var radius: CGFloat { cornerRadius ?? (size * 0.12) }
    private var t: Theme { Theme(scheme: colorScheme, lightPalette: ThemeManager.shared.activeLightTheme.theme) }
    
    var body: some View {
        AsyncImageLoader(path: path) { img in
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                t.primaryContainer.opacity(0.3)
                Image(systemName: "music.note")
                    .foregroundStyle(t.primary.opacity(0.5))
                    .font(.system(size: size * 0.3, weight: .bold))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Format Time
func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
    let s = Int(max(0, seconds))
    let hours = s / 3600
    let minutes = (s % 3600) / 60
    let secs = s % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Marquee Text
struct MarqueeText: View {
    let text: String
    let font: Font

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollTask: Task<Void, Never>? = nil

    var overflowing: Bool { textWidth > containerWidth + 2 && containerWidth > 0 }

    var body: some View {
        ZStack(alignment: .leading) {
            // Invisible text strictly to provide natural height and read container width
            Text(text)
                .font(font)
                .lineLimit(1)
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                containerWidth = geo.size.width
                                restartScroll()
                            }
                            .onChange(of: geo.size.width) { _, w in
                                containerWidth = w
                                restartScroll()
                            }
                    }
                )

            // Visible scrolling text, allowed to extend horizontally
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .offset(x: offset)
                .background(
                    GeometryReader { inner in
                        Color.clear
                            .onAppear {
                                textWidth = inner.size.width
                                restartScroll()
                            }
                            .onChange(of: inner.size.width) { _, w in
                                textWidth = w
                                restartScroll()
                            }
                    }
                )
        }
        .clipped()
        .onChange(of: text) { _, _ in
            offset = 0
            restartScroll()
        }
    }

    private func restartScroll() {
        scrollTask?.cancel()
        offset = 0
        guard overflowing else { return }

        let travel = textWidth - containerWidth
        let pixelsPerSec: Double = 35
        let duration = max(2.0, travel / pixelsPerSec)
        let pauseDuration: UInt64 = 1_500_000_000 // 1.5 s in ns
        let repeatCount = 3

        scrollTask = Task {
            try? await Task.sleep(nanoseconds: pauseDuration) // initial pause
            guard !Task.isCancelled else { return }

            for _ in 0..<repeatCount {
                // scroll left
                withAnimation(.linear(duration: duration)) { offset = -travel }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }

                try? await Task.sleep(nanoseconds: 500_000_000) // small pause at end
                guard !Task.isCancelled else { return }

                // scroll back right
                withAnimation(.linear(duration: duration)) { offset = 0 }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }

                try? await Task.sleep(nanoseconds: pauseDuration) // pause before next loop
                guard !Task.isCancelled else { return }
            }
            // Done — rest at the beginning (offset = 0 already)
        }
    }
}

