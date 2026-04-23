import SwiftUI
import AppKit
import GRDB

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    }
}

@main
struct ArisefApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let db: DatabasePool
    
    init() {
        let appDir = AppDatabase.resolveDataDirectory()

        do {
            try AppDatabase.shared.setup(in: appDir)
            guard let pool = AppDatabase.shared.dbWriter else {
                fatalError("Database setup succeeded but dbWriter is nil")
            }
            self.db = pool
            LibraryStore.shared.startObserving(db: pool)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        setupEngineCallbacks()
    }
    
    private func setupEngineCallbacks() {
        let engine = AudioEngine.shared
        
        engine.onTrackChanged = { filePath in
            let url = URL(fileURLWithPath: filePath)
            LyricsState.shared.load(for: url)
        }
        
        engine.onChapterCompleted = { audiobook, chapterIndex in
            guard let db = AppDatabase.shared.dbWriter else { return }
            LibraryStore.shared.saveChapterProgress(
                for: audiobook, chapterIndex: chapterIndex,
                progressMs: 0, isCompleted: true, db: db
            )
        }
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