import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Virtual try-on education on the store page. Try-on itself only starts from a piece's full-screen
/// view, so the store page teaches it inside the catalogue: a leading card in the rail opens a sheet that shows what
/// try-on does, where to find it ("Try it on" on any piece), and sends people into the catalogue.
/// Visual language follows the AI VTO Figma (SDP file, section 21886:10926): graphite, a
/// champagne-edged arch, twinkling stars, a silver title and a white pill.
enum VTOStyle {
    /// The Figma's champagne arch edge (#FFEED1).
    static let champagne = Color(rgba: 0xFFEED1FF)
    static let page = Color(rgba: 0x131316FF)
    static let graphite = Color(rgba: 0x1E1E20FF)
    /// The silver title fill: text primary to #919191.
    static let silver = LinearGradient(colors: [Color(rgba: 0xF7F7F7FF), Color(rgba: 0xB4B4B8FF)], startPoint: .top, endPoint: .bottom)
    /// The studio backdrop behind the try-on looks.
    static let studio = LinearGradient(colors: [Color(rgba: 0x5E5A6EFF), Color(rgba: 0xE4DFEEFF)], startPoint: .top, endPoint: .bottom)
    static let looks = ["vto_edu_look_1", "vto_edu_look_2", "vto_edu_look_3"]
}

// MARK: - The morph

/// The same person in one outfit after another: a chrome scan line sweeps down and leaves the next
/// look behind it, the way the try-on dresses your photo. Still on the first look with Reduce Motion.
struct TryOnLookMorph: View {
    var hold: Double = 1.6
    var sweep: Double = 1.1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let cycle = hold + sweep
            let t = context.date.timeIntervalSinceReferenceDate
            let step = Int(t / cycle)
            let phase = t.truncatingRemainder(dividingBy: cycle)
            let raw = reduceMotion ? 0 : max(0, min(1, (phase - hold) / sweep))
            // Ease in and out so the line settles at the hem.
            let p = raw < 0.5 ? 2 * raw * raw : 1 - pow(-2 * raw + 2, 2) / 2
            let now = VTOStyle.looks[step % VTOStyle.looks.count]
            let next = VTOStyle.looks[(step + 1) % VTOStyle.looks.count]
            GeometryReader { g in
                let y = g.size.height * p
                ZStack(alignment: .top) {
                    look(now)
                    look(next)
                        .mask(alignment: .top) { Rectangle().frame(height: y) }
                    if raw > 0 && raw < 1 {
                        ScanBeam()
                            .frame(height: 56)
                            .offset(y: y - 56)
                    }
                }
                .frame(width: g.size.width, height: g.size.height)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func look(_ name: String) -> some View {
        VTOStyle.studio
            .overlay(alignment: .top) {
                Image(name).resizable().scaledToFill()
            }
            .clipped()
    }
}

/// The chrome line with a soft light trailing above it.
struct ScanBeam: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.28)], startPoint: .top, endPoint: .bottom)
            Rectangle()
                .fill(LinearGradient(colors: [.white.opacity(0.2), .white, VTOStyle.champagne, .white, .white.opacity(0.2)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .shadow(color: .white.opacity(0.9), radius: 6)
        }
        .allowsHitTesting(false)
    }
}

/// The Figma arch: a full semicircle on top, softly rounded at the foot.
func archShape(width: CGFloat, foot: CGFloat) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(topLeadingRadius: width / 2, bottomLeadingRadius: foot, bottomTrailingRadius: foot,
                           topTrailingRadius: width / 2, style: .continuous)
}

/// A star from the Figma that slowly breathes.
struct Twinkle: View {
    let asset: String
    let size: CGFloat
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(asset)
            .resizable()
            .frame(width: size, height: size)
            .phaseAnimator(reduceMotion ? [true] : [false, true]) { star, lit in
                star.opacity(lit ? 1 : 0.35).scaleEffect(lit ? 1 : 0.7)
            } animation: { lit in .easeInOut(duration: lit ? 1.1 : 1.4).delay(lit ? delay : 0) }
            .accessibilityHidden(true)
    }
}

// MARK: - Store page catalogue

