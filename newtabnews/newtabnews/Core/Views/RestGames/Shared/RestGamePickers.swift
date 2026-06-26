import SwiftUI

// MARK: - Visual profile

struct SoundRibbonVisualProfile: Equatable {
    var amplitudeScale: Double
    var wavelengthScale: Double
    var speedScale: Double
    var spreadScale: Double
    var envelopeCycles: Double
    var phaseOffset: Double
    var lineThinning: Double
    /// Quando definido, a onda ignora a frequência real (fase de memorização).
    var decoyVisualNorm: Double?

    static let interactive = SoundRibbonVisualProfile(
        amplitudeScale: 1,
        wavelengthScale: 1,
        speedScale: 0.16,
        spreadScale: 1,
        envelopeCycles: 2.1,
        phaseOffset: 0,
        lineThinning: 0.72,
        decoyVisualNorm: nil
    )

    static let hubBanner = SoundRibbonVisualProfile(
        amplitudeScale: 0.50,
        wavelengthScale: 0.82,
        speedScale: 0.1531,
        spreadScale: 1.52,
        envelopeCycles: 1.15,
        phaseOffset: 0.35,
        lineThinning: 0.88,
        decoyVisualNorm: nil
    )

    static func randomMemorize() -> SoundRibbonVisualProfile {
        SoundRibbonVisualProfile(
            amplitudeScale: Double.random(in: 0.45...1.65),
            wavelengthScale: Double.random(in: 0.5...1.75),
            speedScale: Double.random(in: 0.12...0.28),
            spreadScale: Double.random(in: 0.6...1.45),
            envelopeCycles: Double.random(in: 1.1...3.8),
            phaseOffset: Double.random(in: 0...(2 * .pi)),
            lineThinning: Double.random(in: 0.45...1.15),
            decoyVisualNorm: Double.random(in: 0...1)
        )
    }
}

// MARK: - Sound Ribbon (Dialed-style vertical wave)

struct SoundRibbonView: View {
    @Binding var frequency: Double
    var isInteractive: Bool = true
    var compact: Bool = false
    var visualProfile: SoundRibbonVisualProfile = .interactive
    var showHint: Bool = true

    @State private var visualNorm: Double = 0.5
    @State private var dragAnchorY: CGFloat?
    @State private var dragAnchorFrequency: Double?

    private let minFrequency = RestGameScoring.frequencyRange.lowerBound
    private let maxFrequency = RestGameScoring.frequencyRange.upperBound
    private var isDragging: Bool { dragAnchorY != nil }

    private var displayTargetNorm: Double {
        visualProfile.decoyVisualNorm ?? normalizedFrequency(frequency)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if !compact {
                    Color.black.ignoresSafeArea()
                }

                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    SoundRibbonSmoothingTick(
                        targetNorm: displayTargetNorm,
                        isDragging: isDragging,
                        visualNorm: $visualNorm,
                        tick: timeline.date.timeIntervalSinceReferenceDate
                    )

                    Canvas { context, size in
                        SoundRibbonRenderer.draw(
                            context: &context,
                            size: size,
                            visualNorm: visualNorm,
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            compact: compact,
                            profile: visualProfile,
                            isInteractive: isInteractive
                        )
                    }
                }

                if isInteractive && !compact && showHint {
                    VStack {
                        Spacer()
                        Text("Arraste ↑↓ na onda")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.32))
                            .padding(.bottom, 24)
                    }
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                isInteractive
                    ? DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragAnchorY == nil {
                                dragAnchorY = value.startLocation.y
                                dragAnchorFrequency = frequency
                            }

                            guard let anchorY = dragAnchorY, let anchorFrequency = dragAnchorFrequency else { return }

                            let deltaY = value.location.y - anchorY
                            let startNorm = normalizedFrequency(anchorFrequency)
                            // ~40% da altura da tela cobre toda a faixa 200–800 Hz
                            let deltaNorm = Double(-deltaY / geo.size.height) / 0.4
                            let newNorm = min(1, max(0, startNorm + deltaNorm))
                            let newFrequency = frequencyFromNormalized(newNorm)

                            frequency = newFrequency

                            if isInteractive && !compact {
                                ToneGenerator.shared.sustain(frequency: newFrequency)
                            }
                            RestFeedbackManager.shared.sliderTick()
                        }
                        .onEnded { _ in
                            dragAnchorY = nil
                            dragAnchorFrequency = nil
                        }
                    : nil
            )
        }
        .frame(height: compact ? 72 : nil)
        .frame(maxHeight: compact ? 72 : .infinity)
        .onAppear {
            visualNorm = displayTargetNorm
            if isInteractive && !compact {
                ToneGenerator.shared.sustain(frequency: frequency)
            }
        }
        .onChange(of: frequency) { _, newValue in
            if isInteractive && !compact {
                ToneGenerator.shared.sustain(frequency: newValue)
            }
        }
        .onChange(of: visualProfile) { _, _ in
            visualNorm = displayTargetNorm
        }
    }

    private func frequencyFromNormalized(_ norm: Double) -> Double {
        let minLog = log2(minFrequency)
        let maxLog = log2(maxFrequency)
        return pow(2, minLog + norm * (maxLog - minLog))
    }

    private func normalizedFrequency(_ value: Double) -> Double {
        let minLog = log2(minFrequency)
        let maxLog = log2(maxFrequency)
        return (log2(value) - minLog) / (maxLog - minLog)
    }
}

