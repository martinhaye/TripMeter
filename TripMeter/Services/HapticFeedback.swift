import CoreHaptics
import UIKit

enum HapticFeedback {
    private static let softImpact: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        return generator
    }()

    /// Soft pulse: quick rise, gentle fade. Falls back to impact on unsupported hardware.
    static func savePulse() {
        guard UIApplication.shared.applicationState == .active else {
            savePulseImmediate()
            return
        }

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            savePulseImmediate()
            return
        }

        do {
            let engine = try CHHapticEngine()
            try engine.start()

            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            let attack = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            )

            let fadeIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35)
            let fadeSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            let fade = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [fadeIntensity, fadeSharpness],
                relativeTime: 0.04,
                duration: 0.18
            )

            let pattern = try CHHapticPattern(events: [attack, fade], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                engine.stop(completionHandler: nil)
            }
        } catch {
            savePulseImmediate()
        }
    }

    /// Synchronous UIKit impact — works in the brief window before the app backgrounds.
    static func savePulseImmediate() {
        softImpact.prepare()
        softImpact.impactOccurred(intensity: 0.85)
    }

    static func keyTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    }
}
