import SwiftUI
import AppKit
import GRDB

@main
struct ResonanceApp: App {
    private let db: DatabasePool
    
    init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Resonance")
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        do {
            try AppDatabase.shared.setup(in: appDir)
            self.db = AppDatabase.shared.dbWriter
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
        
        LibraryStore.shared.startObserving(db: AppDatabase.shared.dbWriter)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(db: db)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play / Pause") { AudioEngine.shared.togglePlayPause() }
                    .keyboardShortcut(" ", modifiers: [])
                Button("Next Track") { AudioEngine.shared.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous Track") { AudioEngine.shared.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}
