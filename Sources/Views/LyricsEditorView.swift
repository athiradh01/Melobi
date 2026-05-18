import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Editor Phase

private enum EditorPhase: Equatable {
    case idle
    case textReady
    case trackSelected
    case manualSync   // user is tap-timestamping each line while the audio plays
    case review
}

// MARK: - ViewModel

@MainActor
@Observable
private final class LyricsEditorViewModel {

    var phase: EditorPhase = .idle
    var rawText: String = "" { didSet { reconcilePhase() } }
    var lrcLines: [LRCLine] = []

    var selectedURL: URL?
    var trackTitle    = ""
    var trackArtist   = ""
    var trackArtwork: String?

    var isPlaying    = false
    var currentTime: Double = 0
    var duration: Double    = 0

    var syncError: String?

    var preRollMs: Double = 0
    var appliedGlobalOffsetMs: Double = 0
    var appliedIndividualOffsets: [UUID: Double] = [:]

    /// Stores the original timestamps before any pre-roll offsets were applied.
    /// This is the baseline used for all delta calculations.
    var originalLrcLines: [LRCLine] = []

    /// Whether the Fine-tune section is visible on the trackSelected page.
    var showFineTune: Bool = false

    var nudgingIndex: Int?

    /// Set to `true` when any line in the current `lrcLines` was stamped by a
    /// user tap (either initial manual sync or refine-after-auto). Save() then
    /// applies a constant −300 ms read-ahead so the lyric appears slightly
    /// before the singer hits the line.
    var isManualMode: Bool = false

    /// Index of the next line awaiting a timestamp during manual sync.
    var manualCursor: Int = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    // MARK: Phase

    private func reconcilePhase() {
        let hasText = !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch phase {
        case .idle:
            if hasText { phase = selectedURL != nil ? .trackSelected : .textReady }
        case .textReady:
            if !hasText { phase = .idle }
            else if selectedURL != nil { phase = .trackSelected }
        case .trackSelected:
            if !hasText { clearTrack(); phase = .idle }
        default:
            break
        }
    }

    // MARK: Track Selection

    func selectTrack(_ url: URL, library: LibraryStore? = nil) async {
        let asset = AVURLAsset(url: url)
        guard let cmDuration = try? await asset.load(.duration) else { return }

        selectedURL  = url
        duration     = cmDuration.seconds
        isPlaying    = false
        currentTime  = 0

        if let lib = library,
           let track = lib.filteredTracks.first(where: { $0.filePath == url.path }) {
            trackTitle  = track.title  ?? url.deletingPathExtension().lastPathComponent
            trackArtist = track.artist ?? ""
            trackArtwork = track.artworkPath
        } else {
            trackTitle  = url.deletingPathExtension().lastPathComponent
            trackArtist = ""
            trackArtwork = nil
        }

        installPlayer(url: url)

        let hasText = !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        phase = hasText ? .trackSelected : .idle
    }

