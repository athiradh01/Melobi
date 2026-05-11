import SwiftUI
import GRDB

enum SettingsSection: String, CaseIterable {
    case appearance = "Appearance"
    case equalizer = "Equalizer"
    case about = "About"
    
    var iconName: String {
        switch self {
        case .appearance: return "paintpalette"
        case .equalizer: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    
    @State private var themeManager = ThemeManager.shared
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
                                    .foregroundColor(selectedSection == section ? t.onPrimary : t.onSurfaceVariant)
                                    .frame(width: 20)
                                
                                Text(section.rawValue)
                                    .font(.system(size: 14, weight: .medium))
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
            
            Divider().background(t.outlineVariant.opacity(0.3))
            
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
                            .font(.system(size: 20))
                            .foregroundStyle(t.outlineVariant)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                
                Divider().background(t.outlineVariant.opacity(0.3))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedSection {
                        case .appearance:
                            appearanceSection
                        case .equalizer:
                            EqualizerMasterView()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(t.onSurface)
            
            HStack(spacing: 12) {
                themeButton(title: "System", scheme: nil)
                themeButton(title: "Light", scheme: .light)
                themeButton(title: "Dark", scheme: .dark)
            }
        }
    }
    
    private func themeButton(title: String, scheme: ColorScheme?) -> some View {
        let isSelected = themeManager.overrideScheme == scheme
        return Button(action: { themeManager.overrideScheme = scheme }) {
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
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Melobi")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(t.primary)
            
            Text("Version 1.0.0")
                .font(.system(size: 14))
                .foregroundStyle(t.onSurfaceVariant)
            
            Text("A beautiful, glassmorphic music player built with SwiftUI.")
                .font(.system(size: 14))
                .foregroundStyle(t.onSurface)
                .padding(.top, 8)
        }
    }
}