/// The Figma onboarding's faint grid, fading out from the spotlight.
struct FigmaGrid: View {
    var spacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// Every so often a chrome scan line runs down a catalogue's collage, the same line that dresses
/// your photo in try-on, so the pieces quietly read as try-able. Nothing moves with Reduce Motion.
struct TryOnCollageSweep: View {
    var every: Double = 5.5
    var sweep: Double = 1.3
    /// Offsets cards so their lines don't run together.
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = (context.date.timeIntervalSinceReferenceDate + delay).truncatingRemainder(dividingBy: every)
            let raw = min(1, phase / sweep)
            let p = raw < 0.5 ? 2 * raw * raw : 1 - pow(-2 * raw + 2, 2) / 2
            GeometryReader { g in
                if !reduceMotion && raw < 1 {
                    ScanBeam()
                        .frame(height: 64)
                        .offset(y: (g.size.height + 64) * p - 64)
                        .opacity(sin(.pi * raw))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "Try these on you" inside the catalogue section: a heading and three step cards made from this
/// store's own pieces (open a piece, add your photo, see it on you). The steps light up in turn
/// so the order reads at a glance; the whole block opens the guide.
struct TryOnCatalogueSteps: View {
    /// A piece from this store's catalogue, shown in the first step.
    let piece: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stepHeight: CGFloat = 132
    private static let beat: Double = 1.8

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                header
                TimelineView(.animation(minimumInterval: 0.1, paused: reduceMotion)) { context in
                    let lit = reduceMotion ? -1 : Int(context.date.timeIntervalSinceReferenceDate / Self.beat) % 3
                    HStack(alignment: .top, spacing: R.spacingSpace8) {
                        step(1, "Open any\npiece", lit: lit == 0) { pieceArt }
                        step(2, "Add your\nphoto", lit: lit == 1) { photoArt }
                        step(3, "See it\non you", lit: lit == 2) { TryOnLookMorph(hold: 1.6, sweep: 1.1) }
                    }
                    .animation(.easeInOut(duration: 0.4), value: lit)
                }
            }
            .padding(R.spacingSpace16)
            .background(card)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New: try these pieces on you. Open any piece, add your photo, and see it on you.")
        .accessibilityHint("Shows how virtual try-on works")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: R.spacingSpace8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Try these on you")
                        .dropFont("SemiBold", 16, relativeTo: .headline)
                        .tracking(-0.16)
                        .foregroundStyle(VTOStyle.silver)
                    Text("New")
                        .dropFont("Medium", 9, relativeTo: .caption2)
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(VTOStyle.champagne)
                        .padding(.horizontal, 6)
                        .frame(height: 16)
                        .overlay(Capsule().strokeBorder(VTOStyle.champagne.opacity(0.5), lineWidth: 0.6))
                }
                Text("Every piece in this catalogue works with virtual try-on")
                    .dropFont("Regular", 12, relativeTo: .caption)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Text("How it works")
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
            }
            .font(.custom("BeVietnamPro-SemiBold", size: 12, relativeTo: .caption))
            .foregroundStyle(VTOStyle.champagne)
            .padding(.top, 3)
        }
    }

    private func step<Art: View>(_ n: Int, _ title: String, lit: Bool, @ViewBuilder art: () -> Art) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(alignment: .leading, spacing: R.spacingSpace8) {
            art()
                .frame(maxWidth: .infinity)
                .frame(height: Self.stepHeight)
                .background(VTOStyle.studio)
                .clipShape(shape)
                .overlay(shape.strokeBorder(lit ? VTOStyle.champagne : .white.opacity(0.1), lineWidth: lit ? 1.2 : 0.6))
                .shadow(color: VTOStyle.champagne.opacity(lit ? 0.35 : 0), radius: 10)
                .scaleEffect(lit ? 1.02 : 1)
            HStack(alignment: .top, spacing: 6) {
                Text("\(n)")
                    .dropFont("SemiBold", 10, relativeTo: .caption2)
                    .foregroundStyle(lit ? VTOStyle.page : M.textPrimary)
                    .frame(width: 16, height: 16)
                    .background(lit ? AnyShapeStyle(VTOStyle.champagne) : AnyShapeStyle(.white.opacity(0.12)), in: Circle())
                Text(title)
                    .dropFont("Medium", 12, relativeTo: .caption)
                    .foregroundStyle(lit ? M.textPrimary : M.textSecondary)
                    .lineSpacing(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Step one: a piece from this store with the real "Try it on" cue on it.
    private var pieceArt: some View {
        Color.clear
            .overlay { Image(piece).resizable().scaledToFill() }
            .clipped()
            .overlay(alignment: .bottom) {
                HStack(spacing: 3) {
                    Image("vtf_pill_sparkle").resizable().frame(width: 9, height: 9)
                    Text("Try it on").dropFont("SemiBold", 9, relativeTo: .caption2).foregroundStyle(.white)
                }
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Color.black.opacity(0.55), in: Capsule())
                .overlay(Capsule().strokeBorder(VTOStyle.champagne.opacity(0.6), lineWidth: 0.6))
                .padding(.bottom, 8)
            }
    }

    /// Step two: your photo, framed by a scanner's corners.
    private var photoArt: some View {
        Color.clear
            .overlay(alignment: .top) { Image(VTOStyle.looks[0]).resizable().scaledToFill() }
            .clipped()
            .overlay { ScanCorners().padding(8) }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VTOStyle.page)
                    .frame(width: 20, height: 20)
                    .background(Color.white, in: Circle())
                    .padding(6)
            }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return LinearGradient(colors: [VTOStyle.graphite, VTOStyle.page], startPoint: .top, endPoint: .bottom)
            .overlay {
                FigmaGrid(spacing: 24)
                    .mask(RadialGradient(colors: [.black, .clear], center: .topTrailing, startRadius: 0, endRadius: 260))
            }
            .overlay {
                EllipticalGradient(colors: [.white.opacity(0.08), .clear], center: .topTrailing, startRadiusFraction: 0, endRadiusFraction: 0.8)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [VTOStyle.champagne.opacity(0.35), .white.opacity(0.06)],
                                                       startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 0.8))
    }
}

