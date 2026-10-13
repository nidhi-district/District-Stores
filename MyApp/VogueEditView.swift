import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// The Explore tab, "The Edit" (Figma: 🛍️ Homepage and Search › Editorial, 7212:108).
// A dark editorial scroll under the stage spotlight, read like a magazine: the page snaps section
// by section, and each new section slides up over the last one, which stays pinned beneath it
// like a page on a stack. Each section opens on a ghosted Playfair folio over a hairline rule and
// is washed from the top in its own faint colour; every photo card shares one frame (square
// corners, a hairline border and a frosted caption on a scrim tinted from the photo itself).

struct VogueEditView: View {
    @State private var scrollY: CGFloat = 0
    @State private var location = "Golf Course Extension Road"
    /// Where a finished section comes to rest: just under the header.
    @State private var pinTop: CGFloat = 0
    @State private var screenHeight: CGFloat = 0
    /// Each page's top edge in the column, for the scroll's soft snap.
    @State private var pageTops: [Int: CGFloat] = [:]
    /// The contents page's top edge on screen, so the closing glow can rise as it arrives.
    @State private var indexTop: CGFloat = .infinity
    @Environment(\.tabBarCompactHandler) private var setTabBarCompact

    private let locations = ["Golf Course Extension Road", "Vatika City", "Cyberhub, DLF Phase 2", "Sector 29"]

    var body: some View {
        ZStack(alignment: .top) {
            M.backgroundPrimary.ignoresSafeArea()
            Spotlight(scrollY: scrollY)

            ScrollViewReader { proxy in
            ScrollView(.vertical) {
                // No spacing: each page carries its own margins so its paper covers the gap too.
                // Pages keep their natural height, so one section runs straight into the next.
                VStack(alignment: .leading, spacing: 0) {
                    VogueStoriesSection().stackedPage(pinTop: pinTop, backdrop: nil).page(1, into: $pageTops)
                    VogueRackSection()
                        .stackedPage(pinTop: pinTop, backdrop: .wash(Color(hex: 0xA5A5AC).opacity(0.1))).page(2, into: $pageTops)
                    VoguePairSection().stackedPage(pinTop: pinTop, backdrop: .wash(.white.opacity(0.06))).page(3, into: $pageTops)
                    VogueLooksSection().stackedPage(pinTop: pinTop, backdrop: .wash(Color(hex: 0xF9B3EB).opacity(0.07))).page(4, into: $pageTops)
                    VoguePlansSection().stackedPage(pinTop: pinTop, backdrop: .wash(.white.opacity(0.06))).page(5, into: $pageTops)
                    VogueBentoSection().stackedPage(pinTop: pinTop, backdrop: .wash(Color(hex: 0xBCAEFE).opacity(0.08))).page(6, into: $pageTops)
                    VoguePaletteSection()
                        .stackedPage(pinTop: pinTop, backdrop: .bloom(EditorialData.palettes.compactMap { $0.hexes.first }))
                        .page(7, into: $pageTops)
                    // The contents page closes the tab; it fills the screen so the page ends on it.
                    VogueIndexSection { n in
                        withAnimation(.smooth(duration: 0.6)) { proxy.scrollTo(EditPages.id(n), anchor: .topLeading) }
                    }
                    .padding(.bottom, 96)
                    .stackedPage(pinTop: pinTop, minHeight: pageHeight, backdrop: nil)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { indexTop = $0 }
                    .page(8, into: $pageTops)
                }
                .coordinateSpace(name: EditPages.space)
            }
            // Free scrolling that settles on a section's top only when it stops close to one.
            // Flat scroll while testing: the soft section snap is off for now.
            // .scrollTargetBehavior(SectionSnap(tops: Array(pageTops.values)))
            #if DEBUG
            // Debug builds accept `-startSection N` so a simulator can open on a given section.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-startSection"), i + 1 < args.count, let n = Int(args[i + 1]) {
                    try? await Task.sleep(for: .seconds(2.5))
                    // `-startSection 0` jumps to the very end of the page instead.
                    if n == 0 { proxy.scrollTo(EditPages.id(8), anchor: .bottom) } else { proxy.scrollTo(EditPages.id(n), anchor: .topLeading) }
                }
                // `-flipGender` toggles Women / Men a moment later, to see the skeleton loader.
                if args.contains("-flipGender") {
                    try? await Task.sleep(for: .seconds(2))
                    let key = "edit.gender"
                    UserDefaults.standard.set(UserDefaults.standard.string(forKey: key) == "men" ? "women" : "men", forKey: key)
                }
            }
            #endif
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                VogueEditHeader(location: $location, locations: locations, scrolled: scrollY < -8)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { pinTop = $0 }
            }
            .modifier(ExploreScrollTracker(onScroll: scrolled(to:)))
            }

            BottomBarFade()
            // Above the fade so it reaches the screen's foot, behind the floating tab bar.
            EditBottomGlow().opacity(endReveal)
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { screenHeight = $0 }
        .environment(\.editorialStyle, .newspaper)
    }

    /// The screen below the header.
    private var pageHeight: CGFloat { max(0, screenHeight - pinTop) }

    /// 0 until the contents page comes up, 1 once it fills the screen.
    private var endReveal: Double {
        guard screenHeight > 0, pageHeight > 0, indexTop.isFinite else { return 0 }
        return Double(min(1, max(0, (screenHeight - indexTop) / pageHeight)))
    }

    /// `y` is the content's top edge: 0 at rest, negative as the page scrolls down.
    private func scrolled(to y: CGFloat) {
        let delta = y - scrollY
        if y > -40 { setTabBarCompact(false) }
        else if delta < -6 { setTabBarCompact(true) }
        else if delta > 6 { setTabBarCompact(false) }
        scrollY = y
    }
}

// MARK: - Scroll

private enum EditPages {
    static let space = "editPages"
    /// Page ids are strings so they never collide with the Int ids inside the carousels.
    static func id(_ n: Int) -> String { "page-\(n)" }
}

private extension View {
    /// Records where page `n` starts in the column.
    func page(_ n: Int, into tops: Binding<[Int: CGFloat]>) -> some View {
        id(EditPages.id(n)).onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(EditPages.space)).minY } action: { tops.wrappedValue[n] = $0 }
    }
}

/// A soft snap: a flick that comes to rest near a section's top edge glides onto it, and anywhere
/// else the page stops where the finger left it, so long sections stay free to read.
private struct SectionSnap: ScrollTargetBehavior {
    /// Section tops in the column (the scroll target's space, where the header inset is already applied).
    let tops: [CGFloat]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.minY
        guard let nearest = tops.min(by: { abs($0 - y) < abs($1 - y) }) else { return }
        if abs(nearest - y) < context.containerSize.height * 0.22 { target.rect.origin.y = nearest }
    }
}

/// The Figma's bottom bar: the page fades to black under the floating tabs.
private struct BottomBarFade: View {
    var body: some View {
        LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0), location: 0),
                               .init(color: M.backgroundPrimary, location: 0.88)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 110)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - System

/// The page's three voices: Playfair Display for headlines and card titles, Be Vietnam Pro for
/// deks, kickers and counters, and Figtree for the header.
enum EditType {
    static func display(_ size: CGFloat, italic: Bool = false, bold: Bool = false, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("PlayfairDisplay\(italic ? "Italic" : "Roman")-\(bold ? "Bold" : "SemiBold")", size: size, relativeTo: style)
    }

    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Figtree-\(weight.rawValue)", size: size, relativeTo: style)
    }

    static func text(_ size: CGFloat, _ weight: TextWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("BeVietnamPro-\(weight.rawValue)", size: size, relativeTo: style)
    }

    enum SansWeight: String { case light = "Light", regular = "Regular", medium = "Medium", semibold = "SemiBold" }
    enum TextWeight: String { case regular = "Regular", medium = "Medium" }
}

