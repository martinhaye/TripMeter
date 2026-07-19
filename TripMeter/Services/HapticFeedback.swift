import AudioToolbox
import CoreHaptics
import UIKit

enum HapticFeedback {
    private static let softImpact: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .soft)
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

    /// Interesting multi-second pulse: continuous swell plus a few spaced hits at varied intensity.
    static func savePulse() {
        let duration = Double.random(in: 0.5...1.5)
        let hitCount = Int.random(in: 3...5)
        let intensities = (0..<hitCount).map { _ in Float.random(in: 0.25...1.0) }
        let times = Self.spacedEventTimes(count: hitCount, duration: duration)

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            playImpactFallback(intensities: intensities, times: times, duration: duration)
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()

            var events: [CHHapticEvent] = []
            var curves: [CHHapticParameterCurve] = []

            // Continuous base so the pulse has body across the whole window.
            let baseIntensity = Float.random(in: 0.2...0.45)
            let baseSharpness = Float.random(in: 0.15...0.4)
            events.append(
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: baseIntensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: baseSharpness),
                    ],
                    relativeTime: 0,
                    duration: duration
                )
            )

            // Slow intensity drift — changes humans can actually feel.
            let controlPoints = Self.swellControlPoints(duration: duration, peak: Float.random(in: 0.55...1.0))
            curves.append(
                CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: controlPoints,
                    relativeTime: 0
                )
            )

            // Spaced transient accents with distinct intensities/sharpness.
            for (time, intensity) in zip(times, intensities) {
                events.append(
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                            CHHapticEventParameter(
                                parameterID: .hapticSharpness,
                                value: Float.random(in: 0.2...0.9)
                            ),
                        ],
                        relativeTime: time
                    )
                )
            }

            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
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
            playImpactFallback(intensities: intensities, times: times, duration: duration)
        }
    }

    static func keyTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
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

    /// Evenly slotted times with jitter so hits stay spaced enough to feel intensity changes.
    private static func spacedEventTimes(count: Int, duration: Double) -> [TimeInterval] {
        guard count > 0 else { return [] }
        if count == 1 { return [duration * Double.random(in: 0.15...0.45)] }

        let slot = duration / Double(count)
        // Keep at least ~120ms between hits when duration allows.
        let minGap = min(0.12, slot * 0.5)
        var times: [TimeInterval] = []
        for i in 0..<count {
            let start = Double(i) * slot
            let end = start + slot - minGap
            let lo = start + minGap * 0.25
            let hi = max(lo, end)
            times.append(Double.random(in: lo...hi))
        }
        return times.sorted()
    }

    private static func swellControlPoints(
        duration: Double,
        peak: Float
    ) -> [CHHapticParameterCurve.ControlPoint] {
        // 3–4 slow waypoints so the swell is readable, not a buzz.
        let midA = duration * Double.random(in: 0.25...0.4)
        let midB = duration * Double.random(in: 0.55...0.75)
        let midIntensity = Float.random(in: 0.3...0.7)
        return [
            .init(relativeTime: 0, value: Float.random(in: 0.15...0.35)),
            .init(relativeTime: midA, value: peak),
            .init(relativeTime: midB, value: midIntensity),
            .init(relativeTime: duration, value: Float.random(in: 0.1...0.3)),
        ]
    }

    private static func playImpactFallback(
        intensities: [Float],
        times: [TimeInterval],
        duration: Double
    ) {
        softImpact.prepare()
        // Soft continuous stand-in: a few extra soft taps across the window.
        let baseCount = max(3, Int(duration / 0.35))
        for i in 0..<baseCount {
            let t = duration * Double(i) / Double(max(baseCount - 1, 1))
            let base = Float.random(in: 0.2...0.45)
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                softImpact.impactOccurred(intensity: CGFloat(base))
            }
        }
        for (time, intensity) in zip(times, intensities) {
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                softImpact.impactOccurred(intensity: CGFloat(intensity))
            }
        }
    }
}
