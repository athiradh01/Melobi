# Melobi (Offline Audio Player)

**Resonance** is a modern, high-performance, and entirely offline audio and audiobook player built natively for macOS using Swift and SwiftUI. Designed for power users and library localists, the app avoids cloud-syncing and subscriptions, giving you complete control over your local `.mp3`, `.flac`, `.m4a`, and `.m4b` files through a beautiful, keyboard-navigable interface.

## ✨ Features

- **Blazing Fast Local Library:** Powered by `GRDB` (SQLite), Resonance effortlessly scans your local folders, extracts metadata, and categorizes your library into Music and Audiobooks.
- **Advanced Audiobook Support:** Natively parses `.m4b` and `.mp4b` chapters, displays a dedicated chapter panel, and automatically persists your listening position so you can resume exactly where you left off.
- **Power-User Keyboard Navigation:** Navigate the entire UI—from the library search, to the playback controls, to the playlist management—without ever touching a mouse.
- **Modern Apple UI:** Built entirely in latest SwiftUI with dynamic design tokens, responsive layouts, blurred backgrounds, and a high-fidelity "Now Playing" experience.
- **Under-the-hood:** Driven by Swift 6 Concurrency and AVFoundation for zero-latency playback, efficient background scanning, and robust audio routing.

## 🛠 Tech Stack

- **Platform:** macOS (Native)
- **Language:** Swift 6
- **UI Framework:** SwiftUI
- **Database:** GRDB.swift (SQLite)
- **Audio Engine:** AVFoundation

## 🚀 Getting Started

1. Clone this repository.
2. Open the directory or `.xcworkspace` with Xcode 15/16.
3. Build and Run the `Resonance` macOS target.
4. Go to the Library tab to import your local folders and start listening!

---
*Created as a lightweight, keyboard-accessible alternative for managing offline music and audiobooks on the Mac.*