/// One rhythm for the whole page.
enum EditLayout {
    static let gutter = R.spacingSpace16
    /// Space between the header and the first line of every page.
    static let pageTop = R.spacingSpace24
    /// Space below the first page's content; later sections use `sectionBottom`.
    static let pageMargin = R.spacingSpace32
    /// Space below every section after the first: double the page margin, so each one breathes.
    static let sectionBottom = R.spacingSpace64
    static let headerGap = R.spacingSpace24
    static let cardGap = R.spacingSpace12
}

/// A section opener: the folio number in Playfair, fading from white to clear,
/// tucked behind a 28pt headline, then an optional dek and the hairline rule over the cards.
private struct EditSectionHeader: View {
    let number: Int
    let title: Text
    var dek: String?
    var centered = false
    /// Shows the Women / Men switch on the folio line.
    var genderSwitch = false
    /// The hairline under the heading; off where the cards should follow the dek directly.
    var rule = true

    var body: some View {
        let alignment: HorizontalAlignment = centered ? .center : .leading
        VStack(alignment: alignment, spacing: EditLayout.headerGap) {
            VStack(alignment: alignment, spacing: R.spacingSpace8) {
                VStack(alignment: alignment, spacing: -18) {
                    Text(String(format: "%02d", number))
                        .font(EditType.display(48, bold: true))
                        .tracking(0.37)
                        // Fades to nothing behind the headline, so it sits right on any page's wash.
                        .foregroundStyle(LinearGradient(stops: [.init(color: M.textWhite.opacity(0.9), location: 0), .init(color: M.textWhite.opacity(0), location: 0.85)],
                                                        startPoint: .top, endPoint: .bottom))
                        .accessibilityHidden(true)
                    title
                        .font(EditType.display(28, bold: true))
                        .tracking(-0.84)
                        .foregroundStyle(M.textWhite)
                        .multilineTextAlignment(centered ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                if let dek { EditDek(text: dek).multilineTextAlignment(centered ? .center : .leading) }
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .overlay(alignment: .topTrailing) {
                if genderSwitch { GenderSwitch().padding(.top, 6) }
            }
            if rule { EditRule() }
        }
        .padding(.horizontal, EditLayout.gutter)
        .riseIn()
    }
}

/// Women / Men, as a small segmented pill. One choice shared by every section that shows it.
/// Design only for now: the sections show the same edit either way.
private struct GenderSwitch: View {
    @AppStorage("edit.gender") private var gender = "women"
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options = [("women", "Women"), ("men", "Men")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { id, label in
                let on = gender == id
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { gender = id }
                } label: {
                    Text(label)
                        .font(EditType.text(12, .medium, relativeTo: .caption))
                        .foregroundStyle(on ? M.textInverse : M.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background {
                            if on { Capsule().fill(M.surfaceInverse).matchedGeometryEffect(id: "pill", in: pill) }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 2)
        .background {
            Capsule()
                .fill(M.surfaceTransparent)
                .overlay { Capsule().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
                .frame(height: 32)
        }
        .sensoryFeedback(.selection, trigger: gender)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Show edits for")
    }
}

/// What a section shows for a moment after Women / Men changes: grey card shapes with a soft
/// shimmer, standing in for the cards while the new edit "loads".
enum EditSkeleton {
    /// A carousel row of cards this size.
    case row(CGSize)
    /// The pair section's 3 × 2 grid of prints.
    case grid
}

private struct SkeletonBlock: View {
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(M.surfaceTransparent)
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.6)
                        .offset(x: sweep ? g.size.width : -g.size.width * 0.6)
                }
                .clipped()
                .opacity(reduceMotion ? 0 : 1)
            }
            .overlay { Rectangle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { sweep = true }
            }
    }
}

private struct SkeletonView: View {
    let style: EditSkeleton

    var body: some View {
        switch style {
        case let .row(size):
            HStack(alignment: .top, spacing: EditLayout.cardGap) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock()
                        .frame(width: size.width, height: size.height)
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 8) {
                                Capsule().fill(M.surfaceTransparent).frame(width: 60, height: 8)
                                Capsule().fill(M.surfaceTransparent).frame(width: size.width * 0.55, height: 12)
                            }
                            .padding(R.spacingSpace16)
                        }
                }
            }
            .padding(.leading, EditLayout.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        case .grid:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: EditLayout.cardGap), count: 3), spacing: R.spacingSpace16) {
                ForEach(0..<6, id: \.self) { _ in SkeletonBlock().frame(height: 152) }
            }
            .padding(.horizontal, EditLayout.gutter)
            .padding(.top, R.spacingSpace4)
        }
    }
}

/// Swaps a section's cards for a skeleton for a beat whenever Women / Men changes.
private struct GenderReload: ViewModifier {
    let skeleton: EditSkeleton
    @AppStorage("edit.gender") private var gender = "women"
    @State private var loading = false

    func body(content: Content) -> some View {
        content
            .opacity(loading ? 0 : 1)
            .overlay(alignment: .topLeading) {
                if loading { SkeletonView(style: skeleton).transition(.opacity) }
            }
            .animation(.easeInOut(duration: 0.25), value: loading)
            .onChange(of: gender) {
                loading = true
                Task {
                    try? await Task.sleep(for: .seconds(0.9))
                    loading = false
                }
            }
    }
}

private extension View {
    func genderReload(_ skeleton: EditSkeleton) -> some View { modifier(GenderReload(skeleton: skeleton)) }
}

