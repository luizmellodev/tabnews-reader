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

    static let interactive = SoundRibbonVisualProfile(
        amplitudeScale: 1,
        wavelengthScale: 1,
        speedScale: 0.11,
        spreadScale: 1,
        envelopeCycles: 2.1,
        phaseOffset: 0,
        lineThinning: 0.72
    )

    static func randomMemorize() -> SoundRibbonVisualProfile {
        SoundRibbonVisualProfile(
            amplitudeScale: Double.random(in: 0.45...1.65),
            wavelengthScale: Double.random(in: 0.5...1.75),
            speedScale: Double.random(in: 0.04...0.13),
            spreadScale: Double.random(in: 0.6...1.45),
            envelopeCycles: Double.random(in: 1.1...3.8),
            phaseOffset: Double.random(in: 0...(2 * .pi)),
            lineThinning: Double.random(in: 0.45...1.15)
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

    @State private var renderFrequency: Double = 440
    @State private var dragStretch: Double = 0
    @State private var dragAnchorY: CGFloat?
    @State private var dragAnchorFrequency: Double?

    private let minFrequency = RestGameScoring.frequencyRange.lowerBound
    private let maxFrequency = RestGameScoring.frequencyRange.upperBound

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if !compact {
                    Color.black.ignoresSafeArea()
                }

                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    Canvas { context, size in
                        SoundRibbonRenderer.draw(
                            context: &context,
                            size: size,
                            frequency: renderFrequency,
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            compact: compact,
                            profile: visualProfile,
                            dragStretch: dragStretch
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
                            let deltaNorm = Double(-deltaY / geo.size.height) * 1.15
                            let newNorm = min(1, max(0, startNorm + deltaNorm))
                            let newFrequency = frequencyFromNormalized(newNorm)

                            frequency = newFrequency
                            renderFrequency = newFrequency
                            dragStretch = newNorm - startNorm

                            if isInteractive && !compact {
                                ToneGenerator.shared.sustain(frequency: newFrequency)
                            }
                            RestFeedbackManager.shared.sliderTick()
                        }
                        .onEnded { _ in
                            dragAnchorY = nil
                            dragAnchorFrequency = nil
                            renderFrequency = frequency
                            dragStretch = 0
                        }
                    : nil
            )
        }
        .frame(height: compact ? 72 : nil)
        .frame(maxHeight: compact ? 72 : .infinity)
        .onAppear {
            renderFrequency = frequency
            if isInteractive && !compact {
                ToneGenerator.shared.sustain(frequency: frequency)
            }
        }
        .onChange(of: frequency) { _, newValue in
            guard !isInteractive || dragAnchorY == nil else { return }
            renderFrequency = newValue

            if isInteractive && !compact {
                ToneGenerator.shared.sustain(frequency: newValue)
            }
        }
        .onChange(of: visualProfile) { _, _ in
            renderFrequency = frequency
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

// MARK: - Renderer

private enum SoundRibbonRenderer {
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
        frequency: Double,
        time: TimeInterval,
        compact: Bool,
        profile: SoundRibbonVisualProfile,
        dragStretch: Double = 0
    ) {
        let strands = compact ? compactStrands : fullStrands
        let centerX = size.width * 0.5
        let norm = normalizedFrequency(frequency)
        let wavelength = max(compact ? 36 : 44, (compact ? 4600 : 8200) / frequency) * profile.wavelengthScale
        let baseAmplitude = compact ? 6.5 : min(46, size.width * 0.13)
        let amplitude = baseAmplitude * (0.5 + (1 - norm) * 0.85) * profile.amplitudeScale
        let drift = time * profile.speedScale
        let stretchBoost = 1 + abs(dragStretch) * (compact ? 0.06 : 0.14)

        drawStrands(
            context: &context,
            size: size,
            strands: strands,
            centerX: centerX,
            wavelength: wavelength,
            amplitude: amplitude * stretchBoost,
            drift: drift,
            compact: compact,
            profile: profile,
            dragStretch: dragStretch
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
        compact: Bool,
        profile: SoundRibbonVisualProfile,
        dragStretch: Double
    ) {
        let step = compact ? 2.8 : 2.2
        let liveTension = dragStretch * (compact ? 0.06 : 0.1)

        for strand in strands {
            var path = Path()
            var started = false

            for y in stride(from: 0.0, through: Double(size.height), by: step) {
                let progress = y / max(Double(size.height), 1)
                let edgeFade = sin(progress * .pi)
                let bulge = 0.28 + 0.72 * pow(
                    sin(progress * .pi * profile.envelopeCycles + profile.phaseOffset + strand.phase * 0.08),
                    2
                )
                let tension = 1 - liveTension * sin(progress * .pi * 2 + strand.phase)
                let phase = (y / (wavelength * tension) + drift + strand.phase * 0.04) * .pi * 2
                let primary = sin(phase)
                let silk = sin(phase * 0.5 + strand.harmonicPhase) * strand.harmonic * 0.35
                let wave = (primary + silk) * amplitude * bulge * edgeFade

                let spread = strand.spread * profile.spreadScale
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
                .opacity(strand.opacity * (compact ? 0.9 : 0.72))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: max(0.6, strand.width * profile.lineThinning * (compact ? 0.85 : 0.7)),
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
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .frame(height: 72)
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
                    gradient: saturationGradient
                )

                verticalSlider(
                    value: $color.lightness,
                    range: 0...100,
                    gradient: lightnessGradient
                )

                Spacer()
            }
            .padding(.leading, 16)
            .padding(.vertical, 80)
        }
        .onAppear {
            ToneGenerator.shared.configureSessionIfNeeded()
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
                            height: geo.size.height
                        )
                    }
            )
        }
        .frame(width: 28)
    }

    private func verticalSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        gradient: LinearGradient
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
                            height: geo.size.height
                        )
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
        height: CGFloat
    ) {
        let clampedY = max(0, min(height, locationY))
        let inverted = 1 - (clampedY / height)
        binding.wrappedValue = range.lowerBound + inverted * (range.upperBound - range.lowerBound)

        RestFeedbackManager.shared.colorAdjust(
            hue: color.hue,
            saturation: color.saturation,
            lightness: color.lightness
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
