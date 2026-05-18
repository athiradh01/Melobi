# Lyrics Editor UI/UX Redesign Logic

## 1. Critique of the Current Design (Screenshot Analysis)
The current UI is a small, centered modal overlay on top of the "Mint Breeze" music player. While the aesthetic is clean, the UX logic has several critical flaws for a complex tool like an AI lyric aligner:
* **Broken Layout:** The "Cancel" and "Import .lrc" buttons are stacked vertically letter-by-letter, indicating a layout constraint or wrapping issue.
* **Premature Action Binding:** The "Select Track & Save" button combines track selection and saving into one action. In a forced-alignment workflow, the user must select a track, *wait for AI processing*, review/nudge the timestamps, and *then* save. 
* **Insufficient Space:** An AI lyric editor requires audio playback controls, a pre-roll offset slider, and a way to view/nudge timestamps. A small text-area modal cannot accommodate these features.

---

## 2. The New Architectural Logic: "Split-Pane Editor Sheet"
Instead of a small popup, clicking "+ Add Lyrics" or "Realign Lyrics" should open a **Full-Screen Sheet** or a **Dedicated Editor View** within the app. This provides the necessary real estate for the workflow we previously blueprinted.

### **The Layout (Two-Column Approach)**

**Left Column: The Text Engine (Input & Output)**
* **Mode 1 (Raw Input):** A clean text area to paste lyrics manually.
* **Mode 2 (Interactive List):** Once AI processing is complete, the text area transitions into a selectable list of `[timestamp]` + `Lyric` rows. Double-clicking a timestamp allows manual nudging.
* **Bottom Actions:** "Import .lrc file" and "Clear Text" buttons.

**Right Column: The Audio & Sync Engine**
* **Step 1: Track Selection:** A large, prominent button: 🎵 `Select Track to Align`. Clicking this opens the native macOS library/file picker.
* **Step 2: Audio Controls (Appears after selection):** A waveform or progress bar, Play/Pause buttons, and a toggle for "Isolate Vocals (AI)".
* **Step 3: The Action Button:** ✨ `Auto-Sync Lyrics (Whisper AI)`.
* **Step 4: Refinement Tools (Appears after sync):** The `Pre-roll Offset` slider (-300ms default) to adjust lead-in time globally.
* **Bottom Action:** The final `Save & Link to Library` button.

---

## 3. Step-by-Step User Flow (The Logic)

### **State 1: Initialization**
* User clicks "+ Add Lyrics" from the main app.
* The Editor Sheet slides up.
* **UI State:** The right column is grayed out. The user's focus is forced to the left column to paste raw lyrics or import an `.lrc`.

### **State 2: Track Pairing**
* Once text is detected in the left column, the 🎵 `Select Track to Align` button in the right column turns active (Primary Color).
* User clicks it, searches their Mint Breeze library or local files, and selects the matching `.mp3`.

### **State 3: AI Processing State**
* The audio is loaded. The right pane updates to show the Audio Player.
* User clicks ✨ `Auto-Sync Lyrics`.
* **UI State:** A progress view appears. 
  * *Sub-step A:* Isolating vocals (Soniqo).
  * *Sub-step B:* Aligning text (WhisperKit / AI4Bharat).

### **State 4: Review & Nudge (The Editor Mode)**
* The left column transforms from raw text into the interactive timestamp list.
* The Pre-roll Offset automatically applies a -300ms shift.
* **User Action:** The user presses Play. The active lyric highlights as the song plays. If a line is late, the user adjusts the Pre-roll slider or double-clicks the specific timestamp to nudge it.

### **State 5: Finalization**
* User clicks `Save`. The app generates the `.lrc` file, saves it to the local app directory, links it to the database for that song, and dismisses the Editor Sheet, returning to the main player view.
