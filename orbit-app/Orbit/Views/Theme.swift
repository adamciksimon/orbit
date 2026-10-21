//
//  Theme.swift
//  Orbit
//

import SwiftUI

/// Orbit's "space" palette, shared with the website (orbit-web/app/assets/css/main.css).
enum Theme {
    static let space = Color(hex: 0x0B0A14)
    static let spaceHigh = Color(hex: 0x1C1930)
    static let card = Color(hex: 0x1A1726)

    static let sun = Color(hex: 0xFF8A5B)
    static let planet = Color(hex: 0x8F88FF)
    static let aurora = Color(hex: 0x5EF0C0)
    static let moon = Color(hex: 0xFFB3C7)

    /// The color of a project's planet in the sidebar.
    static func planetColor(for id: Int) -> Color {
        let colors = [sun, aurora, planet, moon]
        return colors[abs(id - 1) % colors.count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Background

/// Deep violet sky with faint stars, a warm and a cool haze, and two orbit
/// rings, like the website's hero.
struct SpaceBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Theme.spaceHigh, Theme.space], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    colors: [Theme.sun.opacity(0.12), .clear],
                    center: UnitPoint(x: 0.9, y: 0.0), startRadius: 0, endRadius: 560
                )
                RadialGradient(
                    colors: [Theme.planet.opacity(0.12), .clear],
                    center: UnitPoint(x: 0.05, y: 1.0), startRadius: 0, endRadius: 520
                )
                Starfield()

                Circle()
                    .strokeBorder(Theme.sun.opacity(0.10), lineWidth: 1)
                    .frame(width: 900, height: 900)
                    .position(x: geometry.size.width + 140, y: -180)
                Circle()
                    .strokeBorder(Theme.planet.opacity(0.10), lineWidth: 1)
                    .frame(width: 760, height: 760)
                    .position(x: -220, y: geometry.size.height + 160)
            }
        }
        .ignoresSafeArea()
    }
}

/// Stars at fixed relative positions, so resizing the window stretches the sky
/// instead of reshuffling it.
private struct Starfield: View {
    private struct Star {
        var x: Double
        var y: Double
        var radius: Double
        var opacity: Double
    }

    private static let stars: [Star] = {
        var generator = SeededGenerator(seed: 0x0B17)
        return (0..<160).map { _ in
            Star(
                x: .random(in: 0...1, using: &generator),
                y: .random(in: 0...1, using: &generator),
                radius: .random(in: 0.4...1.1, using: &generator),
                opacity: .random(in: 0.12...0.55, using: &generator)
            )
        }
    }()

    var body: some View {
        Canvas { context, size in
            for star in Self.stars {
                let rect = CGRect(
                    x: star.x * size.width - star.radius,
                    y: star.y * size.height - star.radius,
                    width: star.radius * 2,
                    height: star.radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))
            }
        }
    }
}

/// SplitMix64, so the starfield looks the same on every launch.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Fields

extension View {
    /// A text field on a dark violet fill that lights up periwinkle while
    /// focused, or coral when its value is invalid.
    func spaceField(isInvalid: Bool = false) -> some View {
        modifier(SpaceField(isInvalid: isInvalid))
    }
}

private struct SpaceField: ViewModifier {
    let isInvalid: Bool

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        let border: Color = isInvalid ? Theme.sun : isFocused ? Theme.planet : .white.opacity(0.1)

        content
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.space.opacity(0.75), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(border, lineWidth: isFocused || isInvalid ? 1.5 : 1)
            }
            .shadow(color: isFocused ? Theme.planet.opacity(0.35) : .clear, radius: 6)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Logo

/// The orbit logo from the website: a sun with two orbiting planets and a moon.
struct OrbitMark: View {
    var size: CGFloat = 64
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !animated || reduceMotion)) { timeline in
            let time = animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, canvasSize in
                draw(in: &context, size: canvasSize.width, time: time)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Drawn on a 64-point grid, matching orbit-web/app/components/OrbitLogo.vue,
    /// with 8 points of margin on every side: the outer planet and its moon
    /// swing out to about 40 points from the center.
    private func draw(in context: inout GraphicsContext, size: CGFloat, time: Double) {
        let s = size / 80
        let center = CGPoint(x: 40 * s, y: 40 * s)

        func disc(_ point: CGPoint, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
        func orbit(_ radius: CGFloat, degrees: Double, around point: CGPoint) -> CGPoint {
            let angle = degrees * .pi / 180
            return CGPoint(x: point.x + cos(angle) * radius, y: point.y + sin(angle) * radius)
        }

        for radius: CGFloat in [30, 20] {
            context.stroke(disc(center, radius * s), with: .color(.white.opacity(0.18)), lineWidth: 1.4 * s)
        }

        context.fill(
            disc(center, 15 * s),
            with: .radialGradient(
                Gradient(colors: [Theme.sun.opacity(0.55), Theme.sun.opacity(0)]),
                center: center, startRadius: 0, endRadius: 15 * s
            )
        )
        context.fill(
            disc(center, 8.5 * s),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: 0xFFE6A8), location: 0),
                    .init(color: Color(hex: 0xFFB26B), location: 0.45),
                    .init(color: Color(hex: 0xFF6B4A), location: 1),
                ]),
                center: CGPoint(x: center.x - 2 * s, y: center.y - 2 * s), startRadius: 0, endRadius: 12 * s
            )
        )

        let inner = orbit(20 * s, degrees: -35 + time * 60, around: center)
        context.fill(disc(inner, 3.6 * s), with: .color(Theme.aurora))

        let outer = orbit(30 * s, degrees: 130 + time * 360 / 14, around: center)
        context.fill(disc(outer, 4.6 * s), with: .color(Theme.planet))
        context.fill(disc(orbit(8 * s, degrees: time * 120, around: outer), 1.7 * s), with: .color(Theme.moon))
    }
}
