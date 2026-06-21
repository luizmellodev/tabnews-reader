import AVFoundation

final class ToneGenerator {
    static let shared = ToneGenerator()

    private final class OscillatorState {
        var phase: Double = 0
        var frequency: Double = 440
        var volume: Float = 0.25
    }

    private let engine = AVAudioEngine()
    private let state = OscillatorState()
    private var sourceNode: AVAudioSourceNode?
    private var isConfigured = false
    private var isRunning = false
    private var isSustainMode = false
    private var briefToneWorkItem: DispatchWorkItem?

    var isSustaining: Bool { isSustainMode }

    private let sampleRate: Double = 44_100

    private init() {}

    func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isConfigured = true
        } catch {
            // Audio is best-effort for the rest games.
        }
    }

    /// Continuous tone for Sound Match (memorize + recreate). Only updates frequency in place.
    func sustain(frequency: Double, volume: Float = 0.25) {
        configureSessionIfNeeded()
        briefToneWorkItem?.cancel()
        isSustainMode = true
        state.frequency = max(20, frequency)
        state.volume = volume
        startEngineIfNeeded()
    }

    /// Short tone for color slider ticks and countdown — does not interrupt sustain mode.
    func playBriefTone(frequency: Double, duration: TimeInterval = 0.055, volume: Float = 0.18) {
        configureSessionIfNeeded()
        briefToneWorkItem?.cancel()

        if isSustainMode {
            state.frequency = max(20, frequency)
            return
        }

        state.frequency = max(20, frequency)
        state.volume = volume
        startEngineIfNeeded()

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isSustainMode else { return }
            self.stopEngineOnly()
        }
        briefToneWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func stop() {
        briefToneWorkItem?.cancel()
        isSustainMode = false
        stopEngineOnly()
    }

    private func stopEngineOnly() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        state.phase = 0
    }

    private func startEngineIfNeeded() {
        if sourceNode == nil {
            setupSourceNode()
        }

        guard !isRunning else { return }

        do {
            if !engine.isRunning {
                try engine.start()
            }
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    private func setupSourceNode() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let oscillator = state

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = 2 * Double.pi * oscillator.frequency / self.sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = Float32(sin(oscillator.phase)) * oscillator.volume
                oscillator.phase += phaseIncrement
                if oscillator.phase >= 2 * Double.pi {
                    oscillator.phase -= 2 * Double.pi
                }
                for buffer in ablPointer {
                    guard let buf = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    buf[frame] = sample
                }
            }
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }
}