/// Be Vietnam standfirst under a heading.
private struct EditDek: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EditType.text(14, relativeTo: .subheadline))
            .lineSpacing(5)
            .foregroundStyle(M.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The hairline that separates a heading from its cards (stronger under the masthead).
private struct EditRule: View {
    var color = M.borderSubtle

    var body: some View {
        Rectangle().fill(color).frame(height: R.stroke1Px).accessibilityHidden(true)
    }
}

/// Position in a carousel: an optional "02/08" counter, then a hairline whose bright run grows
/// as you swipe.
private struct EditProgress: View {
    let index: Int
    let count: Int
    var counter = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = count > 0 ? CGFloat(index + 1) / CGFloat(count) : 1
        HStack(spacing: R.spacingSpace12) {
            if counter {
                Text("\(String(format: "%02d", index + 1))/\(String(format: "%02d", count))")
                    .font(EditType.text(11, .medium, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(M.textWhite)
                    .contentTransition(.numericText(value: Double(index)))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(M.borderIntense).frame(height: 3)
                    Rectangle().fill(M.textPrimary).frame(width: g.size.width * progress, height: 3)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: 14)
        .padding(.horizontal, EditLayout.gutter)
        .animation(reduceMotion ? nil : .smooth, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index + 1) of \(count)")
    }
}

// MARK: - Page stack

private extension View {
    /// One magazine page. Once its top reaches the header it stays put, and the next page slides
    /// up over it; the covered page sinks back (a little smaller, a little darker) until hidden.
    /// `minHeight` lets a page fill the screen; `backdrop` is the page's paper; nil
    /// leaves it clear so the spotlight shows through.
    func stackedPage(pinTop: CGFloat, minHeight: CGFloat = 0, bottom: CGFloat = EditLayout.sectionBottom,
                     backdrop: PageBackdrop?) -> some View {
        modifier(StackedPage(pinTop: pinTop, height: minHeight, bottom: bottom, backdrop: backdrop))
    }
}

private struct StackedPage: ViewModifier {
    let pinTop: CGFloat
    let height: CGFloat
    let bottom: CGFloat
    let backdrop: PageBackdrop?
    /// Set once the page first scrolls into view; its cards slide in on it.
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // Used by the stacking effect below, which is commented out for the flat-scroll test.
        let _ = (pinTop, reduceMotion)
        return content
            .environment(\.editRevealed, revealed || reduceMotion)
            .modifier(RevealTracker { if !revealed { revealed = true } })
            // Content keeps its natural height (carousels would otherwise stretch to fill the page).
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, EditLayout.pageTop)
            .padding(.bottom, bottom)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
            .background {
                if let backdrop {
                    PageBackdropView(style: backdrop)
                        // Stacking shadow, off while the page scrolls flat.
                        // .shadow(color: .black.opacity(0.6), radius: 18, y: -8)
                }
            }
            // Page stacking (pin, sink and fade under the next page) is off while the page scrolls
            // flat for testing. Restore this block to bring it back.
            // .visualEffect { view, proxy in
            //     let frame = proxy.frame(in: .global)
            //     // How far the page has been pushed past its resting line.
            //     let past = max(0, pin - frame.minY)
            //     let covered = min(1, past / max(1, frame.height))
            //     return view
            //         .offset(y: past)
            //         .scaleEffect(1 - sink * covered, anchor: .top)
            //         .brightness(-0.42 * covered)
            //         .opacity(covered >= 1 ? 0 : 1 - 0.3 * covered)
            // }
    }
}

// MARK: - Reveal

private struct EditRevealedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether the enclosing page has come on screen yet (cards wait for it to slide in).
    fileprivate var editRevealed: Bool {
        get { self[EditRevealedKey.self] }
        set { self[EditRevealedKey.self] = newValue }
    }
}

/// Calls back the first time a fifth of the view is visible in the scroll view.
private struct RevealTracker: ViewModifier {
    let onReveal: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollVisibilityChange(threshold: 0.2) { visible in if visible { onReveal() } }
        } else {
            content.onAppear(perform: onReveal)
        }
    }
}

/// A card that waits off to the right, then slides in when its page is revealed, each one a
/// beat after the last.
private struct SlideIn: ViewModifier {
    let index: Int
    @Environment(\.editRevealed) private var revealed

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(x: revealed ? 0 : 90)
            .animation(.spring(response: 0.65, dampingFraction: 0.86).delay(Double(min(max(index, 0), 5)) * 0.08), value: revealed)
    }
}

/// A heading that waits a little low and faded, then rises into place as its page comes on screen.
private struct RiseIn: ViewModifier {
    @Environment(\.editRevealed) private var revealed

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 28)
            .animation(.easeOut(duration: 0.6), value: revealed)
    }
}

private extension View {
    func slideIn(_ index: Int) -> some View { modifier(SlideIn(index: index)) }
    func riseIn() -> some View { modifier(RiseIn()) }
}

/// Each page's paper: the same near-black throughout, so the stack reads as one issue, washed
/// from the top in the section's colour as in the Figma. Colours here are decorative, not UI chrome.
enum PageBackdrop {
    /// A colour wash from the top edge, fading out down the page.
    case wash(Color)
    /// Bare paper with a hairline along the top.
    case plain
    /// A hairline along the top over a soft bloom of the given swatches (the palettes).
    case bloom([UInt32])
}

private struct PageBackdropView: View {
    let style: PageBackdrop

    var body: some View {
        ZStack(alignment: .top) {
            M.backgroundPrimary
            switch style {
            case let .wash(color):
                wash(color)
            case .plain:
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            case let .bloom(hexes):
                bloom(hexes)
                wash(.white.opacity(0.03))
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func wash(_ color: Color) -> some View {
        LinearGradient(colors: [color, color.opacity(0)], startPoint: .top, endPoint: .bottom)
    }

    /// The swatches as large blurred discs strung across the page, like light through dyed fabric.
    private func bloom(_ hexes: [UInt32]) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let step = size.width / CGFloat(max(hexes.count, 1))
            ZStack(alignment: .topLeading) {
                ForEach(hexes.indices, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: hexes[i]))
                        .frame(width: 240, height: 240)
                        .position(x: step * (CGFloat(i) + 0.5),
                                  y: size.height * (i.isMultiple(of: 2) ? 0.42 : 0.62))
                }
            }
            .blur(radius: 100)
            .opacity(0.09)
        }
    }
}

/// A faint grey glow rising from the screen's foot, under the tab bar, closing the edit.
private struct EditBottomGlow: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(colors: [.white.opacity(0.07), .white.opacity(0)],
                           center: .bottom, startRadius: 0, endRadius: 420)
            Ellipse()
                .fill(.white.opacity(0.06))
                .frame(width: 360, height: 180)
                .blur(radius: 70)
                .offset(y: 70)
        }
        .frame(height: 380)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Small tracked uppercase line above a card title, trailed by a hairline.
private struct VogueKicker: View {
    let text: String
    /// How strongly the trailing hairline shows (0 hides it).
    var rule: Double = 1

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Text(text.uppercased())
                .font(EditType.text(12, .medium, relativeTo: .caption))
                .tracking(1.2)
                .foregroundStyle(M.textWhite.opacity(0.7))
                .lineLimit(1)
            if rule > 0 {
                Rectangle().fill(M.borderIntense).frame(height: R.stroke1Px).opacity(rule)
            }
        }
    }
}

