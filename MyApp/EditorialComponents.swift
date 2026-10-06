import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Imagery

/// Fills its proposed frame with the asset named by `art.image`, or a generative placeholder.
/// Decorative by default; the enclosing element supplies the accessibility label.
struct ArtView: View {
    let art: Art
    /// Vertical scroll parallax as a fraction of the frame height (0 = none). The image moves slower
    /// than its frame as the page scrolls, and is overscanned so edges never show.
    var parallax: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let amount = reduceMotion ? 0 : parallax
        Color.clear
            .overlay {
                image
                    .scaleEffect(1 + amount * 2)
                    .visualEffect { content, proxy in
                        guard amount > 0, let page = proxy.bounds(of: .scrollView(axis: .vertical)) else { return content.offset(y: 0) }
                        let midY = proxy.frame(in: .scrollView(axis: .vertical)).midY
                        let travel = max(-1, min(1, (midY - page.height / 2) / page.height))
                        return content.offset(y: -travel * amount * proxy.size.height)
                    }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    @ViewBuilder private var image: some View {
        if let name = art.image, Self.assetExists(name) {
            Image(name).resizable().scaledToFill()
        } else {
            GenerativeArt(art: art)
        }
    }

    static func assetExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #else
        NSImage(named: name) != nil
        #endif
    }
}

/// Bottom-weighted legibility scrim for fixed-white text over photography.
struct ImageScrim: View {
    var strength: Double = 0.85

    var body: some View {
        LinearGradient(
            colors: [M.proposedOverlayScrim.opacity(0), M.proposedOverlayScrim.opacity(strength)],
            startPoint: .center,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

/// Placeholder used only when a photo asset is missing. Colours come from content data, not UI tokens.
struct GenerativeArt: View {
    let art: Art

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let j = art.jitter

            ZStack {
                LinearGradient(colors: art.colors, startPoint: .top, endPoint: .bottom)
                Image(systemName: art.symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(height: h * 0.74)
                    .foregroundStyle(.black.opacity(0.3))
                    .offset(x: j * w * 0.35, y: h * 0.16)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Headers & labels

/// One corner radius for every card and photo frame in the Editorial tab.
enum EditorialCard {
    static let radius = BackstageTokens.Responsive.cornerRadiusCorner12
    static let shape = RoundedRectangle(cornerRadius: radius)
}

/// Section opener: a numbered hairline rule, then a tight, lowercase display headline.
struct SectionHeader: View {
    let number: Int
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace8) {
                Text(String(format: "%02d", number))
                    .backstageText(.specialTitle)
                    .foregroundStyle(M.textTertiary)
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(M.iconTertiary)
            }
            .accessibilityHidden(true)

            EditorialHeadline(lines: lines, size: DisplaySize.section, kinetic: true)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.spacingSpace16)
    }
}

/// Magazine-cover section opener: the numbered rule, then a high-contrast italic serif phrase set
/// over a towering condensed uppercase line (DM Serif Display Italic over Anton).
struct CoverHeader: View {
    let number: Int
    /// The italic serif lead-in, e.g. "fits for".
    let lead: String
    /// The big condensed line, e.g. "every plan".
    let headline: String
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace8) {
                Text(String(format: "%02d", number))
                    .backstageText(.specialTitle)
                    .foregroundStyle(M.textTertiary)
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(M.iconTertiary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: -10 * scale) {
                Text(lead)
                    .font(.custom("DMSerifDisplay-Italic", fixedSize: 30 * scale))
                    .foregroundStyle(M.textPurple)
                    .padding(.leading, 2)
                    .zIndex(1)
                    .modifier(KineticLine(index: 0))
                Text(headline.uppercased())
                    .font(.custom("Anton-Regular", fixedSize: 54 * scale))
                    .tracking(0.5)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .modifier(KineticLine(index: 1))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(lead) \(headline)")
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.spacingSpace16)
    }
}

/// Hairline rule with a centred ornament, used to frame interludes.
struct OrnamentRule: View {
    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(M.iconTertiary)
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
        }
        .accessibilityHidden(true)
    }
}

/// Printer's crop marks just outside each corner of the view.
struct CropMarks: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let gap: CGFloat = 4, len: CGFloat = 10
            Path { p in
                for (x, y, sx, sy) in [(0.0, 0.0, -1.0, -1.0), (w, 0.0, 1.0, -1.0), (0.0, h, -1.0, 1.0), (w, h, 1.0, 1.0)] {
                    p.move(to: CGPoint(x: x + sx * gap, y: y))
                    p.addLine(to: CGPoint(x: x + sx * (gap + len), y: y))
                    p.move(to: CGPoint(x: x, y: y + sy * gap))
                    p.addLine(to: CGPoint(x: x, y: y + sy * (gap + len)))
                }
            }
            .stroke(M.borderIntense, lineWidth: R.stroke1Px)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func cropMarks() -> some View { overlay { CropMarks() } }
}

/// Dotted leader line, as in a table of contents.
struct DottedLeader: View {
    var body: some View {
        LeaderLine()
            .stroke(M.borderModerate, style: StrokeStyle(lineWidth: R.stroke1Px, lineCap: .round, dash: [1, 5]))
            .frame(height: R.stroke1Px)
            .accessibilityHidden(true)
    }

    private struct LeaderLine: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            return p
        }
    }
}

