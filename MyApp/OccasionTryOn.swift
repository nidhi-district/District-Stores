import SwiftUI
import PhotosUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// "Shop for occasion" on the stores home (Figma 3838:9352): a festive rail of edits tagged "Try on
/// available", each opening a gallery of looks. The gallery's "Virtual try on" pill opens a try-on
/// space with the same looks and how it works; a look's quick view and product page carry the
/// Figma's "Try on" pill, which starts try-on on that piece.

// MARK: - Data

/// One edit on the rail and the looks in it.
struct OccasionEdit: Identifiable, Hashable {
    var id: String { title }
    let title: String
    /// The gallery's title.
    let gallery: String
    let thumbs: [String]
    let looks: [StoreProduct]
}

enum OccasionData {
    static let lehengas: [StoreProduct] = [
        StoreProduct(image: "occ_lehenga_navy", name: "Navy sequin lehenga", brand: "Kalki", store: "Kalki",
                     kind: .apparel, price: 4499, colour: "Midnight navy"),
        StoreProduct(image: "occ_lehenga_red", name: "Red Embroidered lehenga", brand: "Sabhyata", store: "Sabhyata",
                     kind: .apparel, price: 2999, colour: "Festive red"),
        StoreProduct(image: "occ_lehenga_blue", name: "Royal blue lehenga", brand: "Libas", store: "Libas",
                     kind: .apparel, price: 3799, colour: "Royal blue"),
    ]

    static let edits: [OccasionEdit] = [
        OccasionEdit(title: "Handpicked lehengas for you", gallery: "Handpicked lehengas",
                     thumbs: ["occ_rail_1", "occ_rail_2", "occ_rail_3"], looks: lehengas),
        OccasionEdit(title: "Lehengas under ₹5,000", gallery: "Lehengas under ₹5,000",
                     thumbs: ["occ_rail_2", "occ_rail_3", "occ_rail_1"], looks: [lehengas[1], lehengas[2], lehengas[0]]),
    ]

    static let filters = ["Lehenga", "Sarees", "Kurta sets", "Sherwanis", "Jewellery"]
    static let collections = ["Spring collection", "Trendy winter outfit", "Bestseller-Men", "Cafes", "Entertainment"]
}

// MARK: - Starting try-on

/// Starts try-on on a piece set into `request`, the same way the catalogue viewer does: a piece
/// with a look opens it, a returning user goes straight to styling, and a first-timer meets the
/// onboarding sheet and adds a photo first.
private struct TryOnLauncher: ViewModifier {
    @Binding var request: StoreProduct?
    @State private var route: TryOnRoute?
    @State private var onboarding = false
    @State private var pickingPhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var waiting: StoreProduct?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, piece in
                guard let piece else { return }
                request = nil
                start(piece)
            }
            .fullScreenCover(item: $route) { TryOnFlowView(step: $0.step) }
            .sheet(isPresented: $onboarding) {
                TryOnOnboardingSheet {
                    onboarding = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pickingPhoto = true }
                }
            }
            .photosPicker(isPresented: $pickingPhoto, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        TryOnStudio.shared.photo = image
                    }
                    TryOnStudio.shared.hasPhoto = true
                    photoItem = nil
                    if let piece = waiting { route = TryOnRoute(step: .styling(piece)) }
                    waiting = nil
                }
            }
    }

    private func start(_ piece: StoreProduct) {
        let studio = TryOnStudio.shared
        if let look = studio.look(for: piece) {
            route = TryOnRoute(step: .result(look, .catalogue))
        } else if studio.hasPhoto {
            route = TryOnRoute(step: .styling(piece))
        } else {
            waiting = piece
            onboarding = true
        }
    }
}

private extension View {
    func tryOnLauncher(_ request: Binding<StoreProduct?>) -> some View {
        modifier(TryOnLauncher(request: request))
    }
}

// MARK: - Figma "Try on" pill

/// The Figma's try-on pill: dark, a light edge, a soft glow rising from the foot, a sparkle and the
/// chrome shirt on a hanger peeking out at the end. `.large` is the gallery's floating "Virtual try
/// on"; `.card` and `.page` are the "Try on" pills on a look's photo.
struct OccasionTryOnPill: View {
    enum Size { case large, card, page }

    var size: Size = .card
    let action: () -> Void