/// The shared photo card: art, a frosted foot behind the caption, a scrim tinted from the photo,
/// a hairline frame and the caption itself.
private struct VoguePhotoCard<Caption: View>: View {
    let art: Art
    let width: CGFloat
    let height: CGFloat
    /// How far up the card the scrim reaches (0…1).
    var scrimReach: CGFloat = 0.4
    /// Strength of the black floor under the caption.
    var shade: Double = 0.6
    /// Strength of the photo-tinted wash over the shade.
    var tint: Double = 0.8
    /// Blurs the photo under the caption, as the Figma's caption frost does.
    var frosted = true
    @ViewBuilder let caption: () -> Caption
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let wash = DominantColor.foot(of: art)
        let top = 1 - scrimReach
        ArtView(art: art)
            .frame(width: width, height: height)
            .overlay {
                if frosted && !reduceTransparency {
                    ArtView(art: art)
                        .frame(width: width, height: height)
                        .blur(radius: 10, opaque: true)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: top), .init(color: .black, location: top + scrimReach * 0.35)],
                                             startPoint: .top, endPoint: .bottom))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                ZStack {
                    LinearGradient(stops: [.init(color: .clear, location: top), .init(color: .black.opacity(shade), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    LinearGradient(stops: [.init(color: wash.opacity(0), location: top), .init(color: wash.opacity(tint), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                caption().frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
            .clipShape(Rectangle())
            .contentShape(Rectangle())
    }
}

// MARK: - Header

/// Back to District, the page name with its location, and the profile. Frosts once the page moves.
private struct VogueEditHeader: View {
    @Binding var location: String
    let locations: [String]
    let scrolled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "arrow.left", label: "Back to District")

            Menu {
                Picker("Location", selection: $location) {
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Editorial")
                        .font(EditType.sans(16, .semibold, relativeTo: .headline))
                        .foregroundStyle(M.textPrimary)
                    HStack(spacing: 4) {
                        Text(location).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(EditType.sans(12, .semibold, relativeTo: .caption))
                    .foregroundStyle(M.textTertiary)
                    .id(location)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)).combined(with: .opacity))
                }
                .clipped()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Editorial, location \(location)")
            .accessibilityHint("Changes location")

            Spacer(minLength: 0)

            Button {} label: {
                Image("vogue_ic_profile")
                    .resizable()
                    .frame(width: 37, height: 38)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, EditLayout.gutter)
        .padding(.vertical, R.spacingSpace8)
        .background {
            if scrolled {
                Group {
                    if reduceTransparency { M.backgroundPrimary } else {
                        ZStack { Rectangle().fill(.ultraThinMaterial); M.backgroundPrimary.opacity(0.55) }
                    }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: scrolled)
        .animation(.easeInOut(duration: 0.3), value: location)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - 01 The Edit (stories)

private struct VogueStoriesSection: View {
    @State private var reading: Story?
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            masthead
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(Array(EditorialData.stories.enumerated()), id: \.element.id) { i, story in
                        Button { reading = story } label: { card(story) }
                            .slideIn(i)
                            .buttonStyle(PressableStyle())
                            .zoomSource(id: story.id, in: zoom)
                            .accessibilityLabel("\(story.brand): \(story.title)")
                            .accessibilityHint("Opens the story")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
        }
        .readerCover(item: $reading) { story in
            StoryReaderView(story: story).zoomTransition(id: story.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reading?.id)
    }

    /// The page nameplate: "The Edit" and its dek over a hairline.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("The Edit")
                    .font(EditType.display(40, bold: true, relativeTo: .largeTitle))
                    .tracking(-1.6)
                    .foregroundStyle(M.textWhite)
                    .accessibilityAddTraits(.isHeader)
                EditDek(text: "Five homegrown labels, the hands behind them, and the shops in your district.")
            }
            EditRule(color: M.borderIntense)
        }
        .padding(.horizontal, EditLayout.gutter)
        .riseIn()
    }

    private func card(_ story: Story) -> some View {
        VoguePhotoCard(art: story.art, width: 280, height: 420, scrimReach: 0.38) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                VogueKicker(text: story.brand)
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(story.title)
                        .font(EditType.display(20, relativeTo: .title3))
                        .tracking(-0.6)
                        .foregroundStyle(M.textWhite)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(story.article.dek)
                        .font(EditType.text(12, relativeTo: .caption))
                        .lineSpacing(3)
                        .foregroundStyle(M.textWhite.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.bottom, R.spacingSpace20)
        }
        // The blog cue: how long the read is, tucked in the top corner.
        .overlay(alignment: .topTrailing) {
            Text(story.article.readTime)
                .font(EditType.text(11, .medium, relativeTo: .caption2))
                .tracking(0.4)
                .foregroundStyle(M.textWhite)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(.black.opacity(0.45), in: Capsule())
                .overlay { Capsule().strokeBorder(.white.opacity(0.18), lineWidth: R.stroke1Px) }
                .padding(R.spacingSpace12)
        }
    }
}

// MARK: - 02 Hot off the rack

private struct VogueRackSection: View {
    @State private var opened: Product?
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: 2, title: Text("Hot off the rack"),
                              dek: "Fresh in this week from the labels on your high street, and the stores that stock them.")
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                RackCarousel(products: EditorialData.products, index: $index) { opened = $0 }
                EditProgress(index: index, count: EditorialData.products.count, counter: true)
            }
        }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.selection, trigger: index)
    }
}

/// An endless shop window: the card in front stands tall and the rest wait smaller. A native
/// paging scroll view lies invisibly over the cards and drives them, so swiping hands the height
/// to the next card (while the one before steps down and slides away) with real scroll physics.
/// The scroll view is many laps long and starts in the middle, so the line never runs out.
private struct RackCarousel: View {
    let products: [Product]
    /// The focused product (wrapped into `products`).
    @Binding var index: Int
    let open: (Product) -> Void

    @State private var page: Int?
    /// The pager's horizontal content offset.
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let laps = 400
    private let large = CGSize(width: 283, height: 346)
    private let small = CGSize(width: 228, height: 279)
    private let gap = EditLayout.cardGap
    private var step: CGFloat { large.width + gap }

    var body: some View {
        // Fractional position: 0.5 is halfway to the next card.
        let p = offset / step
        let first = Int(floor(p)) - 1
        let focused = Int(p.rounded())

        // Cards stand on one baseline, so every caption lines up as the rack slides.
        ZStack(alignment: .bottomLeading) {
            ForEach(first...(first + 4), id: \.self) { k in
                let r = CGFloat(k) - p
                let t = min(1, abs(r))
                let product = products[wrap(k)]
                card(product, size: size(t), emphasis: 1 - t)
                    .slideIn(k - focused)
                    .offset(x: x(r))
                    .opacity(r < -0.98 ? 0 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityHidden(k != focused)
                    .accessibilityLabel("\(product.name) by \(product.brand), \(product.price) onwards")
                    .accessibilityHint("Double-tap to open. Swipe up or down for the next piece.")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { open(product) }
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: scroll(to: focused + 1)
                        case .decrement: scroll(to: focused - 1)
                        @unknown default: break
                        }
                    }
            }
        }
        .frame(height: large.height, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, EditLayout.gutter)
        .overlay { pager(focused: focused, p: p) }
        .onChange(of: page) { index = wrap(page ?? 0) }
    }

    /// The invisible scroll surface. Its pages are one card-step wide and snap like the cards.
    private func pager(focused: Int, p: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<(products.count * laps), id: \.self) { _ in
                    // Clear views don't take touches, so give each page a shape to catch the swipe.
                    Color.clear
                        .frame(width: step, height: large.height)
                        .contentShape(Rectangle())
                }
            }
            .scrollTargetLayout()
            .background {
                GeometryReader { g in
                    Color.clear.preference(key: RackOffsetKey.self, value: -g.frame(in: .named("rackPager")).minX)
                }
            }
        }
        .coordinateSpace(name: "rackPager")
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page, anchor: .leading)
        // iOS 18+: read the offset from the scroll view itself; the preference is the iOS 17 path
        // (on newer systems it can stop reporting once laid out).
        .modifier(RackOffsetTracker { offset = $0 })
        .onPreferenceChange(RackOffsetKey.self) { x in
            if #available(iOS 18.0, macOS 15.0, *) { return }
            offset = x
        }
        .onAppear { if page == nil { page = products.count * laps / 2 } }
        .contentShape(Rectangle())
        .onTapGesture { location in tap(at: location, focused: focused, p: p) }
        .accessibilityHidden(true)
    }

    /// Opens the card in front; tapping a waiting card brings it forward instead.
    private func tap(at location: CGPoint, focused: Int, p: CGFloat) {
        let x = location.x - EditLayout.gutter
        for k in (Int(floor(p)) - 1)...(Int(floor(p)) + 3) {
            let r = CGFloat(k) - p
            let s = size(min(1, abs(r)))
            let left = self.x(r)
            guard x >= left, x <= left + s.width, location.y >= large.height - s.height else { continue }
            if k == focused { open(products[wrap(k)]) } else { scroll(to: k) }
            return
        }
    }

    private func scroll(to k: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)) { page = k }
    }

    private func size(_ t: CGFloat) -> CGSize {
        CGSize(width: lerp(large.width, small.width, t), height: lerp(large.height, small.height, t))
    }

    /// Leading edge of a card `r` places from the focused slot (negative is already passed).
    private func x(_ r: CGFloat) -> CGFloat {
        if r <= 0 { return r * (small.width + gap) }
        if r <= 1 { return r * step }
        return step + (r - 1) * (small.width + gap)
    }

    private func wrap(_ k: Int) -> Int { ((k % products.count) + products.count) % products.count }
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    /// The card in front drops its kicker rule and sets its name larger, as in the Figma.
    private func card(_ product: Product, size: CGSize, emphasis: CGFloat) -> some View {
        VoguePhotoCard(art: product.art, width: size.width, height: size.height,
                       scrimReach: 0.3, shade: 0.75, tint: 1, frosted: false) {
            VStack(alignment: .leading, spacing: lerp(6, 8, emphasis)) {
                VogueKicker(text: product.brand, rule: Double(1 - emphasis))
                Text(product.name)
                    .font(EditType.display(lerp(16, 18, emphasis), relativeTo: .headline))
                    .tracking(-0.54)
                    .foregroundStyle(M.textWhite)
                    .lineLimit(1)
            }
            .padding(.horizontal, lerp(12, 16, emphasis))
            .padding(.bottom, R.spacingSpace16)
        }
        // The waiting cards sit back a touch so the tall one reads as "in front".
        .brightness(-0.12 * (1 - emphasis))
    }
}

