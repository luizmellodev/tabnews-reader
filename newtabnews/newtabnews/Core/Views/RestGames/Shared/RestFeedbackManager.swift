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

    private init() {}

    func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    func tap() {
        impactLight.impactOccurred(intensity: 0.6)
        AudioServicesPlaySystemSound(1104)
    }

    /// Rare tick while dragging sliders — haptic only, no sound.
    func sliderTick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSliderHapticTime > 0.12 else { return }
        lastSliderHapticTime = now
        impactLight.impactOccurred(intensity: 0.35)
    }

    func phaseTransition() {
        impactLight.impactOccurred(intensity: 0.5)
    }

    func confirm() {
        impactMedium.impactOccurred(intensity: 0.85)
        AudioServicesPlaySystemSound(1104)
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
