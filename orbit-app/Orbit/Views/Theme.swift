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
            .background {
                // Clicks in the padding land here (the text field gets its
                // own clicks), and focus the field.
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.space.opacity(0.75))
                    .onTapGesture { isFocused = true }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(border, lineWidth: isFocused || isInvalid ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
            // The text field only sets the I-beam over its text, so own the
            // cursor for the padding too: otherwise leaving through the
            // padding leaves the I-beam stuck until another view resets it.
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .pointerStyle(.horizontalText)
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
    @Environment(\.appearsActive) private var appearsActive

    /// Orbit stays open all day, so only animate while it's the active app.
    /// The frame rate isn't capped: a cap that doesn't divide the display's
    /// refresh rate makes the planets judder.
    private var isMoving: Bool {
        animated && !reduceMotion && appearsActive
    }

    var body: some View {
        ZStack {
            // Painted once; only the planets below move each frame.
            OrbitMarkSystem(size: size)
            TimelineView(.animation(paused: !isMoving)) { timeline in
                // Paused, the timeline keeps its last date, so the planets
                // stop where they are instead of jumping back.
                planets(time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Laid out on the same 80-point grid as `OrbitMarkSystem`. Each planet
    /// sits at a fixed distance from its center and its whole orbit is rotated:
    /// rotation isn't rounded to the pixel grid the way moving a view is, so
    /// even the slow outer planet glides instead of stepping a pixel at a time.
    private func planets(time: Double) -> some View {
        let s = size / 80

        return ZStack {
            Circle().fill(Theme.aurora)
                .frame(width: 7.2 * s, height: 7.2 * s)
                .offset(x: 20 * s)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-35 + time * 60))

            ZStack {
                Circle().fill(Theme.planet)
                    .frame(width: 9.2 * s, height: 9.2 * s)
                Circle().fill(Theme.moon)
                    .frame(width: 3.4 * s, height: 3.4 * s)
                    .offset(x: 8 * s)
                    .frame(width: 20 * s, height: 20 * s)
                    .rotationEffect(.degrees(time * 120))
            }
            .frame(width: 20 * s, height: 20 * s)
            .offset(x: 30 * s)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(130 + time * 360 / 14))
        }
    }
}

/// The logo's still parts: orbit rings, glow and sun. Drawn on a 64-point grid,
/// matching orbit-web/app/components/OrbitLogo.vue, with 8 points of margin on
/// every side: the outer planet and its moon swing out to about 40 points from
/// the center.
private struct OrbitMarkSystem: View, Equatable {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 80
            let center = CGPoint(x: 40 * s, y: 40 * s)

            func disc(_ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }

            for radius: CGFloat in [30, 20] {
                context.stroke(disc(radius * s), with: .color(.white.opacity(0.18)), lineWidth: 1.4 * s)
            }
            context.fill(
                disc(15 * s),
                with: .radialGradient(
                    Gradient(colors: [Theme.sun.opacity(0.55), Theme.sun.opacity(0)]),
                    center: center, startRadius: 0, endRadius: 15 * s
                )
            )
            context.fill(
                disc(8.5 * s),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(hex: 0xFFE6A8), location: 0),
                        .init(color: Color(hex: 0xFFB26B), location: 0.45),
                        .init(color: Color(hex: 0xFF6B4A), location: 1),
                    ]),
                    center: CGPoint(x: center.x - 2 * s, y: center.y - 2 * s), startRadius: 0, endRadius: 12 * s
                )
            )
        }
        .frame(width: size, height: size)
    }
}
