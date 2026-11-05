import SwiftUI
import PhotosUI
import Observation

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// The AI virtual try-on flow from a catalogue piece (Figma "SDP" file, page "AI virtual try on",
// sections 23766:82409 and 23601:919): TryOn! on the piece → (first time) the onboarding sheet
// and your photo → "Styling your look" → the result → your closet. Once a piece has a look, its
// pill reads "View try on" and opens that look instead of making a new one.
// Prototype: no model runs. A look shows the piece's own photo, revealed as if it was styled.

/// Figma values for the try-on screens (graphite, champagne, silver, white).
enum VTOFlowStyle {
    static let page = Color(rgba: 0x131316FF)
    static let champagne = Color(rgba: 0xFFEED1FF)
    static let silver = LinearGradient(colors: [Color(rgba: 0xF7F7F7FF), Color(rgba: 0x919191FF)], startPoint: .top, endPoint: .bottom)
    /// The studio behind a result (Figma #48484A → #6E6E6E → #C5C2C9).
    static let studio = LinearGradient(stops: [.init(color: Color(rgba: 0x48484AFF), location: 0.02),
                                               .init(color: Color(rgba: 0x6E6E6EFF), location: 0.48),
                                               .init(color: Color(rgba: 0xC5C2C9FF), location: 0.81)],
                                       startPoint: .top, endPoint: .bottom)
    /// Round glass control on the try-on screens: black 56% with a subtle edge.
    static let control = Color.black.opacity(0.56)
    static let resultInk = Color(rgba: 0x131316FF)
}

// MARK: - Model

/// One try-on result.
struct TryOnLook: Identifiable, Hashable {
    let id = UUID()
    /// The piece it was made from, when it came from a catalogue.
    var product: StoreProduct?
    let image: String
    let title: String
    let store: String
    var storeLogo: String?
    let tag: String
    let created: Date
    var liked = false
}

/// Your photo and every look made with it. Shared across the app so a piece's pill knows it has a
/// look wherever it's shown.
@MainActor @Observable
final class TryOnStudio {
    static let shared = TryOnStudio()

    /// The photo you dress up. Kept in memory for the prototype; "has a photo" is remembered.
    var photo: UIImage?
    var hasPhoto: Bool {
        didSet { UserDefaults.standard.set(hasPhoto, forKey: "vto.hasPhoto") }
    }
    var looks: [TryOnLook]
    let dailyLimit = 10

    private init() {
        hasPhoto = UserDefaults.standard.bool(forKey: "vto.hasPhoto")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-vtoNewUser") { hasPhoto = false }
        if ProcessInfo.processInfo.arguments.contains("-vtoRepeatUser") { hasPhoto = true }
        #endif
        // Earlier sample looks (free Pexels photos), so the closet never opens empty.
        let earlier = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 11)) ?? .now
        looks = [
            TryOnLook(image: "vto_edu_look_1", title: "Paisley crop top & flares", store: "Shopper's stop", storeLogo: "vtf_store_shoppers_stop", tag: "Active", created: earlier, liked: true),
            TryOnLook(image: "vto_edu_look_2", title: "Blue bodycon dress", store: "Shopper's stop", storeLogo: "vtf_store_shoppers_stop", tag: "Casual", created: earlier),
            TryOnLook(image: "vto_edu_look_3", title: "White shirt & floral skirt", store: "Shopper's stop", storeLogo: "vtf_store_shoppers_stop", tag: "Formal", created: earlier, liked: true),
        ]
    }

    var remaining: Int {
        max(0, dailyLimit - looks.filter { Calendar.current.isDateInToday($0.created) }.count)
    }

    func look(for product: StoreProduct) -> TryOnLook? {
        looks.first { $0.product?.image == product.image && $0.product?.store == product.store }
    }

    /// A new look of the piece (or the one it already has, so a piece is never queued twice).
    func makeLook(of product: StoreProduct) -> TryOnLook {
        if let existing = look(for: product) { return existing }
        let look = TryOnLook(product: product, image: product.image, title: product.name, store: product.store,
                             storeLogo: product.store == "adidas" ? "sdp_logo_adidas" : nil,
                             tag: product.kind == .footwear ? "Active" : "Casual", created: .now)
        looks.insert(look, at: 0)
        return look
    }

    func toggleLike(_ look: TryOnLook) {
        guard let i = looks.firstIndex(where: { $0.id == look.id }) else { return }
        looks[i].liked.toggle()
    }

    func delete(_ look: TryOnLook) {
        looks.removeAll { $0.id == look.id }
    }

    func current(_ look: TryOnLook) -> TryOnLook { looks.first { $0.id == look.id } ?? look }
}

