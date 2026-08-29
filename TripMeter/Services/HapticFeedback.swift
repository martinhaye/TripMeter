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

    private struct Strike {
        var time: TimeInterval
        var intensity: Float
        var sharpness: Float
    }

    private struct Sustain {
        var time: TimeInterval
        var duration: TimeInterval
        var intensity: Float
        var sharpness: Float
    }

    private enum SavePulseSelection {
        case motif(duration: TimeInterval)
        case symphony(duration: TimeInterval, alteredSelf: Bool)
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

    /// Plays one authored rhythm, or — rarely — a longer composed performance.
    static func savePulse() {
        let selection = randomSavePulseSelection()

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            playUnavailableFallback()
            return
        }

        switch selection {
        case .motif(let duration):
            playFittedMotif(duration: duration)
        case .symphony(let duration, let alteredSelf):
            playSymphony(duration: duration, alteredSelf: alteredSelf)
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

    /// Whole-second durations, with rare longer performances:
    /// 1s: 28%, 2s: 22%, 3s: 19%, 4s: 16%, 5s: 9%, 10s symphony: 5%, 20s symphony: 1%.
    private static func randomSavePulseSelection() -> SavePulseSelection {
        switch Int.random(in: 0..<100) {
        case 0..<28: .motif(duration: 1)
        case 28..<50: .motif(duration: 2)
        case 50..<69: .motif(duration: 3)
        case 69..<85: .motif(duration: 4)
        case 85..<94: .motif(duration: 5)
        case 94..<99: .symphony(duration: 10, alteredSelf: false)
        default: .symphony(duration: 20, alteredSelf: true)
        }
    }

    private static func playFittedMotif(duration: TimeInterval) {
        let selectedPattern = savePulsePatterns.randomElement()!
        let fitMode = PatternFitMode.allCases.randomElement()!
        let strikes = fittedBeats(
            from: selectedPattern,
            duration: duration,
            mode: fitMode
        ).map { time, beat in
            Strike(time: time, intensity: beat.intensity, sharpness: beat.sharpness)
        }
        play(strikes: strikes, sustains: [], duration: duration)
    }

    // MARK: - Symphony

    private static func playSymphony(duration: TimeInterval, alteredSelf: Bool) {
        let coreDuration = alteredSelf ? duration / 2 : duration
        var strikes = arrangeMovements(
            duration: coreDuration,
            movementCount: alteredSelf ? 5 : 4
        )
        var sustains: [Sustain] = []

        if alteredSelf {
            let fold = coreDuration
            let mirror = retrogradeInversion(strikes: strikes, within: coreDuration)
                .map { strike in
                    Strike(
                        time: strike.time + fold,
                        intensity: strike.intensity,
                        sharpness: strike.sharpness
                    )
                }
            strikes.append(contentsOf: lookingGlassStrikes(around: fold))
            sustains.append(contentsOf: lookingGlassSustains(around: fold))
            strikes.append(contentsOf: mirror)
        } else {
            strikes.append(contentsOf: cadence(at: duration))
        }

        pourChocolate(
            strikes: &strikes,
            sustains: &sustains,
            totalDuration: duration
        )

        play(strikes: strikes, sustains: sustains, duration: duration)
    }

    /// Sequence several library motifs into a single span, inverting a subset.
    private static func arrangeMovements(duration: TimeInterval, movementCount: Int) -> [Strike] {
        var library = savePulsePatterns.shuffled()
        while library.count < movementCount {
            library.append(contentsOf: savePulsePatterns.shuffled())
        }
        let chosen = Array(library.prefix(movementCount))

        var invert: [Bool] = (0..<movementCount).map { _ in Bool.random() }
        if invert.allSatisfy({ $0 }) { invert[0] = false }
        if invert.allSatisfy({ !$0 }) { invert[Int.random(in: 0..<movementCount)] = true }

        let rest: TimeInterval = 0.2
        let restTotal = rest * TimeInterval(max(0, movementCount - 1))
        let tail: TimeInterval = 0.32
        let playable = max(duration - restTotal - tail, duration * 0.75)
        let weights = (0..<movementCount).map { _ in Double.random(in: 0.72...1.38) }
        let weightSum = weights.reduce(0, +)

        var cursor: TimeInterval = 0
        var strikes: [Strike] = []
        for (index, pattern) in chosen.enumerated() {
            let slot = playable * (weights[index] / weightSum)
            let mode = PatternFitMode.allCases.randomElement()!
            var beats = fittedBeats(from: pattern, duration: slot, mode: mode)
            if invert[index] {
                beats = turnUpsideDown(beats, slotDuration: slot)
            }
            for (localTime, beat) in beats {
                let time = cursor + localTime
                if time >= 0, time < duration {
                    strikes.append(
                        Strike(time: time, intensity: beat.intensity, sharpness: beat.sharpness)
                    )
                }
            }
            cursor += slot + rest
        }
        return strikes
    }

    private static func turnUpsideDown(
        _ beats: [(TimeInterval, PulseBeat)],
        slotDuration: TimeInterval
    ) -> [(TimeInterval, PulseBeat)] {
        beats.map { time, beat in
            let inverted = PulseBeat(
                time: 0,
                intensity: flipped(beat.intensity),
                sharpness: flipped(beat.sharpness)
            )
            return (max(0, slotDuration - time), inverted)
        }
        .sorted { $0.0 < $1.0 }
    }

    private static func retrogradeInversion(strikes: [Strike], within duration: TimeInterval) -> [Strike] {
        strikes.map { strike in
            Strike(
                time: max(0, duration - strike.time),
                intensity: flipped(strike.intensity),
                sharpness: flipped(strike.sharpness)
            )
        }
        .filter { $0.time < duration }
        .sorted { $0.time < $1.time }
    }

    /// Palindrome around the fold — two selves meeting.
    private static func lookingGlassStrikes(around center: TimeInterval) -> [Strike] {
        [
            Strike(time: center - 0.46, intensity: 0.52, sharpness: 0.28),
            Strike(time: center - 0.20, intensity: 0.78, sharpness: 0.50),
            Strike(time: center, intensity: 1.00, sharpness: 0.22),
            Strike(time: center + 0.20, intensity: 0.78, sharpness: 0.50),
            Strike(time: center + 0.46, intensity: 0.52, sharpness: 0.28),
        ]
    }

    private static func lookingGlassSustains(around center: TimeInterval) -> [Sustain] {
        [
            Sustain(time: center - 0.55, duration: 1.10, intensity: 0.30, sharpness: 0.16),
        ]
    }

    private static func cadence(at duration: TimeInterval) -> [Strike] {
        [
            Strike(time: max(0, duration - 0.30), intensity: 0.72, sharpness: 0.40),
            Strike(time: max(0, duration - 0.08), intensity: 1.00, sharpness: 0.68),
        ]
    }

    /// A warm continuous sauce lands on a random contiguous half and coats whatever it covers.
    private static func pourChocolate(
        strikes: inout [Strike],
        sustains: inout [Sustain],
        totalDuration: TimeInterval
    ) {
        let windowStart = Double.random(in: 0...(totalDuration / 2))
        let windowEnd = windowStart + totalDuration / 2

        for index in strikes.indices {
            let time = strikes[index].time
            guard time >= windowStart, time < windowEnd else { continue }
            strikes[index].sharpness = max(0.08, strikes[index].sharpness * 0.42)
            strikes[index].intensity = min(1, strikes[index].intensity * 1.12)
        }

        let drips: [(TimeInterval, Float, Float)] = [
            (0.00, 0.88, 0.32),
            (0.17, 0.64, 0.20),
            (0.36, 0.50, 0.12),
        ]
        for (offset, intensity, sharpness) in drips {
            let time = windowStart + offset
            if time < windowEnd {
                strikes.append(Strike(time: time, intensity: intensity, sharpness: sharpness))
            }
        }

        let chunkCount = 4
        let chunkDuration = (windowEnd - windowStart) / Double(chunkCount)
        let flowIntensity: [Float] = [0.26, 0.40, 0.50, 0.34]
        let flowSharpness: [Float] = [0.22, 0.13, 0.08, 0.06]
        for chunk in 0..<chunkCount {
            sustains.append(
                Sustain(
                    time: windowStart + chunkDuration * Double(chunk),
                    duration: max(0.08, chunkDuration - 0.03),
                    intensity: flowIntensity[chunk],
                    sharpness: flowSharpness[chunk]
                )
            )
        }
    }

    /// Keep inverted dynamics/color readable on the Taptic Engine.
    private static func flipped(_ value: Float) -> Float {
        min(1, max(0.22, 1.05 - value))
    }

    // MARK: - Engine

    private static func play(strikes: [Strike], sustains: [Sustain], duration: TimeInterval) {
        stopActiveSavePulse()

        let clippedStrikes = strikes.filter { $0.time >= 0 && $0.time < duration }
        let clippedSustains = sustains.compactMap { sustain -> Sustain? in
            guard sustain.time < duration else { return nil }
            let start = max(0, sustain.time)
            let end = min(duration, sustain.time + sustain.duration)
            let length = end - start
            guard length >= 0.05 else { return nil }
            return Sustain(
                time: start,
                duration: length,
                intensity: sustain.intensity,
                sharpness: sustain.sharpness
            )
        }

        var events: [CHHapticEvent] = clippedStrikes.map { strike in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: strike.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: strike.sharpness),
                ],
                relativeTime: strike.time
            )
        }
        events += clippedSustains.map { sustain in
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: sustain.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sustain.sharpness),
                ],
                relativeTime: sustain.time,
                duration: sustain.duration
            )
        }
        events.sort { $0.relativeTime < $1.relativeTime }

        guard !events.isEmpty else {
            playUnavailableFallback()
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            activeSavePulse = (engine, player)
            try player.start(atTime: CHHapticTimeImmediate)

            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.25) {
                engine.stop(completionHandler: nil)
                if activeSavePulse?.engine === engine {
                    activeSavePulse = nil
                }
            }
        } catch {
            playUnavailableFallback()
        }
    }

    private static func stopActiveSavePulse() {
        guard let active = activeSavePulse else { return }
        try? active.player.stop(atTime: CHHapticTimeImmediate)
        active.engine.stop(completionHandler: nil)
        activeSavePulse = nil
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