/// Four white corner brackets, the viewfinder over your photo.
private struct ScanCorners: View {
    var body: some View {
        Canvas { context, size in
            let l: CGFloat = 12
            var p = Path()
            for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (size.width, 0, -1, 1), (0, size.height, 1, -1), (size.width, size.height, -1, -1)] {
                p.move(to: CGPoint(x: x + dx * l, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy * l))
            }
            context.stroke(p, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}

/// Marks a catalogue as try-on ready: a small glass tag on the collage.
struct TryOnReadyTag: View {
    var body: some View {
        HStack(spacing: 4) {
            Image("vtf_pill_sparkle").resizable().frame(width: 11, height: 11)
            Text("Try-on")
                .dropFont("SemiBold", 11, relativeTo: .caption2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Color.black.opacity(0.35), in: Capsule())
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [VTOStyle.champagne.opacity(0.7), .white.opacity(0.15)],
                                                       startPoint: .leading, endPoint: .trailing), lineWidth: 0.6))
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("Virtual try-on available")
    }
}

// MARK: - Education sheet

/// How try-on works, told in the try-on's own look: the arch with the morph and stars, the silver
/// title, three steps on a chrome timeline (step two shows the real "Try it on" button so it's
/// recognised later), a privacy line, and one white pill into the catalogue.
struct TryOnEducationSheet: View {
    let store: String
    let browse: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: R.spacingSpace24) {
                hero
                    .padding(.top, R.spacingSpace24)
                VStack(spacing: 6) {
                    Text("Virtual try-on")
                        .font(.custom("BeVietnamPro-SemiBold", size: 34, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .foregroundStyle(VTOStyle.silver)
                        .accessibilityAddTraits(.isHeader)
                    Text("See how anything at \(store) looks on you, before you head to the trial room.")
                        .backstageText(.body2)
                        .foregroundStyle(M.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, R.spacingSpace24)
                steps
                    .padding(.horizontal, R.spacingSpace16)
                privacy
                    .padding(.horizontal, R.spacingSpace24)
            }
            .padding(.bottom, R.spacingSpace24)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.top)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .overlay(alignment: .topTrailing) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(R.spacingSpace12)
        }
        .background {
            ZStack(alignment: .top) {
                VTOStyle.page
                // The Figma's spotlight from above.
                RadialGradient(colors: [.white.opacity(0.13), .clear], center: .top, startRadius: 0, endRadius: 380)
                    .frame(height: 520)
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .presentationBackground(VTOStyle.page)
        .onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.25).delay(0.1)) { shown = true } }
    }

    private var hero: some View {
        let inner = archShape(width: 214, foot: 22)
        return TryOnLookMorph()
            .frame(width: 214, height: 292)
            .clipShape(inner)
            .overlay(inner.strokeBorder(VTOStyle.champagne, lineWidth: 1))
            .padding(9)
            .background(archShape(width: 232, foot: 26)
                .fill(LinearGradient(colors: [Color(rgba: 0x2C2C2ECC), Color(rgba: 0x2C2C2C00)], startPoint: .top, endPoint: .bottom)))
            .overlay(archShape(width: 232, foot: 26).strokeBorder(VTOStyle.champagne.opacity(0.5), lineWidth: 0.9))
            .overlay(alignment: .topLeading) { Twinkle(asset: "vto_edu_star_big", size: 27).offset(x: -36, y: 10) }
            .overlay(alignment: .trailing) { Twinkle(asset: "vto_edu_star_small", size: 19, delay: 0.5).offset(x: 30, y: -60) }
            .overlay(alignment: .bottomLeading) { Twinkle(asset: "vto_edu_star_mid", size: 20, delay: 0.9).offset(x: -26, y: -40) }
            .scaleEffect(shown ? 1 : 0.92)
            .opacity(shown ? 1 : 0)
            .accessibilityHidden(true)
    }

    // MARK: Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 0) {
            step(1, title: "Open any piece", last: false) {
                Text("Browse the catalogue and tap a piece to see it full screen.")
            }
            step(2, title: "Tap “Try it on” on the photo", last: false) {
                HStack(spacing: R.spacingSpace8) {
                    TryOnPill {}
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    Text("sits on every piece")
                }
            }
            step(3, title: "Add one photo, see it on you", last: true) {
                Text("A full-length photo in good light works best. Your look is ready in seconds.")
            }
        }
        .padding(R.spacingSpace16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }

    private func step<Detail: View>(_ n: Int, title: String, last: Bool, @ViewBuilder detail: () -> Detail) -> some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(spacing: 0) {
                Text("\(n)")
                    .dropFont("SemiBold", 13, relativeTo: .footnote)
                    .foregroundStyle(Metallic.face)
                    .frame(width: 30, height: 30)
                    .background(Metallic.plate, in: Circle())
                    .overlay(Circle().strokeBorder(Metallic.ring, lineWidth: 1.2))
                if !last {
                    // The chrome thread to the next step.
                    LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(title)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                detail()
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 5)
            .padding(.bottom, last ? 0 : R.spacingSpace20)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var privacy: some View {
        HStack(alignment: .top, spacing: R.spacingSpace8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(M.textTertiary)
                .padding(.top, 2)
            Text("Your photo stays private. It's only used to make your looks, and you can delete it anytime.")
                .backstageText(.body3)
                .foregroundStyle(M.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: R.spacingSpace12) {
            Button(action: browse) {
                HStack(spacing: R.spacingSpace8) {
                    Image("vto_edu_star_small").resizable().renderingMode(.template).frame(width: 14, height: 14)
                    Text("Browse the catalogue")
                }
                .font(.custom("BeVietnamPro-SemiBold", size: 16, relativeTo: .headline))
                .tracking(-0.16)
                .foregroundStyle(M.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Opens the catalogue, where every piece has Try it on")
            HStack(spacing: R.spacingSpace4) {
                Image(systemName: "info.circle").font(.system(size: 11))
                Text("10 free try-ons every day")
            }
            .backstageText(.label3)
            .foregroundStyle(M.textTertiary)
        }
        .padding(.horizontal, R.spacingSpace24)
        .padding(.top, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace8)
        .background {
            LinearGradient(stops: [.init(color: VTOStyle.page.opacity(0), location: 0), .init(color: VTOStyle.page, location: 0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Coach mark

/// A one-time pointer to the "Try it on" button for people arriving from the education sheet: a chrome
/// ring pulsing around the pill, and a white bubble under it. Put it on the pill itself so the two
/// always line up.
struct TryOnCoachMark: ViewModifier {
    let active: Bool
    /// Hang the bubble under the button (pointing up) instead of above it.
    var below = false
    var text = "Tap to see this on you"
    /// A step number for guided flows, shown in place of the sparkle.
    var step: Int? = nil
    let dismiss: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                if active {
                    Capsule()
                        .strokeBorder(Metallic.ring, lineWidth: 1.5)
                        .padding(-4)
                        .scaleEffect(pulse ? 1.18 : 1)
                        .opacity(pulse ? 0 : 1)
                        .allowsHitTesting(false)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
                        }
                }
            }
            .overlay(alignment: below ? .topLeading : .bottomLeading) {
                if active {
                    bubble
                        .fixedSize()
                        .offset(y: below ? 50 : -50)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                }
            }
    }

    private var bubble: some View {
        HStack(spacing: R.spacingSpace8) {
            if let step {
                Text("\(step)")
                    .font(.custom("BeVietnamPro-SemiBold", size: 11, relativeTo: .caption2))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color(rgba: 0x131316FF), in: Circle())
            } else {
                Image("vto_edu_star_small").resizable().renderingMode(.template).frame(width: 12, height: 12)
            }
            Text(text)
                .backstageText(.label2)
        }
        .foregroundStyle(M.textInverse)
        .padding(.horizontal, R.spacingSpace12)
        .frame(height: 34)
        .background(Color.white, in: Capsule())
        .overlay(alignment: below ? .topLeading : .bottomLeading) {
            // The pointer, towards the pill.
            Image(systemName: "triangle.fill")
                .font(.system(size: 9))
                .rotationEffect(.degrees(below ? 0 : 180))
                .foregroundStyle(.white)
                .offset(x: 30, y: below ? -7 : 7)
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Dismisses the tip")
    }
}

#Preview("Catalogue steps") {
    TryOnCatalogueSteps(piece: "sdp_cat_c1_b1") {}
        .padding()
        .background(Color(rgba: 0x131316FF))
        .preferredColorScheme(.dark)
}
