import SwiftUI

struct LibraryTrackPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LibraryStore.self) private var library

    let onSelect: (URL) -> Void

    @State private var searchText = ""

    private var t: Theme { Theme(scheme: colorScheme) }

    private var filtered: [Track] {
        let all = library.filteredTracks.sorted { $0.dateAdded > $1.dateAdded }
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter {
            ($0.title  ?? "").lowercased().contains(q) ||
            ($0.artist ?? "").lowercased().contains(q) ||
            ($0.album  ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(t.primary)
                Text("Select Track")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(t.onSurface)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(t.onSurface.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(t.outline)
                TextField("Search tracks…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(t.onSurface)
                if !searchText.isEmpty {
                    Button { 
                        searchText = ""
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(t.outline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(t.surfaceContainerHigh)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().overlay(t.onSurface.opacity(0.08))

            // Track list
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(t.outlineVariant.opacity(0.5))
                    Text("No tracks found")
                        .font(.system(size: 13))
                        .foregroundStyle(t.onSurfaceVariant.opacity(0.6))
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { track in
                            TrackPickerRow(track: track, theme: t) {
                                let url = URL(fileURLWithPath: track.filePath)
                                onSelect(url)
                                dismiss()
                            }
                            Divider()
                                .overlay(t.onSurface.opacity(0.05))
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 540)
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Row

private struct TrackPickerRow: View {
    let track: Track
    let theme: Theme
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(path: track.artworkPath, size: 40, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.onSurface)
                    .lineLimit(1)
                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            if let ms = track.durationMs {
                Text(durationString(Double(ms) / 1000))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.outline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(isHovered ? theme.surfaceContainerHigh : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
    }

    private func durationString(_ s: Double) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}
