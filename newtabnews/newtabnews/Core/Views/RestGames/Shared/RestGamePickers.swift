import SwiftUI

// MARK: - Sound Ribbon (Dialed-style vertical wave)

struct SoundRibbonView: View {
    @Binding var frequency: Double
    var isInteractive: Bool = true
    var compact: Bool = false

    @State private var isDragging = false
    @State private var dragGlow: CGFloat = 0

    private let minFrequency = RestGameScoring.frequencyRange.lowerBound
    private let maxFrequency = RestGameScoring.frequencyRange.upperBound

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if !compact {
                    Color.black.ignoresSafeArea()

                    RadialGradient(
                        colors: [
                            ribbonAccent(for: frequency).opacity(0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: max(geo.size.width, geo.size.height) * 0.55
                    )
                    .ignoresSafeArea()
                    .animation(RestGameTheme.spring, value: frequency)
                }

                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    Canvas { context, size in
                        SoundRibbonRenderer.draw(
                            context: &context,
                            size: size,
                            frequency: frequency,
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            compact: compact,
                            glow: isDragging ? 1 : dragGlow
                        )
                    }
                }

                if isInteractive && !compact {
                    VStack {
                        Spacer()
                        Text(isDragging ? "Ajustando..." : "Arraste ↑↓ na onda")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.35))
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
                            if !isDragging {
                                withAnimation(RestGameTheme.quickSpring) { isDragging = true }
                            }
                            updateFrequency(from: value.location.y, in: geo.size.height)
                        }
                        .onEnded { _ in
                            withAnimation(RestGameTheme.spring) { isDragging = false }
                        }
                    : nil
            )
        }
        .frame(height: compact ? 72 : nil)
        .frame(maxHeight: compact ? 72 : .infinity)
        .onAppear {
            if isInteractive && !compact {
                ToneGenerator.shared.sustain(frequency: frequency)
            }
        }
        .onChange(of: frequency) { _, newValue in
            guard isInteractive && !compact else { return }
            ToneGenerator.shared.sustain(frequency: newValue)
            withAnimation(RestGameTheme.quickSpring) {
                dragGlow = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(RestGameTheme.spring) {
                    dragGlow = 0
                }
            }
        }
    }

    private func updateFrequency(from y: CGFloat, in height: CGFloat) {
        let clampedY = max(0, min(height, y))
        let inverted = 1 - (clampedY / height)
        let minLog = log2(minFrequency)
        let maxLog = log2(maxFrequency)
        let newFrequency = pow(2, minLog + inverted * (maxLog - minLog))
        frequency = newFrequency
    }

    private func ribbonAccent(for frequency: Double) -> Color {
        let t = normalizedFrequency(frequency)
        return SoundRibbonRenderer.paletteColor(at: t * 0.6 + 0.2)
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
        glow: CGFloat
    ) {
        let strands = compact ? compactStrands : fullStrands
        let centerX = size.width * 0.5
        let norm = normalizedFrequency(frequency)
        let wavelength = max(compact ? 36 : 52, (compact ? 5200 : 6800) / frequency)
        let amplitude = (compact ? 7 : min(38, size.width * 0.11)) * (1.05 - norm * 0.25)
        let speed = (frequency / (compact ? 110 : 70)) * (compact ? 0.65 : 1)

        if !compact && glow > 0 {
            var glowContext = context
            glowContext.addFilter(.blur(radius: 10 + glow * 6))
            drawStrands(
                context: &glowContext,
                size: size,
                strands: strands,
                centerX: centerX,
                wavelength: wavelength,
                amplitude: amplitude * 1.15,
                speed: speed,
                time: time,
                compact: compact,
                opacityScale: 0.35 + Double(glow) * 0.25,
                widthScale: 2.2
            )
        }

        drawStrands(
            context: &context,
            size: size,
            strands: strands,
            centerX: centerX,
            wavelength: wavelength,
            amplitude: amplitude,
            speed: speed,
            time: time,
            compact: compact,
            opacityScale: 1,
            widthScale: 1
        )
    }

    private static func drawStrands(
        context: inout GraphicsContext,
        size: CGSize,
        strands: [Strand],
        centerX: CGFloat,
        wavelength: Double,
        amplitude: Double,
        speed: Double,
        time: TimeInterval,
        compact: Bool,
        opacityScale: Double,
        widthScale: CGFloat
    ) {
        let step = compact ? 2.5 : 1.8

        for strand in strands {
            var path = Path()
            var started = false

            for y in stride(from: 0.0, through: Double(size.height), by: step) {
                let progress = y / max(Double(size.height), 1)
                let envelope = sin(progress * .pi)
                let primary = sin((y / wavelength + time * speed + strand.phase) * .pi * 2)
                let secondary = sin((y / (wavelength * 0.52) + time * speed * 1.35 + strand.harmonicPhase) * .pi * 2)
                let wave = (primary + strand.harmonic * secondary) * amplitude * envelope

                let point = CGPoint(x: centerX + strand.spread + wave, y: y)
                if started {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    started = true
                }
            }

            let color = paletteColor(at: progressMix(strand.colorBias, speed: speed))
                .opacity(strand.opacity * opacityScale)

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: strand.width * widthScale,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    static func paletteColor(at t: Double) -> Color {
        let clamped = min(1, max(0, t))
        let stops: [(Double, Color)] = [
            (0.0, Color(red: 0.58, green: 0.28, blue: 0.92)),
            (0.28, Color(red: 0.34, green: 0.48, blue: 0.98)),
            (0.55, Color(red: 0.22, green: 0.82, blue: 0.88)),
            (0.78, Color(red: 0.95, green: 0.72, blue: 0.28)),
            (1.0, Color(red: 0.98, green: 0.42, blue: 0.55))
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

    private static func progressMix(_ bias: Double, speed: Double) -> Double {
        (bias * 0.65 + (speed * 0.08).truncatingRemainder(dividingBy: 1) * 0.35)
            .truncatingRemainder(dividingBy: 1)
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
        SoundRibbonView(frequency: $frequency, isInteractive: true)
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
