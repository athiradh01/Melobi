import SwiftUI
import AppKit

public enum AppThemeMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2
    case dynamic = 3
    case custom = 4
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .dynamic: return "Dynamic"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Theme Manager
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    
    private static let schemeKey = "app.themeScheme"
    private static let lightThemeKey = "app.lightTheme"
    private static let darkThemeKey = "app.darkTheme"
    // Persist the dominant + secondary RGB so theme survives app restart
    private static let dom1RKey = "app.dyn.dom1R"
    private static let dom1GKey = "app.dyn.dom1G"
    private static let dom1BKey = "app.dyn.dom1B"
    private static let dom2RKey = "app.dyn.dom2R"
    private static let dom2GKey = "app.dyn.dom2G"
    private static let dom2BKey = "app.dyn.dom2B"
    // Custom theme persistence keys
    private static let customPrimaryRKey = "app.custom.primaryR"
    private static let customPrimaryGKey = "app.custom.primaryG"
    private static let customPrimaryBKey = "app.custom.primaryB"
    private static let customSecondaryRKey = "app.custom.secondaryR"
    private static let customSecondaryGKey = "app.custom.secondaryG"
    private static let customSecondaryBKey = "app.custom.secondaryB"
    private static let customIsDarkKey = "app.custom.isDark"
    
    var themeMode: AppThemeMode = .system {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: Self.schemeKey)
        }
    }
    
    // Custom theme state
    var customPrimaryColor: Color = Color(red: 0.4, green: 0.6, blue: 0.9) {
        didSet { persistCustomColors() }
    }
    var customSecondaryColor: Color = Color(red: 0.9, green: 0.5, blue: 0.3) {
        didSet { persistCustomColors() }
    }
    var customIsDark: Bool = true {
        didSet {
            UserDefaults.standard.set(customIsDark, forKey: Self.customIsDarkKey)
            applyCustomTheme()
        }
    }
    var customPalette: ThemePalette?
    
    var dynamicPalette: ThemePalette?
    var dynamicIsDarkTheme: Bool = true
    
    var overrideScheme: ColorScheme? {
        switch themeMode {
        case .light: return .light
        case .dark: return .dark
        case .dynamic: return dynamicIsDarkTheme ? .dark : .light
        case .custom: return customIsDark ? .dark : .light
        case .system: return nil
        }
    }
    
    var activeLightTheme: LightThemeOption {
        didSet { UserDefaults.standard.set(activeLightTheme.rawValue, forKey: Self.lightThemeKey) }
    }
    var activeDarkTheme: DarkThemeOption {
        didSet { UserDefaults.standard.set(activeDarkTheme.rawValue, forKey: Self.darkThemeKey) }
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.lightThemeKey),
           let theme = LightThemeOption(rawValue: raw) {
            activeLightTheme = theme
        } else {
            activeLightTheme = .mintBreeze
        }
        
        if let raw = UserDefaults.standard.string(forKey: Self.darkThemeKey),
           let theme = DarkThemeOption(rawValue: raw) {
            activeDarkTheme = theme
        } else {
            activeDarkTheme = .midnightBlue
        }
        
        let schemeRaw = UserDefaults.standard.integer(forKey: Self.schemeKey)
        themeMode = AppThemeMode(rawValue: schemeRaw) ?? .system
        
        // Restore persisted dynamic palette from last session
        if themeMode == .dynamic {
            let d1r = UserDefaults.standard.double(forKey: Self.dom1RKey)
            let d1g = UserDefaults.standard.double(forKey: Self.dom1GKey)
            let d1b = UserDefaults.standard.double(forKey: Self.dom1BKey)
            let d2r = UserDefaults.standard.double(forKey: Self.dom2RKey)
            let d2g = UserDefaults.standard.double(forKey: Self.dom2GKey)
            let d2b = UserDefaults.standard.double(forKey: Self.dom2BKey)
            if d1r > 0 || d1g > 0 || d1b > 0 {
                let result = Self.buildPalette(
                    dominant: (d1r, d1g, d1b),
                    secondary: (d2r, d2g, d2b)
                )
                dynamicPalette = result.palette
                dynamicIsDarkTheme = result.isDark
            }
        }
        
        // Restore persisted custom palette
        customIsDark = UserDefaults.standard.bool(forKey: Self.customIsDarkKey)
        let cpR = UserDefaults.standard.double(forKey: Self.customPrimaryRKey)
        let cpG = UserDefaults.standard.double(forKey: Self.customPrimaryGKey)
        let cpB = UserDefaults.standard.double(forKey: Self.customPrimaryBKey)
        let csR = UserDefaults.standard.double(forKey: Self.customSecondaryRKey)
        let csG = UserDefaults.standard.double(forKey: Self.customSecondaryGKey)
        let csB = UserDefaults.standard.double(forKey: Self.customSecondaryBKey)
        if cpR > 0 || cpG > 0 || cpB > 0 {
            customPrimaryColor = Color(red: cpR, green: cpG, blue: cpB)
            customSecondaryColor = Color(red: csR, green: csG, blue: csB)
            let result = Self.buildPalette(
                dominant: (cpR, cpG, cpB),
                secondary: (csR, csG, csB),
                forceDark: customIsDark
            )
            customPalette = result.palette
        }
    }
    
    // MARK: - Extract dominant colors from album artwork
    func extractDynamicTheme(from track: Track?) {
        guard let track = track, let path = track.artworkPath,
              let nsImage = NSImage(contentsOfFile: path),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return // Keep last theme
        }
        
        // Sample image at 50x50
        let size = 50
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = context.data else { return }
        let ptr = data.bindMemory(to: UInt8.self, capacity: size * size * 4)
        
        // ── Color quantization with perceptual weighting ──
        // Skip very dark / very light pixels so backdrop doesn't dominate.
        // Weight each pixel by its saturation so colorful pixels count more.
        var buckets: [Int: (score: Double, count: Int, totalR: Double, totalG: Double, totalB: Double)] = [:]
        
        let totalPixels = size * size
        for i in 0..<totalPixels {
            let base = i * 4
            let r = Double(ptr[base]) / 255.0
            let g = Double(ptr[base + 1]) / 255.0
            let b = Double(ptr[base + 2]) / 255.0
            
            let maxC = max(r, g, b), minC = min(r, g, b)
            let lum = (maxC + minC) / 2.0
            
            // Aggressively skip near-black and near-white/cream pixels
            if lum < 0.10 || lum > 0.82 { continue }
            
            let delta = maxC - minC
            let sat = delta > 0 ? min(1.0, delta / max(0.01, 1.0 - abs(2.0 * lum - 1.0))) : 0
            
            // Skip very desaturated pixels (greys/creams) entirely
            if sat < 0.08 { continue }
            
            // Perceptual weight: saturated mid-tones dominate
            let lumScore = 1.0 - abs(lum - 0.45) * 2.0  // sweet spot at ~0.45
            let weight = sat * sat * 3.0 + max(0, lumScore) * 0.5  // quadratic saturation boost
            
            // Quantize to 8 levels per channel (coarser = better grouping)
            let qr = Int(r * 7.0)
            let qg = Int(g * 7.0)
            let qb = Int(b * 7.0)
            let key = qr * 64 + qg * 8 + qb
            
            if var existing = buckets[key] {
                existing.score += weight
                existing.count += 1
                existing.totalR += r
                existing.totalG += g
                existing.totalB += b
                buckets[key] = existing
            } else {
                buckets[key] = (score: weight, count: 1, totalR: r, totalG: g, totalB: b)
            }
        }
        
        // Sort by perceptual score (not just pixel count)
        let sorted = buckets.values.sorted { $0.score > $1.score }
        
        guard let top1 = sorted.first else { return }
        
        // Dominant color = average of the highest-scoring bucket
        let dom1 = (
            top1.totalR / Double(top1.count),
            top1.totalG / Double(top1.count),
            top1.totalB / Double(top1.count)
        )
        
        // Secondary color = next bucket that is visually distinct from dominant
        var dom2 = (0.5, 0.5, 0.5)
        for bucket in sorted.dropFirst() {
            let avg = (
                bucket.totalR / Double(bucket.count),
                bucket.totalG / Double(bucket.count),
                bucket.totalB / Double(bucket.count)
            )
            let dist = sqrt(pow(avg.0 - dom1.0, 2) + pow(avg.1 - dom1.1, 2) + pow(avg.2 - dom1.2, 2))
            if dist > 0.15 {
                dom2 = avg
                break
            }
        }
        
        // Persist so theme survives app restart
        UserDefaults.standard.set(dom1.0, forKey: Self.dom1RKey)
        UserDefaults.standard.set(dom1.1, forKey: Self.dom1GKey)
        UserDefaults.standard.set(dom1.2, forKey: Self.dom1BKey)
        UserDefaults.standard.set(dom2.0, forKey: Self.dom2RKey)
        UserDefaults.standard.set(dom2.1, forKey: Self.dom2GKey)
        UserDefaults.standard.set(dom2.2, forKey: Self.dom2BKey)
        
        let result = Self.buildPalette(dominant: dom1, secondary: dom2)
        dynamicPalette = result.palette
        dynamicIsDarkTheme = result.isDark
    }
    
    // MARK: - Build palette from dominant + secondary colors
    private static func buildPalette(
        dominant: (Double, Double, Double),
        secondary: (Double, Double, Double),
        forceDark: Bool? = nil
    ) -> (palette: ThemePalette, isDark: Bool) {
        let (dr, dg, db) = dominant
        var (sr, sg, sb) = secondary
        
        // Determine if the dominant color is light or dark
        let dominantLum = dr * 0.299 + dg * 0.587 + db * 0.114
        let isDark = forceDark ?? (dominantLum < 0.5)
        
        // ── Ensure the accent/primary always has high visibility ──
        let secLum = sr * 0.299 + sg * 0.587 + sb * 0.114
        
        if isDark {
            // In dark theme, brighten the accent if it's too dim
            if secLum < 0.45 {
                let boost = 0.5 / max(0.01, secLum)
                sr = min(1.0, sr * boost)
                sg = min(1.0, sg * boost)
                sb = min(1.0, sb * boost)
            }
        } else {
            // In light theme, darken the accent if it's too bright
            if secLum > 0.7 {
                let dim = 0.5 / max(0.01, secLum)
                sr = sr * dim
                sg = sg * dim
                sb = sb * dim
            }
        }
        
        let primary = Color(red: sr, green: sg, blue: sb)
        let primaryDim = Color(red: sr * 0.75, green: sg * 0.75, blue: sb * 0.75)
        
        let finalSecLum = sr * 0.299 + sg * 0.587 + sb * 0.114
        let onPrimary: Color = finalSecLum > 0.55 ? .black : .white
        
        if isDark {
            // ── DARK THEME ──
            // Surfaces use the dominant color but with minimum brightness floors
            let minFloor = 0.06
            let bgR = max(minFloor, dr * 0.55), bgG = max(minFloor, dg * 0.55), bgB = max(minFloor, db * 0.55)
            let sideR = max(minFloor + 0.02, dr * 0.6), sideG = max(minFloor + 0.02, dg * 0.6), sideB = max(minFloor + 0.02, db * 0.6)
            let surfR = max(minFloor + 0.04, dr * 0.7), surfG = max(minFloor + 0.04, dg * 0.7), surfB = max(minFloor + 0.04, db * 0.7)
            let contR = max(minFloor + 0.06, dr * 0.8), contG = max(minFloor + 0.06, dg * 0.8), contB = max(minFloor + 0.06, db * 0.8)
            let contLR = max(minFloor + 0.05, dr * 0.75), contLG = max(minFloor + 0.05, dg * 0.75), contLB = max(minFloor + 0.05, db * 0.75)
            let contHR = max(minFloor + 0.08, dr * 0.9), contHG = max(minFloor + 0.08, dg * 0.9), contHB = max(minFloor + 0.08, db * 0.9)
            let contHhR = min(1, max(0.15, dr * 1.1)), contHhG = min(1, max(0.15, dg * 1.1)), contHhB = min(1, max(0.15, db * 1.1))
            let contLoR = max(0.04, dr * 0.4), contLoG = max(0.04, dg * 0.4), contLoB = max(0.04, db * 0.4)
            
            return (ThemePalette(
                primary: primary,
                primaryDim: primaryDim,
                primaryContainer: Color(red: sr * 0.3, green: sg * 0.3, blue: sb * 0.3),
                onPrimary: onPrimary,
                onPrimaryContainer: Color(white: 0.92),
                surface: Color(red: surfR, green: surfG, blue: surfB),
                onSurface: .white,
                onSurfaceVariant: Color(white: 0.72),
                surfaceContainer: Color(red: contR, green: contG, blue: contB),
                surfaceContainerLow: Color(red: contLR, green: contLG, blue: contLB),
                surfaceContainerHigh: Color(red: contHR, green: contHG, blue: contHB),
                surfaceContainerHighest: Color(red: contHhR, green: contHhG, blue: contHhB),
                surfaceContainerLowest: Color(red: contLoR, green: contLoG, blue: contLoB),
                outline: Color(white: 0.38),
                outlineVariant: Color(white: 0.25),
                secondaryContainer: Color(red: sr * 0.2, green: sg * 0.2, blue: sb * 0.2),
                background: Color(red: bgR, green: bgG, blue: bgB),
                sidebarBg: Color(red: sideR, green: sideG, blue: sideB).opacity(0.95),
                isGlassmorphic: true
            ), isDark: true)
        } else {
            // ── LIGHT THEME ──
            let surfBase = (min(1, dr * 0.12 + 0.88), min(1, dg * 0.12 + 0.88), min(1, db * 0.12 + 0.88))
            let bgBase = (min(1, dr * 0.08 + 0.92), min(1, dg * 0.08 + 0.92), min(1, db * 0.08 + 0.92))
            
            // Ensure text is always dark enough to read
            let textR = min(0.25, dr * 0.2)
            let textG = min(0.25, dg * 0.2)
            let textB = min(0.25, db * 0.2)
            let textVarR = min(0.4, dr * 0.35)
            let textVarG = min(0.4, dg * 0.35)
            let textVarB = min(0.4, db * 0.35)
            
            return (ThemePalette(
                primary: primary,
                primaryDim: primaryDim,
                primaryContainer: Color(red: min(1, sr * 0.25 + 0.75), green: min(1, sg * 0.25 + 0.75), blue: min(1, sb * 0.25 + 0.75)),
                onPrimary: onPrimary,
                onPrimaryContainer: Color(red: sr * 0.35, green: sg * 0.35, blue: sb * 0.35),
                surface: Color(red: surfBase.0, green: surfBase.1, blue: surfBase.2),
                onSurface: Color(red: textR, green: textG, blue: textB),
                onSurfaceVariant: Color(red: textVarR, green: textVarG, blue: textVarB),
                surfaceContainer: Color(red: min(1, dr * 0.18 + 0.82), green: min(1, dg * 0.18 + 0.82), blue: min(1, db * 0.18 + 0.82)),
                surfaceContainerLow: Color(red: min(1, dr * 0.15 + 0.85), green: min(1, dg * 0.15 + 0.85), blue: min(1, db * 0.15 + 0.85)),
                surfaceContainerHigh: Color(red: min(1, dr * 0.22 + 0.78), green: min(1, dg * 0.22 + 0.78), blue: min(1, db * 0.22 + 0.78)),
                surfaceContainerHighest: Color(red: min(1, dr * 0.28 + 0.72), green: min(1, dg * 0.28 + 0.72), blue: min(1, db * 0.28 + 0.72)),
                surfaceContainerLowest: Color(red: min(1, dr * 0.06 + 0.94), green: min(1, dg * 0.06 + 0.94), blue: min(1, db * 0.06 + 0.94)),
                outline: Color(red: min(0.5, dr * 0.45), green: min(0.5, dg * 0.45), blue: min(0.5, db * 0.45)),
                outlineVariant: Color(red: min(0.7, dr * 0.3 + 0.4), green: min(0.7, dg * 0.3 + 0.4), blue: min(0.7, db * 0.3 + 0.4)),
                secondaryContainer: Color(red: min(1, sr * 0.12 + 0.88), green: min(1, sg * 0.12 + 0.88), blue: min(1, sb * 0.12 + 0.88)),
                background: Color(red: bgBase.0, green: bgBase.1, blue: bgBase.2),
                sidebarBg: Color(red: min(1, dr * 0.1 + 0.9), green: min(1, dg * 0.1 + 0.9), blue: min(1, db * 0.1 + 0.9)).opacity(0.95)
            ), isDark: false)
        }
    }
    
    func toggle(currentTrack: Track?) {
        switch themeMode {
        case .light:
            themeMode = .dark
        case .dark:
            themeMode = .light
        case .custom:
            themeMode = .light
        case .dynamic:
            themeMode = .light
        case .system:
            themeMode = .light
        }
    }
    
    // MARK: - Custom theme application
    func applyCustomTheme() {
        let (pr, pg, pb) = Self.colorToRGB(customPrimaryColor)
        let (sr, sg, sb) = Self.colorToRGB(customSecondaryColor)
        let result = Self.buildPalette(
            dominant: (pr, pg, pb),
            secondary: (sr, sg, sb),
            forceDark: customIsDark
        )
        customPalette = result.palette
    }
    
    private func persistCustomColors() {
        let (pr, pg, pb) = Self.colorToRGB(customPrimaryColor)
        let (sr, sg, sb) = Self.colorToRGB(customSecondaryColor)
        UserDefaults.standard.set(pr, forKey: Self.customPrimaryRKey)
        UserDefaults.standard.set(pg, forKey: Self.customPrimaryGKey)
        UserDefaults.standard.set(pb, forKey: Self.customPrimaryBKey)
        UserDefaults.standard.set(sr, forKey: Self.customSecondaryRKey)
        UserDefaults.standard.set(sg, forKey: Self.customSecondaryGKey)
        UserDefaults.standard.set(sb, forKey: Self.customSecondaryBKey)
        applyCustomTheme()
    }
    
    private static func colorToRGB(_ color: Color) -> (Double, Double, Double) {
        let nsColor = NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