private struct RackOffsetTracker: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x + $0.contentInsets.leading } action: { _, x in
                onScroll(x)
            }
        } else {
            content
        }
    }
}

private struct RackOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - 03 What to pair with?

/// Starts on the pieces you already own, as product shots. Tap one and the grid folds up into tabs
/// (each product flies into its tab's thumbnail) while looks built on that piece rise in below.
private struct VoguePairSection: View {
    @State private var selected: String?
    @State private var opened: Opened?
    @State private var visible: Int?
    @Namespace private var sku
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Opened: Identifiable { let id: String; let staple: Staple; let start: Int }

    /// A piece you own: its product shot, and looks that are built on that exact piece.
    struct Anchor: Identifiable {
        let id: String
        let name: String
        let cutout: String
        let staple: Staple
        /// The one cheeky line written on the polaroid under the piece.
        var quip: String { Self.quips[id] ?? "" }

        static let quips: [String: String] = [
            "jeans": "The everything jeans",
            "tee": "Never basic",
            "denim-jacket": "Double denim? Yes.",
            "blazer": "Meeting energy",
            "leather": "Main character",
            "sneakers": "20k steps later",
        ]
    }

    private static var anchors: [Anchor] {
        let byTitle = Dictionary(uniqueKeysWithValues: EditorialData.staples.map { ($0.title, $0) })
        let tee = byTitle["White tee"], denim = byTitle["Straight denim"], blazer = byTitle["Sharp blazer"]
        func anchor(_ id: String, _ name: String, _ shot: String, _ looks: [String], tint: [UInt32], pairs: Staple?) -> Anchor {
            let arts = looks.enumerated().map { i, image in Art(image, tint, seed: 1200 + i) }
            let staple = Staple(title: name, subtitle: pairs?.subtitle ?? "", thumb: Art(shot, tint, seed: 1199),
                                pairs: pairs?.pairs ?? [], looks: arts)
            return Anchor(id: id, name: name, cutout: shot, staple: staple)
        }
        return [
            anchor("jeans", "Light blue jeans", "vogue_pair_jeans",
                   ["staple_white_tee_6", "look_quiet_luxury", "vogue_look_olive", "photo_rose_6", "plan_office_2", "rack_bonkers_jeans"],
                   tint: [0x86B6DE, 0x3E5C7E], pairs: denim),
            anchor("tee", "White tee", "vogue_pair_tee",
                   ["staple_white_tee_2", "staple_white_tee_3", "staple_white_tee_1", "plan_active_hero", "staple_white_tee_6"],
                   tint: [0xF4F4F4, 0xBDBDBD], pairs: tee),
            anchor("denim-jacket", "Denim jacket", "palette_slate-noir_4",
                   ["staple_denim_3", "staple_denim_2", "staple_denim_1", "rack_blu_trucker", "palette_butter-denim_5"],
                   tint: [0x3E5C7E, 0x1E3350], pairs: denim),
            anchor("blazer", "Tailored blazer", "staple_blazer_2",
                   ["vogue_look_ivory", "rack_zara_blazer", "staple_blazer_1", "staple_blazer_3", "vogue_fit_office", "vogue_fit_brunch"],
                   tint: [0xE9E4DA, 0x2A2826], pairs: blazer),
            anchor("leather", "Leather jacket", "palette_slate-noir_5",
                   ["rack_snitch_biker", "palette_midnight-olive_3"],
                   tint: [0x151515, 0x8A5A3B], pairs: tee),
            anchor("sneakers", "Court sneakers", "palette_butter-denim_6",
                   ["staple_blazer_3", "plan_active_hero", "staple_denim_1", "palette_sage-linen_5", "palette_butter-denim_3"],
                   tint: [0xE9E2D4, 0xC49A6C], pairs: denim),
        ]
    }

