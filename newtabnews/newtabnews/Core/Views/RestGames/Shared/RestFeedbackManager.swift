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
    private var lastColorSoundTime: TimeInterval = 0

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

    /// Pitch follows hue while adjusting color sliders.
    func colorAdjust(hue: Double, saturation: Double, lightness: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastColorSoundTime > 0.07 else { return }
        lastColorSoundTime = now

        let hueNorm = hue / 360
        let satNorm = saturation / 100
        let lightNorm = lightness / 100
        let frequency = 280 + (hueNorm * 520) + (satNorm * 80)
        let volume = Float(0.16 + (lightNorm * 0.2))

        ToneGenerator.shared.playBriefTone(frequency: frequency, duration: 0.07, volume: volume)
        if now - lastSliderHapticTime > 0.12 {
            lastSliderHapticTime = now
            impactLight.impactOccurred(intensity: 0.3)
        }
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
