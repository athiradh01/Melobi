import SwiftUI

// MARK: - Selected Light Theme Option
public enum LightThemeOption: String, CaseIterable, Identifiable {
    case roseQuartz = "Rose Quartz"
    case mintBreeze = "Mint Breeze"
    case lavenderDream = "Lavender Dream"
    
    public var id: String { self.rawValue }
    
    var theme: ThemePalette {
        switch self {
        case .roseQuartz: return DS.Light.roseQuartz
        case .mintBreeze: return DS.Light.mintBreeze
        case .lavenderDream: return DS.Light.lavenderDream
        }
    }
}

// MARK: - Theme Palette Definition
public struct ThemePalette {
    let primary: Color
    let primaryDim: Color
    let primaryContainer: Color
    let onPrimary: Color
    let onPrimaryContainer: Color
    
    let surface: Color
    let onSurface: Color
    let onSurfaceVariant: Color
    let surfaceContainer: Color
    let surfaceContainerLow: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let surfaceContainerLowest: Color
    
    let outline: Color
    let outlineVariant: Color
    let secondaryContainer: Color
    let background: Color
    
    let sidebarBg: Color
}

// MARK: - Design System
enum DS {
    // Light Mode Palettes
    enum Light {
        static let roseQuartz = ThemePalette(
            primary: Color(r: 168, g: 82, b: 110),
            primaryDim: Color(r: 145, g: 68, b: 94),
            primaryContainer: Color(r: 255, g: 194, b: 211),
            onPrimary: Color.white,
            onPrimaryContainer: Color(r: 96, g: 20, b: 47),
            surface: Color(r: 255, g: 248, b: 250),
            onSurface: Color(r: 60, g: 45, b: 48),
            onSurfaceVariant: Color(r: 120, g: 105, b: 108),
            surfaceContainer: Color(r: 252, g: 232, b: 238),
            surfaceContainerLow: Color(r: 255, g: 236, b: 242),
            surfaceContainerHigh: Color(r: 247, g: 224, b: 231),
            surfaceContainerHighest: Color(r: 242, g: 216, b: 224),
            surfaceContainerLowest: Color(r: 255, g: 252, b: 253),
            outline: Color(r: 140, g: 125, b: 128),
            outlineVariant: Color(r: 200, g: 185, b: 188),
            secondaryContainer: Color(r: 245, g: 220, b: 228),
            background: Color(r: 255, g: 248, b: 250),
            sidebarBg: Color(r: 250, g: 235, b: 240, a: 0.8)
        )
        
        static let mintBreeze = ThemePalette(
            primary: Color(r: 45, g: 130, b: 115),
            primaryDim: Color(r: 35, g: 110, b: 95),
            primaryContainer: Color(r: 174, g: 235, b: 220),
            onPrimary: Color.white,
            onPrimaryContainer: Color(r: 10, g: 65, b: 55),
            surface: Color(r: 245, g: 253, b: 250),
            onSurface: Color(r: 40, g: 60, b: 55),
            onSurfaceVariant: Color(r: 90, g: 115, b: 110),
            surfaceContainer: Color(r: 220, g: 242, b: 236),
            surfaceContainerLow: Color(r: 230, g: 248, b: 243),
            surfaceContainerHigh: Color(r: 210, g: 235, b: 230),
            surfaceContainerHighest: Color(r: 198, g: 228, b: 222),
            surfaceContainerLowest: Color(r: 250, g: 255, b: 253),
            outline: Color(r: 120, g: 145, b: 140),
            outlineVariant: Color(r: 180, g: 205, b: 200),
            secondaryContainer: Color(r: 215, g: 238, b: 232),
            background: Color(r: 245, g: 253, b: 250),
            sidebarBg: Color(r: 225, g: 245, b: 235, a: 0.8)
        )
        
