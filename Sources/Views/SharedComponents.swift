import SwiftUI
import AppKit

// MARK: - Artwork View
struct ArtworkView: View {
    let path: String?
    var size: CGFloat = 56
    var cornerRadius: CGFloat? = nil
    
    private var radius: CGFloat { cornerRadius ?? (size * 0.12) }
    
    var body: some View {
        AsyncImageLoader(path: path) { img in
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                DS.Light.primaryContainer.opacity(0.3)
                Image(systemName: "music.note")
                    .foregroundStyle(DS.Light.primary.opacity(0.5))
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