private struct SoundRibbonSmoothingTick: View {
    let targetNorm: Double
    let isDragging: Bool
    @Binding var visualNorm: Double
    let tick: TimeInterval

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: tick) { _, _ in
                let rate = isDragging ? 0.065 : 0.12
                visualNorm += (targetNorm - visualNorm) * rate
            }
    }
}

// MARK: - Renderer

enum SoundRibbonRenderer {
    private struct Strand {
        let phase: Double
        let spread: Double
        let harmonic: Double
        let harmonicPhase: Double
        let opacity: Double
        let width: CGFloat
        let colorBias: Double
    }

    private static let fullStrands: [Strand] = {
        (0..<28).map { i in
            let n = Double(i)
            let center = 13.5
            return Strand(
                phase: n * 0.31,
                spread: (n - center) * 1.35,
                harmonic: 0.22 + (n.truncatingRemainder(dividingBy: 3)) * 0.08,
                harmonicPhase: n * 0.47,
                opacity: 0.22 + (1 - abs(n - center) / center) * 0.55,
                width: 1.4 + (1 - abs(n - center) / center) * 1.6,
                colorBias: n / 27
            )
        }
    }()

    private static let compactStrands: [Strand] = {
        (0..<10).map { i in
            let n = Double(i)
            let center = 4.5
            return Strand(
                phase: n * 0.4,
                spread: (n - center) * 1.1,
                harmonic: 0.18,
                harmonicPhase: n * 0.55,
                opacity: 0.35 + (1 - abs(n - center) / center) * 0.4,
                width: 1.2 + (1 - abs(n - center) / center) * 0.8,
                colorBias: n / 9
            )
        }
    }()

    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        visualNorm: Double,
        time: TimeInterval,
        compact: Bool,
        profile: SoundRibbonVisualProfile,
        isInteractive: Bool = false
    ) {
        let strands = profile == .hubBanner ? fullStrands : (compact ? compactStrands : fullStrands)
        let centerX = size.width * 0.5
        let deform = frequencyDeformation(norm: visualNorm, compact: compact)
        let visualFrequency = frequencyFromNormalized(visualNorm)

        let minWavelength = compact ? 44.0 : 56.0
        let wavelength = max(minWavelength, (compact ? 4800 : 9200) / visualFrequency)
            * profile.wavelengthScale
            * deform.wavelengthScale
        let baseAmplitude: Double
        if profile == .hubBanner {
            baseAmplitude = min(Double(size.width), Double(size.height)) * 0.26
        } else if compact {
            baseAmplitude = 6.5
        } else {
            baseAmplitude = min(52, size.width * 0.14)
        }
        let amplitude = max(compact ? 4.8 : 14, baseAmplitude * deform.amplitudeScale * profile.amplitudeScale)
        let driftSpeed: Double
        if profile == .hubBanner {
            driftSpeed = profile.speedScale
        } else if isInteractive && !compact {
            driftSpeed = profile.speedScale * 0.82
        } else {
            driftSpeed = profile.speedScale * deform.animSpeed
        }
        let drift = time * driftSpeed

        drawStrands(
            context: &context,
            size: size,
            strands: strands,
            centerX: centerX,
            wavelength: wavelength,
            amplitude: amplitude,
            drift: drift,
            time: time,
            compact: compact,
            profile: profile,
            deform: deform,
            visualNorm: visualNorm
        )
    }

    private static func frequencyFromNormalized(_ norm: Double) -> Double {
        let minLog = log2(RestGameScoring.frequencyRange.lowerBound)
        let maxLog = log2(RestGameScoring.frequencyRange.upperBound)
        return pow(2, minLog + norm * (maxLog - minLog))
    }

    private struct FrequencyDeformation {
        let spreadScale: Double
        let amplitudeScale: Double
        let wavelengthScale: Double
        let lineScale: Double
        let bulgeScale: Double
        let animSpeed: Double
        let pinch: Double
    }

    private static func frequencyDeformation(norm: Double, compact: Bool) -> FrequencyDeformation {
        let low = 1 - norm
        let boost = compact ? 0.75 : 1.0

        return FrequencyDeformation(
            spreadScale: (0.44 + low * 0.82) * boost,
            amplitudeScale: 0.46 + low * 1.05,
            wavelengthScale: 0.68 + low * 0.58,
            lineScale: 0.52 + low * 0.72,
            bulgeScale: 0.32 + low * 0.88,
            animSpeed: 0.75 + norm * 0.85,
            pinch: 0.06 + norm * 0.28
        )
    }

    private static func drawStrands(
        context: inout GraphicsContext,
        size: CGSize,
        strands: [Strand],
        centerX: CGFloat,
        wavelength: Double,
        amplitude: Double,
        drift: Double,
        time: TimeInterval,
        compact: Bool,
        profile: SoundRibbonVisualProfile,
        deform: FrequencyDeformation,
        visualNorm: Double
    ) {
        let step = compact ? 2.6 : 2.0
        let breathe = sin(time * (profile == .hubBanner ? 0.923 : 0.85)) * (profile == .hubBanner ? 0.0497 : 0.045)
        let strandDriftSpeed = profile == .hubBanner ? 0.793 : 0.55
        let strandDriftAmplitude = profile == .hubBanner ? 0.0464 : 0.045

        for strand in strands {
            var path = Path()
            var started = false

            for y in stride(from: 0.0, through: Double(size.height), by: step) {
                let progress = y / max(Double(size.height), 1)
                let edgeFade = sin(progress * .pi)
                let bulgeWave = sin(progress * .pi * profile.envelopeCycles + profile.phaseOffset + strand.phase * 0.08)
                let bulge = (0.12 + deform.bulgeScale * pow(bulgeWave, 2)) * (1 - deform.pinch * pow(abs(bulgeWave), 1.4))
                let strandDrift = drift + sin(time * strandDriftSpeed + strand.phase) * strandDriftAmplitude
                let phase = (y / wavelength + strandDrift + strand.phase * 0.05) * .pi * 2
                let primary = sin(phase)
                let silk = sin(phase * 0.5 + strand.harmonicPhase) * strand.harmonic * (0.32 + visualNorm * 0.12)
                let wave = (primary + silk) * amplitude * bulge * edgeFade * (1 + breathe)

                let spread = strand.spread * profile.spreadScale * deform.spreadScale
                let point = CGPoint(x: centerX + spread + wave, y: y)
                if started {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    started = true
                }
            }

            let colorT = strand.colorBias * 0.7 + profile.phaseOffset.truncatingRemainder(dividingBy: 1) * 0.3
            let color = paletteColor(at: colorT)
                .opacity(strand.opacity * (compact ? 0.9 : (profile == .hubBanner ? 0.42 : 0.74)))

            let lineWidth = max(
                0.45,
                strand.width * profile.lineThinning * deform.lineScale * (compact ? 0.85 : (profile == .hubBanner ? 1.05 : 0.72))
            )

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    static func paletteColor(at t: Double) -> Color {
        let clamped = min(1, max(0, t))
        let stops: [(Double, Color)] = [
            (0.0, Color(red: 0.18, green: 0.82, blue: 0.78)),
            (0.35, Color(red: 0.24, green: 0.72, blue: 0.88)),
            (0.62, Color(red: 0.52, green: 0.38, blue: 0.92)),
            (0.85, Color(red: 0.72, green: 0.32, blue: 0.86)),
            (1.0, Color(red: 0.88, green: 0.38, blue: 0.72))
        ]

        for index in 0..<(stops.count - 1) {
            let start = stops[index]
            let end = stops[index + 1]
            if clamped >= start.0 && clamped <= end.0 {
                let local = (clamped - start.0) / (end.0 - start.0)
                return blend(start.1, end.1, local)
            }
        }
        return stops.last!.1
    }

    private static func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let tc = min(1, max(0, t))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(a).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        UIColor(b).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: Double(ar + (br - ar) * tc),
            green: Double(ag + (bg - ag) * tc),
            blue: Double(ab + (bb - ab) * tc)
        )
    }

    private static func normalizedFrequency(_ value: Double) -> Double {
        let minLog = log2(RestGameScoring.frequencyRange.lowerBound)
        let maxLog = log2(RestGameScoring.frequencyRange.upperBound)
        return (log2(value) - minLog) / (maxLog - minLog)
    }
}