// MARK: - TryOn! pill

/// The try-on button, a "lens" in the try-on's own palette: dark frosted glass with a chrome edge
/// whose highlight slowly travels round the rim, a round lens holding the Figma's shirt-in-scan-
/// brackets (a chrome line sweeps across it, as on "Styling your look"), and "Try it on / See it
/// on you". Once the piece has a look, the lens shows that look in a champagne ring and the words
/// read "View your look / Ready"; the moment it turns, a champagne ring pulses and sparkles pop.
/// `.compact` is a one-line version for small cards. Still with Reduce Motion.
struct TryOnPill: View {
    enum Size { case regular, compact }

    var viewLook = false
    /// The look's photo, shown in the lens once there is one.
    var lookImage: String? = nil
    var size: Size = .regular
    let action: () -> Void
    @State private var celebrate = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var compact: Bool { size == .compact }
    private var height: CGFloat { compact ? 32 : 44 }
    private var lens: CGFloat { compact ? 26 : 36 }

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(paused: reduceMotion)) { context in
                pill(reduceMotion ? 0.9 : context.date.timeIntervalSinceReferenceDate)
            }
            .keyframeAnimator(initialValue: Burst(), trigger: celebrate) { view, burst in
                view
                    .scaleEffect(burst.scale)
                    .background {
                        Capsule()
                            .strokeBorder(VTOFlowStyle.champagne, lineWidth: 1.5)
                            .scaleEffect(burst.ring)
                            .opacity(burst.ringOpacity)
                    }
                    .overlay(alignment: .topLeading) {
                        ZStack {
                            Image("vtf_pill_sparkle").resizable().frame(width: 12, height: 12).offset(x: 30, y: -12)
                            Image("vtf_pill_sparkle").resizable().frame(width: 8, height: 8).offset(x: 6, y: -8)
                            Image("vtf_pill_sparkle").resizable().frame(width: 7, height: 7).offset(x: 42, y: 4)
                        }
                        .scaleEffect(burst.sparkles)
                        .opacity(burst.sparkles > 0.05 ? 1 : 0)
                        .allowsHitTesting(false)
                    }
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.08, duration: 0.18)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
                KeyframeTrack(\.ring) {
                    LinearKeyframe(1, duration: 0.01)
                    CubicKeyframe(1.3, duration: 0.7)
                }
                KeyframeTrack(\.ringOpacity) {
                    LinearKeyframe(0.9, duration: 0.01)
                    CubicKeyframe(0, duration: 0.7)
                }
                KeyframeTrack(\.sparkles) {
                    SpringKeyframe(1.2, duration: 0.25)
                    CubicKeyframe(1, duration: 0.3)
                    CubicKeyframe(0, duration: 0.35)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.25), value: viewLook)
        .onChange(of: viewLook) { _, now in
            if now && !reduceMotion { celebrate += 1 }
        }
        .sensoryFeedback(.success, trigger: celebrate)
        .accessibilityLabel(viewLook ? "View your try-on look" : "Try it on")
        .accessibilityHint(viewLook ? "Opens your look with this piece" : "See this piece on a photo of you")
    }

    private func pill(_ t: Double) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            lensView(t)
            words
        }
        .padding(.leading, viewLook ? (height - lens) / 2 : (compact ? 8 : 10))
        .padding(.trailing, compact ? 12 : 18)
        .frame(height: height)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(LinearGradient(colors: [Color(rgba: 0x1E1E20E6), Color(rgba: 0x131316F2)], startPoint: .top, endPoint: .bottom))
                // A soft glint across the top, like light on glass.
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
            }
        }
        .overlay { rim(t) }
        .background {
            // A soft white halo that breathes, so the button is noticed on any photo.
            Capsule()
                .fill(Color.white.opacity(0.10 + 0.06 * sin(t * 1.6)))
                .blur(radius: 10)
                .padding(-2)
        }
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }

    /// The gradient stroke: two bright arcs (white into champagne into cool silver) chase each other
    /// round the pill every 3s over a faint base rim, with a blurred copy as a glow.
    private func rim(_ t: Double) -> some View {
        let turn = t.truncatingRemainder(dividingBy: 3) / 3 * 360
        let warm = VTOFlowStyle.champagne
        let cool = Color(rgba: 0xB9C2D6FF)
        let stroke = AngularGradient(stops: [.init(color: .white, location: 0),
                                             .init(color: warm, location: 0.08),
                                             .init(color: warm.opacity(0), location: 0.22),
                                             .init(color: .clear, location: 0.45),
                                             .init(color: .white, location: 0.5),
                                             .init(color: cool, location: 0.58),
                                             .init(color: cool.opacity(0), location: 0.72),
                                             .init(color: .clear, location: 0.95),
                                             .init(color: .white, location: 1)],
                                     center: .center, angle: .degrees(turn))
        return ZStack {
            Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1)
            Capsule().strokeBorder(stroke, lineWidth: 1.6)
            Capsule().strokeBorder(stroke, lineWidth: 3).blur(radius: 4).opacity(0.85)
        }
        .allowsHitTesting(false)
    }

    /// A white sparkle that twinkles straight on the glass, or your look in a champagne ring once
    /// there is one.
    @ViewBuilder private func lensView(_ t: Double) -> some View {
        if viewLook, let lookImage {
            Color(rgba: 0xC5C2C9FF)
                .overlay(alignment: .top) { Image(lookImage).resizable().scaledToFill() }
                .frame(width: lens, height: lens)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(VTOFlowStyle.champagne, lineWidth: 1))
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .accessibilityHidden(true)
        } else {
            Image("vtf_pill_sparkle").resizable().renderingMode(.template)
                .foregroundStyle(.white)
                .frame(width: compact ? 14 : 18, height: compact ? 14 : 18)
                .scaleEffect(0.9 + 0.12 * sin(t * 2.4))
                .rotationEffect(.degrees(sin(t * 1.2) * 12))
                .shadow(color: .white.opacity(0.6), radius: 4)
                .padding(.leading, compact ? 4 : 8)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewLook ? "View your look" : "Try it on")
                .font(.custom("BeVietnamPro-SemiBold", size: compact ? 12 : 15, relativeTo: .subheadline))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .overlay { TextShimmer().mask { Text(viewLook ? "View your look" : "Try it on")
                    .font(.custom("BeVietnamPro-SemiBold", size: compact ? 12 : 15, relativeTo: .subheadline))
                    .tracking(-0.2) } }
        }
        .lineLimit(1)
        .fixedSize()
        .contentTransition(.interpolate)
    }
}

