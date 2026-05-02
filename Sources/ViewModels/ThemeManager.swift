import SwiftUI

// MARK: - Theme Manager
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    
    private static let schemeKey = "app.themeScheme"
    private static let lightThemeKey = "app.lightTheme"
    private static let darkThemeKey = "app.darkTheme"
    
    var overrideScheme: ColorScheme? {
        didSet { saveScheme() }
    }
    var activeLightTheme: LightThemeOption {
        didSet { UserDefaults.standard.set(activeLightTheme.rawValue, forKey: Self.lightThemeKey) }
    }
    var activeDarkTheme: DarkThemeOption {
        didSet { UserDefaults.standard.set(activeDarkTheme.rawValue, forKey: Self.darkThemeKey) }
    }
    
    private init() {
        // Restore light theme
        if let raw = UserDefaults.standard.string(forKey: Self.lightThemeKey),
           let theme = LightThemeOption(rawValue: raw) {
            activeLightTheme = theme
        } else {
            activeLightTheme = .mintBreeze
        }
        
        // Restore dark theme
        if let raw = UserDefaults.standard.string(forKey: Self.darkThemeKey),
           let theme = DarkThemeOption(rawValue: raw) {
            activeDarkTheme = theme
        } else {
            activeDarkTheme = .midnightBlue
        }
        
        // Restore dark/light override
        let schemeRaw = UserDefaults.standard.integer(forKey: Self.schemeKey)
        switch schemeRaw {
        case 1:  overrideScheme = .light
        case 2:  overrideScheme = .dark
        default: overrideScheme = nil
        }
    }
    
    private func saveScheme() {
        switch overrideScheme {
        case .light:   UserDefaults.standard.set(1, forKey: Self.schemeKey)
        case .dark:    UserDefaults.standard.set(2, forKey: Self.schemeKey)
        default:       UserDefaults.standard.set(0, forKey: Self.schemeKey)
        }
    }
    
    func toggle(current: ColorScheme) {
        overrideScheme = current == .dark ? .light : .dark
    }
}
