import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Preset Definitions
enum EQPreset: String, CaseIterable {
    case off, acoustic, classical, dance, deep, electronic, harman, hipHop, increaseBass, jazz, piano, pop, rb, reducedBass, rock, vocalBooster, custom
    
    var displayName: String {
        switch self {
        case .harman: return "Harman Curve"
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
        case .harman:       return [6.0, 3.5, -1.0, 1.5, 3.0, 1.0]
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

// MARK: - View Model
@MainActor
class EqualizerViewModel: ObservableObject {
    @Published var activePreset: EQPreset = .off {
        didSet {
            UserDefaults.standard.set(activePreset.rawValue, forKey: "EQActivePreset")
            applyPreset(activePreset)
        }
    }
    
    @Published var gains: [Float] = Array(repeating: 0.0, count: 6) {
        didSet {
            UserDefaults.standard.set(gains, forKey: "EQGains")
            AudioEngine.shared.setEQGains(gains)
        }
    }
    
    let bandLabels = ["Sub Bass", "Mid Bass", "Low Mid", "Up Mid", "Treble", "High"]
    
    init() {
        let savedPresetRaw = UserDefaults.standard.string(forKey: "EQActivePreset") ?? EQPreset.off.rawValue
        let preset = EQPreset(rawValue: savedPresetRaw) ?? .off
        self.activePreset = preset
        
        let savedGains = UserDefaults.standard.array(forKey: "EQGains") as? [Float] ?? Array(repeating: 0.0, count: 6)
        self.gains = savedGains
        
        // Apply immediately
        AudioEngine.shared.setEQGains(savedGains)
        applyPreset(preset)
    }
    
    private func applyPreset(_ preset: EQPreset) {
        if preset == .off {
            AudioEngine.shared.useEQEngine = false
        } else {
            AudioEngine.shared.useEQEngine = true
        }
    }
    
    func selectPreset(_ preset: EQPreset) {
        activePreset = preset
        if preset == .off {
            animateGains(to: Array(repeating: 0.0, count: 6))
        } else {
            if preset != .custom {
                animateGains(to: preset.targetGains)
            }
        }
    }
    
    func userDidDragSlider(index: Int, newValue: Float) {
        if activePreset == .off {
            AudioEngine.shared.useEQEngine = true
            activePreset = .custom
        } else if activePreset != .custom {
            activePreset = .custom
        }
        gains[index] = newValue
    }
    
    private func animateGains(to newGains: [Float]) {
        withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
            self.gains = newGains
        }
    }
}

// MARK: - Frequency Response Curve
struct DynamicEQGraph: View {
    var gains: [Float]
    var themePrimary: Color
    let maxGain: Float = 24.0
    let bandLabels = ["Sub Bass", "Mid Bass", "Low Mid", "Up Mid", "Treble", "High"]
    
    var body: some View {
        HStack(spacing: 8) {
            // Y-Axis Labels (Decibels)
            VStack(alignment: .trailing) {
                Text("+24dB").font(.system(size: 9)).foregroundColor(.secondary)
                Spacer()
                Text("+12dB").font(.system(size: 9)).foregroundColor(.secondary)
                Spacer()
                Text("0dB").font(.system(size: 9)).foregroundColor(.secondary)
                Spacer()
                Text("-12dB").font(.system(size: 9)).foregroundColor(.secondary)
                Spacer()
                Text("-24dB").font(.system(size: 9)).foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let midY = height / 2
                    
                    ZStack {
                        // Vertical frequency lines
                        ForEach(0..<gains.count, id: \.self) { i in
                            let x = CGFloat(i) * (width / CGFloat(max(1, gains.count - 1)))
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: height))
                            }
                            .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                        
                        // Horizontal Gain Lines (+12dB, 0dB, -12dB)
                        ForEach([0.25, 0.5, 0.75], id: \.self) { multiplier in
                            let y = height * multiplier
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                            .stroke(
                                Color.gray.opacity(multiplier == 0.5 ? 0.3 : 0.15),
                                style: StrokeStyle(lineWidth: 1, dash: multiplier == 0.5 ? [5] : [4])
                            )
                        }
                        
                        // EQ Curve
                        Path { path in
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
                            LinearGradient(gradient: Gradient(colors: [themePrimary.opacity(0.7), themePrimary, themePrimary.opacity(0.7)]), startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: themePrimary.opacity(0.4), radius: 5, y: 3)
                    }
                }
                .frame(height: 180)
                
                // X-Axis Labels (Band Names)
                HStack {
                    ForEach(0..<bandLabels.count, id: \.self) { i in
                        Text(bandLabels[i])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Master View
struct EqualizerMasterView: View {
    @StateObject private var vm = EqualizerViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var themeManager = ThemeManager.shared
    
    private var t: Theme { Theme(scheme: colorScheme) }
    
    var body: some View {
        VStack(spacing: 24) {
            DynamicEQGraph(gains: vm.gains, themePrimary: t.primary).padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EQPreset.allCases, id: \.self) { preset in
                        Button(action: { vm.selectPreset(preset) }) {
                            Text(preset.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(vm.activePreset == preset ? t.primary : t.surfaceContainerHigh)
                                .foregroundColor(vm.activePreset == preset ? t.onPrimary : t.onSurface)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
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
                            Slider(value: Binding(get: { vm.gains[i] }, set: { vm.userDidDragSlider(index: i, newValue: $0) }), in: -24.0...24.0)
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
