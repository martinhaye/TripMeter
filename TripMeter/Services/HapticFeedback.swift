import AudioToolbox
import CoreHaptics
import UIKit

enum HapticFeedback {
    private static let keyTapImpact: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()

    private static let lightImpact: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()

    /// Retains the engine/player until the pattern finishes (locals alone can cut haptics short).
    private static var activeSavePulse: (engine: CHHapticEngine, player: CHHapticPatternPlayer)?

    private struct PulseBeat {
        let time: TimeInterval
        let intensity: Float
        let sharpness: Float
    }

    private struct SavePulsePattern {
        let cycleDuration: TimeInterval
        let beats: [PulseBeat]
    }

    private enum PatternFitMode: CaseIterable {
        case repeatToFit
        case stretchToFit
        case pingPongToFit
    }

    /// Twenty deliberate rhythms. Values stay fairly strong so each shape reads clearly.
    private static let savePulsePatterns: [SavePulsePattern] = [
        // Heartbeat
        .init(cycleDuration: 0.72, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.30),
            .init(time: 0.16, intensity: 0.78, sharpness: 0.55),
        ]),
        // Gallop
        .init(cycleDuration: 0.90, beats: [
            .init(time: 0, intensity: 0.68, sharpness: 0.45),
            .init(time: 0.14, intensity: 0.82, sharpness: 0.60),
            .init(time: 0.34, intensity: 1.00, sharpness: 0.80),
        ]),
        // Knock, pause, knock-knock
        .init(cycleDuration: 1.05, beats: [
            .init(time: 0, intensity: 0.95, sharpness: 0.30),
            .init(time: 0.12, intensity: 0.72, sharpness: 0.35),
            .init(time: 0.58, intensity: 0.92, sharpness: 0.65),
            .init(time: 0.72, intensity: 0.92, sharpness: 0.65),
        ]),
        // Upbeat triplet
        .init(cycleDuration: 0.80, beats: [
            .init(time: 0, intensity: 0.70, sharpness: 0.35),
            .init(time: 0.28, intensity: 0.84, sharpness: 0.60),
            .init(time: 0.42, intensity: 1.00, sharpness: 0.90),
        ]),
        // Four-corner
        .init(cycleDuration: 1.15, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.75),
            .init(time: 0.18, intensity: 0.72, sharpness: 0.35),
            .init(time: 0.36, intensity: 0.72, sharpness: 0.35),
            .init(time: 0.78, intensity: 0.94, sharpness: 0.75),
        ]),
        // Quick double with an echo
        .init(cycleDuration: 0.95, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.85),
            .init(time: 0.10, intensity: 0.88, sharpness: 0.80),
            .init(time: 0.20, intensity: 0.76, sharpness: 0.70),
            .init(time: 0.62, intensity: 0.66, sharpness: 0.25),
        ]),
        // Steady five
        .init(cycleDuration: 1.20, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.50),
            .init(time: 0.24, intensity: 0.72, sharpness: 0.50),
            .init(time: 0.48, intensity: 0.84, sharpness: 0.50),
            .init(time: 0.72, intensity: 0.72, sharpness: 0.50),
            .init(time: 0.96, intensity: 1.00, sharpness: 0.50),
        ]),
        // Late flurry
        .init(cycleDuration: 0.82, beats: [
            .init(time: 0, intensity: 0.92, sharpness: 0.30),
            .init(time: 0.32, intensity: 0.68, sharpness: 0.55),
            .init(time: 0.46, intensity: 0.84, sharpness: 0.72),
            .init(time: 0.60, intensity: 1.00, sharpness: 0.92),
        ]),
        // Two pairs
        .init(cycleDuration: 1.10, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.65),
            .init(time: 0.12, intensity: 0.76, sharpness: 0.40),
            .init(time: 0.24, intensity: 0.88, sharpness: 0.55),
            .init(time: 0.68, intensity: 0.76, sharpness: 0.40),
            .init(time: 0.84, intensity: 1.00, sharpness: 0.75),
        ]),
        // Strong-soft-strong
        .init(cycleDuration: 0.90, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.25),
            .init(time: 0.18, intensity: 0.66, sharpness: 0.80),
            .init(time: 0.54, intensity: 1.00, sharpness: 0.55),
        ]),
        // Rolling six
        .init(cycleDuration: 1.25, beats: [
            .init(time: 0, intensity: 0.68, sharpness: 0.30),
            .init(time: 0.16, intensity: 0.76, sharpness: 0.40),
            .init(time: 0.32, intensity: 0.86, sharpness: 0.50),
            .init(time: 0.72, intensity: 0.78, sharpness: 0.60),
            .init(time: 0.88, intensity: 0.88, sharpness: 0.72),
            .init(time: 1.04, intensity: 1.00, sharpness: 0.90),
        ]),
        // Machine burst
        .init(cycleDuration: 0.76, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.95),
            .init(time: 0.12, intensity: 0.76, sharpness: 0.90),
            .init(time: 0.24, intensity: 0.88, sharpness: 0.90),
            .init(time: 0.36, intensity: 0.70, sharpness: 0.85),
        ]),
        // Pause then three
        .init(cycleDuration: 1.00, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.35),
            .init(time: 0.40, intensity: 0.68, sharpness: 0.60),
            .init(time: 0.52, intensity: 0.84, sharpness: 0.72),
            .init(time: 0.64, intensity: 1.00, sharpness: 0.85),
        ]),
        // March with a finale
        .init(cycleDuration: 1.18, beats: [
            .init(time: 0, intensity: 0.94, sharpness: 0.40),
            .init(time: 0.20, intensity: 0.72, sharpness: 0.40),
            .init(time: 0.40, intensity: 0.94, sharpness: 0.40),
            .init(time: 0.60, intensity: 0.72, sharpness: 0.40),
            .init(time: 0.98, intensity: 1.00, sharpness: 0.82),
        ]),
        // Bookended doubles
        .init(cycleDuration: 0.88, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.75),
            .init(time: 0.10, intensity: 0.78, sharpness: 0.55),
            .init(time: 0.44, intensity: 0.78, sharpness: 0.55),
            .init(time: 0.54, intensity: 1.00, sharpness: 0.75),
        ]),
        // Long roll
        .init(cycleDuration: 1.30, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.25),
            .init(time: 0.14, intensity: 0.82, sharpness: 0.35),
            .init(time: 0.28, intensity: 0.70, sharpness: 0.45),
            .init(time: 0.42, intensity: 0.82, sharpness: 0.55),
            .init(time: 0.82, intensity: 0.90, sharpness: 0.72),
            .init(time: 1.10, intensity: 1.00, sharpness: 0.90),
        ]),
        // Rising quarters
        .init(cycleDuration: 1.05, beats: [
            .init(time: 0, intensity: 0.68, sharpness: 0.30),
            .init(time: 0.26, intensity: 0.78, sharpness: 0.48),
            .init(time: 0.52, intensity: 0.88, sharpness: 0.66),
            .init(time: 0.78, intensity: 1.00, sharpness: 0.88),
        ]),
        // Stutter and answer
        .init(cycleDuration: 0.92, beats: [
            .init(time: 0, intensity: 0.88, sharpness: 0.90),
            .init(time: 0.11, intensity: 0.72, sharpness: 0.85),
            .init(time: 0.22, intensity: 0.88, sharpness: 0.90),
            .init(time: 0.52, intensity: 1.00, sharpness: 0.35),
            .init(time: 0.74, intensity: 0.84, sharpness: 0.55),
        ]),
        // Alternating weight
        .init(cycleDuration: 1.22, beats: [
            .init(time: 0, intensity: 1.00, sharpness: 0.25),
            .init(time: 0.30, intensity: 0.68, sharpness: 0.90),
            .init(time: 0.44, intensity: 0.94, sharpness: 0.30),
            .init(time: 0.74, intensity: 0.68, sharpness: 0.90),
            .init(time: 0.88, intensity: 1.00, sharpness: 0.35),
        ]),
        // Accelerating ladder
        .init(cycleDuration: 1.00, beats: [
            .init(time: 0, intensity: 0.68, sharpness: 0.35),
            .init(time: 0.15, intensity: 0.74, sharpness: 0.45),
            .init(time: 0.30, intensity: 0.80, sharpness: 0.55),
            .init(time: 0.45, intensity: 0.88, sharpness: 0.65),
            .init(time: 0.60, intensity: 0.94, sharpness: 0.78),
            .init(time: 0.75, intensity: 1.00, sharpness: 0.92),
        ]),
    ]

    /// Plays one authored rhythm, fitted to the selected duration in one of three ways.
    static func savePulse() {
        let duration = Self.randomSavePulseDuration()

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            playUnavailableFallback()
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()

            let selectedPattern = savePulsePatterns.randomElement()!
            let fitMode = PatternFitMode.allCases.randomElement()!
            let events = fittedBeats(
                from: selectedPattern,
                duration: duration,
                mode: fitMode
            ).map { time, beat in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: beat.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.sharpness),
                    ],
                    relativeTime: time
                )
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            activeSavePulse = (engine, player)
            try player.start(atTime: CHHapticTimeImmediate)

            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
                engine.stop(completionHandler: nil)
                if activeSavePulse?.engine === engine {
                    activeSavePulse = nil
                }
            }
        } catch {
            playUnavailableFallback()
        }
    }

    static func keyTap() {
        keyTapImpact.impactOccurred(intensity: 0.6)
        keyTapImpact.prepare()
    }

    /// Gentle chime plus two quick taps — capture idle lock reminder.
    static func lockScreenReminder() {
        AudioServicesPlaySystemSound(1057)
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.75)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            lightImpact.impactOccurred(intensity: 0.75)
        }
    }

    /// Whole-second durations weighted toward shorter patterns:
    /// 1s: 30%, 2s: 23%, 3s: 20%, 4s: 17%, 5s: 10%.
    private static func randomSavePulseDuration() -> Double {
        switch Int.random(in: 0..<100) {
        case 0..<30: 1
        case 30..<53: 2
        case 53..<73: 3
        case 73..<90: 4
        default: 5
        }
    }

    private static func fittedBeats(
        from pattern: SavePulsePattern,
        duration: Double,
        mode: PatternFitMode
    ) -> [(TimeInterval, PulseBeat)] {
        switch mode {
        case .stretchToFit:
            let patternSpan = max(pattern.beats.map(\.time).max() ?? 0, 0.01)
            let targetSpan = duration * 0.92
            return pattern.beats.map { beat in
                (beat.time / patternSpan * targetSpan, beat)
            }

        case .repeatToFit, .pingPongToFit:
            let pingPong = mode == .pingPongToFit
            let patternSpan = pattern.beats.map(\.time).max() ?? 0
            var result: [(TimeInterval, PulseBeat)] = []
            var cycleStart: TimeInterval = 0
            var cycleIndex = 0

            while cycleStart < duration {
                let reverse = pingPong && cycleIndex.isMultiple(of: 2) == false
                for beat in pattern.beats {
                    let localTime = reverse ? patternSpan - beat.time : beat.time
                    let eventTime = cycleStart + localTime
                    if eventTime < duration {
                        result.append((eventTime, beat))
                    }
                }
                cycleStart += pattern.cycleDuration
                cycleIndex += 1
            }
            return result.sorted { $0.0 < $1.0 }
        }
    }

    private static func playUnavailableFallback() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
