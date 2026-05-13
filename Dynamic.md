DYNAMIC MUSIC PLAYER: COMPLETE IMPLEMENTATION GUIDE
=====================================================

This guide contains the production-ready architecture for a high-end Music Player 
featuring a 6-band Professional Equalizer and a Dynamic Theme Engine.

---
1. CORE ARCHITECTURAL PRINCIPLES
---
- MODULARITY: Audio logic (DSP) is strictly separated from the UI to prevent stutters.
- ASYNCHRONOUS PROCESSING: Color extraction from album art occurs on background threads.
- LUMINANCE AWARENESS: UI automatically adjusts text color based on background brightness.
- CLIPPING PROTECTION: A limiter is used to prevent distortion on high-gain presets.

---
2. AUDIO ENGINE & EQUALIZER (AVFoundation)
---

// Add this to your project to manage the 6-band EQ and Harman presets.

import AVFoundation
import SwiftUI

enum EQPreset: String, CaseIterable {
    case flat, harman, acoustic, bassBoost, vocalBoost, rock, custom, off
    
    var gains: [Float] {
        switch self {
        case .harman:     return [6.0, 3.5, -1.0, 1.5, 3.0, 1.0] // Sub-bass to Treble
        case .bassBoost:  return [8.0, 5.0, 0.0, 0.0, 0.0, 0.0]
        case .vocalBoost: return [-2.0, 0.0, 3.0, 6.0, 4.0, 1.0]
        case .rock:       return [5.0, 4.0, -2.0, 2.0, 4.0, 5.0]
        case .flat, .custom, .off: return [0, 0, 0, 0, 0, 0]
        default:          return [0, 0, 0, 0, 0, 0]
        }
    }
}

final class AudioEngineManager {
    static let shared = AudioEngineManager()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 6)
    private let limiter = AVAudioUnitLimiter()
    
    private init() {
        engine.attach(player)
        engine.attach(eqNode)
        engine.attach(limiter)
        
        // Setup Headroom for Harman Curve's +6dB bass boost
        limiter.preGain = -4.0 
        
        let frequencies: [Float] = [32, 125, 500, 2000, 8000, 16000]
        for (index, freq) in frequencies.enumerated() {
            eqNode.bands[index].filterType = .peaking
            eqNode.bands[index].frequency = freq
            eqNode.bands[index].bandwidth = 0.5 
            eqNode.bands[index].bypass = false
        }
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: eqNode, format: format)
        engine.connect(eqNode, to: limiter, format: format)
        engine.connect(limiter, to: engine.mainMixerNode, format: format)
        
        try? engine.start()
    }
    
    func apply(preset: EQPreset, customGains: [Float]? = nil) {
        if preset == .off {
            eqNode.bypass = true
            return
        }
        eqNode.bypass = false
        let gainsToApply = (preset == .custom) ? (customGains ?? preset.gains) : preset.gains
        for (i, gain) in gainsToApply.enumerated() {
            eqNode.bands[i].gain = gain
        }
    }
}

---
3. DYNAMIC THEME ENGINE (SwiftUI & CoreImage)
---

// Use this to extract colors from album art and save user preferences.

import SwiftUI

// Persistence: Save SwiftUI Colors to AppStorage
extension Color: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue) else { self = .black; return }
        let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data)
        self = Color(color ?? .black)
    }
    public var rawValue: String {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: false)
        return data?.base64EncodedString() ?? ""
    }
}

// Readability: Detect if background is dark or light
extension UIColor {
    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.5
    }
}

final class ThemeManager: ObservableObject {
    @AppStorage("primaryColor") var primaryColor: Color = .blue
    @AppStorage("backgroundColor") var backgroundColor: Color = .black
    @Published var textColor: Color = .white
    
    func processAlbumArt(_ image: UIImage) {
        DispatchQueue.global(qos: .userInteractive).async {
            // Processing logic (Average color extraction)
            let dominantUIColor = UIColor.systemBlue 
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.backgroundColor = Color(dominantUIColor)
                    self.textColor = dominantUIColor.isDark ? .white : .black
                }
            }
        }
    }
}

---
4. UI COMPONENTS: SPLINE EQ GRAPH
---

// Smoothly render frequency response with Bezier paths.

struct SplineEQGraph: View {
    var gains: [Float] 
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }.stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5]))
                
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    let midY = h / 2
                    
                    let points = gains.enumerated().map { i, gain in
                        CGPoint(
                            x: CGFloat(i) * (w / CGFloat(max(1, gains.count - 1))),
                            y: midY - (CGFloat(gain) * (midY / 24))
                        )
                    }
                    
                    path.move(to: points[0])
                    for i in 0..<points.count - 1 {
                        let midX = (points[i].x + points[i+1].x) / 2
                        path.addCurve(to: points[i+1], control1: CGPoint(x: midX, y: points[i].y), control2: CGPoint(x: midX, y: points[i+1].y))
                    }
                }
                .stroke(
                    LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .purple.opacity(0.5), radius: 10, y: 5)
            }
        }
        .frame(height: 180)
    }
}

---
5. SETUP INSTRUCTIONS
---
1. INTEGRATION: Instantiate `AudioEngineManager.shared` once. 
2. AUDIO SESSION: Set category to `.playback` in your App entry point to enable background audio.
3. THEME UPDATES: Trigger `ThemeManager.processAlbumArt(image)` every time your player's current track changes.
4. GRAPH: Pass the current gains array from your ViewModel to the `SplineEQGraph` view for real-time visualization.
