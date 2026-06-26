import AVFoundation

enum ToneSustainPurpose: Equatable {
    case soundMatch
    case colorPicker
}

final class ToneGenerator {
    static let shared = ToneGenerator()

    private final class OscillatorState {
        var phase: Double = 0
        var currentFrequency: Double = 440
        var targetFrequency: Double = 440
        var currentVolume: Float = 0
        var targetVolume: Float = 0
    }

    private let engine = AVAudioEngine()
    private let state = OscillatorState()
    private var sourceNode: AVAudioSourceNode?
    private var isConfigured = false
    private var isRunning = false
    private var isSustainMode = false
    private var sustainPurpose: ToneSustainPurpose?
    private var briefToneWorkItem: DispatchWorkItem?

    var isSustaining: Bool { isSustainMode }

    private let sampleRate: Double = 44_100
    private let frequencySmoothing = 0.004
    private let volumeSmoothing = 0.015

    private init() {}

    func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isConfigured = true
        } catch {
            // Audio is best-effort for the rest games.
        }
    }

    /// Continuous tone — updates pitch/volume in place without restarting the engine.
    func sustain(
        frequency: Double,
        volume: Float = 0.25,
        purpose: ToneSustainPurpose = .soundMatch
    ) {
        configureSessionIfNeeded()
        briefToneWorkItem?.cancel()
        isSustainMode = true
        sustainPurpose = purpose
        state.targetFrequency = max(20, frequency)
        state.targetVolume = volume
        startEngineIfNeeded()
    }

    /// Fades out and stops a sustained tone for the given purpose.
    func release(purpose: ToneSustainPurpose, fadeDuration: TimeInterval = 0.08) {
        guard sustainPurpose == purpose else { return }
        briefToneWorkItem?.cancel()
        isSustainMode = false
        sustainPurpose = nil
        state.targetVolume = 0

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.state.currentVolume < 0.003 {
                self.stopEngineOnly()
            }
        }
        briefToneWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration, execute: work)
    }

    /// Short tone for countdown — does not interrupt sustain mode.
    func playBriefTone(frequency: Double, duration: TimeInterval = 0.055, volume: Float = 0.18) {
        configureSessionIfNeeded()
        briefToneWorkItem?.cancel()

        if isSustainMode {
            state.targetFrequency = max(20, frequency)
            return
        }

        state.targetFrequency = max(20, frequency)
        state.targetVolume = volume
        startEngineIfNeeded()

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isSustainMode else { return }
            self.state.targetVolume = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self, !self.isSustainMode, self.state.currentVolume < 0.003 else { return }
                self.stopEngineOnly()
            }
        }
        briefToneWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func stop() {
        briefToneWorkItem?.cancel()
        isSustainMode = false
        sustainPurpose = nil
        state.targetVolume = 0
        state.currentVolume = 0
        stopEngineOnly()
    }

    private func stopEngineOnly() {
        guard isRunning else { return }
        engine.stop()
        isRunning = false
        state.phase = 0
        state.currentVolume = 0
        state.targetVolume = 0
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
        let freqSmooth = frequencySmoothing
        let volSmooth = volumeSmoothing
        let rate = sampleRate

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                oscillator.currentFrequency += (oscillator.targetFrequency - oscillator.currentFrequency) * freqSmooth
                oscillator.currentVolume += (oscillator.targetVolume - oscillator.currentVolume) * Float(volSmooth)

                let sample = Float32(sin(oscillator.phase)) * oscillator.currentVolume
                let phaseIncrement = 2 * Double.pi * oscillator.currentFrequency / rate
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
