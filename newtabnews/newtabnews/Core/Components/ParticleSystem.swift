//
//  ParticleSystem.swift
//  newtabnews
//
//  Created by Luiz Mello on 04/01/26.
//

import SwiftUI

// MARK: - Particle Model
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
    var color: Color
    var shape: ParticleShape
    var lifetime: TimeInterval
    var age: TimeInterval = 0
}

// MARK: - Particle Shape
public enum ParticleShape {
    case circle
    case square
    case triangle
    case star
    case heart
    case confetti
    
    @ViewBuilder
    func view(size: CGFloat) -> some View {
        switch self {
        case .circle:
            Circle()
                .frame(width: size, height: size)
        case .square:
            Rectangle()
                .frame(width: size, height: size)
        case .triangle:
            Triangle()
                .frame(width: size, height: size)
        case .star:
            Star()
                .frame(width: size, height: size)
        case .heart:
            Heart()
                .frame(width: size, height: size)
        case .confetti:
            RoundedRectangle(cornerRadius: 2)
                .frame(width: size * 0.4, height: size)
        }
    }
}

// MARK: - Custom Shapes
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5
        
        for i in 0..<points * 2 {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width * 0.5, y: height * 0.25))
        path.addCurve(
            to: CGPoint(x: 0, y: height * 0.25),
            control1: CGPoint(x: width * 0.5, y: 0),
            control2: CGPoint(x: 0, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: 0, y: height * 0.5),
            control2: CGPoint(x: width * 0.5, y: height * 0.75)
        )
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.25),
            control1: CGPoint(x: width * 0.5, y: height * 0.75),
            control2: CGPoint(x: width, y: height * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.25),
            control1: CGPoint(x: width, y: 0),
            control2: CGPoint(x: width * 0.5, y: 0)
        )
        return path
    }
}

// MARK: - Particle System Configuration
public struct ParticleSystemConfiguration {
    let particleCount: Int
    let shapes: [ParticleShape]
    let colors: [Color]
    let minSize: CGFloat
    let maxSize: CGFloat
    let minVelocity: CGFloat
    let maxVelocity: CGFloat
    let gravity: CGFloat
    let lifetime: TimeInterval
    let fadeOut: Bool
    let emissionAngle: ClosedRange<Double>
    
    public init(
        particleCount: Int = 50,
        shapes: [ParticleShape] = [.circle, .square, .triangle],
        colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange],
        minSize: CGFloat = 8,
        maxSize: CGFloat = 16,
        minVelocity: CGFloat = 100,
        maxVelocity: CGFloat = 300,
        gravity: CGFloat = 500,
        lifetime: TimeInterval = 3.0,
        fadeOut: Bool = true,
        emissionAngle: ClosedRange<Double> = -45...45
    ) {
        self.particleCount = particleCount
        self.shapes = shapes
        self.colors = colors
        self.minSize = minSize
        self.maxSize = maxSize
        self.minVelocity = minVelocity
        self.maxVelocity = maxVelocity
        self.gravity = gravity
        self.lifetime = lifetime
        self.fadeOut = fadeOut
        self.emissionAngle = emissionAngle
    }
    
    public static let confetti = ParticleSystemConfiguration(
        particleCount: 100,
        shapes: [.confetti],
        colors: [.red, .blue, .green, .yellow, .purple, .orange, .pink],
        minSize: 6,
        maxSize: 12,
        minVelocity: 200,
        maxVelocity: 400,
        gravity: 600,
        emissionAngle: -90...90
    )
    
    public static let hearts = ParticleSystemConfiguration(
        particleCount: 30,
        shapes: [.heart],
        colors: [.red, .pink],
        minSize: 12,
        maxSize: 24,
        minVelocity: 50,
        maxVelocity: 150,
        gravity: -100,
        lifetime: 4.0
    )
    
    public static let stars = ParticleSystemConfiguration(
        particleCount: 40,
        shapes: [.star],
        colors: [.yellow, .orange],
        minSize: 10,
        maxSize: 20,
        minVelocity: 100,
        maxVelocity: 250,
        gravity: 300
    )
}

// MARK: - Particle System View
public struct ParticleSystemView: View {
    let configuration: ParticleSystemConfiguration
    let origin: CGPoint
    
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    
    public init(
        configuration: ParticleSystemConfiguration = ParticleSystemConfiguration(),
        origin: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    ) {
        self.configuration = configuration
        self.origin = origin
    }
    
    public var body: some View {
        ZStack {
            ForEach(particles) { particle in
                particle.shape.view(size: particle.scale)
                    .foregroundStyle(particle.color)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(particle.opacity)
                    .position(particle.position)
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func generateParticles() {
        particles = (0..<configuration.particleCount).map { _ in
            let angle = Double.random(in: configuration.emissionAngle) * .pi / 180
            let speed = CGFloat.random(in: configuration.minVelocity...configuration.maxVelocity)
            
            return Particle(
                position: origin,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                ),
                scale: CGFloat.random(in: configuration.minSize...configuration.maxSize),
                rotation: Double.random(in: 0...360),
                opacity: 1.0,
                color: configuration.colors.randomElement() ?? .blue,
                shape: configuration.shapes.randomElement() ?? .circle,
                lifetime: configuration.lifetime
            )
        }
    }
    
    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updateParticles(deltaTime: 1/60)

            // Todas as partículas morreram: para o timer em vez de rodar a 60fps até o onDisappear
            if particles.isEmpty {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func updateParticles(deltaTime: TimeInterval) {
        particles = particles.compactMap { particle in
            var updatedParticle = particle
            updatedParticle.age += deltaTime
            
            // Remove dead particles
            if updatedParticle.age >= updatedParticle.lifetime {
                return nil
            }
            
            // Update position
            updatedParticle.position.x += updatedParticle.velocity.x * deltaTime
            updatedParticle.position.y += updatedParticle.velocity.y * deltaTime
            
            // Apply gravity
            updatedParticle.velocity.y += configuration.gravity * deltaTime
            
            // Update rotation
            updatedParticle.rotation += 180 * deltaTime
            
            // Fade out
            if configuration.fadeOut {
                let lifetimeProgress = updatedParticle.age / updatedParticle.lifetime
                updatedParticle.opacity = 1.0 - lifetimeProgress
            }
            
            return updatedParticle
        }
    }
}

// MARK: - Button Position Preference Key
struct ButtonPositionPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - Particle Emitter Modifier
public struct ParticleEmitterModifier: ViewModifier {
    let configuration: ParticleSystemConfiguration
    @Binding var isEmitting: Bool
    
    @State private var emitterOrigin: CGPoint = .zero
    
    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ButtonPositionPreferenceKey.self,
                        value: CGPoint(
                            x: geometry.frame(in: .global).midX,
                            y: geometry.frame(in: .global).midY
                        )
                    )
                }
            )
            .onPreferenceChange(ButtonPositionPreferenceKey.self) { position in
                emitterOrigin = position
            }
            .overlay(
                Group {
                    if isEmitting {
                        ParticleSystemView(
                            configuration: configuration,
                            origin: emitterOrigin
                        )
                        .allowsHitTesting(false)
                    }
                }
            )
    }
}

extension View {
    public func particleEmitter(
        configuration: ParticleSystemConfiguration = .confetti,
        isEmitting: Binding<Bool>
    ) -> some View {
        modifier(ParticleEmitterModifier(configuration: configuration, isEmitting: isEmitting))
    }
}