    func clearTrack() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        player?.pause(); player = nil
        selectedURL = nil; trackTitle = ""; trackArtist = ""; trackArtwork = nil
        currentTime = 0; duration = 0; isPlaying = false
    }

    // MARK: Playback

    func togglePlayback() {
        if isPlaying { player?.pause(); isPlaying = false }
        else         { player?.play();  isPlaying = true  }
    }

    func seek(to time: Double) {
        let clamped = max(0, min(time, duration))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 1000))
        currentTime = clamped
    }

    private func installPlayer(url: URL) {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
        player?.pause()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        let interval = CMTime(seconds: 0.1, preferredTimescale: 10)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.currentTime = t.seconds
            }
        }
    }



    // MARK: Nudge

    func nudge(at index: Int, by delta: Double) {
        guard lrcLines.indices.contains(index) else { return }
        lrcLines[index].timestamp = max(0, lrcLines[index].timestamp + delta)
    }

    // MARK: Manual sync

    /// Seed lrcLines from rawText with placeholder timestamps and switch into the
    /// manual-stamping UI. Playback starts automatically so the user can begin
    /// marking immediately.
    func startManualSync() {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }

        // Retain existing timestamps if they were loaded from an existing file
        lrcLines = lines.enumerated().map { idx, text in
            let ts = idx < lrcLines.count ? lrcLines[idx].timestamp : -1
            return LRCLine(timestamp: ts, text: text)
        }

        manualCursor = 0
        isManualMode = true
        syncError = nil
        phase = .manualSync
        seek(to: 0)
        
        Task { @MainActor in
            AudioEngine.shared.pause()
            try? await Task.sleep(for: .seconds(1))
            if !self.isPlaying { self.togglePlayback() }
        }
    }

    /// Re-enter manual-tap mode AFTER an auto-sync, keeping the auto timestamps
    /// as a starting point. Each tap overwrites the auto value with the user's
    /// timing; lines the user doesn't re-mark retain their auto stamp.
    /// Because at least some lines will be human-timed, save() applies the
    /// 300 ms read-ahead.
    func startManualRefine() {
        guard !lrcLines.isEmpty else { return }
        manualCursor = 0
        isManualMode = true
        syncError = nil
        phase = .manualSync
        seek(to: max(lrcLines.first?.timestamp ?? 0, 0))
        if !isPlaying { togglePlayback() }
    }

    /// Capture the current playback time for the cursor line, then advance.
    /// When the cursor walks past the last line the editor flips to .review
    /// and playback pauses so the user can scrub through the result.
    func markCurrentLine() {
        guard phase == .manualSync, lrcLines.indices.contains(manualCursor) else { return }
        lrcLines[manualCursor].timestamp = max(currentTime, 0)
        manualCursor += 1
        if manualCursor >= lrcLines.count {
            if isPlaying { togglePlayback() }
            // Save sync data to DB — capture the raw manual timestamps as baseline
            originalLrcLines = lrcLines.map { LRCLine(timestamp: $0.timestamp, text: $0.text) }
            saveSyncData(method: "manual")
            preRollMs = 0
            appliedGlobalOffsetMs = 0
            phase = .review
        }
    }

    /// Go back to `.trackSelected` phase without clearing the timestamps
    /// so the user can continue later.
    func cancelManualSync() {
        if isPlaying { togglePlayback() }
        phase = .trackSelected
    }

    // MARK: Save

    @discardableResult
    func save() -> Bool {
        guard let url = selectedURL,
              let lyricsDir = AppDatabase.shared.lyricsDirectory else { return false }

        // Manual-mode timestamps capture the exact instant the user heard each
        // line, so shifting them back 300 ms produces a natural "read-ahead" feel
        // during playback.
        let linesToWrite: [LRCLine]
        if isManualMode {
            let readAhead = 0.300
            linesToWrite = lrcLines.map { line in
                LRCLine(timestamp: max(line.timestamp - readAhead, 0), text: line.text)
            }
        } else {
            linesToWrite = lrcLines
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        let dest     = lyricsDir.appendingPathComponent("\(baseName).lrc")
        let content  = LRCFormatter.formatLRC(linesToWrite)

        do {
            try content.write(to: dest, atomically: true, encoding: .utf8)
        } catch {
            syncError = "Save failed: \(error.localizedDescription)"
            return false
        }

        // Update the pre-roll slider position in the DB so it persists
        updatePreRollInDB()

        // Keep slider position — appliedGlobalOffsetMs tracks what's been applied
        appliedGlobalOffsetMs = preRollMs
        appliedIndividualOffsets.removeAll()

        if LyricsState.shared.loadedForFilePath == url.path {
            LyricsState.shared.clear()
            LyricsState.shared.load(for: url)
        }
        return true
    }

    // MARK: Sync/Tune Data Persistence

    /// Save the raw sync timestamps to the database. This is the permanent
    /// baseline that never changes unless a new sync is performed.
    func saveSyncData(method: String, preRoll: Double = 0) {
        guard let url = selectedURL,
              let db = AppDatabase.shared.dbWriter else { return }
        let syncContent = LRCFormatter.formatLRC(originalLrcLines)
        var record = LyricsSyncData(
            trackFilePath: url.path,
            lrcContent: syncContent,
            preRollMs: preRoll,
            syncMethod: method
        )
        do {
            try db.write { dbConn in
                // Upsert: delete old, insert new
                try dbConn.execute(sql: "DELETE FROM lyricsSyncData WHERE trackFilePath = ?", arguments: [url.path])
                try record.insert(dbConn)
            }
        } catch {
            print("[LyricsEditor] Failed to save sync data: \(error)")
        }
    }

    /// Update just the preRollMs in the database so the slider position persists.
    func updatePreRollInDB() {
        guard let url = selectedURL,
              let db = AppDatabase.shared.dbWriter else { return }
        do {
            var updated = false
            try db.write { dbConn in
                let stmt = try dbConn.makeStatement(sql: "UPDATE lyricsSyncData SET preRollMs = ? WHERE trackFilePath = ?")
                try stmt.execute(arguments: [preRollMs, url.path])
                updated = dbConn.changesCount > 0
            }
            if !updated {
                saveSyncData(method: "fine_tune", preRoll: preRollMs)
            }
        } catch {
            print("[LyricsEditor] Failed to update preRollMs: \(error)")
        }
    }

    /// Load sync data from the database. Sets originalLrcLines as the baseline
    /// and restores the last preRollMs slider position.
    func loadSyncData() {
        guard let url = selectedURL,
              let db = AppDatabase.shared.dbWriter else { return }
        do {
            let record = try db.read { dbConn in
                try LyricsSyncData.fetchOne(dbConn, sql: "SELECT * FROM lyricsSyncData WHERE trackFilePath = ?", arguments: [url.path])
            }
            if let record {
                let syncLines = LRCParser.parse(record.lrcContent)
                if !syncLines.isEmpty {
                    originalLrcLines = syncLines
                    preRollMs = record.preRollMs
                    appliedGlobalOffsetMs = record.preRollMs
                }
            }
        } catch {
            print("[LyricsEditor] Failed to load sync data: \(error)")
        }
    }

}

