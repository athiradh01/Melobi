import SwiftUI

// MARK: - Design System from Stitch "Velvet Echo" Desktop Screens

enum DS {
    // Light Mode
    enum Light {
        static let primary = Color(r: 82, g: 91, b: 150)       // #525B96
        static let primaryDim = Color(r: 70, g: 78, b: 137)    // #464E89
        static let primaryContainer = Color(r: 170, g: 178, b: 244) // #AAB2F4
        static let onPrimary = Color(r: 250, g: 248, b: 255)   // #FAF8FF
        static let onPrimaryContainer = Color(r: 39, g: 47, b: 104) // #272F68
        
        static let surface = Color(r: 248, g: 249, b: 255)     // #F8F9FF
        static let onSurface = Color(r: 45, g: 51, b: 59)      // #2D333B
        static let onSurfaceVariant = Color(r: 89, g: 95, b: 105) // #595F69
        static let surfaceContainer = Color(r: 234, g: 238, b: 247) // #EAEEF7
        static let surfaceContainerLow = Color(r: 241, g: 243, b: 251) // #F1F3FB
        static let surfaceContainerHigh = Color(r: 228, g: 232, b: 242) // #E4E8F2
        static let surfaceContainerHighest = Color(r: 221, g: 227, b: 238) // #DDE3EE
        static let surfaceContainerLowest = Color.white
        
        static let outline = Color(r: 117, g: 123, b: 133)     // #757B85
        static let outlineVariant = Color(r: 172, g: 178, b: 189) // #ACB2BD
        static let secondaryContainer = Color(r: 224, g: 226, b: 238) // #E0E2EE
        static let background = Color(r: 248, g: 249, b: 255)  // #F8F9FF
        
        // Sidebar glass
        static let sidebarBg = Color(r: 248, g: 250, b: 255, a: 0.7) // slate-50/70
    }
    
    // Dark Mode
    enum Dark {
        static let primary = Color(r: 170, g: 178, b: 244)     // #AAB2F4
        static let primaryDim = Color(r: 156, g: 164, b: 229)  // #9CA4E5
        static let primaryContainer = Color(r: 48, g: 56, b: 114) // #303872
        static let onPrimary = Color(r: 39, g: 47, b: 92)      // #272F5C
        static let onPrimaryContainer = Color(r: 224, g: 225, b: 255) // #E0E1FF
        
        static let surface = Color(r: 18, g: 20, b: 26)        // #12141A
        static let onSurface = Color(r: 228, g: 225, b: 233)   // #E4E1E9
        static let onSurfaceVariant = Color(r: 199, g: 197, b: 208) // #C7C5D0
        static let surfaceContainer = Color(r: 30, g: 32, b: 40) // #1E2028
        static let surfaceContainerLow = Color(r: 24, g: 26, b: 34) // #181A22
        static let surfaceContainerHigh = Color(r: 38, g: 40, b: 48) // #262830
        static let surfaceContainerHighest = Color(r: 46, g: 48, b: 56) // #2E3038
        static let surfaceContainerLowest = Color(r: 14, g: 16, b: 22)
        
        static let outline = Color(r: 145, g: 144, b: 154)
        static let outlineVariant = Color(r: 70, g: 70, b: 79)
        static let secondaryContainer = Color(r: 67, g: 70, b: 89)
        static let background = Color(r: 18, g: 20, b: 26)
        
        static let sidebarBg = Color(r: 15, g: 17, b: 25, a: 0.7)
    }
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
struct Theme {
    let scheme: ColorScheme
    
    var primary: Color { scheme == .dark ? DS.Dark.primary : DS.Light.primary }
    var primaryDim: Color { scheme == .dark ? DS.Dark.primaryDim : DS.Light.primaryDim }
    var primaryContainer: Color { scheme == .dark ? DS.Dark.primaryContainer : DS.Light.primaryContainer }
    var onPrimary: Color { scheme == .dark ? DS.Dark.onPrimary : DS.Light.onPrimary }
    var surface: Color { scheme == .dark ? DS.Dark.surface : DS.Light.surface }
    var onSurface: Color { scheme == .dark ? DS.Dark.onSurface : DS.Light.onSurface }
    var onSurfaceVariant: Color { scheme == .dark ? DS.Dark.onSurfaceVariant : DS.Light.onSurfaceVariant }
    var surfaceContainer: Color { scheme == .dark ? DS.Dark.surfaceContainer : DS.Light.surfaceContainer }
    var surfaceContainerLow: Color { scheme == .dark ? DS.Dark.surfaceContainerLow : DS.Light.surfaceContainerLow }
    var surfaceContainerHigh: Color { scheme == .dark ? DS.Dark.surfaceContainerHigh : DS.Light.surfaceContainerHigh }
    var surfaceContainerHighest: Color { scheme == .dark ? DS.Dark.surfaceContainerHighest : DS.Light.surfaceContainerHighest }
    var outline: Color { scheme == .dark ? DS.Dark.outline : DS.Light.outline }
    var outlineVariant: Color { scheme == .dark ? DS.Dark.outlineVariant : DS.Light.outlineVariant }
    var secondaryContainer: Color { scheme == .dark ? DS.Dark.secondaryContainer : DS.Light.secondaryContainer }
    var background: Color { scheme == .dark ? DS.Dark.background : DS.Light.background }
    var sidebarBg: Color { scheme == .dark ? DS.Dark.sidebarBg : DS.Light.sidebarBg }
}
