import SwiftUI

struct HSLColor: Equatable {
    var hue: Double
    var saturation: Double
    var lightness: Double

    var swiftUIColor: Color {
        let rgb = rgbComponents
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    var displayHue: String { String(format: "%.0f°", hue) }
    var displaySaturation: String { String(format: "%.0f%%", saturation) }
    var displayLightness: String { String(format: "%.0f%%", lightness) }

    var displaySummary: String {
        "\(displayHue) · \(displaySaturation) · \(displayLightness)"
    }

    /// `#RRGGBB` em maiúsculas, a partir da conversão RGB.
    var hex: String {
        let rgb = rgbComponents
        func byte(_ value: Double) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.r), byte(rgb.g), byte(rgb.b))
    }

    /// Texto escuro lê melhor por cima desta cor.
    var prefersDarkForeground: Bool {
        let rgb = rgbComponents
        return (0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b) > 0.55
    }

    static func randomEasy() -> HSLColor {
        HSLColor(
            hue: Double.random(in: 0...360),
            saturation: Double.random(in: 40...90),
            lightness: Double.random(in: 30...70)
        )
    }
}

enum RestGameScoring {
    static let frequencyRange: ClosedRange<Double> = 200...800
    static let memorizeDuration: TimeInterval = 3
    static let totalRounds = 5
    static let choiceCorrectScore: Double = 10
    static let pitchToneDuration: TimeInterval = 1
    static let pitchToneGap: TimeInterval = 0.4

    static func randomEasyFrequency() -> Double {
        let logMin = log2(frequencyRange.lowerBound)
        let logMax = log2(frequencyRange.upperBound)
        let randomLog = Double.random(in: logMin...logMax)
        return pow(2, randomLog)
    }

    static func colorScore(target: HSLColor, guess: HSLColor) -> Double {
        let deltaE = deltaE2000(target.rgb, guess.rgb)
        let score = 10 - (deltaE / 4.5)
        return min(10, max(0, score))
    }

    static func frequencyScore(target: Double, guess: Double) -> Double {
        guard target > 0, guess > 0 else { return 0 }
        let logDiff = abs(log2(target) - log2(guess))
        let score = 10 - (logDiff * 4.2)
        return min(10, max(0, score))
    }

    static func formattedScore(_ score: Double) -> String {
        String(format: "%.2f", score)
    }

    static func formattedFrequency(_ hz: Double) -> String {
        String(format: "%.0f Hz", hz)
    }

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Nota temperada mais próxima (A4 = 440 Hz), com sustenidos.
    static func noteName(for hz: Double) -> String {
        guard hz > 0 else { return "—" }
        let midi = Int((69 + 12 * log2(hz / 440)).rounded())
        let name = noteNames[((midi % 12) + 12) % 12]
        let octave = Int(floor(Double(midi) / 12)) - 1
        return "\(name)\(octave)"
    }

    /// Ex.: "440 Hz · A4"
    static func formattedFrequencyWithNote(_ hz: Double) -> String {
        "\(formattedFrequency(hz)) · \(noteName(for: hz))"
    }

    // MARK: - Choice rounds

    /// Alvo + 3 distratores para o round "Ler o hex", já embaralhados.
    /// Longe: matizes ≥ 60° do alvo e entre si. Perto: ~30–40° com variação de luminosidade.
    static func hexReadOptions(closeDistractors: Bool) -> (options: [HSLColor], correctIndex: Int) {
        // Faixa mais saturada que `randomEasy` para os matizes ficarem legíveis lado a lado.
        let target = HSLColor(
            hue: Double.random(in: 0..<360),
            saturation: Double.random(in: 55...85),
            lightness: Double.random(in: 40...60)
        )

        let distractors: [HSLColor]
        if closeDistractors {
            let side: Double = Bool.random() ? 1 : -1
            let near = Double.random(in: 30...40)
            let offsets: [(hue: Double, lightness: Double)] = [
                (side * near, Double.random(in: -6...6)),
                (-side * Double.random(in: 30...40), Double.random(in: -6...6)),
                (side * (near + Double.random(in: 30...40)), (Bool.random() ? 1 : -1) * 12)
            ]
            distractors = offsets.map { offset in
                HSLColor(
                    hue: wrappedHue(target.hue + offset.hue),
                    saturation: target.saturation,
                    lightness: min(70, max(30, target.lightness + offset.lightness))
                )
            }
        } else {
            var hues = [target.hue]
            var attempts = 0
            while hues.count < 4 && attempts < 200 {
                let candidate = Double.random(in: 0..<360)
                if hues.allSatisfy({ hueDistance($0, candidate) >= 60 }) {
                    hues.append(candidate)
                }
                attempts += 1
            }
            if hues.count < 4 {
                hues = [0, 90, 180, 270].map { wrappedHue(target.hue + $0) }
            }
            distractors = hues.dropFirst().map { hue in
                HSLColor(
                    hue: hue,
                    saturation: min(90, max(40, target.saturation + Double.random(in: -8...8))),
                    lightness: min(70, max(30, target.lightness + Double.random(in: -6...6)))
                )
            }
        }

        let options = ([target] + distractors).shuffled()
        return (options, options.firstIndex(of: target) ?? 0)
    }