// MARK: - Main View

struct LyricsEditorView: View {
    var initialRawText: String = ""
    var initialURL: URL?       = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LibraryStore.self) private var library
    @Environment(AudioEngine.self)  private var engine

    @State private var vm = LyricsEditorViewModel()
    @State private var showTrackPicker = false

    private var t: Theme { Theme(scheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(t.onSurface.opacity(0.08))
            HStack(spacing: 0) {
                leftPanel.frame(width: 420)
                Divider().overlay(t.onSurface.opacity(0.08))
                rightPanel.frame(maxWidth: .infinity)
            }
        }
        .frame(width: 900, height: 680)
        .background(t.isGlassmorphic ? Color.clear : t.surface)
        .background(.ultraThinMaterial)
        .onAppear {
            if !initialRawText.isEmpty {
                let parsed = LRCParser.parse(initialRawText)
                if !parsed.isEmpty {
                    vm.lrcLines = parsed
                    // Store original timestamps as baseline for pre-roll deltas
                    vm.originalLrcLines = parsed.map { LRCLine(timestamp: $0.timestamp, text: $0.text) }
                    vm.rawText = initialRawText.replacingOccurrences(
                        of: #"\[\d{1,3}:\d{2}(?:\.\d{1,3})?\]\s*"#,
                        with: "",
                        options: .regularExpression
                    )
                } else {
                    vm.rawText = initialRawText
                }
            }
            let targetURL = initialURL ?? engine.currentTrack.map { URL(fileURLWithPath: $0.filePath) }
            if let url = targetURL {
                Task {
                    await vm.selectTrack(url, library: library)
                    // Load sync data from DB to restore the sync baseline
                    // and the last pre-roll slider position
                    vm.loadSyncData()
                }
            }
        }
        .onDisappear {
            vm.clearTrack()
        }
        .sheet(isPresented: $showTrackPicker) {
            LibraryTrackPickerView { url in
                Task { await vm.selectTrack(url, library: library) }
            }
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(t.primary)
            Text("Lyrics Editor")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(t.onSurface)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(t.onSurface.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(leftPanelTitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(t.outline)
                    .tracking(2)
                Spacer()
                if vm.phase == .review {
                    Text("\(vm.lrcLines.count) lines")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)
                } else if vm.phase == .manualSync {
                    Text("\(vm.manualCursor) / \(vm.lrcLines.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(t.primary)
                } else if vm.phase == .trackSelected && vm.showFineTune && !vm.lrcLines.isEmpty {
                    Text("\(vm.lrcLines.count) lines")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            if vm.phase == .review {
                lrcLineList
            } else if vm.phase == .manualSync {
                manualSyncLineList
            } else if vm.phase == .trackSelected && vm.showFineTune && !vm.lrcLines.isEmpty {
                lrcLineList
            } else {
                rawTextArea
            }

            Divider().overlay(t.onSurface.opacity(0.08))
            leftToolbar
        }
        .background(t.surfaceContainerLow.opacity(0.5))
    }

    private var leftPanelTitle: String {
        switch vm.phase {
        case .review:     return "SYNCED LYRICS"
        case .manualSync: return "TAP TO MARK"
        default:
            if vm.showFineTune && !vm.lrcLines.isEmpty { return "SYNCED LYRICS" }
            return "RAW LYRICS"
        }
    }

    private var rawTextArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Bindable(vm).rawText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(t.onSurface)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)

            if vm.rawText.isEmpty {
                Text("Paste lyrics here, one line per verse…")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant.opacity(0.45))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    private var lrcLineList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.lrcLines.enumerated()), id: \.element.id) { idx, line in
                        LRCEditorRow(
                            line: line,
                            isActive:  idx == activeIndex,
                            isNudging: vm.nudgingIndex == idx,
                            theme: t,
                            onSeek:   { vm.seek(to: line.timestamp) },
                            onToggleNudge: { vm.nudgingIndex = vm.nudgingIndex == idx ? nil : idx },
                            onDelta:  { delta in vm.nudge(at: idx, by: delta) }
                        )
                        .id(idx)
                    }
                    Spacer().frame(height: 60)
                }
            }
            .onChange(of: activeIndex) { _, idx in
                guard let idx else { return }
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo(idx, anchor: .center) }
            }
        }
    }

    private var activeIndex: Int? {
        LRCParser.activeIndex(in: vm.lrcLines, at: vm.currentTime)
    }

    /// Manual-mode line list. Each line shows a timestamp once it's been
    /// stamped, an em-dash placeholder otherwise. The cursor line is highlighted
    /// so the user knows which line a "Mark" tap will assign.
    private var manualSyncLineList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.lrcLines.enumerated()), id: \.element.id) { idx, line in
                        manualSyncRow(idx: idx, line: line)
                            .id(idx)
                    }
                    Spacer().frame(height: 60)
                }
            }
            .onChange(of: vm.manualCursor) { _, idx in
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo(idx, anchor: .center) }
            }
        }
    }

    private func manualSyncRow(idx: Int, line: LRCLine) -> some View {
        let isCursor = idx == vm.manualCursor
        let isStamped = line.timestamp >= 0
        return HStack(spacing: 12) {
            Text(isStamped ? stampString(line.timestamp) : "—:—:—")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(isCursor ? t.onPrimary : (isStamped ? t.primary.opacity(0.75) : t.onSurfaceVariant.opacity(0.4)))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isCursor ? t.primary : t.primaryContainer.opacity(isStamped ? 0.18 : 0.06))
                .cornerRadius(5)

            Text(line.text)
                .font(.system(size: isCursor ? 14 : 13, weight: isCursor ? .bold : .medium))
                .foregroundStyle(isCursor ? t.onSurface : t.onSurface.opacity(isStamped ? 0.7 : 0.45))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(isCursor ? t.surfaceContainer : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tapping a row sets it as the cursor — lets the user back up if
            // they missed a line.
            vm.manualCursor = idx
            
            if idx > 0 {
                // Find the closest previous line that is stamped
                if let prevStamped = vm.lrcLines[0..<idx].reversed().first(where: { $0.timestamp >= 0 }) {
                    vm.seek(to: prevStamped.timestamp)
                } else {
                    vm.seek(to: 0)
                }
            } else {
                vm.seek(to: 0)
            }
        }
    }

    private func stampString(_ t: TimeInterval) -> String {
        let cs = Int(max(t, 0) * 100)
        return String(format: "%d:%02d.%02d", cs / 6000, (cs % 6000) / 100, cs % 100)
    }

    private var leftToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(label: "Import .lrc", icon: "square.and.arrow.down", action: importLRC)

            if !vm.rawText.isEmpty || !vm.lrcLines.isEmpty {
                toolbarButton(label: "Clear", icon: "trash", isDestructive: true) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.rawText   = ""
                        vm.lrcLines  = []
                        vm.nudgingIndex = nil
                        vm.isManualMode = false
                        vm.manualCursor = 0
                        vm.phase = vm.selectedURL != nil ? .trackSelected : .idle
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func toolbarButton(label: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isDestructive ? Color.red.opacity(0.12) : t.surfaceContainerHigh)
                .foregroundStyle(isDestructive ? Color.red : t.onSurface)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    trackSection
                    syncSection
                    if vm.phase == .review {
                        playerSection
                        preRollSection
                    }
                    if vm.phase == .trackSelected && !vm.lrcLines.isEmpty {
                        fineTuneToggle
                        if vm.showFineTune {
                            preRollSection
                        }
                    }
                    if let err = vm.syncError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 2)
                    }

                }
                .padding(20)
            }

            if vm.phase == .review {
                Divider().overlay(t.onSurface.opacity(0.08))
                saveButton.padding(20)
            }
            if vm.phase == .trackSelected && vm.showFineTune && !vm.lrcLines.isEmpty {
                Divider().overlay(t.onSurface.opacity(0.08))
                saveButton.padding(20)
            }
        }
    }

    // MARK: Track Section

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepLabel("1", "Select Track")

            if !vm.trackTitle.isEmpty {
                trackCard
            } else {
                selectTrackButton
            }
        }
    }

    private var trackCard: some View {
        HStack(spacing: 14) {
            if let art = vm.trackArtwork {
                ArtworkView(path: art, size: 52, cornerRadius: 8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(t.primaryContainer.opacity(0.3))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "music.note").font(.system(size: 18)).foregroundStyle(t.primary))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.trackTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(t.onSurface)
                    .lineLimit(1)
                if !vm.trackArtist.isEmpty {
                    Text(vm.trackArtist)
                        .font(.system(size: 11))
                        .foregroundStyle(t.onSurfaceVariant)
                }
                Text(durationString(vm.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(t.outline)
            }
            Spacer()
            Button { pickTrack() } label: {
                Text("Change")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(t.surfaceContainerHigh)
                    .foregroundStyle(t.onSurface)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(t.surfaceContainerHigh)
        .cornerRadius(12)
    }

    private var selectTrackButton: some View {
        let enabled = vm.phase == .textReady || vm.phase == .trackSelected || vm.phase == .review
        return Button { pickTrack() } label: {
            HStack(spacing: 10) {
                Image(systemName: "music.note.badge.plus").font(.system(size: 17))
                Text("Select Track to Align").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(enabled ? t.onPrimary : t.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(enabled ? t.primary : t.surfaceContainerHigh)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .overlay(alignment: .topTrailing) {
            if !enabled {
                Text("Paste lyrics first")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(t.onSurfaceVariant)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(t.surfaceContainerHigh)
                    .cornerRadius(4)
                    .offset(x: -4, y: -10)
            }
        }
    }

    // MARK: Player Section

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepLabel("3", "Preview")

            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(t.surfaceContainer).frame(height: 4)
                        Capsule().fill(t.primary)
                            .frame(width: vm.duration > 0 ? geo.size.width * CGFloat(vm.currentTime / vm.duration) : 0, height: 4)
                    }
                    .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 20)))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        vm.seek(to: max(0, min(1, v.location.x / geo.size.width)) * vm.duration)
                    })
                }
                .frame(height: 20)

                HStack {
                    Text(timeString(vm.currentTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)
                    Spacer()
                    Button { vm.togglePlayback() } label: {
                        Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(t.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(timeString(vm.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.onSurfaceVariant)
                }
            }
            .padding(14)
            .background(t.surfaceContainerHigh)
            .cornerRadius(12)
        }
    }

    // MARK: Sync Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepLabel("2", vm.phase == .manualSync ? "Mark Lines" : "Sync")

            switch vm.phase {
            case .manualSync:
                manualSyncControls

            case .review:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(t.primary)
                        Text("Synced — \(vm.lrcLines.count) lines")
                            .font(.system(size: 13))
                            .foregroundStyle(t.onSurface)
                        Spacer()
                    }
                    Button { vm.startManualRefine() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill").font(.system(size: 12))
                            Text("Refine timestamps manually")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(t.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(t.surfaceContainer)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Walk through each line again, tapping when the singer hits it. Save adds a 300 ms read-ahead so the lyric appears slightly before the vocal.")
                }
                .padding(14)
                .background(t.primaryContainer.opacity(0.12))
                .cornerRadius(12)

            default:
                let enabled = vm.phase == .trackSelected
                VStack(spacing: 8) {
                    Button { vm.startManualSync() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill").font(.system(size: 15))
                            Text("Manual Sync").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(enabled ? t.onPrimary : t.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(enabled ? t.primary : t.surfaceContainerHigh)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)

                    HStack(spacing: 5) {
                        Image(systemName: "hand.tap").font(.system(size: 10)).foregroundStyle(t.primary)
                        Text("Record timestamps manually in real-time as the song plays.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(t.onSurfaceVariant)
                        Spacer()
                    }
                }
            }
        }
    }

    /// Player-style controls shown during manual sync.
    private var manualSyncControls: some View {
        VStack(spacing: 12) {
            // Compact transport: time · play/pause · scrubber
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(t.surfaceContainer).frame(height: 4)
                    Capsule().fill(t.primary)
                        .frame(width: vm.duration > 0 ? geo.size.width * CGFloat(vm.currentTime / vm.duration) : 0, height: 4)
                }
                .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 20)))
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    vm.seek(to: max(0, min(1, v.location.x / geo.size.width)) * vm.duration)
                })
            }
            .frame(height: 20)

            HStack {
                Text(timeString(vm.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant)
                Spacer()
                Button { vm.togglePlayback() } label: {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(t.primary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(timeString(vm.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.onSurfaceVariant)
            }

            // The big mark button — captures the current playback time for the
            // cursor line and advances. Disabled when there's nothing left to mark.
            let canMark = vm.manualCursor < vm.lrcLines.count
            Button { vm.markCurrentLine() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 15))
                    Text(canMark
                         ? "Mark line \(vm.manualCursor + 1) at \(timeString(vm.currentTime))"
                         : "All lines stamped")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(canMark ? t.onPrimary : t.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canMark ? t.primary : t.surfaceContainerHigh)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(!canMark)
            .keyboardShortcut(.space, modifiers: [])

            HStack(spacing: 8) {
                Button { vm.cancelManualSync() } label: {
                    Text("Back")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(t.surfaceContainerHigh)
                        .foregroundStyle(t.onSurface)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                if vm.manualCursor > 0 && vm.manualCursor <= vm.lrcLines.count {
                    Button {
                        vm.manualCursor = max(0, vm.manualCursor - 1)
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(t.surfaceContainerHigh)
                            .foregroundStyle(t.onSurface)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    // User wants to finish early or has stamped everything — flip to review so they can save.
                    if vm.isPlaying { vm.togglePlayback() }
                    // Save sync data to DB — capture the raw manual timestamps as baseline
                    vm.originalLrcLines = vm.lrcLines.map { LRCLine(timestamp: $0.timestamp, text: $0.text) }
                    vm.saveSyncData(method: "manual")
                    vm.preRollMs = 0
                    vm.appliedGlobalOffsetMs = 0
                    vm.phase = .review
                } label: {
                    Label("Finish", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(t.primary)
                        .foregroundStyle(t.onPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(t.surfaceContainerHigh)
        .cornerRadius(12)
    }

    // MARK: Fine-tune Toggle

    private var fineTuneToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.showFineTune.toggle()
                if vm.showFineTune {
                    // Restore saved slider position from DB when opening Fine-tune
                    vm.loadSyncData()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13))
                Text("Fine-tune Timestamps")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: vm.showFineTune ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(t.onSurface)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(t.surfaceContainerHigh)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Pre-roll Section

    private var preRollSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepLabel("4", "Fine-tune")

            VStack(spacing: 10) {
                HStack {
                    Text("Pre-roll Offset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(t.onSurface)
                    Spacer()
                    Text("\(Int(vm.preRollMs)) ms")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(t.primary)
                        .frame(width: 64, alignment: .trailing)
                }

                Slider(value: Binding(
                    get: { -vm.preRollMs },
                    set: { vm.preRollMs = -$0 }
                ), in: 0...1000, step: 10)
                    .tint(t.primary)

                HStack {
                    Text("0").font(.system(size: 10, design: .monospaced)).foregroundStyle(t.onSurfaceVariant)
                    Spacer()
                    Text("−1000 ms").font(.system(size: 10, design: .monospaced)).foregroundStyle(t.onSurfaceVariant)
                }

                HStack(spacing: 8) {
                    Button {
                        // Apply offset relative to original timestamps
                        let offsetSec = vm.preRollMs / 1000.0
                        for i in 0..<vm.lrcLines.count {
                            let origTs = i < vm.originalLrcLines.count ? vm.originalLrcLines[i].timestamp : vm.lrcLines[i].timestamp
                            vm.lrcLines[i].timestamp = max(0, origTs + offsetSec)
                        }
                        vm.appliedGlobalOffsetMs = vm.preRollMs
                    } label: {
                        Text("Apply Globally")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(t.primary)
                            .foregroundStyle(t.onPrimary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if let idx = activeIndex, vm.lrcLines.indices.contains(idx) {
                            let origTs = idx < vm.originalLrcLines.count ? vm.originalLrcLines[idx].timestamp : vm.lrcLines[idx].timestamp
                            let offsetSec = vm.preRollMs / 1000.0
                            vm.lrcLines[idx].timestamp = max(0, origTs + offsetSec)
                            vm.appliedIndividualOffsets[vm.lrcLines[idx].id] = vm.preRollMs
                        }
                    } label: {
                        Text("Apply to Active Line")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(t.surfaceContainerHigh)
                            .foregroundStyle(t.onSurface)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.onSurface.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(t.surfaceContainerHigh)
            .cornerRadius(12)
        }
    }

    // MARK: Save

    private var saveButton: some View {
        Button {
            if vm.save() {
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.fill")
                Text("Save & Link to Library").font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(t.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(t.primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func stepLabel(_ number: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text(number)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(t.onPrimary)
                .frame(width: 18, height: 18)
                .background(t.primary.opacity(0.8))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(t.onSurfaceVariant)
                .tracking(0.5)
        }
    }

    private func pickTrack() {
        showTrackPicker = true
    }

    private func importLRC() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let lrc = UTType(filenameExtension: "lrc") { panel.allowedContentTypes = [lrc] }
        panel.message = "Select an existing .lrc file to edit or re-sync"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            let parsed = LRCParser.parse(content)
            if !parsed.isEmpty {
                vm.lrcLines = parsed
                vm.rawText = parsed.map { $0.text }.joined(separator: "\n")
                if vm.selectedURL != nil { vm.phase = .review }
            } else {
                vm.rawText = content
            }
        }
    }

    private func timeString(_ s: Double) -> String {
        let v = max(s, 0)
        return String(format: "%d:%02d", Int(v) / 60, Int(v) % 60)
    }

    private func durationString(_ s: Double) -> String {
        guard s > 0 else { return "--:--" }
        return timeString(s)
    }
}

// MARK: - LRC Line Row

private struct LRCEditorRow: View {
    let line: LRCLine
    let isActive: Bool
    let isNudging: Bool
    let theme: Theme
    let onSeek: () -> Void
    let onToggleNudge: () -> Void
    let onDelta: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(stampString(line.timestamp))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isActive ? theme.onPrimary : theme.primary.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isActive ? theme.primary : theme.primaryContainer.opacity(0.18))
                    .cornerRadius(5)
                    .onTapGesture(count: 2) { onToggleNudge() }
                    .help("Double-click to nudge timestamp")

                Text(line.text.isEmpty ? "♪" : line.text)
                    .font(.system(size: isActive ? 14 : 13, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? theme.onSurface : theme.onSurface.opacity(0.6))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isActive ? theme.surfaceContainer : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { onSeek() }

            if isNudging {
                HStack(spacing: 5) {
                    ForEach([(-0.5, "−500"), (-0.1, "−100"), (-0.05, "−50"), (0.05, "+50"), (0.1, "+100"), (0.5, "+500")], id: \.1) { delta, label in
                        Button {
                            onDelta(delta)
                        } label: {
                            Text("\(label)ms")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(delta < 0 ? Color.red : theme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(delta < 0 ? Color.red.opacity(0.1) : theme.primaryContainer.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Button { onToggleNudge() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.onSurfaceVariant)
                            .frame(width: 18, height: 18)
                            .background(theme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isNudging)
    }

    private func stampString(_ t: TimeInterval) -> String {
        let cs = Int(max(t, 0) * 100)
        return String(format: "%d:%02d.%02d", cs / 6000, (cs % 6000) / 100, cs % 100)
    }
}
