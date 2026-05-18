import SwiftUI
import AppKit
import GRDB

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Listen for Spacebar to toggle Play/Pause globally, but only if not typing
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // keyCode 49 is Space
            if event.keyCode == 49 {
                // Check if the current first responder is a text input field
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder.isKind(of: NSTextView.self) || responder.isKind(of: NSTextField.self) {
                    return event // Let the text field handle the space character
                }
                
                Task { @MainActor in
                    AudioEngine.shared.togglePlayPause()
                }
                return nil // Consume the event
            }
            return event
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Show existing main window instead of creating a new one
            NSApp.windows.first { !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }
}

@main
struct ResonanceApp: App {
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
            LibraryStore.shared.startPlaylistObserving(db: pool)
            LibraryStore.shared.backfillLanguagesIfNeeded(db: pool)
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
                Button("Next Track") { AudioEngine.shared.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous Track") { AudioEngine.shared.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}