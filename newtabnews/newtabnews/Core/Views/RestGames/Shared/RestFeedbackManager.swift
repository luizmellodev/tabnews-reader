import AudioToolbox
import UIKit

@MainActor
final class RestFeedbackManager {
    static let shared = RestFeedbackManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private var lastSliderHapticTime: TimeInterval = 0
    private var isColorAdjusting = false

    private init() {}

    func prepare() {
        ToneGenerator.shared.configureSessionIfNeeded()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    func tap() {
        impactLight.impactOccurred(intensity: 0.6)
        AudioServicesPlaySystemSound(1104)
    }

    func tapHaptic() {
        impactLight.impactOccurred(intensity: 0.6)
    }

    /// Rare tick while dragging sliders — haptic only, no sound.
    func sliderTick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSliderHapticTime > 0.12 else { return }
        lastSliderHapticTime = now
        impactLight.impactOccurred(intensity: 0.35)
    }

    /// Continuous pitch while adjusting color sliders — no engine restarts per tick.
    func colorAdjust(
        hue: Double,
        saturation: Double,
        lightness: Double,
        activeAxis: ColorSliderAxis = .hue
    ) {
        let hueNorm = hue / 360
        let satNorm = saturation / 100
        let lightNorm = lightness / 100

        // Hue sets the base note; saturation & lightness bend pitch and loudness.
        let hueFrequency = 220 + (hueNorm * 500)

        let satPitchRange = activeAxis == .saturation ? 340.0 : 200.0
        let saturationPitch = (satNorm - 0.5) * satPitchRange

        let lightPitchRange = activeAxis == .lightness ? 280.0 : 160.0
        let lightnessPitch = (lightNorm - 0.5) * lightPitchRange

        let frequency = min(1_200, max(90, hueFrequency + saturationPitch + lightnessPitch))

        let volumeLightRange = activeAxis == .lightness ? 0.28 : 0.18
        let volumeSatBoost = activeAxis == .saturation ? 0.10 : 0.05
        let volume = Float(min(0.45, 0.13 + (lightNorm * volumeLightRange) + (satNorm * volumeSatBoost)))

        ToneGenerator.shared.sustain(
            frequency: frequency,
            volume: volume,
            purpose: .colorPicker
        )
        isColorAdjusting = true

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastSliderHapticTime > 0.12 {
            lastSliderHapticTime = now
            impactLight.impactOccurred(intensity: 0.3)
        }
    }

    func endColorAdjust() {
        guard isColorAdjusting else { return }
        isColorAdjusting = false
        ToneGenerator.shared.release(purpose: .colorPicker)
    }

    func countdownTick(second: Int, total: Int) {
        if ToneGenerator.shared.isSustaining {
            AudioServicesPlaySystemSound(second <= 2 ? 1052 : 1104)
        } else {
            let progress = Double(second) / Double(max(total, 1))
            let frequency = 520 + ((1 - progress) * 380)
            ToneGenerator.shared.playBriefTone(frequency: frequency, duration: 0.1, volume: 0.28)
        }
        impactLight.impactOccurred(intensity: second <= 2 ? 0.7 : 0.45)
    }

    func countdownFinish() {
        if ToneGenerator.shared.isSustaining {
            AudioServicesPlaySystemSound(1057)
        } else {
            ToneGenerator.shared.playBriefTone(frequency: 880, duration: 0.14, volume: 0.26)
        }
        impactMedium.impactOccurred(intensity: 0.85)
    }

    func phaseTransition() {
        impactLight.impactOccurred(intensity: 0.5)
    }

    func confirm() {
        impactMedium.impactOccurred(intensity: 0.85)
        AudioServicesPlaySystemSound(1104)
    }

    func confirmHaptic() {
        impactMedium.impactOccurred(intensity: 0.85)
    }

    func scoreReveal(score: Double) {
        if score >= 8 {
            notification.notificationOccurred(.success)
        } else if score >= 5 {
            impactMedium.impactOccurred(intensity: 0.7)
        } else {
            notification.notificationOccurred(.warning)
        }
    }

    func cardPress() {
        impactMedium.impactOccurred(intensity: 0.75)
        AudioServicesPlaySystemSound(1104)
    }

    func correct() {
        notification.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057)
    }

    func wrong() {
        notification.notificationOccurred(.error)
        AudioServicesPlaySystemSound(1053)
    }
}

enum ColorSliderAxis {
    case hue
    case saturation
    case lightness
}
