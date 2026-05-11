import SwiftUI
import GRDB

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let db: DatabasePool
    
    @State private var themeManager = ThemeManager.shared
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .heavy))
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
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider().background(t.outlineVariant.opacity(0.3))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Preferences
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(t.primary)
                        
                        HStack {
                            Text("Theme")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(t.onSurface)
                            Spacer()
                            Menu {
                                Button("System") { themeManager.overrideScheme = nil }
                                Button("Light") { themeManager.overrideScheme = .light }
                                Button("Dark") { themeManager.overrideScheme = .dark }
                            } label: {
                                Text(themeManager.overrideScheme == nil ? "System" : (themeManager.overrideScheme == .light ? "Light" : "Dark"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(t.onSurfaceVariant)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 80)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(t.surfaceContainerHigh)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    Divider().background(t.outlineVariant.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(t.primary)
                        
                        Text("Melobi")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(t.onSurface)
                        Text("Version 1.0.0")
                            .font(.system(size: 12))
                            .foregroundStyle(t.onSurfaceVariant)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 400, height: 350)
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .background(.ultraThinMaterial)
    }
}