/// A silver glint that slides through text every few seconds.
private struct TextShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let p = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 1.2
            GeometryReader { g in
                LinearGradient(colors: [.clear, Color(rgba: 0xC9CBD1FF), .white, Color(rgba: 0xC9CBD1FF), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.6)
                    .offset(x: -g.size.width * 0.6 + (g.size.width * 1.6) * min(p, 1))
                    .opacity(reduceMotion || p > 1 ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The pill's "ready" moment.
private struct Burst {
    var scale: CGFloat = 1
    var ring: CGFloat = 1
    var ringOpacity: Double = 0
    var sparkles: CGFloat = 0
}

// MARK: - Onboarding sheet

/// First-time sheet (Figma 23616:1832): the champagne arch with the Figma photo under a beam of
/// light and a faint grid, stars, "AI Virtual Try-on", "Get started" and the terms line.
struct TryOnOnboardingSheet: View {
    let start: () -> Void

    var body: some View {
        // Decorations sit in overlays so their large frames never set the sheet's width.
        VTOFlowStyle.page
            .overlay(alignment: .top) {
                Image("vtf_ob_grid").resizable().frame(width: 715.6, height: 715.6)
                    .offset(y: -16)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) { arch.padding(.top, 41) }
            .overlay(alignment: .top) {
                Image("vtf_sheet_beam").resizable().frame(width: 444.4, height: 593.3)
                    .offset(y: -34 - 413.337 * 0.2177)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                Image("vtf_ob_star1").resizable().frame(width: 26.7, height: 26.7).padding(.top, 67).padding(.trailing, 22)
            }
            .overlay(alignment: .topLeading) {
                Image("vtf_ob_star2").resizable().frame(width: 15.9, height: 15.9).padding(.top, 25).padding(.leading, 85)
            }
            .overlay(alignment: .bottom) {
                words
                    .padding(.horizontal, R.spacingSpace24)
                    .padding(.bottom, R.spacingSpace32)
            }
        .clipped()
        .presentationDetents([.height(697)])
        .presentationCornerRadius(16)
        .presentationBackground(VTOFlowStyle.page)
        .presentationDragIndicator(.hidden)
    }

    private var arch: some View {
        let inner = UnevenRoundedRectangle(topLeadingRadius: 179.8, bottomLeadingRadius: 21.6, bottomTrailingRadius: 21.6, topTrailingRadius: 179.8, style: .continuous)
        let outer = UnevenRoundedRectangle(topLeadingRadius: 189.3, bottomLeadingRadius: 22.7, bottomTrailingRadius: 22.7, topTrailingRadius: 189.3, style: .continuous)
        return LinearGradient(stops: [.init(color: Color(rgba: 0x1E1E20FF), location: 0.17), .init(color: VTOFlowStyle.page, location: 0.84)],
                              startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .topLeading) {
                Image("vtf_sheet_photo").resizable().scaledToFill()
                    .frame(width: 360.7, height: 704.5)
                    .opacity(0.8)
                    .overlay(LinearGradient(stops: [.init(color: .clear, location: 0.32), .init(color: .black.opacity(0.32), location: 0.46),
                                                    .init(color: .black.opacity(0.5), location: 0.55), .init(color: .black.opacity(0.74), location: 0.65),
                                                    .init(color: VTOFlowStyle.page, location: 0.77)],
                                           startPoint: .top, endPoint: .bottom))
                    .offset(x: -21.6)
            }
            .frame(width: 302, height: 567.8)
            .clipShape(inner)
            .overlay(inner.strokeBorder(VTOFlowStyle.champagne, lineWidth: 1))
            .padding(8.3)
            .background(outer.fill(LinearGradient(colors: [Color(rgba: 0x2C2C2ECC), Color(rgba: 0x2C2C2C00)], startPoint: .top, endPoint: .bottom)))
            .accessibilityHidden(true)
    }

    private var words: some View {
        VStack(spacing: R.spacingSpace32) {
            VStack(spacing: R.spacingSpace16) {
                VStack(spacing: 2) {
                    Text("AI Virtual Try-on")
                        .font(.custom("BeVietnamPro-Medium", size: 29, relativeTo: .largeTitle))
                        .tracking(-0.29)
                        .foregroundStyle(VTOFlowStyle.silver)
                        .accessibilityAddTraits(.isHeader)
                    Text("Upload your image and outfits you want to try and see the magic")
                        .backstageText(.body2)
                        .foregroundStyle(M.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 281)
                }
                Button(action: start) {
                    Text("Get started")
                        .backstageText(.title3)
                        .foregroundStyle(M.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Choose a full-length photo of you")
            }
            (Text("By proceeding, I agree with the ") + Text("Terms of Service").foregroundStyle(M.textSecondary)
             + Text(" and ") + Text("Privacy Policy").foregroundStyle(M.textSecondary))
                .font(.custom("BeVietnamPro-Medium", size: 11, relativeTo: .caption2))
                .foregroundStyle(M.textTertiary)
                .multilineTextAlignment(.center)
                .frame(width: 246)
        }
    }
}

// MARK: - The flow

/// Where a result was opened from, so its back button returns there (Figma dev note).
enum TryOnOrigin { case catalogue, closet }

/// The full-screen try-on flow: styling → result → closet, in one cover so moving between them
/// doesn't stack screens.
struct TryOnFlowView: View {
    enum Step: Equatable {
        case styling(StoreProduct)
        case result(TryOnLook, TryOnOrigin)
        case closet

        static func == (a: Step, b: Step) -> Bool {
            switch (a, b) {
            case let (.styling(x), .styling(y)): x.id == y.id
            case let (.result(x, _), .result(y, _)): x.id == y.id
            case (.closet, .closet): true
            default: false
            }
        }
    }

    @State var step: Step
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let studio = TryOnStudio.shared

    var body: some View {
        ZStack {
            switch step {
            case .styling(let product):
                TryOnStylingView(product: product) { look in
                    go(.result(look, .catalogue))
                }
                .transition(.opacity)
            case .result(let look, let origin):
                TryOnResultView(look: studio.current(look),
                                back: { origin == .closet ? go(.closet) : dismiss() },
                                closet: { go(.closet) },
                                browse: { dismiss() },
                                deleted: { origin == .closet ? go(.closet) : dismiss() })
                    .transition(.opacity)
            case .closet:
                TryOnClosetGalleryView(open: { go(.result($0, .closet)) }, back: { dismiss() })
                    .transition(.opacity)
            }
        }
        .background(VTOFlowStyle.page.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func go(_ next: Step) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { step = next }
    }
}

// MARK: - Styling (loader)

/// "Styling your look" (Figma 23753:81845): the charcoal shirt in scan brackets breathing in a soft
/// glow, a progress line, and a line of copy that changes as it works. Hands over a look when done.
struct TryOnStylingView: View {
    let product: StoreProduct
    let done: (TryOnLook) -> Void
    @State private var progress: CGFloat = 0
    @State private var line = 0
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let lines = ["Styling your look", "Perfecting the fit", "Doing a little twirl",
                                "Checking your vibe", "Adding the wow factor", "Almost runway-ready"]
    private static let duration: Double = 5.4

    var body: some View {
        // Decorations sit in backgrounds so their large frames never move the content.
        VStack(spacing: 0) {
            ZStack {
                Image("vtf_ld_glow").resizable().frame(width: 180, height: 160)
                    .blendMode(.screen)
                    .scaleEffect(breathe ? 1.12 : 0.92)
                    .opacity(breathe ? 1 : 0.6)
                Image("vtf_loader_shirt").resizable().frame(width: 138, height: 138)
                    .scaleEffect(breathe ? 1.03 : 0.98)
            }
            .frame(height: 160)
            ZStack(alignment: .leading) {
                Image("vtf_ld_track").resizable().frame(width: 245, height: 4)
                Image("vtf_ld_fill").resizable().frame(width: 245, height: 4)
                    .mask(alignment: .leading) { Rectangle().frame(width: 245 * progress) }
            }
            .padding(.top, 14)
            Text(Self.lines[line])
                .font(.custom("BeVietnamPro-Medium", size: 24, relativeTo: .title))
                .tracking(-0.48)
                .foregroundStyle(LinearGradient(colors: [Color(rgba: 0x3A3A3EFF), Color(rgba: 0xA5A5ACFF), Color(rgba: 0x3A3A3EFF)],
                                                startPoint: .leading, endPoint: .trailing))
                .id(line)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)).animation(.easeOut(duration: 0.3).delay(0.15)),
                                        removal: .opacity.animation(.easeIn(duration: 0.15))))
                .padding(.top, 34)
        }
        .offset(y: -20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { LoaderBackdrop().ignoresSafeArea().allowsHitTesting(false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Styling your look with \(product.name)")
        .accessibilityAddTraits(.updatesFrequently)
        .task { await run() }
    }

    private func run() async {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { breathe = true }
        }
        withAnimation(.easeInOut(duration: Self.duration)) { progress = 1 }
        let step = Self.duration / Double(Self.lines.count)
        for i in 1..<Self.lines.count {
            try? await Task.sleep(for: .seconds(step))
            withAnimation(.easeInOut(duration: 0.35)) { line = i }
        }
        try? await Task.sleep(for: .seconds(step))
        done(TryOnStudio.shared.makeLook(of: product))
    }
}

/// The loader's room, drawn only with gradients so nothing ends in a hard edge: graphite that
/// deepens downward and a soft spotlight falling from above onto the shirt.
private struct LoaderBackdrop: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(stops: [.init(color: Color(rgba: 0x1C1C1FFF), location: 0),
                                       .init(color: Color(rgba: 0x161619FF), location: 0.45),
                                       .init(color: Color(rgba: 0x0E0E10FF), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                // The spotlight: a tall, soft ellipse of light from the top centre.
                EllipticalGradient(stops: [.init(color: .white.opacity(0.16), location: 0),
                                           .init(color: .white.opacity(0.07), location: 0.35),
                                           .init(color: .white.opacity(0.02), location: 0.7),
                                           .init(color: .white.opacity(0), location: 1)],
                                   center: UnitPoint(x: 0.5, y: 0), startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: g.size.width * 1.6, height: g.size.height * 1.3)
                    .position(x: g.size.width / 2, y: 0)
            }
            .frame(width: g.size.width, height: g.size.height)
            .clipped()
        }
    }
}

// MARK: - Result

/// Your look (Figma 23753:82039): the figure on the studio gradient, revealed by a chrome sweep;
/// like, share and delete on the right; the store and piece at the foot; "View closet" and
/// "Continue browsing".
struct TryOnResultView: View {
    let look: TryOnLook
    let back: () -> Void
    let closet: () -> Void
    let browse: () -> Void
    let deleted: () -> Void
    @State private var reveal: CGFloat = 0
    @State private var confirmDelete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let studio = TryOnStudio.shared

    var body: some View {
        GeometryReader { g in
            // The full screen, including the status bar and home indicator areas.
            let full = g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom
            ZStack(alignment: .top) {
                VTOFlowStyle.studio
                    .overlay(alignment: .top) {
                        // The look runs edge to edge, top to bottom: no seam to the backdrop.
                        Image(look.image).resizable().scaledToFill()
                            .frame(width: g.size.width, height: full)
                            .clipped()
                    }
                    .frame(width: g.size.width, height: full)
                    // The reveal: everything below the sweep stays soft until it passes.
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.ultraThinMaterial)
                            .frame(height: full * (1 - reveal))
                    }
                    .overlay(alignment: .top) {
                        if reveal > 0 && reveal < 1 {
                            RevealBeam().frame(height: 60).offset(y: full * reveal - 60)
                        }
                    }
                // The header shade, eased so it has no visible edge.
                LinearGradient(stops: Self.ease(from: 0.55, steps: 8), startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
                    .allowsHitTesting(false)
                // The foot shade, tall and eased, under the info and buttons.
                LinearGradient(stops: Self.ease(from: 0.92, steps: 10), startPoint: .bottom, endPoint: .top)
                    .frame(height: 300 + g.safeAreaInsets.bottom)
                    .frame(maxHeight: full, alignment: .bottom)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            GlassIconButton(systemName: "arrow.left", label: "Back", action: back)
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace8)
        }
        .overlay(alignment: .bottom) { foot }
        .confirmationDialog("Delete this look?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete look", role: .destructive) {
                studio.delete(look)
                deleted()
            }
        } message: {
            Text("It will be removed from your closet.")
        }
        .onAppear {
            guard !reduceMotion else { reveal = 1; return }
            withAnimation(.easeInOut(duration: 1.3).delay(0.15)) { reveal = 1 }
        }
        .sensoryFeedback(.success, trigger: reveal == 1)
    }

    /// An eased black fade (smootherstep) from `from` opacity to clear, so shades never show a band.
    static func ease(from: Double, steps: Int) -> [Gradient.Stop] {
        (0...steps).map { i in
            let x = Double(i) / Double(steps)
            let e = 1 - x * x * x * (x * (x * 6 - 15) + 10)
            return .init(color: Color(rgba: 0x0C0B0EFF).opacity(from * e), location: x)
        }
    }

    private var foot: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                HStack(spacing: R.spacingSpace12) {
                    skuPhoto
                    VStack(alignment: .leading, spacing: 2) {
                        Text(look.product?.brand ?? look.store)
                            .font(.custom("BeVietnamPro-Bold", size: 16, relativeTo: .headline))
                            .foregroundStyle(M.textWhite)
                            .lineLimit(1)
                        Text(look.title)
                            .font(.custom("BeVietnamPro-SemiBold", size: 12, relativeTo: .caption))
                            .foregroundStyle(M.textWhite.opacity(0.72))
                            .lineLimit(2)
                        if let price = look.product?.price {
                            Text(rupees(price))
                                .font(.custom("BeVietnamPro-SemiBold", size: 12, relativeTo: .caption))
                                .foregroundStyle(M.textWhite)
                                .padding(.top, 2)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: R.spacingSpace12)
                actions
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.trailing, 1.5)
            HStack(spacing: R.spacingSpace12) {
                Button(action: closet) {
                    Text("View closet")
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(M.borderSelection, lineWidth: R.stroke1Px))
                }
                .buttonStyle(PressableStyle())
                Button(action: browse) {
                    Text("Continue browsing")
                        .backstageText(.title3)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(M.surfaceInverse, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, 25)
            .padding(.bottom, R.spacingSpace8)
        }
    }

    /// The piece the look was made from, as a product photo, with the store's logo tucked on its
    /// corner, so you can see what you're wearing next to how it looks on you.
    private var skuPhoto: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Color(rgba: 0xEBEBEBFF)
            .overlay(alignment: .top) {
                Image(look.product?.image ?? look.image).resizable().scaledToFill()
            }
            .frame(width: 56, height: 72)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                Group {
                    if let logo = look.storeLogo {
                        Color.white.overlay { Image(logo).resizable().scaledToFit().padding(2) }
                    } else {
                        BrandMark(brand: look.store, mark: String(look.store.prefix(4)).uppercased(), size: 22)
                    }
                }
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
                .offset(x: 6, y: 6)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
            .padding(.trailing, 6)
            .accessibilityLabel("Product photo")
    }

    /// Like, share, delete: 40pt glass circles stacked on the right.
    private var actions: some View {
        let liked = studio.current(look).liked
        return VStack(spacing: R.spacingSpace12) {
            Button { studio.toggleLike(look) } label: {
                circle {
                    Image(liked ? "vtf_cl_heart" : "vtf_rs_heart").resizable().frame(width: 24, height: 24)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(liked ? "Liked" : "Like")
            .accessibilityAddTraits(liked ? .isSelected : [])
            .sensoryFeedback(.impact(weight: .light), trigger: liked)
            ShareLink(item: "My look in \(look.title) from \(look.store), styled on District") {
                circle { Image("vtf_rs_share").resizable().frame(width: 28.5, height: 28.5) }
            }
            .accessibilityLabel("Share look")
            Button { confirmDelete = true } label: {
                circle { Image("vtf_rs_trash").resizable().frame(width: 24, height: 24) }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Delete look")
        }
        .padding(.bottom, 4)
    }

    private func circle<Content: View>(@ViewBuilder _ icon: () -> Content) -> some View {
        icon()
            .frame(width: 40, height: 40)
            .background(VTOFlowStyle.control, in: Circle())
            .overlay(Circle().strokeBorder(M.borderSubtle, lineWidth: 0.594))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }
}

/// The chrome line of the reveal, with a little light trailing above it.
private struct RevealBeam: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.35)], startPoint: .top, endPoint: .bottom)
            Rectangle()
                .fill(LinearGradient(colors: [.white.opacity(0.2), .white, VTOFlowStyle.champagne, .white, .white.opacity(0.2)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .shadow(color: .white, radius: 8)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Closet

/// "Your closet" (Figma 23602:5214): your photo in a glowing circle, filter chips, looks grouped by
/// day as little polaroids with a paperclip, and "Back to browsing" with today's remaining count.
struct TryOnClosetGalleryView: View {
    let open: (TryOnLook) -> Void
    let back: () -> Void
    @State private var filter = "All"
    private let studio = TryOnStudio.shared

    private static let filters = ["Favourites", "Casual wear", "Party wear", "Formal wear", "Active wear"]

    private var shown: [TryOnLook] {
        switch filter {
        case "Favourites": studio.looks.filter(\.liked)
        case "Casual wear": studio.looks.filter { $0.tag == "Casual" }
        case "Formal wear", "Party wear": studio.looks.filter { $0.tag == "Formal" }
        case "Active wear": studio.looks.filter { $0.tag == "Active" }
        default: studio.looks
        }
    }

    private var days: [(String, [TryOnLook])] {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        var order: [String] = []
        var groups: [String: [TryOnLook]] = [:]
        for look in shown {
            let key = Calendar.current.isDateInToday(look.created) ? "Today" : f.string(from: look.created)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(look)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: R.spacingSpace24) {
                avatar
                chips
                VStack(spacing: R.spacingSpace32) {
                    ForEach(days, id: \.0) { day, looks in
                        VStack(spacing: R.spacingSpace16) {
                            dayRule(day)
                            ScrollView(.horizontal) {
                                HStack(spacing: 13) {
                                    ForEach(looks) { look in
                                        Button { open(look) } label: { ClosetPolaroid(look: look) }
                                            .buttonStyle(PressableStyle())
                                            .accessibilityLabel("\(look.title), \(look.tag)\(look.liked ? ", liked" : "")")
                                            .accessibilityHint("Opens the look")
                                    }
                                }
                                .padding(.top, 12)
                            }
                            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
                            .scrollIndicators(.hidden)
                        }
                    }
                    if days.isEmpty {
                        Text(filter == "Favourites" ? "Tap the heart on a look to keep it here." : "No looks here yet.")
                            .backstageText(.body3)
                            .foregroundStyle(M.textTertiary)
                            .padding(.top, R.spacingSpace24)
                    }
                }
            }
            .padding(.top, R.spacingSpace16)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .overlay(alignment: .bottom) { foot }
        .background {
            ZStack(alignment: .top) {
                VTOFlowStyle.page
                Image("vtf_closet_spotlight").resizable().frame(width: 400, height: 844).allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace16) {
            GlassIconButton(systemName: "arrow.left", label: "Back", action: back)
            Text("Your closet")
                .backstageText(.title2)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace8)
        .background(LinearGradient(colors: [Color(rgba: 0x0C0B0EB3), Color(rgba: 0x0C0B0E00)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    /// Your photo (or the Figma's, before you've added one) in a 116pt circle with a pencil.
    private var avatar: some View {
        Group {
            if let photo = studio.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Image("vtf_closet_avatar").resizable().scaledToFill()
                    .frame(width: 154, height: 333)
                    .offset(x: 8, y: 60)
            }
        }
        .frame(width: 116, height: 116)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.24), lineWidth: 1.16))
        .shadow(color: .white.opacity(0.15), radius: 17, y: 4.6)
        .overlay(alignment: .bottomTrailing) {
            Image("vtf_cl_frame").resizable().frame(width: 15.8, height: 15.8)
                .frame(width: 30, height: 30)
                .background(VTOFlowStyle.control, in: Circle())
                .overlay(Circle().strokeBorder(M.borderSubtle, lineWidth: 0.6))
                .offset(x: 2, y: 2)
        }
        .accessibilityLabel("Your try-on photo")
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(Self.filters, id: \.self) { f in
                    let on = filter == f
                    Button { withAnimation(.snappy) { filter = on ? "All" : f } } label: {
                        HStack(spacing: R.spacingSpace8) {
                            if f == "Favourites" { Image("vtf_cl_chipheart").resizable().frame(width: 16, height: 16) }
                            Text(f)
                        }
                    }
                    .buttonStyle(BackstageFilterButtonStyle(isActive: on))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func dayRule(_ day: String) -> some View {
        HStack(spacing: 11.4) {
            Image("vtf_cl_rule_l").resizable().frame(width: 45, height: 0.5)
            Text(day)
                .font(.custom("BeVietnamPro-Regular", size: 13.3, relativeTo: .footnote))
                .foregroundStyle(Color(rgba: 0xF7F7F75C))
            Image("vtf_cl_rule_r").resizable().frame(width: 45, height: 0.5)
        }
    }

    private var foot: some View {
        VStack(spacing: R.spacingSpace12) {
            Button(action: back) {
                HStack(spacing: R.spacingSpace8) {
                    Image("vtf_cl_shirt").resizable().frame(width: 20, height: 20)
                    Text("Back to browsing")
                }
                .backstageText(.title3)
                .foregroundStyle(M.textInverse)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(M.surfaceInverse, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            HStack(spacing: R.spacingSpace4) {
                Image("vtf_cl_info").resizable().frame(width: 14, height: 14)
                Text("\(studio.remaining) try-ons remaining today")
            }
            .backstageText(.label3)
            .foregroundStyle(M.textTertiary)
        }
        .padding(.horizontal, R.spacingSpace24)
        .padding(.top, R.spacingSpace24)
        .padding(.bottom, R.spacingSpace8)
        .background {
            LinearGradient(stops: [.init(color: VTOFlowStyle.page.opacity(0), location: 0), .init(color: VTOFlowStyle.page, location: 0.45)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

/// One look in the closet: a 102×136 print in a graphite frame with a paperclip, a heart when
/// liked, and its tag between two dots.
private struct ClosetPolaroid: View {
    let look: TryOnLook

    var body: some View {
        VStack(spacing: 12.15) {
            VTOFlowStyle.studio
                .overlay(alignment: .top) { Image(look.image).resizable().scaledToFill() }
                .frame(width: 102, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            HStack(spacing: 6) {
                Image("vtf_cl_dot").resizable().frame(width: 3.6, height: 3.6)
                Text(look.tag)
                    .font(.custom("BeVietnamPro-Medium", size: 10, relativeTo: .caption2))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.6))
                Image("vtf_cl_dot").resizable().frame(width: 3.6, height: 3.6)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, R.spacingSpace12)
        .background(LinearGradient(colors: [Color(rgba: 0x202020FF), Color(rgba: 0x2A2A2EFF)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 3.3, y: 4.4)
        .overlay(alignment: .topLeading) {
            Image("vtf_cl_clip").resizable().frame(width: 20, height: 20).offset(x: 9.5, y: -8.5)
        }
        .overlay(alignment: .topTrailing) {
            if look.liked {
                Image("vtf_cl_heart").resizable().frame(width: 16, height: 16).padding(.top, 9).padding(.trailing, 9.5)
            }
        }
    }
}
