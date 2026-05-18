import Foundation
import Observation



@MainActor
@Observable
final class LyricsSettings {
    static let shared = LyricsSettings()

    var preRollOffsetMs: Double {
        didSet { UserDefaults.standard.set(preRollOffsetMs, forKey: "lyrics.preRollOffsetMs") }
    }

    private init() {
        let stored = UserDefaults.standard.double(forKey: "lyrics.preRollOffsetMs")
        preRollOffsetMs = stored == 0 ? -300 : stored
    }
}
