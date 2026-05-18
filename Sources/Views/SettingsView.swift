import SwiftUI
import GRDB

enum SettingsSection: String, CaseIterable {
    case appearance = "Appearance"
    case equalizer = "Equalizer"
    case lyrics = "Lyrics"
    case about = "About"

    var iconName: String {
        switch self {
        case .appearance: return "paintpalette"
        case .equalizer: return "slider.horizontal.3"
        case .lyrics:    return "music.note.list"
        case .about:     return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    
    @State private var themeManager = ThemeManager.shared
    @State private var lyricsSettings = LyricsSettings.shared
    @State private var selectedSection: SettingsSection = .appearance
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(t.onSurface)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                
                VStack(spacing: 4) {
                    ForEach(SettingsSection.allCases, id: \.self) { section in
                        Button(action: { selectedSection = section }) {
                            HStack(spacing: 12) {
                                Image(systemName: section.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedSection == section ? t.onPrimary : t.onSurface)
                                    .frame(width: 20)
                                
                                Text(section.rawValue)
                                    .font(.system(size: 14, weight: selectedSection == section ? .bold : .medium))
                                    .foregroundColor(selectedSection == section ? t.onPrimary : t.onSurface)
                                
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                            .background(selectedSection == section ? t.primary : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
            }
            .frame(width: 220)
            .background(t.surfaceContainerLow)
            
            // Detail View
            VStack(alignment: .leading, spacing: 0) {
                // Header with Dismiss button
                HStack {
                    Text(selectedSection.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(t.onSurface)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(t.onSurface.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedSection {
                        case .appearance:
                            appearanceSection
                        case .equalizer:
                            EqualizerMasterView()
                        case .lyrics:
                            lyricsSection
                        case .about:
                            aboutSection
                        }
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 900, height: 750)
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .background(.ultraThinMaterial)
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.onSurface)
                
                HStack(spacing: 12) {
                    ForEach(AppThemeMode.allCases, id: \.self) { mode in
                        themeButton(title: mode.displayName, mode: mode)
                    }
                }
            }
            
            if themeManager.themeMode == .dynamic {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dynamic Palette")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.onSurface)
                    
                    Text("The application theme will automatically adapt to the colors of the currently playing track's artwork.")
                        .font(.system(size: 12))
                        .foregroundStyle(t.onSurfaceVariant)
                }
            } else if themeManager.themeMode == .custom {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Custom Palette")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.onSurface)
                    
                    Text("Choose your own colors to create a personalized theme.")
                        .font(.system(size: 12))
                        .foregroundStyle(t.onSurfaceVariant)
                    
                    // Color pickers
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Primary Color")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(t.onSurface)
                            ColorPicker("", selection: Bindable(themeManager).customPrimaryColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 44, height: 32)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accent Color")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(t.onSurface)
                            ColorPicker("", selection: Bindable(themeManager).customSecondaryColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 44, height: 32)
                        }
                    }
                    
                    // Dark/Light mode toggle for custom
                    HStack(spacing: 12) {
                        Text("Appearance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(t.onSurface)
                        
                        HStack(spacing: 4) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    themeManager.customIsDark = false
                                }
                            } label: {
                                Text("Light")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 14)
                                    .background(!themeManager.customIsDark ? t.primary : t.surfaceContainerHigh)
                                    .foregroundColor(!themeManager.customIsDark ? t.onPrimary : t.onSurface)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    themeManager.customIsDark = true
                                }
                            } label: {
                                Text("Dark")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 14)
                                    .background(themeManager.customIsDark ? t.primary : t.surfaceContainerHigh)
                                    .foregroundColor(themeManager.customIsDark ? t.onPrimary : t.onSurface)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Live preview swatch
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(themeManager.customPrimaryColor)
                            .frame(width: 60, height: 36)
                            .overlay(
                                Text("Aa")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(themeManager.customSecondaryColor)
                            .frame(width: 60, height: 36)
                            .overlay(
                                Text("Aa")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        
                        Spacer()
                        
                        Text("Preview")
                            .font(.system(size: 11))
                            .foregroundStyle(t.onSurfaceVariant)
                    }
                }
            } else {
                let effectiveScheme = themeManager.overrideScheme ?? colorScheme
                
                if effectiveScheme == .light {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Light Palettes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(t.onSurface)
                        
                        HStack(spacing: 12) {
                            ForEach(LightThemeOption.allCases) { option in
                                paletteButton(title: option.rawValue, isSelected: themeManager.activeLightTheme == option) {
                                    themeManager.activeLightTheme = option
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dark Palettes")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(t.onSurface)
                        
                        HStack(spacing: 12) {
                            ForEach(DarkThemeOption.allCases) { option in
                                paletteButton(title: option.rawValue, isSelected: themeManager.activeDarkTheme == option) {
                                    themeManager.activeDarkTheme = option
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func themeButton(title: String, mode: AppThemeMode) -> some View {
        let isSelected = themeManager.themeMode == mode
        return Button(action: { themeManager.themeMode = mode }) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? t.primary : t.surfaceContainerHigh)
                .foregroundColor(isSelected ? t.onPrimary : t.onSurface)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func paletteButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? t.primary : t.surfaceContainerHigh)
                .foregroundColor(isSelected ? t.onPrimary : t.onSurface)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: 28) {

            // Pre-roll Offset
            VStack(alignment: .leading, spacing: 12) {
                Text("Pre-roll Offset")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.onSurface)

                Text("Shifts lyrics earlier so they appear just before the vocals — matching professional karaoke and Spotify UX.")
                    .font(.system(size: 12))
                    .foregroundStyle(t.onSurfaceVariant)
                    .lineSpacing(3)

                HStack(spacing: 16) {
                    Text("0 ms")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)

                    Slider(
                        value: Bindable(lyricsSettings).preRollOffsetMs,
                        in: -600...0,
                        step: 10
                    )
                    .tint(t.primary)

                    Text("-600 ms")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)
                }

                HStack {
                    Spacer()
                    Text("\(Int(lyricsSettings.preRollOffsetMs)) ms")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(t.primary)
                    Spacer()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        lyricsSettings.preRollOffsetMs = -300
                    }
                } label: {
                    Text("Reset to Default (−300 ms)")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(t.surfaceContainerHigh)
                        .foregroundStyle(t.onSurface)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }



        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App Identity
            VStack(alignment: .leading, spacing: 6) {
                Text("Melobi")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(t.primary)
                Text("Version 1.0.0 · Build 2026.05")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant)
            }
            
            Text("A premium, offline-first music player for macOS — crafted with SwiftUI and designed for audiophiles who demand beautiful interfaces and high-fidelity sound.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(t.onSurface)
                .lineSpacing(4)
            
            // Features
            aboutFeatureGroup(title: "Playback Engine", items: [
                ("waveform", "Dual-engine architecture — AVPlayer for efficient playback, AVAudioEngine for real-time DSP processing"),
                ("slider.horizontal.3", "6-band parametric equalizer with presets including Harman Target Curve"),
                ("gauge.with.dots.needle.33percent", "Peak limiter to prevent digital clipping on high-gain EQ presets"),
                ("music.note.list", "Gapless playback, shuffle, repeat modes, and queue management")
            ])
            
            aboutFeatureGroup(title: "Dynamic Theming", items: [
                ("paintpalette.fill", "Dynamic mode — automatically extracts the dominant color from album artwork and transforms the entire UI"),
                ("circle.lefthalf.filled", "4 theme modes: System, Light, Dark, and Dynamic"),
                ("swatchpalette", "Multiple hand-crafted palettes: Rose Quartz, Mint Breeze, Lavender Dream, Warm Ivory, Obsidian Red, and more")
            ])
            
            aboutFeatureGroup(title: "Library & Organization", items: [
                ("folder.badge.plus", "Local folder scanning with automatic metadata extraction (title, artist, album, artwork)"),
                ("heart.fill", "Liked songs collection"),
                ("music.note.list", "Custom playlists with cover art support"),
                ("books.vertical", "Audiobook support with chapter navigation and progress tracking"),
                ("text.magnifyingglass", "Real-time library search")
            ])
            
            aboutFeatureGroup(title: "Interface", items: [
                ("sparkles", "Glassmorphic Luminous Audio design system with ambient gradient blobs"),
                ("captions.bubble", "Real-time synchronized lyrics panel with LRC file support"),
                ("waveform.path.ecg", "Animated Now Playing view with artwork-tinted accent gradients"),
                ("rectangle.split.3x1", "Modern sidebar navigation with responsive hit-testing")
            ])
            
            // Tech Stack
            VStack(alignment: .leading, spacing: 8) {
                Text("Built With")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(t.onSurface)
                
                HStack(spacing: 16) {
                    techBadge("SwiftUI")
                    techBadge("AVFoundation")
                    techBadge("AVAudioEngine")
                    techBadge("CoreGraphics")
                    techBadge("GRDB")
                }
            }
            
            // Credits
            VStack(alignment: .leading, spacing: 6) {
                Text("Designed & Developed by")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(t.onSurfaceVariant)
                Text("Athiradh Hari")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(t.onSurface)
            }
            .padding(.top, 4)
            
            Text("© 2026 Melobi. All rights reserved.")
                .font(.system(size: 11))
                .foregroundStyle(t.onSurfaceVariant)
        }
    }
    
    private func aboutFeatureGroup(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(t.onSurface)
            
            ForEach(items, id: \.0) { icon, text in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(t.primary)
                        .frame(width: 20, alignment: .center)
                        .padding(.top, 2)
                    
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(t.onSurface)
                        .lineSpacing(3)
                }
            }
        }
    }
    
    private func techBadge(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(t.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(t.primaryContainer.opacity(0.3))
            .cornerRadius(6)
    }
}