        static let lavenderDream = ThemePalette(
            primary: Color(r: 125, g: 85, b: 165),
            primaryDim: Color(r: 105, g: 70, b: 145),
            primaryContainer: Color(r: 226, g: 200, b: 255),
            onPrimary: Color.white,
            onPrimaryContainer: Color(r: 55, g: 25, b: 90),
            surface: Color(r: 250, g: 246, b: 255),
            onSurface: Color(r: 50, g: 45, b: 60),
            onSurfaceVariant: Color(r: 105, g: 100, b: 115),
            surfaceContainer: Color(r: 240, g: 230, b: 252),
            surfaceContainerLow: Color(r: 245, g: 238, b: 254),
            surfaceContainerHigh: Color(r: 232, g: 222, b: 248),
            surfaceContainerHighest: Color(r: 226, g: 214, b: 244),
            surfaceContainerLowest: Color(r: 253, g: 251, b: 255),
            outline: Color(r: 135, g: 130, b: 145),
            outlineVariant: Color(r: 195, g: 190, b: 205),
            secondaryContainer: Color(r: 228, g: 216, b: 245),
            background: Color(r: 250, g: 246, b: 255),
            sidebarBg: Color(r: 240, g: 230, b: 252, a: 0.8)
        )
    }
    
    // Dark Mode (Static reference for now, but converted to ThemePalette for consistency)
    static let dark = ThemePalette(
        primary: Color(r: 170, g: 178, b: 244),
        primaryDim: Color(r: 156, g: 164, b: 229),
        primaryContainer: Color(r: 48, g: 56, b: 114),
        onPrimary: Color(r: 39, g: 47, b: 92),
        onPrimaryContainer: Color(r: 224, g: 225, b: 255),
        surface: Color(r: 18, g: 20, b: 26),
        onSurface: Color(r: 228, g: 225, b: 233),
        onSurfaceVariant: Color(r: 199, g: 197, b: 208),
        surfaceContainer: Color(r: 30, g: 32, b: 40),
        surfaceContainerLow: Color(r: 24, g: 26, b: 34),
        surfaceContainerHigh: Color(r: 38, g: 40, b: 48),
        surfaceContainerHighest: Color(r: 46, g: 48, b: 56),
        surfaceContainerLowest: Color(r: 14, g: 16, b: 22),
        outline: Color(r: 145, g: 144, b: 154),
        outlineVariant: Color(r: 70, g: 70, b: 79),
        secondaryContainer: Color(r: 67, g: 70, b: 89),
        background: Color(r: 18, g: 20, b: 26),
        sidebarBg: Color(r: 15, g: 17, b: 25, a: 0.7)
    )
}

// Convenience initializer
extension Color {
    init(r: Int, g: Int, b: Int, a: Double = 1.0) {
        self.init(.sRGB, red: Double(r)/255.0, green: Double(g)/255.0, blue: Double(b)/255.0, opacity: a)
    }
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF)/255.0, green: Double((hex >> 8) & 0xFF)/255.0, blue: Double(hex & 0xFF)/255.0, opacity: alpha)
    }
}

// Adaptive color resolver
public struct Theme {
    let scheme: ColorScheme
    let activeLightPalette: ThemePalette
    
    // Fallback initializer that properly defaults to the user's active theme
    @MainActor
    init(scheme: ColorScheme) {
        self.scheme = scheme
        self.activeLightPalette = ThemeManager.shared.activeLightTheme.theme
    }
    
    // New initializer that takes the active light palette
    init(scheme: ColorScheme, lightPalette: ThemePalette) {
        self.scheme = scheme
        self.activeLightPalette = lightPalette
    }
    
    private var p: ThemePalette {
        scheme == .dark ? DS.dark : activeLightPalette
    }
    
    var primary: Color { p.primary }
    var primaryDim: Color { p.primaryDim }
    var primaryContainer: Color { p.primaryContainer }
    var onPrimary: Color { p.onPrimary }
    var surface: Color { p.surface }
    var onSurface: Color { p.onSurface }
    var onSurfaceVariant: Color { p.onSurfaceVariant }
    var surfaceContainer: Color { p.surfaceContainer }
    var surfaceContainerLow: Color { p.surfaceContainerLow }
    var surfaceContainerHigh: Color { p.surfaceContainerHigh }
    var surfaceContainerHighest: Color { p.surfaceContainerHighest }
    var outline: Color { p.outline }
    var outlineVariant: Color { p.outlineVariant }
    var secondaryContainer: Color { p.secondaryContainer }
    var background: Color { p.background }
    var sidebarBg: Color { p.sidebarBg }
}