    private var motion: Animation? { reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.86) }

    var body: some View {
        let anchors = Self.anchors
        let current = anchors.first { $0.id == selected }
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: 3,
                              title: Text("What to \(Text("pair").font(EditType.display(28, italic: true, bold: true))) with?"),
                              dek: "Pick a piece you already own. We'll show you what goes with it.", genderSwitch: true)
            if let current {
                tabs(anchors, current: current)
                    .transition(.opacity)
                looks(current)
                    .genderReload(.row(CGSize(width: 244, height: 320)))
                    .id(current.id)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 28)), removal: .opacity))
            } else {
                shelf(anchors)
                    .genderReload(.grid)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .readerCover(item: $opened) { StapleLookbookView(staple: $0.staple, start: $0.start) }
        #if DEBUG
        // Debug builds accept `-pairSelect <anchor id>` (jeans, tee, denim-jacket…) to open on its looks.
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-pairSelect"), i + 1 < args.count {
                try? await Task.sleep(for: .seconds(4))
                choose(args[i + 1])
            }
        }
        #endif
    }

    private func choose(_ id: String?) {
        withAnimation(motion) {
            selected = id
            visible = 0
        }
    }

    // MARK: First view: the pieces on a shelf

    /// Each polaroid leans its own way, like prints pinned to a board.
    private static let tilts: [Double] = [-2, 1.5, -1, 1.5, -1.5, 2]

    private func shelf(_ anchors: [Anchor]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: EditLayout.cardGap, alignment: .top), count: 3),
                  spacing: R.spacingSpace16) {
            ForEach(Array(anchors.enumerated()), id: \.element.id) { i, anchor in
                Button { choose(anchor.id) } label: {
                    // The polaroid: the product, and one line written beneath it. Nothing else.
                    VStack(alignment: .leading, spacing: 6) {
                        thumb(anchor, corner: 1)
                            .matchedGeometryEffect(id: "img-\(anchor.id)", in: sku)
                            .frame(height: 118)
                        Text(anchor.quip)
                            .font(EditType.display(12, italic: true, relativeTo: .caption))
                            .foregroundStyle(Color(hex: 0x1C1C1E))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 2)
                    }
                    .padding(5)
                    .padding(.bottom, 4)
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .modifier(Wiggle(tilt: Self.tilts[i % Self.tilts.count], order: i))
                    .slideIn(i)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(anchor.name), \(anchor.staple.looks.count) looks")
                .accessibilityHint("Shows looks built on it")
            }
        }
        .padding(.horizontal, EditLayout.gutter)
        .padding(.top, R.spacingSpace4)
    }

    /// The product shot, filling its frame so the photo's own white sweep is the background.
    private func thumb(_ anchor: Anchor, corner: CGFloat) -> some View {
        Color.white
            .overlay {
                Image(anchor.cutout)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: corner))
    }

    // MARK: Second view: tabs and looks

    private func tabs(_ anchors: [Anchor], current: Anchor) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Button { choose(nil) } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 44, height: 44)
                        .background(M.surfaceTransparent, in: Circle())
                        .overlay { Circle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All pieces")

                ForEach(anchors) { anchor in
                    let on = anchor.id == current.id
                    Button { if !on { choose(anchor.id) } } label: {
                        HStack(spacing: R.spacingSpace8) {
                            thumb(anchor, corner: 15)
                                .matchedGeometryEffect(id: "img-\(anchor.id)", in: sku)
                                .frame(width: 30, height: 30)
                            Text(anchor.name)
                                .font(EditType.text(12, .medium, relativeTo: .caption))
                                .foregroundStyle(on ? M.textInverse : M.textPrimary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.leading, 7)
                        .padding(.trailing, R.spacingSpace16)
                        .frame(height: 44)
                        .background(on ? AnyShapeStyle(M.surfaceInverse) : AnyShapeStyle(M.surfaceTransparent), in: Capsule())
                        .overlay { Capsule().strokeBorder(on ? .clear : M.borderModerate, lineWidth: R.stroke1Px) }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(anchor.name)
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, EditLayout.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func looks(_ anchor: Anchor) -> some View {
        let staple = anchor.staple
        return VStack(alignment: .leading, spacing: R.spacingSpace24) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(Array(staple.looks.enumerated()), id: \.offset) { i, look in
                        Button { opened = Opened(id: "\(anchor.id)-\(i)", staple: staple, start: i) } label: {
                            PairLookCard(art: look, number: i + 1, piece: anchor.name)
                        }
                        .slideIn(i)
                        .buttonStyle(PressableStyle())
                        .id(i)
                        .accessibilityLabel("Look \(i + 1) with the \(anchor.name.lowercased())")
                        .accessibilityHint("Opens the lookbook")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: visible ?? 0, count: staple.looks.count)
        }
    }
}

/// A polaroid's resting tilt, plus a small shake when the shelf comes into view and again every
/// few seconds after, staggered across the prints, so the pieces read as things to pick up.
private struct Wiggle: ViewModifier {
    let tilt: Double
    let order: Int
    @State private var shakes = 0
    @Environment(\.editRevealed) private var revealed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: shakes) { view, angle in
                view.rotationEffect(.degrees(tilt + angle))
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(3, duration: 0.09)
                    CubicKeyframe(-2.4, duration: 0.11)
                    CubicKeyframe(1.4, duration: 0.11)
                    CubicKeyframe(-0.6, duration: 0.1)
                    CubicKeyframe(0, duration: 0.14)
                }
            }
            .task(id: revealed) {
                guard revealed, !reduceMotion else { return }
                // First shake lands once the prints have slid in, then a quiet nudge every 6s.
                try? await Task.sleep(for: .seconds(0.7 + Double(order) * 0.12))
                while !Task.isCancelled {
                    shakes += 1
                    try? await Task.sleep(for: .seconds(6))
                }
            }
    }
}

/// One look built on the chosen piece: the photo leads, with only its number and the piece.
private struct PairLookCard: View {
    let art: Art
    let number: Int
    let piece: String

