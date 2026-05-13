# Melobi (Offline Audio Player)

**Resonance** is a modern, high-performance, and entirely offline audio and audiobook player built natively for macOS using Swift and SwiftUI. Designed for power users and library localists, the app avoids cloud-syncing and subscriptions, giving you complete control over your local `.mp3`, `.flac`, `.m4a`, and `.m4b` files through a beautiful, keyboard-navigable interface.

---

## ✨ Core Features

### 🎵 Music & Playlists
- **Blazing Fast Local Library:** Powered by `GRDB` (SQLite), Resonance effortlessly scans local folders, extracts metadata, and categorizes your library with zero-latency searching.
- **Custom Playlist Ordering:** Full manual control over Liked Songs and Playlists. Use drag-and-drop to rearrange your sequence with persistent database ordering.
- **Shuffle Play Everywhere:** Native "Shuffle Play" functionality integrated into every playlist and the Liked Songs library.

### 📖 Advanced Audiobook Support
- **Chapter Navigation:** Native `.m4b` parsing with full chapter lists and instant seeking.
- **Progress Persistence:** Automatically saves your listening position for every book, allowing you to resume exactly where you left off.
- **Dedicated UI:** Custom audiobook views optimized for long-form listening.

### 🎤 Lyrics Engine (Velvet Echo)
- **Real-time Synchronization:** Integrated lyrics engine with support for `.lrc` files and real-time synchronization.
- **Auto-Scrolling:** Smooth, automatic scrolling that keeps the current line centered.
- **Lyric Variants:** Support for multiple lyric versions (e.g., Romanized, Translated) within the same track.

### 🎛️ High-Fidelity Equalizer
- **Dual Audio Engine:** Dynamically switches between `AVPlayer` (for battery-efficient audiobook/off-mode playback) and `AVAudioEngine` (for active hardware DSP processing).
- **6-Band Parametric EQ:** Professional-grade equalizer with a responsive graphic UI, featuring horizontal/vertical grid lines and exact dB labeling.
- **Peak Limiting Protection:** Integrated `AVAudioUnitEffect` peak limiter to prevent audio clipping during heavy bass boosts.
- **Harman Target Curve:** Exclusive built-in 'Harman Curve' preset, alongside 15+ other acoustic configurations.
- **Persistent States:** Slider positions and presets are automatically saved via `UserDefaults` and instantly applied on launch.

### 💎 Luminous Glassmorphic UI
- **Ambient Visuals:** Dynamic ambient gradient "blobs" that respond to the active theme.
- **Glassmorphism:** A premium macOS experience with translucent sidebars, blurred backgrounds, and sleek navigation.
- **Theme Customization:** 7+ curated theme palettes (Rose Quartz, Mint Breeze, Luminous Audio, etc.) with support for Light/Dark/System overrides.

---

## 🛠 Project Architecture

The project follows a clean, modular architecture separated by responsibility:

### 📂 Directory Structure
- **`Sources/App.swift`**: The main entry point and app lifecycle management.
- **`Sources/Database/`**: Contains `AppDatabase.swift` for SQLite migrations and GRDB setup.
- **`Sources/Models/`**: `Entities.swift` defines core data structures like `Track`, `Playlist`, and `Audiobook`.
- **`Sources/Services/`**:
    - `AudioEngine.swift`: The core AVFoundation-powered playback engine.
    - `LibraryScanner.swift`: Handles background file system monitoring and indexing.
    - `MetadataExtractor.swift`: Parses ID3 tags, cover art, and audiobook chapters.
    - `LRCParser.swift`: Logic for parsing synchronized lyrics files.
- **`Sources/ViewModels/`**:
    - `LibraryStore.swift`: The central state manager for the music library and playlists.
    - `LyricsState.swift`: Manages the real-time lyrics synchronization state.
    - `ThemeManager.shared`: Controls the application's visual theme and palette.
- **`Sources/Views/`**: All SwiftUI components, including the modular `DesignTokens.swift` system.

---

## 🏗 Technical Stack

- **Language:** Swift 6 (Concurrency-first)
- **UI Framework:** SwiftUI 5+
- **Database:** [GRDB.swift](https://github.com/groue/GRDB.swift) for robust SQLite management.
- **Audio:** `AVFoundation` for low-latency playback and routing.
- **Design:** Custom-built "Luminous" design system using HSL-based color tokens.

---

## 🚀 Getting Started

1. **Clone & Open:** Clone the repository and open the folder in Xcode 15 or 16.
2. **Build:** Run the `Resonance` target on your Mac.
3. **Import:** Head to the **Library** section to add your local music or audiobook folders.
4. **Enjoy:** Start listening with full offline privacy.

---

*Created as a lightweight, keyboard-accessible alternative for managing offline music and audiobooks on the Mac.*

---

## 📈 Recent Updates (Feature: Equalizer & UI Polish)
- **Architectural Overhaul:** Rewrote `AudioEngine.swift` to seamlessly manage handoffs between `AVPlayer` and `AVAudioEngine` mid-playback without stuttering, allowing native EQ injection while maintaining robust AVPlayer stability for disabled states.
- **Harman Curve Tuning:** Added precise +6.0dB Sub Bass / +3.5dB Mid Bass targets with an inline `-3.0` preGain limiter to perfectly recreate the Harman Target curve.
- **Glassmorphic UI Refinements:** Fixed top-left traffic light clipping in the main macOS window by expanding the `.ignoresSafeArea()` background bleed.
- **Sidebar UX:** Added full-width horizontal hit-testing to all sidebar rows (`.contentShape(Rectangle())`), allowing navigation clicks anywhere inside the row bounding box.
- **Preset Management:** Reordered the Equalizer preset list to prioritize "Off" at the top and "Custom" at the bottom, dynamically updating whenever a user drags an EQ slider.
