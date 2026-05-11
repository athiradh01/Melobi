# Melobi (Offline Audio Player)

**Resonance** is a modern, high-performance, and entirely offline audio and audiobook player built natively for macOS using Swift and SwiftUI. Designed for power users and library localists, the app avoids cloud-syncing and subscriptions, giving you complete control over your local `.mp3`, `.flac`, `.m4a`, and `.m4b` files through a beautiful, keyboard-navigable interface.

## ✨ Features

- **Blazing Fast Local Library:** Powered by `GRDB` (SQLite), Resonance effortlessly scans your local folders, extracts metadata, and categorizes your library into Music and Audiobooks with persistent SQLite state.
- **Custom Playlists & Ordering:** Complete manual control over your Liked Songs and Playlists. Use drag-and-drop to rearrange your playback sequence with full database persistence across restarts.
- **Advanced Audiobook Support:** Natively parses `.m4b` and `.mp4b` chapters, displays a dedicated chapter panel, and automatically persists your listening position.
- **Dedicated Settings Panel:** Native in-app settings to manage appearance (Light/Dark/System theme override) and view application info.
- **Modern Apple UI & Luminous Design:** Built in latest SwiftUI with glassmorphic design tokens, dynamic ambient gradients, and a high-fidelity "Now Playing" experience.
- **Smart Interaction:** Playback controls that appear on hover for playlists, enhanced drag-and-drop visuals showing full track details, and keyboard-centric navigation.

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
