# Master Equalizer Implementation Guide

This document contains the complete, production-ready source code for a 6-band graphical equalizer built using **SwiftUI** and **AVFoundation**.

## 1. The Core Logic (Presets & Audio Engine)
The implementation uses a Singleton pattern for the audio engine to ensure that the hardware resources are managed efficiently.

```swift
import AVFoundation
import Combine
import SwiftUI

// MARK: - Preset Definitions
enum EQPreset: String, CaseIterable {
    case acoustic, classical, dance, deep, electronic, hipHop, increaseBass, jazz, pop, rb, rock, vocalBooster, reducedBass, piano, custom, off
    
    var displayName: String {
        switch self {
        case .hipHop: return "Hip-Hop"
        case .rb: return "R&B"
        case .increaseBass: return "Increase Bass"
        case .reducedBass: return "Reduced Bass"
        case .vocalBooster: return "Vocal Booster"
        default: return rawValue.capitalized
        }
    }
    
    var targetGains: [Float] {
        switch self {
        case .off, .custom: return [0, 0, 0, 0, 0, 0]
        case .acoustic:     return [4, 2, 1, 3, 4, 3]
        case .classical:    return [5, 4, 0, 0, 4, 5]
        case .dance:        return [6, 4, 1, 3, 5, 4]
        case .deep:         return [6, 3, -1, -4, -2, -3]
        case .electronic:   return [5, 4, -1, 2, 5, 4]
        case .hipHop:       return [7, 5, 0, 1, 3, 4]
        case .increaseBass: return [8, 6, 1, 0, 0, 0]
        case .jazz:         return [4, 3, 1, 3, 2, 4]
        case .pop:          return [-1, 2, 5, 5, 3, -1]
        case .rb:           return [4, 5, -1, -2, 3, 4]
        case .rock:         return [5, 4, -2, 2, 4, 5]
        case .vocalBooster: return [-2, 0, 3, 6, 4, 1]
        case .reducedBass:  return [-8, -6, -1, 0, 0, 0]
        case .piano:        return [3, 2, 0, 3, 4, 3]
        }
    }
}

// MARK: - Audio Manager
class AudioEngineManager {
    static let shared = AudioEngineManager()
    
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let eqNode = AVAudioUnitEQ(numberOfBands: 6)
    let frequencies: [Float] = [32, 125, 500, 2000, 8000, 16000]
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(player)
        engine.attach(eqNode)
        
        for (index, freq) in frequencies.enumerated() {
            let band = eqNode.bands[index]
            band.filterType = .peaking
            band.frequency = freq
            band.bandwidth = 0.5
            band.gain = 0.0
            band.bypass = false
        }
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: eqNode, format: format)
        engine.connect(eqNode, to: engine.mainMixerNode, format: format)
        
        try? engine.start()
    }
    
    func setGain(for index: Int, gain: Float) {
        eqNode.bands[index].gain = gain
    }
    
    func setBypass(_ bypassed: Bool) {
        eqNode.bypass = bypassed
    }
}

// MARK: - View Model
class EqualizerViewModel: ObservableObject {
    @Published var activePreset: EQPreset = .off
    @Published var gains: [Float] = Array(repeating: 0.0, count: 6)
    
    private let audioManager = AudioEngineManager.shared
    let bandLabels = ["Sub Bass", "Mid Bass", "Low Mid", "Up Mid", "Treble", "High"]
    
    func selectPreset(_ preset: EQPreset) {
        activePreset = preset
        if preset == .off {
            audioManager.setBypass(true)
            animateGains(to: Array(repeating: 0.0, count: 6))
        } else {
            audioManager.setBypass(false)
            if preset != .custom {
                animateGains(to: preset.targetGains)
            }
        }
    }
    
    func userDidDragSlider(index: Int, newValue: Float) {
        if activePreset == .off {
            audioManager.setBypass(false)
            activePreset = .custom
        } else if activePreset != .custom {
            activePreset = .custom
        }
        gains[index] = newValue
        audioManager.setGain(for: index, gain: newValue)
    }
    
    private func animateGains(to newGains: [Float]) {
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
            self.gains = newGains
        }
        for (i, gain) in newGains.enumerated() {
            audioManager.setGain(for: i, gain: gain)
        }
    }
}
```

## 2. The User Interface (Graph & View)
This section handles the visualization of the frequency response and the layout of the sliders and preset buttons.

```swift
// MARK: - Frequency Response Curve
struct DynamicEQGraph: View {
    var gains: [Float]
    let maxGain: Float = 24.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let midY = height / 2
                    
                    let points: [CGPoint] = gains.enumerated().map { i, gain in
                        let x = CGFloat(i) * (width / CGFloat(max(1, gains.count - 1)))
                        let normalizedGain = CGFloat(gain) / CGFloat(maxGain)
                        let y = midY - (normalizedGain * midY)
                        return CGPoint(x: x, y: y)
                    }
                    
                    if points.isEmpty { return }
                    path.move(to: points[0])
                    
                    for i in 0..<points.count - 1 {
                        let p1 = points[i]
                        let p2 = points[i+1]
                        let midX = (p1.x + p2.x) / 2
                        let control1 = CGPoint(x: midX, y: p1.y)
                        let control2 = CGPoint(x: midX, y: p2.y)
                        path.addCurve(to: p2, control1: control1, control2: control2)
                    }
                }
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [.blue, .purple, .pink]), startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .purple.opacity(0.4), radius: 5, y: 3)
            }
        }
        .frame(height: 180)
        .padding()
        .background(Color.black.opacity(0.03))
        .cornerRadius(16)
    }
}

// MARK: - Master View
struct EqualizerMasterView: View {
    @StateObject private var vm = EqualizerViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Pro Equalizer").font(.system(.title2, design: .rounded).bold()).padding(.top)
            
            DynamicEQGraph(gains: vm.gains).padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EQPreset.allCases, id: \.self) { preset in
                        Button(action: { vm.selectPreset(preset) }) {
                            Text(preset.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(vm.activePreset == preset ? Color.blue : Color.gray.opacity(0.15))
                                .foregroundColor(vm.activePreset == preset ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }.padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                ForEach(0..<6) { i in
                    VStack(spacing: 15) {
                        Text("\(vm.gains[i] > 0 ? "+" : "")\(Int(vm.gains[i]))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geo in
                            Slider(value: Binding(get: { vm.gains[i] }, set: { vm.userDidDragSlider(index: i, newValue: $0) }), in: -24...24)
                                .rotationEffect(.degrees(-90))
                                .frame(width: geo.size.height, height: geo.size.width)
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        }.frame(width: 40, height: 200)
                        
                        Text(vm.bandLabels[i]).font(.system(size: 10, weight: .bold)).multilineTextAlignment(.center).frame(height: 30)
                    }.frame(maxWidth: .infinity)
                }
            }.padding(.horizontal).opacity(vm.activePreset == .off ? 0.3 : 1.0)
            
            Spacer()
        }
    }
}
```

## 3. Deployment Notes
* **Audio Session**: Remember to set your `AVAudioSession` to `.playback` in your `App` entry point.
* **Range**: The sliders are calibrated for +/- 24dB, providing professional-level control over the spectrum.
* **Custom Integration**: To play your own audio, use `AudioEngineManager.shared.player` to schedule files or buffers.

---
*Created for Antigravity.*
