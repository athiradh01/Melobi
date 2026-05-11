# Melobi (Offline Audio Player)

**Resonance** is a modern, high-performance, and entirely offline audio and audiobook player built natively for macOS using Swift and SwiftUI. Designed for power users and library localists, the app avoids cloud-syncing and subscriptions, giving you complete control over your local `.mp3`, `.flac`, `.m4a`, and `.m4b` files through a beautiful, keyboard-navigable interface.

## ✨ Features

- **Blazing Fast Local Library:** Powered by `GRDB` (SQLite), Resonance effortlessly scans local folders, extracts metadata, and categorizes your library into Music and Audiobooks with persistent SQLite state and zero-latency searching.
- **Custom Playlists & Ordering:** Full manual control over Liked Songs and Playlists. Use drag-and-drop to rearrange your sequence with persistent database ordering.
- **Real-time Lyrics (Velvet Echo):** Integrated lyrics engine with support for real-time synchronization, auto-scrolling, and multiple lyric variants.
- **Advanced Audiobook Support:** Native `.m4b` parsing with chapter navigation, dedicated progress tracking, and automatic "resume where you left off" persistence.
- **Private Vaults:** Securely organize your audio content with the ability to create and manage Private Vaults directly from the overview.
- **Shuffle Play Everywhere:** Native "Shuffle Play" functionality integrated into every playlist and the Liked Songs library.
- **Luminous Glassmorphic UI:** A premium macOS experience featuring:
    - Dynamic ambient gradient "blobs" that respond to the active theme.
    - Glassmorphic sidebar with blurred backgrounds and sleek navigation.
    - Interactive "Now Playing" bar with cinematic artwork blurs.
- **Smart Interface Modifiers:**
    - **Hover Actions:** Playback controls that appear only when needed.
    - **Live Dragging:** See the entire horizontal track bar move as you reorder songs.
    - **Collapsible Sidebar:** A cleaner sidebar that keeps your playlist list tucked away until you need it.
- **Native Settings Panel:** Toggle between curated theme palettes (Electric Violet, Cyan, etc.) and manage system-wide appearance overrides.

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