struct SoundRibbonPreview: View {
    var expanded = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: expanded ? 0 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.06, blue: 0.14),
                            Color(red: 0.04, green: 0.05, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            SoundRibbonView(
                frequency: .constant(420),
                isInteractive: false,
                compact: true
            )
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 0 : 16, style: .continuous))
            .overlay {
                if !expanded {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: expanded ? .infinity : nil)
        .frame(height: expanded ? nil : 72)
    }
}

struct FrequencyPickerView: View {
    @Binding var frequency: Double

    var body: some View {
        SoundRibbonView(
            frequency: $frequency,
            isInteractive: true,
            visualProfile: .interactive,
            showHint: true
        )
    }
}

// MARK: - Color Picker (Dialed-style vertical sliders)

struct HSLColorPickerView: View {
    @Binding var color: HSLColor

    var body: some View {
        ZStack {
            color.swiftUIColor
                .ignoresSafeArea()

            HStack(spacing: 10) {
                hueSlider(value: $color.hue)

                verticalSlider(
                    value: $color.saturation,
                    range: 0...100,
                    gradient: saturationGradient,
                    axis: .saturation
                )

                verticalSlider(
                    value: $color.lightness,
                    range: 0...100,
                    gradient: lightnessGradient,
                    axis: .lightness
                )

                Spacer()
            }
            .padding(.leading, 16)
            .padding(.vertical, 80)
        }
        .onAppear {
            ToneGenerator.shared.configureSessionIfNeeded()
        }
        .onDisappear {
            RestFeedbackManager.shared.endColorAdjust()
        }
    }