/// Solid circular arrow affordance (visual only; the enclosing element is the control).
struct CircleArrow: View {
    var systemName = "chevron.right"
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.32, weight: .bold))
            .foregroundStyle(M.buttonPrimaryIcon)
            .frame(width: size, height: size)
            .background(M.buttonPrimaryBackground, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Donut of palette segments. Swatch colours are content data.
struct PaletteWheel: View {
    let hexes: [UInt32]
    var lineWidth: CGFloat = 16

    var body: some View {
        let n = CGFloat(hexes.count)
        ZStack {
            ForEach(hexes.indices, id: \.self) { i in
                Circle()
                    .trim(from: CGFloat(i) / n, to: CGFloat(i + 1) / n)
                    .stroke(Color(hex: hexes[i]), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

/// Square brand logo tile placed on photography: the brand's logo picture when it is bundled
/// (Assets › Logos › logo_<brand>), otherwise its text mark.
struct BrandMark: View {
    let brand: String
    let mark: String
    var size: CGFloat = 40

    /// Logos that are already square app-icon artwork and fill the tile edge to edge.
    private static let fullBleed: Set<String> = ["logo_bonkers_corner", "logo_snitch", "logo_the_souled_store"]
    /// White logos that need a dark tile.
    private static let onDark: Set<String> = ["logo_nicobar"]

    private var asset: String {
        "logo_" + brand.lowercased()
            .replacingOccurrences(of: "&", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "_")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: R.cornerRadiusCorner8)
        Group {
            if ArtView.assetExists(asset) {
                if Self.fullBleed.contains(asset) {
                    Image(asset).resizable().scaledToFill()
                } else {
                    Image(asset).resizable().scaledToFit()
                        .padding(size * 0.16)
                }
            } else {
                Text(mark)
                    .backstageText(.label3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    // Fit the square, but never below 10pt (label 3 is 12pt).
                    .minimumScaleFactor(10 / 12)
                    .foregroundStyle(M.textInverse)
                    .padding(R.spacingSpace4)
            }
        }
        .frame(width: size, height: size)
        .background(Self.onDark.contains(asset) && ArtView.assetExists(asset) ? M.textBlack : M.surfaceInverse)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

// MARK: - Floating controls

struct GlassIconButton: View {
    let systemName: String
    let label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .liquidGlass(in: Circle(), interactive: true, clear: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Endless horizontally scrolling content; static when Reduce Motion is on.
struct Marquee<Content: View>: View {
    var speed: Double = 36
    /// Scrolls left to right instead of right to left.
    var reversed = false
    @ViewBuilder let content: () -> Content
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let travel = width > 0 && !reduceMotion ? CGFloat((t * speed).truncatingRemainder(dividingBy: Double(width))) : 0
            HStack(spacing: 0) {
                content().fixedSize().background(
                    GeometryReader { g in Color.clear.onAppear { width = g.size.width } }
                )
                content().fixedSize()
                content().fixedSize()
            }
            .offset(x: reversed ? travel - width : -travel)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Shop-the-look

struct HotspotPin: View {
    let spot: Hotspot
    let isActive: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if !reduceMotion && !isActive {
                    Circle()
                        .stroke(M.iconWhite, lineWidth: R.stroke1Px)
                        .frame(width: 28, height: 28)
                        .phaseAnimator([false, true]) { ring, expanded in
                            ring.scaleEffect(expanded ? 1.8 : 1).opacity(expanded ? 0 : 1)
                        } animation: { expanded in
                            expanded ? .easeOut(duration: 1.6) : .linear(duration: 0)
                        }
                }
                Color.clear
                    .frame(width: 28, height: 28)
                    .liquidGlass(in: Circle(), interactive: true)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(M.iconPrimary)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spot.item)
        .accessibilityValue(spot.price)
        .accessibilityHint("Shows ways to buy this piece")
    }
}

// MARK: - Dominant colour

/// Extracts a vivid dominant colour from a photo for ambient glows. Results are cached per asset.
/// The colour is derived from content imagery, not a UI token.
@MainActor
enum DominantColor {
    private static var cache: [String: Color] = [:]

    static func of(_ art: Art) -> Color {
        let key = art.image ?? "seed-\(art.seed)"
        if let hit = cache[key] { return hit }
        let colour = art.image.flatMap(extract) ?? art.colors.dropFirst().first ?? art.colors[0]
        cache[key] = colour
        return colour
    }

    private static func extract(_ name: String) -> Color? {
        guard let image = cgImage(named: name) else { return nil }
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Hue histogram weighted by saturation × brightness, ignoring near-greys and shadows.
        let bins = 12
        var weight = [Double](repeating: 0, count: bins)
        var sums = [(h: Double, s: Double, v: Double)](repeating: (0, 0, 0), count: bins)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let (h, s, v) = hsv(Double(pixels[i]) / 255, Double(pixels[i + 1]) / 255, Double(pixels[i + 2]) / 255)
            guard s > 0.18, v > 0.2 else { continue }
            let w = s * v
            let b = min(bins - 1, Int(h * Double(bins)))
            weight[b] += w
            sums[b].h += h * w; sums[b].s += s * w; sums[b].v += v * w
        }
        guard let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 0 else {
            return Color(hue: 0, saturation: 0, brightness: 0.55)
        }
        let w = weight[best]
        return Color(hue: sums[best].h / w, saturation: max(0.5, min(0.85, sums[best].s / w * 1.2)), brightness: 0.8)
    }

    private static func hsv(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        var h = 0.0
        if delta > 0 {
            if maxC == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, maxC == 0 ? 0 : delta / maxC, maxC)
    }

    private static func cgImage(named name: String) -> CGImage? {
        #if canImport(UIKit)
        UIImage(named: name)?.cgImage
        #else
        NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}