    /// Dois tons separados por 3–7 semitons, em ordem aleatória, dentro da faixa do jogo.
    static func pitchPair() -> (frequencies: [Double], higherIndex: Int) {
        let ratio = pow(2, Double(Int.random(in: 3...7)) / 12)
        let logMin = log2(frequencyRange.lowerBound)
        let logMax = log2(frequencyRange.upperBound / ratio)
        let low = pow(2, Double.random(in: logMin...logMax))
        let high = low * ratio
        return Bool.random() ? ([high, low], 0) : ([low, high], 1)
    }

    private static func wrappedHue(_ hue: Double) -> Double {
        let wrapped = hue.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 8...: return .green
        case 5..<8: return .yellow
        default: return .red
        }
    }
}

private extension HSLColor {
    var rgbComponents: (r: Double, g: Double, b: Double) { rgb }

    var rgb: (r: Double, g: Double, b: Double) {
        let h = hue / 360
        let s = saturation / 100
        let l = lightness / 100

        guard s > 0 else {
            return (l, l, l)
        }

        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        return (
            hueToRGB(p, q, h + 1 / 3),
            hueToRGB(p, q, h),
            hueToRGB(p, q, h - 1 / 3)
        )
    }
}

private func deltaE2000(_ color1: (r: Double, g: Double, b: Double), _ color2: (r: Double, g: Double, b: Double)) -> Double {
    let lab1 = rgbToLab(color1)
    let lab2 = rgbToLab(color2)

    let l1 = lab1.l
    let a1 = lab1.a
    let b1 = lab1.b
    let l2 = lab2.l
    let a2 = lab2.a
    let b2 = lab2.b

    let avgL = (l1 + l2) / 2
    let c1 = sqrt(a1 * a1 + b1 * b1)
    let c2 = sqrt(a2 * a2 + b2 * b2)
    let avgC = (c1 + c2) / 2

    let g = 0.5 * (1 - sqrt(pow(avgC, 7) / (pow(avgC, 7) + pow(25, 7))))
    let a1Prime = (1 + g) * a1
    let a2Prime = (1 + g) * a2

    let c1Prime = sqrt(a1Prime * a1Prime + b1 * b1)
    let c2Prime = sqrt(a2Prime * a2Prime + b2 * b2)
    let avgCPrime = (c1Prime + c2Prime) / 2

    func atan2Degrees(_ y: Double, _ x: Double) -> Double {
        var angle = atan2(y, x) * 180 / .pi
        if angle < 0 { angle += 360 }
        return angle
    }

    let h1Prime = c1Prime == 0 ? 0 : atan2Degrees(b1, a1Prime)
    let h2Prime = c2Prime == 0 ? 0 : atan2Degrees(b2, a2Prime)

    var deltaHPrime: Double
    if c1Prime * c2Prime == 0 {
        deltaHPrime = 0
    } else if abs(h2Prime - h1Prime) <= 180 {
        deltaHPrime = h2Prime - h1Prime
    } else if h2Prime - h1Prime > 180 {
        deltaHPrime = h2Prime - h1Prime - 360
    } else {
        deltaHPrime = h2Prime - h1Prime + 360
    }

    let deltaLPrime = l2 - l1
    let deltaCPrime = c2Prime - c1Prime
    let deltaHPrimeValue = 2 * sqrt(c1Prime * c2Prime) * sin((deltaHPrime * .pi / 180) / 2)

    let sl = 1 + (0.015 * pow(avgL - 50, 2)) / sqrt(20 + pow(avgL - 50, 2))
    let sc = 1 + 0.045 * avgCPrime
    let sh = 1 + 0.015 * avgCPrime

    var deltaTheta = 30 * exp(-pow((h1Prime - h2Prime) / 2, 2) / pow(25, 2))
    if c1Prime * c2Prime == 0 {
        deltaTheta = 0
    }

    let rc = 2 * sqrt(pow(avgCPrime, 7) / (pow(avgCPrime, 7) + pow(25, 7)))
    let rt = -sin(2 * deltaTheta * .pi / 180) * rc

    let kl = 1.0
    let kc = 1.0
    let kh = 1.0

    let termL = deltaLPrime / (kl * sl)
    let termC = deltaCPrime / (kc * sc)
    let termH = deltaHPrimeValue / (kh * sh)

    return sqrt(termL * termL + termC * termC + termH * termH + rt * termC * termH)
}

private func rgbToLab(_ rgb: (r: Double, g: Double, b: Double)) -> (l: Double, a: Double, b: Double) {
    func pivot(_ value: Double) -> Double {
        value > 0.04045 ? pow((value + 0.055) / 1.055, 2.4) : value / 12.92
    }

    let r = pivot(rgb.r)
    let g = pivot(rgb.g)
    let b = pivot(rgb.b)

    let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    let y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
    let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    func f(_ t: Double) -> Double {
        t > 0.008856 ? pow(t, 1 / 3) : (7.787 * t) + (16 / 116)
    }

    let fx = f(x)
    let fy = f(y)
    let fz = f(z)

    return (
        (116 * fy) - 16,
        500 * (fx - fy),
        200 * (fy - fz)
    )
}