    var body: some View {
        VoguePhotoCard(art: art, width: 244, height: 320, scrimReach: 0.26) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    VogueKicker(text: "Look \(String(format: "%02d", number))", rule: 0)
                    Text("With the \(piece.lowercased())")
                        .font(EditType.display(16, relativeTo: .headline))
                        .tracking(-0.3)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: R.spacingSpace8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(M.textWhite.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - 04 Cop these looks

private struct VogueLooksSection: View {
    @State private var visible: String?

    /// Street-style looks from the Figma shoot, each tagged with what she's wearing.
    static let looks: [Look] = [
        Look(title: "The Olive Utility", art: Art("vogue_look_olive", [0x4A5A2A, 0x8A9A5A, 0x9FB6C9], seed: 801), spots: [
            Hotspot(x: 0.62, y: 0.4, item: "Olive utility jacket", price: "₹4,990"),
            Hotspot(x: 0.27, y: 0.37, item: "Mini box bag", price: "₹2,950"),
            Hotspot(x: 0.48, y: 0.76, item: "Light-wash mom jeans", price: "₹2,450"),
        ]),
        Look(title: "The Ivory Suit", art: Art("vogue_look_ivory", [0xE9E2D4, 0xC9B79A, 0x5A5F66], seed: 803), spots: [
            Hotspot(x: 0.6, y: 0.38, item: "Cream tailored blazer", price: "₹5,490"),
            Hotspot(x: 0.3, y: 0.36, item: "Mini box bag", price: "₹2,950"),
            Hotspot(x: 0.52, y: 0.74, item: "Ivory wide-leg trousers", price: "₹3,290"),
        ]),
        Look(title: "The Navy Overcoat", art: Art("vogue_look_navy", [0x1A2238, 0x2F3E4E, 0xC9B79A], seed: 805), spots: [
            Hotspot(x: 0.64, y: 0.5, item: "Navy double-breasted coat", price: "₹8,990"),
            Hotspot(x: 0.5, y: 0.36, item: "Cable-knit vest", price: "₹2,890"),
            Hotspot(x: 0.5, y: 0.8, item: "Charcoal straight trousers", price: "₹3,490"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: 4, title: Text("Cop these looks"),
                              dek: "Three outfits spotted on the street. Tap a dot to shop the exact piece, or something close to it.", genderSwitch: true)
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(Array(Self.looks.enumerated()), id: \.element.id) { i, look in
                        VogueLookCard(look: look).slideIn(i).id(look.id)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .genderReload(.row(CGSize(width: 268, height: 420)))
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: Self.looks.firstIndex { $0.id == visible } ?? 0, count: Self.looks.count)
        }
    }
}

private struct VogueLookCard: View {
    let look: Look
    @State private var shopping: Shopping?
    @State private var tryingOn = false

    struct Shopping: Identifiable { let id: Int }

    var body: some View {
        VoguePhotoCard(art: look.art, width: 268, height: 420, scrimReach: 0.22) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                // Wraps to a second line rather than truncating a long outfit name.
                Text(look.title)
                    .font(EditType.display(18, relativeTo: .headline))
                    .tracking(-0.18)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                // Opens the look's shopping sheet on its first piece; a plain underlined link, no chevron.
                Button { shopping = Shopping(id: 0) } label: {
                    Text("Shop the look")
                        .font(EditType.text(13, .medium, relativeTo: .subheadline))
                        .foregroundStyle(M.textWhite)
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(M.textWhite).frame(height: R.stroke1Px)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Opens every piece in this look")
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.bottom, R.spacingSpace20)
        }
        .overlay {
            GeometryReader { geo in
                ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                    HotspotPin(spot: spot, isActive: shopping?.id == i, dot: true) { shopping = Shopping(id: i) }
                        .position(x: spot.x * geo.size.width, y: spot.y * geo.size.height)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            TryOnButton { tryingOn = true }.padding(R.spacingSpace12)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sensoryFeedback(.impact(weight: .light), trigger: shopping?.id)
        .sensoryFeedback(.impact(weight: .medium), trigger: tryingOn)
        .sheet(item: $shopping) { ShopTheLookView(look: look, start: $0.id) }
        .fullScreenCover(isPresented: $tryingOn) { VirtualTryOnView(title: look.title, art: look.art) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(look.title)
    }
}

// MARK: - 05 Got plans? Got fits.

private struct VoguePlansSection: View {
    @State private var opened: Plan?
    @State private var visible: String?
    @Namespace private var zoom

    /// Cover art per occasion; the gallery behind each is the plan's own collection.
    private var covers: [(plan: Plan, cover: Art)] {
        // Vibe first: each plan opens on an illustration of the occasion, not an outfit.
        let pairs: [(String, String)] = [
            ("Sunday brunch", "vibe_brunch"), ("Activewear", "vibe_active"),
            ("Diwali parties", "vibe_diwali"), ("Concert night", "vibe_concert"),
        ]
        return pairs.compactMap { title, image in
            guard let plan = EditorialData.plans.first(where: { $0.title == title }) else { return nil }
            return (plan, Art(image, plan.cards.first?.hexes ?? [0x333333, 0x666666], seed: 820))
        }
    }

    var body: some View {
        let covers = covers
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: 5,
                              title: Text("Every plan, \(Text("sorted.").font(EditType.display(28, italic: true, bold: true)))"), genderSwitch: true)
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace16) {
                    ForEach(covers, id: \.plan.id) { item in
                        Button { opened = item.plan } label: { PlanCard(plan: item.plan, cover: item.cover) }
                            .buttonStyle(PressableStyle())
                            .slideIn(covers.firstIndex { $0.plan.id == item.plan.id } ?? 0)
                            .zoomSource(id: item.plan.id, in: zoom)
                            .id(item.plan.id)
                            .accessibilityLabel("\(item.plan.title), \(item.plan.count) looks")
                            .accessibilityHint("Opens the plan's looks")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .genderReload(.row(CGSize(width: 268, height: 380)))
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: covers.firstIndex { $0.plan.id == visible } ?? 0, count: covers.count)
        }
        .readerCover(item: $opened) { plan in
            PlanGalleryView(plan: plan).zoomTransition(id: plan.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }
}

/// One plan: just its vibe illustration, veiled all over in the illustration's own colour,
/// with the plan's name set in the top-left corner.
private struct PlanCard: View {
    let plan: Plan
    let cover: Art

    static let width: CGFloat = 268
    static let height: CGFloat = 380
    /// Spacing shared with the palette cards.
    static let gap: CGFloat = 5

    /// One line on what each plan is dressed for.
    static let taglines: [String: String] = [
        "Sunday brunch": "Florals, linen and a long table",
        "Activewear": "Sweat first, coffee after",
        "Diwali parties": "Gold, silk and a little sparkle",
        "Concert night": "Black, loud and front row",
    ]

    var body: some View {
        let wash = DominantColor.head(of: cover)
        ArtView(art: cover)
            .frame(width: Self.width, height: Self.height)
            .clipped()
            .overlay {
                ZStack {
                    // A touch of black under the colour keeps white type legible on pale art.
                    LinearGradient(stops: [.init(color: .black.opacity(0.35), location: 0), .init(color: .clear, location: 0.4)],
                                   startPoint: .top, endPoint: .bottom)
                    // The colour veils the whole card: strong behind the type at the top, fading out
                    // toward the foot.
                    LinearGradient(stops: [.init(color: wash.opacity(0.96), location: 0),
                                           .init(color: wash.opacity(0.7), location: 0.4),
                                           .init(color: wash.opacity(0.12), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    // A soft shade at the foot for the looks count.
                    LinearGradient(stops: [.init(color: .clear, location: 0.75), .init(color: .black.opacity(0.45), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(EditType.display(22, bold: true, relativeTo: .title2))
                            .tracking(-0.6)
                            .foregroundStyle(M.textWhite)
                            .lineLimit(1)
                        if let line = Self.taglines[plan.title] {
                            Text(line)
                                .font(EditType.text(12, relativeTo: .caption))
                                .foregroundStyle(M.textWhite.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(R.spacingSpace16)
            }
            .overlay(alignment: .bottomLeading) {
                VogueKicker(text: "\(plan.count) looks", rule: 0).padding(R.spacingSpace16)
            }
            .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
            .contentShape(Rectangle())
    }
}

// MARK: - 07 Pick your palette

/// Vibe first, like the plans: each card is a mood painted in the palette's own colours over a
/// band of its three lead shades. Nothing else.
private struct VoguePaletteSection: View {
    @State private var opened: Palette?
    @Namespace private var zoom

    /// The palettes with a flat-lay, Butter & Denim closing the row.
    private var palettes: [Palette] {
        let shown = EditorialData.palettes.filter { $0.id != "sage-linen" }
        return shown.filter { $0.id != "butter-denim" } + shown.filter { $0.id == "butter-denim" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: 7,
                              title: Text("Pick your \(Text("palette").font(EditType.display(28, italic: true, bold: true)))"),
                              dek: "Start from a colour, not a garment. Choose a mood and we'll build the outfit around it.", genderSwitch: true, rule: false)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace16) {
                    ForEach(palettes) { palette in
                        Button { opened = palette } label: { ColourStoryCard(palette: palette) }
                            .buttonStyle(PressableStyle())
                            .slideIn(palettes.firstIndex { $0.id == palette.id } ?? 0)
                            .zoomSource(id: palette.id, in: zoom)
                            .accessibilityLabel("\(palette.name), \(palette.lookCount) looks: \(palette.shades.joined(separator: ", "))")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .genderReload(.row(CGSize(width: 268, height: 356)))
            .defaultScrollAnchor(.leading)
        }
        .readerCover(item: $opened) { palette in
            PaletteDetailView(palette: palette).zoomTransition(id: palette.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }
}

private struct ColourStoryCard: View {
    let palette: Palette

    static let width = PlanCard.width
    static let coverHeight: CGFloat = 300
    static let bandHeight: CGFloat = 56
    static let gap = PlanCard.gap

    var body: some View {
        VStack(alignment: .leading, spacing: Self.gap) {
            PaletteVibe(palette: palette)
                .frame(width: Self.width, height: Self.coverHeight)
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0.55), .init(color: .black.opacity(0.6), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: R.spacingSpace8) {
                        VogueKicker(text: "\(palette.lookCount) looks")
                        Text(palette.name)
                            .font(EditType.display(20, relativeTo: .title3))
                            .tracking(-0.6)
                            .foregroundStyle(M.textWhite)
                            .lineLimit(1)
                    }
                    .padding(R.spacingSpace16)
                }
                .clipped()
                .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }

            // Its three lead shades, side by side and named.
            HStack(spacing: 0) {
                ForEach(Array(zip(palette.hexes, palette.shades).prefix(3).enumerated()), id: \.offset) { _, shade in
                    Color(hex: shade.0)
                        .overlay(alignment: .bottomLeading) {
                            Text(shade.1)
                                .font(EditType.text(11, .medium, relativeTo: .caption2))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(Self.ink(on: shade.0))
                                .padding(.horizontal, 10)
                                .padding(.bottom, 8)
                        }
                }
            }
            .frame(width: Self.width, height: Self.bandHeight)

        }
        .frame(width: Self.width, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Dark text on light shades, light text on dark ones (relative luminance).
    static func ink(on hex: UInt32) -> Color {
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.6 ? Color.black.opacity(0.75) : Color.white.opacity(0.9)
    }
}

/// The palette's mood: a supplied `vibe_palette_<id>` image when there is one, otherwise a
/// poster-style landscape painted only in the palette's shades (sky, a low sun, two rolling hills)
/// with a fine grain, so it sits beside the plans' illustrations.
private struct PaletteVibe: View {
    let palette: Palette

    var body: some View {
        if UIImage(named: "vibe_palette_\(palette.id)") != nil {
            Image("vibe_palette_\(palette.id)").resizable().scaledToFill()
        } else {
            Canvas { context, size in
                let w = size.width, h = size.height
                let hexes = palette.hexes
                func shade(_ i: Int) -> Color { Color(hex: hexes[i % hexes.count]) }
                var rng = SeededRandom(seed: UInt64(palette.id.unicodeScalars.reduce(0) { $0 &* 31 &+ UInt64($1.value) }))

                // Sky: the lead shade, lifted toward the top.
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(shade(0)))
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .linearGradient(Gradient(colors: [.white.opacity(0.28), .clear]),
                                                   startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))

                // A low sun with a soft halo.
                let sun = CGPoint(x: w * (0.3 + rng.next() * 0.45), y: h * 0.42)
                let r = w * 0.2
                context.fill(Path(ellipseIn: CGRect(x: sun.x - r * 1.6, y: sun.y - r * 1.6, width: r * 3.2, height: r * 3.2)),
                             with: .color(shade(2).opacity(0.25)))
                context.fill(Path(ellipseIn: CGRect(x: sun.x - r, y: sun.y - r, width: r * 2, height: r * 2)), with: .color(shade(2)))

                // Two hills, far then near.
                func hill(top: CGFloat, swell: CGFloat, colour: Color) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: h * top))
                    path.addCurve(to: CGPoint(x: w, y: h * (top + 0.04)),
                                  control1: CGPoint(x: w * 0.35, y: h * (top - swell)),
                                  control2: CGPoint(x: w * 0.6, y: h * (top + swell)))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                    context.fill(path, with: .color(colour))
                }
                hill(top: 0.6, swell: 0.08 + rng.next() * 0.06, colour: shade(3))
                hill(top: 0.76, swell: 0.1, colour: shade(1))

                // Grain, so it reads as print rather than vector.
                for _ in 0..<1400 {
                    let x = rng.next() * w, y = rng.next() * h
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                                 with: .color((rng.next() > 0.5 ? Color.white : Color.black).opacity(rng.next() * 0.12)))
                }
            }
        }
    }
}

/// A tiny deterministic generator, so a palette's grain is the same on every draw.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

// MARK: - 06 Homegrown heroes

/// The district's homegrown labels on a tidy bento board: a big tile and two small ones, then the
/// mirror of that row, each tile a photo with the label's name set inside it. Story labels open
/// their story; the rest open their piece on the rack.
private struct VogueBentoSection: View {
    @State private var reading: Story?
    @State private var opened: Product?
    @Namespace private var zoom

    private struct Label: Identifiable {
        let id: String
        let art: Art
        let story: Story?
        let product: Product?
    }

    private static let gap: CGFloat = 8
    private static let small: CGFloat = 88
    private static var large: CGFloat { small * 2 + gap }

    private var labels: [Label] {
        var rows: [Label] = EditorialData.stories.map { Label(id: $0.brand, art: $0.art, story: $0, product: nil) }
        if let kaftan = EditorialData.products.first(where: { $0.brand == "Nicobar" }) {
            rows.append(Label(id: "Nicobar", art: kaftan.art, story: nil, product: kaftan))
        }
        return rows
    }

    var body: some View {
        let l = labels
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: 6,
                              title: Text("Homegrown \(Text("heroes").font(EditType.display(28, italic: true, bold: true)))"))
            GeometryReader { g in
                let third = (g.size.width - 2 * Self.gap) / 3
                VStack(spacing: Self.gap) {
                    HStack(spacing: Self.gap) {
                        if l.count > 0 { tile(l[0], big: true).slideIn(0).frame(width: third * 2 + Self.gap, height: Self.large) }
                        VStack(spacing: Self.gap) {
                            if l.count > 1 { tile(l[1], big: false).slideIn(1).frame(height: Self.small) }
                            if l.count > 2 { tile(l[2], big: false).slideIn(2).frame(height: Self.small) }
                        }
                        .frame(width: third)
                    }
                    HStack(spacing: Self.gap) {
                        VStack(spacing: Self.gap) {
                            if l.count > 3 { tile(l[3], big: false).slideIn(3).frame(height: Self.small) }
                            if l.count > 4 { tile(l[4], big: false).slideIn(4).frame(height: Self.small) }
                        }
                        .frame(width: third)
                        if l.count > 5 { tile(l[5], big: true).slideIn(5).frame(width: third * 2 + Self.gap, height: Self.large) }
                    }
                }
            }
            .frame(height: Self.large * 2 + Self.gap)
            .padding(.horizontal, EditLayout.gutter)
        }
        .readerCover(item: $reading) { story in
            StoryReaderView(story: story).zoomTransition(id: story.id, in: zoom)
        }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: reading?.id)
    }

    private func tile(_ label: Label, big: Bool) -> some View {
        Button {
            if let story = label.story { reading = story } else { opened = label.product }
        } label: {
            GeometryReader { g in
                ArtView(art: label.art)
                    .frame(width: g.size.width, height: g.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(stops: [.init(color: .clear, location: big ? 0.6 : 0.45), .init(color: .black.opacity(0.75), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(label.id)
                            .font(EditType.display(16, relativeTo: .headline))
                            .tracking(-0.3)
                            .foregroundStyle(M.textWhite)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(R.spacingSpace12)
                    }
            }
            .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .zoomSource(id: label.id, in: zoom)
        .accessibilityLabel(label.id)
        .accessibilityHint(label.story == nil ? "Opens the piece" : "Opens the story")
    }
}

// MARK: - 08 In this edit (contents)

/// The tab's contents: every section's folio and title, each a link back up to it.
private struct VogueIndexSection: View {
    let jump: (Int) -> Void

    private static let entries: [(Int, String)] = [
        (1, "The Edit"), (2, "Hot off the rack"), (3, "What to pair with?"), (4, "Cop these looks"),
        (5, "Every plan, sorted."), (6, "Homegrown heroes"), (7, "Pick your palette"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                Text("In this \(Text("edit").font(EditType.display(28, italic: true, bold: true)))")
                    .font(EditType.display(28, bold: true))
                    .tracking(-0.84)
                    .foregroundStyle(M.textWhite)
                    .accessibilityAddTraits(.isHeader)
                EditDek(text: "Jump back to any page.")
            }
            .padding(.horizontal, EditLayout.gutter)

            VStack(spacing: 0) {
                ForEach(Self.entries, id: \.0) { n, title in
                    Button { jump(n) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace16) {
                            Text(String(format: "%02d", n))
                                .font(EditType.display(20, bold: true))
                                .foregroundStyle(M.textTertiary)
                                .monospacedDigit()
                                .frame(width: 32, alignment: .leading)
                            Text(title)
                                .font(EditType.display(18, relativeTo: .headline))
                                .tracking(-0.3)
                                .foregroundStyle(M.textPrimary)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(M.iconSecondary)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .slideIn(n - 1)
                    .accessibilityLabel("Page \(n), \(title)")
                    .accessibilityHint("Scrolls back to this section")
                    .overlay(alignment: .bottom) { EditRule() }
                }
            }
            .padding(.horizontal, EditLayout.gutter)
        }
    }
}

#Preview {
    VogueEditView().preferredColorScheme(.dark)
}
