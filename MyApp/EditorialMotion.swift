import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Sections & scroll tracking

/// Page sections, listed in the colophon's contents and used as scroll targets.
enum EditorialSection: Int, CaseIterable, Hashable {
    case stories, rack, staples, looks, /* plans, */ vibes, palette

    var title: String {
        switch self {
        case .stories: "Homegrown & unfiltered"
        case .rack: "Hot off the rack"
        case .staples: "What goes well with?"
        case .looks: "Cop these looks"
        // case .plans: "Fits for every plan"
        case .vibes: "Fits for every plan"
        case .palette: "Pick your palette"
        }
    }
}

private struct ViewportHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 800
}

extension EnvironmentValues {
    /// Height of the visible page, for scroll-linked effects.
    var editorialViewport: CGFloat {
        get { self[ViewportHeightKey.self] }
        set { self[ViewportHeightKey.self] = newValue }
    }
}

// MARK: - Reveal on scroll

private struct RevealOnScroll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let lift: CGFloat = reduceMotion ? 0 : 48
        let fade: Double = reduceMotion ? 0 : 0.85
        content.scrollTransition(.interactive.threshold(.visible(0.2)), axis: .vertical) { view, phase in
            // Only animate on the way in from below; sections leaving the top stay put.
            let entering = phase == .bottomTrailing ? phase.value : 0
            return view
                .opacity(1 - entering * fade)
                .offset(y: entering * lift)
                .scaleEffect(1 - entering * 0.04, anchor: .top)
        }
    }
}

/// Staggered slide-up for one line of a headline as it enters.
struct KineticLine: ViewModifier {
    let index: Int
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let travel: CGFloat = reduceMotion || !enabled ? 0 : CGFloat(22 + index * 16)
        content.scrollTransition(.interactive, axis: .vertical) { line, phase in
            let entering = phase == .bottomTrailing ? phase.value : 0
            return line
                .offset(y: entering * travel)
                .opacity(travel == 0 ? 1 : 1 - entering)
        }
    }
}

extension View {
    func revealOnScroll() -> some View { modifier(RevealOnScroll()) }
}

// MARK: - Spotlight

/// Neutral grey stage spotlight hung above the page: a soft beam that sways with scroll and
/// dims as you read deeper.
struct Spotlight: View {
    let scrollY: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let depth = min(1, max(0, -scrollY / 900))
            let sway = reduceMotion ? 0 : sin(Double(-scrollY) / 280) * 8
            let light = M.iconWhite

            ZStack(alignment: .top) {
                // Halo around the light source.
                RadialGradient(
                    colors: [light.opacity(0.09), light.opacity(0.025), light.opacity(0)],
                    center: .top, startRadius: 0, endRadius: w * 0.9
                )
                .frame(height: w * 1.2)

                // The beam.
                BeamShape()
                    .fill(LinearGradient(colors: [light.opacity(0.08), light.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.9, height: w * 1.2)
                    .blur(radius: 28)
                    .rotationEffect(.degrees(sway), anchor: .top)

                // Hot spot where the light originates.
                Ellipse()
                    .fill(light.opacity(0.18))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 20)
                    .offset(y: -12)
            }
            .frame(width: w, height: g.size.height, alignment: .top)
            .opacity(1 - depth * 0.6)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BeamShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * 0.05, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.05, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Drifting background word

// MARK: - Dot field

/// The tab's backdrop: a faint print grid of dots, with a "+" registration mark at every fifth
/// intersection. Dots under the spotlight glow a touch brighter, and the grid drifts slower than the
/// content for a sense of depth (still under Reduce Motion).
struct DotField: View {
    let scrollY: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let step: CGFloat = 20
    private let markEvery = 5
    private let baseAlpha = 0.05
    private let litAlpha = 0.2

    var body: some View {
        Canvas { context, size in
            let period = step * CGFloat(markEvery)
            let drift = reduceMotion ? 0 : (scrollY * 0.25).truncatingRemainder(dividingBy: period)
            let depth = min(1, max(0, -scrollY / 900))
            let lightRadius = size.width * 1.1
            let colour = M.textPrimary

            // Group dots by brightness so each level is a single fill.
            let levels = 8
            var dots = [Path](repeating: Path(), count: levels)
            var marks = [Path](repeating: Path(), count: levels)

            let x0 = (size.width.truncatingRemainder(dividingBy: step)) / 2
            let columns = Int(size.width / step) + 1
            let rows = Int((size.height + period * 2) / step) + 1

            for row in 0..<rows {
                let y = drift - period + CGFloat(row) * step
                guard y > -step, y < size.height + step else { continue }
                for col in 0..<columns {
                    let x = x0 + CGFloat(col) * step
                    let distance = hypot(x - size.width / 2, y)
                    let falloff = max(0, 1 - distance / lightRadius)
                    let lit = falloff * falloff * (1 - depth * 0.6)
                    let level = min(levels - 1, Int(lit * Double(levels)))

                    if row % markEvery == 0, col % markEvery == 0 {
                        let arm: CGFloat = 3
                        marks[level].move(to: CGPoint(x: x - arm, y: y))
                        marks[level].addLine(to: CGPoint(x: x + arm, y: y))
                        marks[level].move(to: CGPoint(x: x, y: y - arm))
                        marks[level].addLine(to: CGPoint(x: x, y: y + arm))
                    } else {
                        let r = 0.7 + lit * 0.5
                        dots[level].addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    }
                }
            }

            for level in 0..<levels {
                let alpha = baseAlpha + litAlpha * Double(level) / Double(levels - 1)
                context.fill(dots[level], with: .color(colour.opacity(alpha)))
                context.stroke(marks[level], with: .color(colour.opacity(alpha * 1.5)), lineWidth: 0.75)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
