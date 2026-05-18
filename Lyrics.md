# macOS Native Offline Lyric-Syncing App: Project Blueprint

## 1. Project Overview
A native, strictly offline macOS application designed to generate time-synced `.lrc` lyric files. The software processes user-provided audio and text, isolating vocals for clarity, and using state-of-the-art AI to automatically align lyrics to millisecond-accurate timestamps. It also functions as a powerful `.lrc` editor to import, adjust, and perfectly offset existing files for optimal playback UX.

## 2. Core Tech Stack
* **Language & UI:** Swift, SwiftUI
* **Audio Processing & Playback:** AVFoundation (`AVAudioEngine`, `AVAudioPlayerNode`)
* **AI & Machine Learning:** CoreML, MLX (Apple Silicon Hardware Acceleration)
* **Target Hardware:** Apple Silicon (M1/M2/M3) Macs

---

## 3. Core Features & Repositories

### A. Vocal Isolation (Source Separation)
To ensure the syncing AI (and the user) can clearly hear the words, the app first isolates the vocal track from the instrumental music.
* **Chosen Approach:** Open-Unmix (UMX)
* **Repository:** `soniqo/speech-swift` (Specifically the SourceSeparation module)

### B. Audio Cleanup Pipeline
Because lightweight separation models leave slight instrumental "bleed," the app uses native `AVFoundation` filters to clean the isolated track in real-time (High-Pass Filter & Noise Gate).

### C. AI Forced Alignment (Lyric Syncing)
**1. For Multilingual & Romanized Text (Manglish, Tanglish, English, Japanese)**
* **Model:** Whisper (`large-v3-turbo`) via `argmaxinc/WhisperKit`.

**2. For Pure Native Indic Scripts (Malayalam, Tamil, Hindi)**
* **Model:** AI4Bharat (IndicConformer) converted to `.mlpackage`.

### D. UI/UX: The Editor, Re-alignment & Lead-in Offset
* **Dedicated Lyrics Input Section:** A prominent text editor pane on the left side of the app for users to easily paste raw lyrics or view/edit imported `.lrc` text.
* **The "Realign Lyrics" Button & Music Search:** A dedicated action button for existing lyrics. When clicked, it opens a native macOS search picker (styled like an "Add Music" menu) that allows the user to browse or search their local audio files/Music library to select the exact audio track they want to pair and realign with the current text.
* **Pre-roll Offset (-300ms to -600ms):** Automatically applies a lead-in offset to AI timestamps so the lyrics pop up just before the singer sings, matching professional karaoke/Spotify UX. Includes a global UI slider.
* **Smart Parsing & Nudging:** Double-click list items to micro-adjust individual line timestamps.

---

## 4. On-Demand Model Download System
* **Tier 1: Fast & Light Sync (~150MB)** (Whisper `base` or `base.en`)
* **Tier 2: Studio Multilingual (~800MB)** (Whisper `large-v3-turbo`)
* **Tier 3: Native Indic Sync (Size Varies)** (Custom CoreML AI4Bharat model)

---

## 5. Application Workflow

1. **Input & Pair:** User pastes raw lyrics into the **Dedicated Input Section** or imports an `.lrc` file. They click the **"Realign Lyrics"** button, which pops open a custom search menu to select the corresponding `.mp3`/`.wav` music file.
2. **Audio Prep:** App runs `soniqo/speech-swift` on a background thread to extract a temporary `vocals_only.wav` file.
3. **Alignment Execution:** The selected AI model processes the vocals against the text prompt.
4. **Pre-roll Application & Review UI:** The app automatically subtracts ~300ms from every timestamp. The user uses the offset slider or manual nudge tools to perfect the timing.
5. **Export:** Formats the final array into standard `[mm:ss.xx]` text and saves it locally.

---

## 6. Implementation Plan (Phased Approach)

### Phase 1: Foundation, UI & Input Logic (Weeks 1-2)
* **Setup Xcode Project:** Initialize a macOS app with SwiftUI.
* **UI Layout:** Build the Split View. Left side: **Lyrics Paste/Input Section**. Right side: Audio controls, alignment list, and Pre-roll sliders.
* **"Realign Lyrics" Flow:** Implement the dedicated button and customize an `NSOpenPanel` (with a search bar) to act as the "Add Music" picker menu.
* **LRC Parser:** Write Swift Regex logic to parse existing `.lrc` files into the input section.

### Phase 2: Vocal Isolation & Cleanup (Weeks 3-4)
* **Integrate Soniqo:** Add `soniqo/speech-swift` via SPM.
* **AVFoundation Filters:** Implement High-Pass Filter and Noise Gate.

### Phase 3: The Download Manager (Week 5)
* **Network Logic:** Use `URLSession` to securely download Whisper ML packages.

### Phase 4: Integration of WhisperKit (Weeks 6-7)
* **Add WhisperKit:** Integrate via SPM and feed audio/prompt into the model.

### Phase 5: Lead-in Offset & Polish (Week 8)
* **Pre-roll Algorithm:** Implement the -300ms calculation.
* **Global Lead-in Slider:** Add the UI slider (0ms to -600ms).

### Phase 6: The AI4Bharat Hurdle (Advanced - Weeks 9-11)
* **Model Conversion:** Convert the PyTorch IndicConformer model to `.mlpackage`.

### Phase 7: Testing & Deployment (Week 12)
* **Performance & UX Testing:** Ensure the music search picker feels native and the UI remains responsive during AI processing.