    private func hueSlider(value: Binding<Double>) -> some View {
        GeometryReader { geo in
            let fraction = value.wrappedValue / 360
            let thumbY = thumbPosition(fraction: fraction, height: geo.size.height)

            ZStack(alignment: .top) {
                Canvas { context, size in
                    let rowCount = max(Int(size.height), 1)
                    for row in 0..<rowCount {
                        let inverted = 1 - (Double(row) / Double(max(rowCount - 1, 1)))
                        let hue = inverted * 360
                        let stripColor = HSLColor(
                            hue: hue,
                            saturation: color.saturation,
                            lightness: color.lightness
                        ).swiftUIColor
                        let rect = CGRect(x: 0, y: CGFloat(row), width: size.width, height: 1)
                        context.fill(Path(rect), with: .color(stripColor))
                    }
                }
                .frame(width: 14)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))

                Circle()
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .position(x: geo.size.width / 2, y: thumbY)
            }
            .frame(width: 28)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateSliderValue(
                            binding: value,
                            range: 0...360,
                            locationY: gesture.location.y,
                            height: geo.size.height,
                            axis: .hue
                        )
                    }
                    .onEnded { _ in
                        RestFeedbackManager.shared.endColorAdjust()
                    }
            )
        }
        .frame(width: 28)
    }

    private func verticalSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        gradient: LinearGradient,
        axis: ColorSliderAxis
    ) -> some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value.wrappedValue - range.lowerBound) / span : 0
            let thumbY = thumbPosition(fraction: fraction, height: geo.size.height)

            ZStack(alignment: .top) {
                Capsule()
                    .fill(gradient)
                    .frame(width: 14)
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))

                Circle()
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .position(x: geo.size.width / 2, y: thumbY)
            }
            .frame(width: 28)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateSliderValue(
                            binding: value,
                            range: range,
                            locationY: gesture.location.y,
                            height: geo.size.height,
                            axis: axis
                        )
                    }
                    .onEnded { _ in
                        RestFeedbackManager.shared.endColorAdjust()
                    }
            )
        }
        .frame(width: 28)
    }

    private func thumbPosition(fraction: Double, height: CGFloat) -> CGFloat {
        max(14, min(height - 14, height * (1 - fraction)))
    }

    private func updateSliderValue(
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        locationY: CGFloat,
        height: CGFloat,
        axis: ColorSliderAxis
    ) {
        let clampedY = max(0, min(height, locationY))
        let inverted = 1 - (clampedY / height)
        binding.wrappedValue = range.lowerBound + inverted * (range.upperBound - range.lowerBound)

        RestFeedbackManager.shared.colorAdjust(
            hue: color.hue,
            saturation: color.saturation,
            lightness: color.lightness,
            activeAxis: axis
        )
    }

    private var saturationGradient: LinearGradient {
        LinearGradient(
            colors: [
                HSLColor(hue: color.hue, saturation: 100, lightness: color.lightness).swiftUIColor,
                HSLColor(hue: color.hue, saturation: 0, lightness: color.lightness).swiftUIColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var lightnessGradient: LinearGradient {
        LinearGradient(
            colors: [
                HSLColor(hue: color.hue, saturation: color.saturation, lightness: 100).swiftUIColor,
                HSLColor(hue: color.hue, saturation: color.saturation, lightness: 0).swiftUIColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