    private var metrics: (width: CGFloat, height: CGFloat, text: CGFloat, title: String, sparkle: String,
                          sparkleAt: CGPoint, sparkleSize: CGSize, shirt: CGFloat, shirtTrailing: CGFloat, shirtTop: CGFloat,
                          glow: String, glowAt: CGPoint) {
        switch size {
        case .large:
            (166, 40, 16, "Virtual try on", "occ_sparkle_lg", CGPoint(x: 122.42, y: 4.85), CGSize(width: 13.45, height: 13.26),
             36.64, 2.62, 6.68, "occ_pill_glow", CGPoint(x: -3.62, y: 3.21))
        case .card:
            (93, 28, 14, "Try on", "occ_sparkle_sm", CGPoint(x: 61.93, y: 4.09), CGSize(width: 10.69, height: 10.54),
             24.96, 1.22, 6, "occ_pill_glow_white", CGPoint(x: -39.62, y: -3.79))
        case .page:
            (93, 32, 14, "Try on", "occ_sparkle_pdp", CGPoint(x: 61.93, y: 4.09), CGSize(width: 10.69, height: 10.54),
             27.14, 0.86, 7.36, "occ_pill_glow", CGPoint(x: -39.62, y: -3.79))
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    /// Only the floating gallery pill moves; the small pills on photos stay still.
    private var animated: Bool { size == .large && !reduceMotion }

    var body: some View {
        let m = metrics
        Button(action: action) {
            TimelineView(.animation(paused: !animated)) { context in
                pill(m, t: animated ? context.date.timeIntervalSinceReferenceDate : nil)
            }
            .shadow(color: .black.opacity(size == .large ? 0.75 : 0.25), radius: size == .large ? 21.5 : 6.5, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(m.title)
        .accessibilityHint("Shows this on you with virtual try-on")
        // The floating pill springs up from below once the looks are on screen.
        .offset(y: size == .large && !arrived && !reduceMotion ? 90 : 0)
        .opacity(size == .large && !arrived ? 0 : 1)
        .onAppear {
            guard size == .large else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.66).delay(0.35)) {
                arrived = true
            }
        }
    }

    /// The pill at time `t`; `nil` draws it at rest. In motion the shirt sways on its hook, the
    /// sparkle twinkles, the glow breathes, and every few seconds a glint crosses the pill and
    /// lights its edge as it goes.
    private func pill(_ m: (width: CGFloat, height: CGFloat, text: CGFloat, title: String, sparkle: String,
                            sparkleAt: CGPoint, sparkleSize: CGSize, shirt: CGFloat, shirtTrailing: CGFloat, shirtTop: CGFloat,
                            glow: String, glowAt: CGPoint), t: Double?) -> some View {
        let w = m.width - 2, h = m.height - 2
        let sway = t.map { sin($0 * 2.2) * 7 } ?? 0
        let twinkle = t.map { (sin($0 * 3.1) + 1) / 2 } ?? 1
        let breathe = t.map { 0.7 + 0.3 * sin($0 * 1.6) } ?? 1
        // The glint crosses in the first 1.1s of each 3.6s.
        let glint = t.map { $0.truncatingRemainder(dividingBy: 3.6) / 1.1 } ?? 2
        let band = Capsule()
            .fill(LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing))
            .frame(width: 44, height: h * 2)
            .rotationEffect(.degrees(20))
            .offset(x: -50 + (w + 100) * min(glint, 1), y: -h / 2)
        return ZStack(alignment: .topLeading) {
            Color(rgba: 0x131316FF)
            // The glow rising from the foot.
            Image(m.glow).resizable()
                .frame(width: 173.41, height: 98.02)
                .offset(x: m.glowAt.x, y: m.glowAt.y)
                .opacity(breathe)
            Text(m.title)
                .dropFont("SemiBold", m.text, relativeTo: .callout)
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .frame(height: h)
                .padding(.leading, 12)
            Image(m.sparkle).resizable()
                .frame(width: m.sparkleSize.width, height: m.sparkleSize.height)
                .scaleEffect(0.75 + 0.35 * twinkle)
                .rotationEffect(.degrees(t.map { sin($0 * 1.5) * 18 } ?? 0))
                .opacity(0.55 + 0.45 * twinkle)
                .offset(x: m.sparkleAt.x, y: m.sparkleAt.y)
            Image("occ_pill_shirt").resizable().scaledToFill()
                .frame(width: m.shirt, height: m.shirt)
                .scaleEffect(x: -1, y: 1)
                // Swinging from the hanger's hook.
                .rotationEffect(.degrees(sway), anchor: UnitPoint(x: 0.62, y: 0.08))
                .offset(x: w - m.shirtTrailing - m.shirt, y: m.shirtTop)
            if glint <= 1 {
                band.opacity(0.22).blendMode(.plusLighter)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipShape(Capsule())
        .padding(1)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
        .overlay {
            if glint <= 1 {
                Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                    .mask(alignment: .topLeading) { band.offset(x: 1, y: 1) }
            }
        }
    }
}

// MARK: - Stores home rail

/// Filter chips over a rail of festive edit cards.
struct ShopForOccasionRail: View {
    let open: (OccasionEdit) -> Void
    @State private var filter: Int? = 0

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(Array(OccasionData.filters.enumerated()), id: \.offset) { i, name in
                        let on = filter == i
                        Button { withAnimation(.snappy) { filter = on ? nil : i } } label: {
                            HStack(spacing: 6) {
                                Text(name)
                                if on { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)) }
                            }
                        }
                        // The Figma keeps every chip in its default state; the chosen one carries the ✕.
                        .buttonStyle(BackstageFilterButtonStyle(isActive: false))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace16) {
                    ForEach(OccasionData.edits) { edit in
                        OccasionEditCard(edit: edit) { open(edit) }
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }
}

/// Figma rail card: the Diwali header art under a fade, "Try on available", the bookmark, the
/// edit's name and three of its looks. The card opens the edit's gallery.
private struct OccasionEditCard: View {
    let edit: OccasionEdit
    let action: () -> Void
    @State private var saved = false

    private static let size = CGSize(width: 305.81, height: 378.03)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                OccasionDiwaliArt()
                    .offset(x: (Self.size.width - 343) / 2, y: -1)
                LinearGradient(stops: [.init(color: Color(rgba: 0x13131600), location: 0.0036),
                                       .init(color: Color(rgba: 0x131316DA), location: 0.51),
                                       .init(color: Color(rgba: 0x131316FF), location: 0.6567)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: Self.size.width, height: 131.72)
                    .offset(y: 122.04)
                foot
                    .frame(width: Self.size.width, height: Self.size.height, alignment: .bottomLeading)
            }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .background(M.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(edit.title). Try on available.")
        .accessibilityHint("Opens the looks")
        .overlay(alignment: .topLeading) {
            Text("Try on available")
                .dropFont("Medium", 12, relativeTo: .caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(M.surfaceTransparent, in: Capsule())
                .padding(.leading, 12.24)
                .padding(.top, 9.7)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            Button { saved.toggle() } label: {
                Image("occ_hotlist").resizable().frame(width: 32, height: 32)
                    .overlay {
                        if saved { Image(systemName: "bookmark.fill").font(.system(size: 11)).foregroundStyle(.white) }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(3.7)
            .accessibilityLabel(saved ? "Saved" : "Save")
            .sensoryFeedback(.selection, trigger: saved)
        }
    }

    private var foot: some View {
        VStack(alignment: .leading, spacing: 10.7) {
            Text(edit.title)
                .dropFont("SemiBold", 14, relativeTo: .subheadline)
                .tracking(-0.24)
                .foregroundStyle(M.textPrimary)
                .lineLimit(1)
                .padding(.leading, 12)
                .padding(.trailing, 10.7)
            HStack(spacing: 11.54) {
                ForEach(edit.thumbs, id: \.self) { thumb in
                    Image(thumb).resizable().scaledToFill()
                        .frame(width: 119.22, height: 119.22)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.leading, 14.375)
            .frame(width: Self.size.width, alignment: .leading)
            .clipped()
        }
        .padding(.vertical, R.spacingSpace16)
    }
}

/// The Figma "Dark Mode Header - diwali": a midnight-to-plum wash, a soft glow, three fine rings
/// and the "Out this Diwali" lettering with its gold stars.
private struct OccasionDiwaliArt: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("occ_glow_ellipse").resizable().frame(width: 611.71, height: 521.79).offset(x: -115.93, y: -274.03)
            Image("occ_ring_dashed").resizable().frame(width: 247.53, height: 247.53).offset(x: 47.73, y: -187.64)
            Image("occ_ring").resizable().frame(width: 205.11, height: 205.11).offset(x: -13.72, y: -155.51)
            Image("occ_ring").resizable().frame(width: 205.11, height: 205.11).offset(x: 193.89, y: -155.51)
            Image("occ_art_diwali").resizable().scaledToFill()
                .frame(width: 231.16, height: 143.69).clipped()
                .offset(x: 55.37, y: 51.16)
            Image("occ_star_big").resizable().frame(width: 18.7, height: 21.44).offset(x: 82.79, y: 72.06)
            Image("occ_star_big").resizable().frame(width: 18.7, height: 21.44).offset(x: 233.02, y: 72.06)
            Image("occ_star_mid").resizable().frame(width: 8.17, height: 10.51).offset(x: 265.13, y: 168.77)
            Image("occ_star_small").resizable().frame(width: 4.67, height: 5.84).offset(x: 256.96, y: 185.11)
        }
        .frame(width: 343, height: 385, alignment: .topLeading)
        .background {
            LinearGradient(stops: [.init(color: Color(rgba: 0x000A48FF), location: 0.13),
                                   .init(color: Color(rgba: 0x2A014087), location: 0.5),
                                   .init(color: Color(rgba: 0x01041A87), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .background(Color(rgba: 0x131313FF))
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Gallery

/// Figma "No vibe section": the edit's looks in a three-across grid under collection chips, with
/// try-on taught inline at the head of the grid. A look opens its quick view, where try-on starts.
struct OccasionGalleryView: View {
    let edit: OccasionEdit
    @Environment(\.dismiss) private var dismiss
    @State private var collection = 0
    @State private var quickLook: Int?
    @State private var product: StoreProduct?
    @State private var tryOn: StoreProduct?
    /// The how-it-works card shows open on the first visit, then stays folded to one line.
    @AppStorage("occasionTryOnIntroSeen") private var introSeen = false
    /// Iteration B: landing on "Trendy winter outfit" raises the intro sheet instead of the banner.
    @State private var introSheet = false
    /// Iteration C: landing on "Bestseller-Men" plays the mirror reveal, then guides the first
    /// try-on: a tooltip on a look, then one on its Try on pill.
    @State private var reveal = false
    @State private var guideOpenLook = false

    /// Eighteen tiles, the edit's looks in turn.
    private var tiles: [StoreProduct] { (0..<18).map { edit.looks[$0 % edit.looks.count] } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                chips
                // Iteration A (Spring collection): the inline banner. Iteration B (Trendy winter
                // outfit) teaches with an intro sheet instead, so the two can be compared.
                if collection == 0 {
                    TryOnIntroCard(expanded: !introSeen) { open in
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { introSeen = !open }
                    }
                    .padding(.horizontal, R.spacingSpace16)
                    .transition(.opacity)
                }
                grid
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(M.backgroundPrimary.ignoresSafeArea())
        // Iteration C, step 2: a tooltip on the first look ("Tap a look to open it").
        .overlayPreferenceValue(GuideTileKey.self) { anchor in
            if guideOpenLook, let anchor {
                OpenLookGuide(anchor: anchor) { withAnimation(.easeOut(duration: 0.3)) { guideOpenLook = false } }
                    .transition(.opacity)
            }
        }
        // Iteration C, step 1: the mirror reveal, mid-screen.
        .overlay {
            if reveal {
                TryOnMirrorReveal(
                    start: {
                        withAnimation(.easeOut(duration: 0.35)) { reveal = false }
                        // Next: point at a look, then at its Try on pill once it opens.
                        UserDefaults.standard.set(false, forKey: "occasionTryOnTipSeen")
                        withAnimation(.easeOut(duration: 0.4).delay(0.35)) { guideOpenLook = true }
                    },
                    close: { withAnimation(.easeOut(duration: 0.35)) { reveal = false } }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let quickLook {
                OccasionQuickLook(looks: tiles, start: quickLook,
                                  close: { withAnimation(.snappy) { self.quickLook = nil } },
                                  open: { product = $0 },
                                  tryOn: { tryOn = $0 })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .readerCover(item: $product) { OccasionProductView(product: $0) }
        .onChange(of: collection) { _, new in
            guideOpenLook = false
            Task {
                try? await Task.sleep(for: .seconds(0.45))
                guard collection == new else { return }
                if new == 1 { introSheet = true }
                if new == 2 { withAnimation(.easeOut(duration: 0.7)) { reveal = true } }
            }
        }
        .sheet(isPresented: $introSheet) {
            TryOnIntroSheet { introSheet = false }
        }
        .tryOnLauncher($tryOn)
        #if DEBUG
        // `-occasionQuickLook`, `-occasionPDP` and `-occasionTryOn` open a step of the flow.
        .task {
            guard !DebugLaunch.occasionUsed else { return }
            DebugLaunch.occasionUsed = true
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-occasionResetTips") {
                introSeen = false
                UserDefaults.standard.set(false, forKey: "occasionTryOnTipSeen")
            }
            try? await Task.sleep(for: .seconds(0.6))
            if args.contains("-occasionWinter") { withAnimation(.snappy) { collection = 1 } }
            if args.contains("-occasionMen") { withAnimation(.snappy) { collection = 2 } }
            if args.contains("-occasionGuide") {
                UserDefaults.standard.set(false, forKey: "occasionTryOnTipSeen")
                withAnimation(.easeOut(duration: 0.4)) { guideOpenLook = true }
            }
            if args.contains("-occasionQuickLook") { quickLook = 1 }
            if args.contains("-occasionPDP") { product = edit.looks[1] }
            if args.contains("-occasionTryOn") { introSeen = false }
        }
        #endif
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "arrow.left", label: "Back") { dismiss() }
            Text(edit.gallery)
                .dropFont("SemiBold", 18, relativeTo: .title3)
                .tracking(-0.18)
                .foregroundStyle(Color(rgba: 0xFAFAFAFF))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, 6)
        .background(M.backgroundPrimary)
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(Array(OccasionData.collections.enumerated()), id: \.offset) { i, name in
                    let on = collection == i
                    Button { withAnimation(.snappy) { collection = i } } label: {
                        Text(name)
                            .dropFont(on ? "Regular" : "Medium", 12, relativeTo: .caption)
                            .foregroundStyle(on ? Color(rgba: 0xFAFAFAFF) : M.textSecondary)
                            .padding(.horizontal, on ? 8 : 12)
                            .frame(height: 40)
                            .background(on ? Color.black.opacity(0.16) : .clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Color(rgba: 0xF1F1F2FF) : Color.white.opacity(0.16), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .padding(.top, R.spacingSpace16)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { i, look in
                Button {
                    guideOpenLook = false
                    withAnimation(.snappy) { quickLook = i }
                } label: {
                    Color(rgba: 0x1E1E20FF)
                        .overlay(alignment: .top) { Image(look.image).resizable().scaledToFill() }
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .anchorPreference(key: GuideTileKey.self, value: .bounds) { i == 0 ? $0 : nil }
                .accessibilityLabel("\(look.name), \(look.brand), \(rupees(look.price))")
                .accessibilityHint("Opens a quick view")
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }
}

// MARK: - Quick view

/// Figma 3837:9057: the looks as cards over the dimmed grid, swiped sideways. Each card has
/// "Try on" on its photo, the brand, name and price, and "Check availability" / "Wishlist".
private struct OccasionQuickLook: View {
    let looks: [StoreProduct]
    let start: Int
    let close: () -> Void
    let open: (StoreProduct) -> Void
    let tryOn: (StoreProduct) -> Void
    @State private var current: Int?
    @State private var wished: Set<Int> = []
    /// The first quick view points once at its "Try on" pill.
    @AppStorage("occasionTryOnTipSeen") private var tipSeen = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.62).ignoresSafeArea()
                .onTapGesture(perform: close)
            GeometryReader { g in
                ScrollView(.horizontal) {
                    HStack(spacing: R.spacingSpace16) {
                        ForEach(Array(looks.enumerated()), id: \.offset) { i, look in
                            card(look, i)
                                .scrollTransition(.interactive, axis: .horizontal) { c, phase in
                                    c.scaleEffect(phase.isIdentity ? 1 : 0.94).opacity(phase.isIdentity ? 1 : 0.6)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, (g.size.width - 316) / 2, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $current)
                .scrollIndicators(.hidden)
                .frame(height: 500)
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear { current = start }
        // The tip leaves on its own after a while, or as soon as the looks are swiped.
        .task {
            guard !tipSeen else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.easeOut(duration: 0.25)) { tipSeen = true }
        }
        .onChange(of: current) { old, _ in
            if old != nil, !tipSeen { withAnimation(.easeOut(duration: 0.2)) { tipSeen = true } }
        }
    }

    private func card(_ look: StoreProduct, _ i: Int) -> some View {
        VStack(spacing: 0) {
            Button { open(look) } label: {
                Color(rgba: 0xEBEBEBFF)
                    .overlay(alignment: .top) {
                        Image(look.image).resizable().scaledToFill()
                            .frame(width: 316, height: 434)
                            .offset(y: -13.8)
                    }
                    .frame(width: 316, height: 311)
                    .clipped()
                    .shadow(color: .white.opacity(0.08), radius: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(look.name) photo")
            .accessibilityHint("Opens the product")
            .overlay(alignment: .bottom) { dots.padding(.bottom, 8) }
            .overlay(alignment: .topLeading) {
                OccasionTryOnPill(size: .card) {
                    tipSeen = true
                    tryOn(look)
                }
                .modifier(TryOnCoachMark(active: !tipSeen && i == (current ?? start), below: true,
                                         text: "Tap Try on to see it on you", step: 2) {
                    withAnimation(.easeOut(duration: 0.2)) { tipSeen = true }
                })
                .padding(.leading, 13.5)
                .padding(.top, 14)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: close) {
                    Image("occ_ic_cross").resizable().frame(width: 10.5, height: 10.5)
                        .frame(width: 24, height: 24)
                        .padding(4)
                        .background(Color.black.opacity(0.08), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel("Close")
            }
            VStack(spacing: 8) {
                Text(look.brand)
                    .dropFont("Medium", 12, relativeTo: .caption)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(M.textSecondary)
                Text(look.name)
                    .dropFont("SemiBold", 16, relativeTo: .headline)
                    .tracking(-0.16)
                    .foregroundStyle(Color(rgba: 0xFAFAFAFF))
                Text(rupees(look.price))
                    .dropFont("Regular", 12, relativeTo: .caption)
                    .foregroundStyle(M.textSecondary)
            }
            .lineLimit(1)
            .frame(width: 316)
            .padding(.top, R.spacingSpace16)
            Spacer(minLength: 0)
            actions(look, i, wishlistWidth: 115)
                .padding(8)
                .frame(width: 292)
                .background(Color.black.opacity(0.56), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.bottom, 14)
        }
        .frame(width: 316, height: 500)
        .background(M.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 17, y: 16)
        .id(i)
    }

    private func actions(_ look: StoreProduct, _ i: Int, wishlistWidth: CGFloat) -> some View {
        HStack(spacing: R.spacingSpace12) {
            Button("Check availability") { open(look) }
                .buttonStyle(OccasionPrimaryStyle())
            Button { wished.formSymmetricDifference([i]) } label: {
                HStack(spacing: 4) {
                    Image(systemName: wished.contains(i) ? "heart.fill" : "heart").font(.system(size: 16))
                    Text("Wishlist").dropFont("SemiBold", 14, relativeTo: .callout)
                }
                .foregroundStyle(M.textPrimary)
                .frame(width: wishlistWidth, height: 44)
                .overlay(Capsule().strokeBorder(M.borderIntense, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: wished)
        }
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { d in
                Circle().fill(d == 0 ? Color(rgba: 0xF7F7F7FF) : Color.white.opacity(0.48))
                    .frame(width: d == 0 ? 6 : 4.5, height: d == 0 ? 6 : 4.5)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.24), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75))
        .accessibilityHidden(true)
    }
}

/// The Figma's medium filled button (44pt), in the primary button's tokens, sized to share the
/// glass bar with "Wishlist".
private struct OccasionPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dropFont("SemiBold", 14, relativeTo: .callout)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .foregroundStyle(M.buttonPrimaryLabel)
            .padding(.horizontal, R.spacingSpace12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(configuration.isPressed ? M.buttonPrimaryBackgroundPressed : M.buttonPrimaryBackground, in: Capsule())
            .contentShape(Capsule())
    }
}

// MARK: - Product page

/// Figma "CATALOUGE" (3837:9220): the look full width with "Try on" on it, its photos as
/// thumbnails, and "Check availability" / "Wishlist" in a glass bar.
struct OccasionProductView: View {
    let product: StoreProduct
    @Environment(\.dismiss) private var dismiss
    @State private var photo = 2
    @State private var wished = false
    @State private var tryOn: StoreProduct?

    var body: some View {
        VStack(spacing: 0) {
            header
            Color(rgba: 0xEBEBEBFF)
                .overlay(alignment: .top) {
                    Image(product.image).resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .offset(y: -12.5)
                }
                .frame(height: 457)
                .clipped()
                .overlay(alignment: .topLeading) {
                    OccasionTryOnPill(size: .page) { tryOn = product }
                        .padding(14)
                }
                .padding(.top, 23)
            thumbnails
                .padding(.top, 32)
            Spacer(minLength: R.spacingSpace16)
            HStack(spacing: R.spacingSpace12) {
                Button("Check availability") {}
                    .buttonStyle(OccasionPrimaryStyle())
                Button { wished.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: wished ? "heart.fill" : "heart").font(.system(size: 16))
                        Text("Wishlist").dropFont("SemiBold", 14, relativeTo: .callout)
                    }
                    .foregroundStyle(M.textPrimary)
                    .frame(width: 139, height: 44)
                    .overlay(Capsule().strokeBorder(M.borderIntense, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: wished)
            }
            .padding(R.spacingSpace16)
            .background(Color.black.opacity(0.56), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, R.spacingSpace16)
            .padding(.bottom, 15)
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .tryOnLauncher($tryOn)
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "arrow.left", label: "Back") { dismiss() }
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(product.name)
                    .dropFont("SemiBold", 18, relativeTo: .title3)
                    .tracking(-0.18)
                    .foregroundStyle(Color(rgba: 0xFAFAFAFF))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 0) {
                    Text(product.brand).dropFont("Medium", 12, relativeTo: .caption)
                    Image("occ_ic_chevron").resizable().frame(width: 16, height: 16)
                }
                .foregroundStyle(Color(rgba: 0x77777EFF))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, 6)
    }

    private var thumbnails: some View {
        HStack(spacing: R.spacingSpace8) {
            ForEach(0..<5, id: \.self) { i in
                let on = i == photo
                Button { photo = i } label: {
                    Color(rgba: 0xEBEBEBFF)
                        .overlay(alignment: .top) { Image(product.image).resizable().scaledToFill() }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(on ? 2 : 0)
                        .overlay {
                            if on { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(rgba: 0xF7F7F7FF), lineWidth: 1) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Photo \(i + 1)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - How it works

/// Try-on taught in place, at the head of the grid. Open: the Figma's champagne double arch with
/// the look-changing morph inside, beside a quiet kicker, a silver title and one line of how-to.
/// The ✕ folds it to a slim reminder that reopens it. Figma VTO palette only (graphite,
/// champagne, silver, white).
private struct TryOnIntroCard: View {
    let expanded: Bool
    let setOpen: (Bool) -> Void

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        Group {
            if expanded { open } else { folded }
        }
        .background {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [VTOStyle.graphite, VTOStyle.page], startPoint: .top, endPoint: .bottom)
                // The Figma's spotlight, falling on the arch.
                RadialGradient(colors: [.white.opacity(0.09), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
            }
            .clipShape(shape)
        }
        .overlay(shape.strokeBorder(
            LinearGradient(colors: [VTOStyle.champagne.opacity(0.35), VTOStyle.champagne.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 0.8))
        .environment(\.colorScheme, .dark)
    }

    /// The double arch with the morph inside, as on the guide.
    private func arch(width: CGFloat, height: CGFloat, gap: CGFloat) -> some View {
        let inner = archShape(width: width, foot: 8)
        let outer = archShape(width: width + gap * 2, foot: 10)
        return TryOnLookMorph(hold: 1.4, sweep: 1.0)
            .frame(width: width, height: height)
            .clipShape(inner)
            .overlay(inner.strokeBorder(VTOStyle.champagne, lineWidth: 0.8))
            .padding(gap)
            .overlay(outer.strokeBorder(VTOStyle.champagne.opacity(0.45), lineWidth: 0.6))
    }

    private var open: some View {
        HStack(alignment: .center, spacing: 18) {
            arch(width: 74, height: 108, gap: 5)
                .overlay(alignment: .topTrailing) {
                    Twinkle(asset: "vto_edu_star_small", size: 13).offset(x: 12, y: 6)
                }
                .overlay(alignment: .bottomLeading) {
                    Twinkle(asset: "vto_edu_star_mid", size: 10, delay: 0.7).offset(x: -10, y: -18)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("VIRTUAL TRY-ON")
                    .dropFont("Medium", 10, relativeTo: .caption2)
                    .tracking(2.2)
                    .foregroundStyle(VTOStyle.champagne.opacity(0.85))
                Text("See any look\non you")
                    .dropFont("Medium", 21, relativeTo: .title3)
                    .tracking(-0.3)
                    .foregroundStyle(VTOStyle.silver)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Open a look, tap Try on and add one photo of you.")
                    .dropFont("Regular", 13, relativeTo: .footnote)
                    .foregroundStyle(Color(rgba: 0xA5A5ACFF))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 22)
        .padding(.trailing, 36)
        .padding(.vertical, 18)
        .overlay(alignment: .topTrailing) {
            Button { setOpen(false) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(rgba: 0x77777EFF))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fold the try-on guide")
        }
        .transition(.opacity)
    }

    private var folded: some View {
        Button { setOpen(true) } label: {
            HStack(spacing: R.spacingSpace12) {
                arch(width: 20, height: 28, gap: 2.5)
                    .accessibilityHidden(true)
                Text("Every look here can be tried on you")
                    .dropFont("Regular", 13, relativeTo: .footnote)
                    .foregroundStyle(Color(rgba: 0xD9D9DEFF))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: R.spacingSpace8)
                HStack(spacing: 4) {
                    Text("How")
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .dropFont("Medium", 12, relativeTo: .caption)
                .foregroundStyle(VTOStyle.champagne.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Every look here can be tried on you")
        .accessibilityHint("Opens the try-on guide")
        .transition(.opacity)
    }
}

// MARK: - Intro sheet (iteration B)

/// A small sheet that rises on landing on "Trendy winter outfit". Centred and quiet: the try-on
/// arch with two of this page's looks fanned behind it under a spotlight, a short title and line,
/// three steps joined by a hairline, one button. Sized to its content. Figma VTO palette only.
private struct TryOnIntroSheet: View {
    let dismiss: () -> Void
    @State private var shown = false
    @State private var height: CGFloat = 560
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let steps: [(icon: String, label: String)] = [
        ("hand.tap", "Open\na look"), ("sparkle", "Tap\nTry on"), ("person.crop.rectangle", "See it\non you"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            hero

            VStack(spacing: 10) {
                Text("VIRTUAL TRY-ON")
                    .dropFont("Medium", 10, relativeTo: .caption2)
                    .tracking(2.4)
                    .foregroundStyle(VTOStyle.champagne.opacity(0.8))
                Text("See it on you,\nbefore the trial room")
                    .dropFont("Medium", 24, relativeTo: .title2)
                    .tracking(-0.4)
                    .lineSpacing(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(VTOStyle.silver)
                    .accessibilityAddTraits(.isHeader)
                Text("Add one photo of yourself and we'll dress it in any look you pick.")
                    .dropFont("Regular", 14, relativeTo: .subheadline)
                    .foregroundStyle(Color(rgba: 0x8B8B93FF))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 290)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 22)

            steps.padding(.top, 28)

            Button(action: dismiss) {
                Text("Start exploring")
                    .dropFont("SemiBold", 16, relativeTo: .headline)
                    .foregroundStyle(VTOStyle.page)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 30)

            HStack(spacing: 6) {
                Image("vto_edu_star_small").resizable().renderingMode(.template)
                    .frame(width: 10, height: 10)
                Text("10 free try-ons, every day")
                    .dropFont("Regular", 12, relativeTo: .caption)
            }
            .foregroundStyle(VTOStyle.champagne.opacity(0.75))
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            ZStack(alignment: .top) {
                VTOStyle.page
                // The Figma's spotlight, falling on the arch.
                RadialGradient(colors: [.white.opacity(0.12), .clear], center: .top, startRadius: 0, endRadius: 260)
                    .frame(height: 320)
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(VTOStyle.page)
        .environment(\.colorScheme, .dark)
        .onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.22).delay(0.12)) { shown = true } }
    }

    /// The arch with the look-changing morph, two of this page's lehengas fanned behind it.
    private var hero: some View {
        let inner = archShape(width: 104, foot: 10)
        let outer = archShape(width: 116, foot: 12)
        return ZStack {
            fanned("occ_lehenga_navy", angle: -9, x: -74)
            fanned("occ_lehenga_blue", angle: 9, x: 74)
            TryOnLookMorph(hold: 1.3, sweep: 1.0)
                .frame(width: 104, height: 150)
                .clipShape(inner)
                .overlay(inner.strokeBorder(VTOStyle.champagne, lineWidth: 0.9))
                .padding(6)
                .background(outer.fill(VTOStyle.page))
                .overlay(outer.strokeBorder(VTOStyle.champagne.opacity(0.45), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
                .overlay(alignment: .topTrailing) { Twinkle(asset: "vto_edu_star_big", size: 18).offset(x: 20, y: 8) }
                .overlay(alignment: .bottomLeading) { Twinkle(asset: "vto_edu_star_mid", size: 12, delay: 0.7).offset(x: -18, y: -26) }
        }
        .frame(height: 176)
        .padding(.top, 20)
        .scaleEffect(shown ? 1 : 0.94)
        .opacity(shown ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func fanned(_ image: String, angle: Double, x: CGFloat) -> some View {
        Color(rgba: 0xEBEBEBFF)
            .overlay(alignment: .top) { Image(image).resizable().scaledToFill() }
            .frame(width: 88, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.45)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .rotationEffect(.degrees(shown ? angle : 0))
            .offset(x: shown ? x : 0, y: 14)
    }

    /// Three steps, each an icon in a fine champagne ring, joined by a hairline.
    private var steps: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Self.steps.indices, id: \.self) { i in
                VStack(spacing: 10) {
                    Group {
                        if Self.steps[i].icon == "sparkle" {
                            Image("vto_edu_star_small").resizable().renderingMode(.template).frame(width: 15, height: 15)
                        } else {
                            Image(systemName: Self.steps[i].icon).font(.system(size: 16, weight: .light))
                        }
                    }
                    .foregroundStyle(VTOStyle.champagne)
                    .frame(width: 44, height: 44)
                    .background(VTOStyle.graphite, in: Circle())
                    .overlay(Circle().strokeBorder(VTOStyle.champagne.opacity(0.35), lineWidth: 0.8))
                    Text(Self.steps[i].label)
                        .dropFont("Regular", 12, relativeTo: .caption)
                        .foregroundStyle(Color(rgba: 0xD9D9DEFF))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(i + 1): \(Self.steps[i].label.replacingOccurrences(of: "\n", with: " "))")
            }
        }
        .background(alignment: .top) {
            // The hairline running through the three rings.
            Rectangle()
                .fill(LinearGradient(colors: [.clear, VTOStyle.champagne.opacity(0.3), VTOStyle.champagne.opacity(0.3), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
                .padding(.horizontal, 40)
                .offset(y: 22)
        }
    }
}

// MARK: - Mirror reveal (iteration C)

/// Landing on "Bestseller-Men": a slow reveal that teaches try-on is available here. A dressing-room
/// mirror rises in, its bulbs light one by one, and the misted glass clears to show a look changing
/// on a person. "Start trying on" hands over to the guided tooltips; the ✕ just closes.
/// Figma VTO palette only (graphite, champagne, silver, white).
private struct TryOnMirrorReveal: View {
    let start: () -> Void
    let close: () -> Void

    @State private var risen = false
    @State private var lit: Date?
    @State private var cleared = false
    @State private var copy = false
    @State private var actions = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mirror = CGSize(width: 156, height: 218)
    private let ink = Color(rgba: 0x131316FF)

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
                .onTapGesture(perform: close)

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image("vto_edu_star_small").resizable().renderingMode(.template).frame(width: 11, height: 11)
                        Text("VIRTUAL TRY-ON")
                            .dropFont("Medium", 11, relativeTo: .caption)
                            .tracking(2.4)
                    }
                    .foregroundStyle(Color(rgba: 0xB9B9C2FF))
                    Text("Every look here can\nbe tried on you")
                        .dropFont("SemiBold", 22, relativeTo: .title2)
                        .tracking(-0.4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(VTOStyle.silver)
                        .shadow(color: .white.opacity(0.3), radius: 12)
                }
                .opacity(copy ? 1 : 0)
                .offset(y: copy ? 0 : 10)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                ZStack {
                    PassRays()
                        .frame(width: 360, height: 360)
                        .opacity(risen ? 0.7 : 0)
                    mirrorView
                        .scaleEffect(risen ? 1 : 0.86)
                        .offset(y: risen ? 0 : 60)
                        .opacity(risen ? 1 : 0)
                    sparkles.opacity(cleared ? 1 : 0)
                }
                .frame(height: mirror.height + 24)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Just tap")
                        OccasionTryOnPill(size: .card) {}
                            .allowsHitTesting(false)
                        Text("on any look")
                    }
                    .dropFont("Regular", 15, relativeTo: .subheadline)
                    .foregroundStyle(Color(rgba: 0xD9D9DEFF))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Just tap Try on on any look")
                    Text("10 free try-ons, every day")
                        .dropFont("Regular", 12, relativeTo: .caption)
                        .foregroundStyle(Color(rgba: 0x8B8B93FF))
                }
                .padding(.top, 10)
                .opacity(copy ? 1 : 0)

                Button(action: start) {
                    Text("Start trying on")
                        .dropFont("SemiBold", 17, relativeTo: .headline)
                        .foregroundStyle(ink)
                        .frame(width: 240, height: 50)
                        .background(Color.white, in: Capsule())
                        .overlay { Glint(enabled: !reduceMotion).clipShape(Capsule()) }
                        .shadow(color: .white.opacity(0.22), radius: 16)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 18)
                .opacity(actions ? 1 : 0)
                .offset(y: actions ? 0 : 16)
                .accessibilityHint("Shows you how to try on a look")

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .opacity(actions ? 1 : 0)
                .accessibilityLabel("Close")
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .sensoryFeedback(.impact(weight: .light), trigger: cleared)
        .onAppear(perform: play)
    }

    /// Slow on purpose: rise, bulbs, the mist clearing, then the words and the buttons.
    private func play() {
        if reduceMotion {
            risen = true; lit = .distantPast; cleared = true; copy = true; actions = true
            return
        }
        withAnimation(.spring(response: 1.3, dampingFraction: 0.86).delay(0.5)) { risen = true }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            lit = .now
        }
        withAnimation(.easeInOut(duration: 1.4).delay(2.4)) { cleared = true }
        withAnimation(.easeOut(duration: 0.9).delay(3.3)) { copy = true }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.86).delay(3.9)) { actions = true }
    }

    // MARK: Mirror

    private var mirrorView: some View {
        let frameShape = archShape(width: mirror.width, foot: 14)
        let glass = archShape(width: mirror.width - 26, foot: 7)
        return ZStack {
            // The frame: dark graphite glass with a chrome rim, like the Try on button.
            frameShape
                .fill(LinearGradient(colors: [Color(rgba: 0x3A3A3EFF), Color(rgba: 0x1E1E20FF), Color(rgba: 0x131316FF)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(frameShape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.85), Color(rgba: 0xB9C2D6FF).opacity(0.5), .white.opacity(0.15), .white.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
                .shadow(color: .white.opacity(0.14), radius: 24)

            // The glass: the look changing on a person, misted until it clears.
            ZStack {
                TryOnLookMorph(hold: 1.4, sweep: 1.1)
                mist
                Sheen(enabled: !reduceMotion && cleared)
            }
            .frame(width: mirror.width - 26, height: mirror.height - 26)
            .clipShape(glass)
            .overlay(glass.strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8))

            bulbs
        }
        .frame(width: mirror.width, height: mirror.height)
        .background(alignment: .bottom) {
            // A soft pool of light on the floor.
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 200, height: 32)
                .offset(y: 16)
        }
        .accessibilityHidden(true)
    }

    /// Silvery mist over the glass that wipes away from left to right.
    private var mist: some View {
        GeometryReader { g in
            let w = g.size.width
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.42),
                                   .init(color: .white, location: 0.56), .init(color: .white, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 2.4, height: g.size.height * 1.4)
                .offset(x: cleared ? 0 : -w * 1.32, y: -g.size.height * 0.2)
                .mask {
                    LinearGradient(colors: [Color(rgba: 0xE8E8EEFF), Color(rgba: 0xB9B9C2FF)], startPoint: .top, endPoint: .bottom)
                }
                .opacity(0.94)
        }
        .allowsHitTesting(false)
    }

    /// Dressing-room bulbs round the frame, lighting one by one, then glowing softly.
    private var bulbs: some View {
        TimelineView(.animation(paused: lit == nil || reduceMotion)) { context in
            let since = lit.map { context.date.timeIntervalSince($0) } ?? -1
            let points = Self.bulbPoints(in: CGSize(width: mirror.width - 13, height: mirror.height - 13), count: 14)
            ZStack(alignment: .topLeading) {
                ForEach(points.indices, id: \.self) { k in
                    let on = lit != nil && (reduceMotion || since > Double(k) * 0.07)
                    let glow = reduceMotion || since < 0 ? 1 : 0.8 + 0.2 * sin(since * 2.4 + Double(k) * 0.9)
                    Circle()
                        .fill(on ? Color.white : Color(rgba: 0x4A4A50FF))
                        .frame(width: 6, height: 6)
                        .shadow(color: on ? .white.opacity(0.9) : .clear, radius: 5)
                        .shadow(color: on ? .white.opacity(0.8) : .clear, radius: 2)
                        .opacity(on ? glow : 1)
                        .position(points[k])
                }
            }
            .frame(width: mirror.width - 13, height: mirror.height - 13, alignment: .topLeading)
        }
    }

    /// Evenly spaced points along an arch (left side up, over the top, right side down).
    private static func bulbPoints(in size: CGSize, count: Int) -> [CGPoint] {
        let w = size.width, h = size.height, r = w / 2
        let side = h - r - 10
        let total = side * 2 + .pi * r
        return (0..<count).map { k in
            let d = total * (CGFloat(k) + 0.5) / CGFloat(count)
            if d < side { return CGPoint(x: 0, y: h - 10 - d) }
            if d < side + .pi * r {
                let theta = .pi + (d - side) / r
                return CGPoint(x: r + r * cos(theta), y: r + r * sin(theta))
            }
            return CGPoint(x: w, y: r + (d - side - .pi * r))
        }
    }

    private var sparkles: some View {
        ZStack {
            Twinkle(asset: "vto_edu_star_big", size: 20).offset(x: -112, y: -56)
            Twinkle(asset: "vto_edu_star_small", size: 14, delay: 0.4).offset(x: 110, y: -88)
            Twinkle(asset: "vto_edu_star_mid", size: 12, delay: 0.8).offset(x: 106, y: 70)
            Twinkle(asset: "vto_edu_star_small", size: 10, delay: 1.1).offset(x: -104, y: 96)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A slow diagonal sheen across the mirror glass.
private struct Sheen: View {
    let enabled: Bool

    var body: some View {
        TimelineView(.animation(paused: !enabled)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4.5) / 1.4
            GeometryReader { g in
                if enabled && t <= 1 {
                    LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 50, height: g.size.height * 1.6)
                        .rotationEffect(.degrees(24))
                        .offset(x: -80 + (g.size.width + 160) * t, y: -g.size.height * 0.3)
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Soft light rays, slowly turning, fading out from the centre.
private struct PassRays: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let stops: [Gradient.Stop] = (0..<20).flatMap { i -> [Gradient.Stop] in
            [.init(color: .white.opacity(0.22), location: Double(i) / 20),
             .init(color: .white.opacity(0), location: (Double(i) + 0.5) / 20)]
        }
        TimelineView(.animation(paused: reduceMotion)) { context in
            AngularGradient(gradient: Gradient(stops: stops), center: .center)
                .rotationEffect(.degrees(reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate * 5))
        }
        .mask(RadialGradient(colors: [.white, .white.opacity(0.4), .clear], center: .center, startRadius: 40, endRadius: 220))
        .overlay(RadialGradient(colors: [.white.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: 150))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A light band crossing the button every few seconds.
private struct Glint: View {
    let enabled: Bool

    var body: some View {
        TimelineView(.animation(paused: !enabled)) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8) / 0.9
            GeometryReader { g in
                if enabled && t <= 1 {
                    LinearGradient(colors: [.clear, VTOStyle.champagne.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 60, height: g.size.height * 2)
                        .rotationEffect(.degrees(20))
                        .offset(x: -60 + (g.size.width + 120) * t, y: -g.size.height / 2)
                        .blendMode(.multiply)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Guide: open a look (iteration C, step 2)

/// Where the first look sits, for the "open a look" tooltip.
private struct GuideTileKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// A light dim with a hole over the first look, a pulsing champagne ring round it and a tooltip
/// under it. Taps in the hole reach the look (which opens it); anywhere else ends the guide.
private struct OpenLookGuide: View {
    let anchor: Anchor<CGRect>
    let dismiss: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let r = proxy[anchor]
            let hole = RoundedRectangle(cornerRadius: 18, style: .continuous).path(in: r.insetBy(dx: -4, dy: -4))
            let dim = Path(CGRect(x: -400, y: -400, width: proxy.size.width + 800, height: proxy.size.height + 800))
                .subtracting(hole)
            ZStack(alignment: .topLeading) {
                dim.fill(Color.black.opacity(0.55))
                    .contentShape(dim)
                    .onTapGesture(perform: dismiss)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VTOStyle.champagne, lineWidth: 1.5)
                    .frame(width: r.width + 8, height: r.height + 8)
                    .scaleEffect(pulse ? 1.08 : 1)
                    .opacity(pulse ? 0 : 1)
                    .position(x: r.midX, y: r.midY)
                    .allowsHitTesting(false)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VTOStyle.champagne.opacity(0.9), lineWidth: 1.2)
                    .frame(width: r.width + 8, height: r.height + 8)
                    .shadow(color: VTOStyle.champagne.opacity(0.5), radius: 8)
                    .position(x: r.midX, y: r.midY)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: -2) {
                    // The caret, up towards the look.
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(.leading, max(12, r.width / 2 - 6))
                    bubble
                }
                .fixedSize()
                .offset(x: r.minX, y: r.maxY + 10)
                .onTapGesture(perform: dismiss)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { pulse = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(12))
            if !Task.isCancelled { dismiss() }
        }
        .accessibilityElement(children: .contain)
    }

    private var bubble: some View {
        HStack(spacing: 8) {
            Text("1")
                .dropFont("SemiBold", 11, relativeTo: .caption2)
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color(rgba: 0x131316FF), in: Circle())
            Text("Tap a look to open it")
                .dropFont("SemiBold", 14, relativeTo: .subheadline)
                .foregroundStyle(Color(rgba: 0x131316FF))
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .frame(height: 36)
        .background(Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Step 1 of 2")
    }
}
