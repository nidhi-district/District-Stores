import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Space between a section headline and its content.
private let headerGap = R.spacingSpace24

// MARK: - Homegrown & unfiltered

struct HomegrownSection: View {
    @State private var reading: Story?
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 1, lines: ["homegrown & unfiltered"])
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace4) {
                    ForEach(EditorialData.stories) { story in
                        StoryCard(story: story) { reading = story }
                            .zoomSource(id: story.id, in: zoom)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
        .readerCover(item: $reading) { story in
            StoryReaderView(story: story)
                .zoomTransition(id: story.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reading?.id)
    }
}

/// Full-bleed story photo; the headline sits on a progressive blur of the photo itself.
struct StoryCard: View {
    let story: Story
    var open: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size = CGSize(width: 264, height: 340)

    var body: some View {
        let parallax: CGFloat = reduceMotion ? 0 : -36
        let zoom: CGFloat = 1  // parallax overscan already covers the horizontal drift
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                photo(zoom: zoom, parallax: parallax)
                // Progressive blur: a blurred copy of the same photo, revealed toward the bottom.
                photo(zoom: zoom, parallax: parallax)
                    .blur(radius: 22, opaque: true)
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.5), .init(color: .black, location: 0.78)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                ImageScrim(strength: 0.6)

                HStack(alignment: .bottom, spacing: R.spacingSpace12) {
                    VStack(alignment: .leading, spacing: R.spacingSpace8) {
                        VStack(alignment: .leading, spacing: R.spacingSpace8) {
                            BrandMark(brand: story.brand, mark: story.mark, size: 40)
                            Text(story.brand)
                                .backstageText(.specialTitle)
                                .foregroundStyle(M.textWhite)
                        }
                        Text(story.title)
                            .backstageText(.title4)
                            .foregroundStyle(M.textWhite)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(M.iconWhite)
                        .frame(width: 32, height: 32)
                        .liquidGlass(in: Circle(), clear: true)
                        .accessibilityHidden(true)
                }
                .padding(R.spacingSpace16)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(EditorialCard.shape)
        }
        .buttonStyle(PressableStyle())
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(story.title), by \(story.brand)")
        .accessibilityAddTraits(.isButton)
    }

    private func photo(zoom: CGFloat, parallax: CGFloat) -> some View {
        ArtView(art: story.art, parallax: 0.12)
            .scrollTransition(.interactive, axis: .horizontal) { art, phase in
                art.scaleEffect(zoom).offset(x: phase.value * parallax)
            }
            .frame(width: size.width, height: size.height)
    }
}

// MARK: - Hot off the rack

/// Endless album-style cover flow driven by a native horizontal scroll view (so swipes are handled by
/// UIKit's scroll physics, nested correctly inside the vertical page scroll).
struct RackSection: View {
    /// One cover in the looped rail: the products repeated lap after lap, each with a unique id, so
    /// there is always a neighbour on both sides.
    struct Slot: Identifiable {
        let id: String
        let product: Product
        let index: Int
    }

    /// Laps of the product list. A regular (non-lazy) row is required: lazy stacks don't reliably
    /// honour zIndex, which let side covers draw over the centre one.
    private static let laps = 9
    private static let slots: [Slot] = (0..<laps).flatMap { lap in
        EditorialData.products.enumerated().map { i, p in
            Slot(id: "\(lap)-\(p.id)", product: p, index: lap * EditorialData.products.count + i)
        }
    }
    /// Opens in the middle lap on the second product, so the first cover sits on the left.
    static let openingID: String = {
        let count = EditorialData.products.count
        return slots[(laps / 2) * count + min(1, count - 1)].id
    }()

    @State private var focused: String? = RackSection.openingID
    @State private var opened: Slot?
    /// Live, fractional index of the cover at the centre, updated every frame while swiping.
    @State private var liveCentre: Double?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    /// Seconds each cover holds the centre before the rack turns on its own.
    private let dwell: Double = 1.6
    /// Turns whenever the Explore page is showing, even before the rack scrolls into view, so it is
    /// already moving when it peeks in below the stories. Pauses while a product is open.
    private var autoplays: Bool { opened == nil && !reduceMotion && !voiceOver }
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardSize = CGSize(width: 220, height: 300)
    private let overlap: CGFloat = -76

    private var products: [Product] { EditorialData.products }

    private var focusedSlot: Slot { Self.slots.first { $0.id == focused } ?? Self.slots[0] }
    private var focusedIndex: Int { focusedSlot.index % products.count }
    private var current: Product { focusedSlot.product }

    var body: some View {
        VStack(spacing: headerGap) {
            SectionHeader(number: 2, lines: ["hot off the rack"])

            VStack(spacing: R.spacingSpace24) {
                carousel
                caption
                dots
            }
        }
        .readerCover(item: $opened) { slot in
            ProductDetailView(product: slot.product)
                .zoomTransition(id: slot.id, in: zoom)
        }
        .sensoryFeedback(.selection, trigger: focused)
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }

    private var carousel: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let step = cardSize.width + overlap
            let swing: Double = reduceMotion ? 0 : 44
            let focusIndex = focusedSlot.index

            ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: overlap) {
                    ForEach(Self.slots) { slot in
                        let i = slot.index
                        let product = slot.product
                        RackCard(product: product, size: cardSize)
                            .visualEffect { content, proxy in
                                // Offset of this cover from the scroll view's true centre, in steps.
                                let viewport = proxy.bounds(of: .scrollView) ?? CGRect(x: 0, y: 0, width: width, height: 0)
                                let raw = (proxy.size.width / 2 - viewport.midX) / step
                                // Flat zone: the centred cover stays straight, full size and undimmed.
                                let flat: CGFloat = 0.18
                                let distance = min(max(abs(raw) - flat, 0) / (1 - flat), 3)
                                let position = raw < 0 ? -distance : distance
                                return content
                                    .rotation3DEffect(
                                        .degrees(-max(-1, min(1, position)) * swing),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.5
                                    )
                                    .scaleEffect(1 - min(distance, 2) * 0.13)
                                    .brightness(-min(distance, 1.5) * 0.22)
                                    // Only the centred cover is in colour; colour drains as a cover moves off-centre.
                                    .grayscale(min(distance, 1))
                            }
                            .zoomSource(id: slot.id, in: zoom)
                            // Stack by live distance from the centre, so the cover nearest the middle
                            // is always on top, even mid-swipe.
                            .zIndex(-abs(Double(i) - stackingCentre(focusIndex)))
                            .onTapGesture {
                                // Centre cover opens the product; a side cover slides to the centre first.
                                if i == focusIndex {
                                    opened = slot
                                } else {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { focused = slot.id }
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(product.brand), \(product.name)\(product.isNew ? ", new drop" : "")")
                            .accessibilityAddTraits(i == focusIndex ? [.isButton, .isSelected] : .isButton)
                            .accessibilityHint(i == focusIndex ? "Opens product" : "Brings to centre")
                    }
                }
                .scrollTargetLayout()
                .background {
                    GeometryReader { g in
                        Color.clear.preference(key: RackOffsetKey.self, value: g.frame(in: .named("rack")).minX)
                    }
                }
            }
            .coordinateSpace(name: "rack")
            .onPreferenceChange(RackOffsetKey.self) { minX in
                // The row starts one side margin in; each cover is one step further along.
                let margin = max(0, (width - cardSize.width) / 2)
                liveCentre = Double((margin - minX) / step)
            }
            // iOS 18+: read the live offset straight from the scroll view (covers programmatic scrolls too).
            .modifier(LiveScrollCentre(step: step) { liveCentre = $0 })
            .contentMargins(.horizontal, max(0, (width - cardSize.width) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focused)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            // Centre the focused cover once the rail has its real width, and again whenever the
            // rail reappears (switching tabs or closing a cover can reset it to the start).
            .task(id: width) { await centre(reader, width: width) }
            .onAppear { Task { await centre(reader, width: width) } }
            }
        }
        .frame(height: cardSize.height)
        // Turn to the next cover after a pause, with the same spring as a swipe; any swipe or tap
        // changes `focused` and so restarts the countdown.
        .task(id: AutoTurn(focused: focused, running: autoplays)) {
            guard autoplays else { return }
            try? await Task.sleep(for: .seconds(dwell))
            guard !Task.isCancelled else { return }
            await advance()
        }
    }

    private struct AutoTurn: Equatable {
        let focused: String?
        let running: Bool
    }

    /// Moves one cover to the right. Near the end of the repeated row it first jumps, unanimated, to
    /// the same cover in the middle lap so the rack can keep turning forever.
    private func advance() async {
        let count = products.count
        var index = focusedSlot.index
        if index >= Self.slots.count - count {
            index = (Self.laps / 2) * count + index % count
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { focused = Self.slots[index].id }
            // Let the jump land before animating, so the two don't merge into one long scroll.
            try? await Task.sleep(for: .milliseconds(60))
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
            focused = Self.slots[index + 1].id
        }
    }

    /// The fractional cover index used for stacking: the live scroll position while it is credible,
    /// otherwise the focused cover. A stale reading (more than a cover and a half away) is ignored
    /// so a side cover can never be stacked above the centre one.
    private func stackingCentre(_ focusIndex: Int) -> Double {
        if let live = liveCentre, abs(live - Double(focusIndex)) <= 1.5 { return live }
        return Double(focusIndex)
    }

    /// Scrolls the focused cover to the centre, retrying while layout settles (a single early
    /// scrollTo can be dropped and leave the first cover pinned to the edge).
    private func centre(_ reader: ScrollViewProxy, width: CGFloat) async {
        guard width > 0 else { return }
        let target = focused ?? RackSection.openingID
        for delay in [0.0, 0.12, 0.35] {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, focused == target else { return }
            reader.scrollTo(target, anchor: .center)
        }
    }

    private var caption: some View {
        VStack(spacing: R.spacingSpace4) {
            Text(current.name)
                .backstageText(.caption)
                .foregroundStyle(M.textPrimary)
            HStack(spacing: R.spacingSpace8) {
                Text(current.brand)
                    .foregroundStyle(M.textSecondary)
                if !current.price.isEmpty {
                    Text("·").foregroundStyle(M.textTertiary)
                    Text(current.price)
                        .foregroundStyle(M.textSecondary)
                        .monospacedDigit()
                }
            }
            .backstageText(.label2)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, R.spacingSpace16)
        .id(current.id)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: current.id)
        .accessibilityHidden(true)
    }

    private var dots: some View {
        HStack(spacing: R.spacingSpace4 + 2) {
            ForEach(products.indices, id: \.self) { i in
                Capsule()
                    .fill(i == focusedIndex ? M.iconPrimary : M.iconTertiary)
                    .frame(width: i == focusedIndex ? 18 : 6, height: 6)
            }
        }
        .animation(.snappy, value: focusedIndex)
        .accessibilityHidden(true)
    }
}

/// Reports the fractional index of the cover at the centre from the scroll view's own geometry.
private struct LiveScrollCentre: ViewModifier {
    let step: CGFloat
    let update: (Double) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.x + geo.contentInsets.leading
            } action: { _, offset in
                update(Double(offset / step))
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

struct RackCard: View {
    let product: Product
    let size: CGSize

    var body: some View {
        ArtView(art: product.art)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                if product.isNew { NewBadge().padding(R.spacingSpace12) }
            }
            .overlay(alignment: .bottomLeading) {
                BrandMark(brand: product.brand, mark: product.mark, size: 36).padding(R.spacingSpace12)
            }
            .clipShape(EditorialCard.shape)
            .elevation(.floating)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("New drop")
            .backstageText(.specialTitle)
            .foregroundStyle(M.textInverse)
            .padding(.horizontal, R.spacingSpace8)
            .padding(.vertical, R.spacingSpace4)
            .background(M.surfaceInverse, in: Capsule())
            .accessibilityHidden(true)
    }
}

// MARK: - Pull quote

/// Big-type pull quote: a Stores-green rule down the left, an oversized green quotation mark, and the
/// line set large in Playfair Display (the key word in italic), its words lighting up as the quote
/// scrolls into view.
struct PullQuote: View {
    @Environment(\.editorialViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    private let words = "Dress like the city is watching. It usually is.".split(separator: " ").map(String.init)
    /// The word set in italic for emphasis.
    private let accentWord = "watching."

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace16) {
            Rectangle()
                .fill(LinearGradient(colors: [M.iconAccentGreen, M.iconAccentGreen.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: R.stroke2Px)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text("“")
                    .font(.custom("PlayfairDisplay-Regular", size: 96, relativeTo: .largeTitle))
                    .foregroundStyle(M.iconAccentGreen)
                    .frame(height: 48, alignment: .top)
                    .accessibilityHidden(true)
                quote
                    .font(.custom("PlayfairDisplay-Regular", size: DisplaySize.quote, relativeTo: .title))
                    .lineSpacing(2)
                    .animation(.easeOut(duration: 0.15), value: progress)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { g in
                Color.clear.preference(key: QuoteTopKey.self, value: g.frame(in: .global).minY)
            }
        }
        .onPreferenceChange(QuoteTopKey.self) { top in
            progress = min(1, max(0, (viewport * 0.85 - top) / (viewport * 0.5)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dress like the city is watching. It usually is.")
    }

    /// Words before the reading point are lit; the rest wait in tertiary grey.
    private var quote: Text {
        let lit = reduceMotion ? words.count : Int((progress * CGFloat(words.count)).rounded(.up))
        return words.enumerated().reduce(Text("")) { text, word in
            var piece = Text(word.element + " ").foregroundStyle(word.offset < lit ? M.textPrimary : M.textTertiary)
            if word.element == accentWord {
                piece = piece.font(.custom("PlayfairDisplay-Italic", size: DisplaySize.quote, relativeTo: .title))
            }
            return Text("\(text)\(piece)")
        }
    }
}

private struct QuoteTopKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Goes with everything

/// One staple, many partners: the staple holds still on the left while its pairings swipe past on
/// the right, joined by a "+" that turns with each swipe.
struct StaplesSection: View {
    @State private var selected = EditorialData.staples[0].id
    @Namespace private var tabPill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var staple: Staple {
        EditorialData.staples.first { $0.id == selected } ?? EditorialData.staples[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 3, lines: ["what goes well with?"])
            tabs

            StapleLooks(staple: staple)
                .id(staple.id)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }

    /// Photo tabs on a capsule track, each with its name; a white pill slides to the chosen staple.
    /// The track scrolls sideways when the names don't all fit.
    private var tabs: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace4) {
                    ForEach(EditorialData.staples) { s in
                        let active = s.id == selected
                        Button {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8)) { selected = s.id }
                        } label: {
                            HStack(spacing: R.spacingSpace8) {
                                ArtView(art: s.thumb)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .overlay(Circle().strokeBorder(active ? Color.clear : M.borderSubtle, lineWidth: R.stroke1Px))
                                    .saturation(active ? 1 : 0.6)
                                Text(s.title)
                                    .backstageText(.label2)
                                    .foregroundStyle(active ? M.buttonPrimaryLabel : M.textSecondary)
                                    .fixedSize()
                            }
                            .padding(.leading, R.spacingSpace4 + 2)
                            .padding(.trailing, R.spacingSpace16)
                            .frame(height: 44)
                            .background {
                                if active {
                                    Capsule()
                                        .fill(M.buttonPrimaryBackground)
                                        .matchedGeometryEffect(id: "staple-pill", in: tabPill)
                                }
                            }
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(s.id)
                        .accessibilityLabel("\(s.title), \(s.pairs.count) pairings")
                        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(R.spacingSpace4)
                .background(M.surfacePrimary, in: Capsule())
                .overlay(Capsule().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: selected) { _, id in
                withAnimation(.snappy) { reader.scrollTo(id, anchor: .center) }
            }
        }
    }
}

/// Whole looks built on the chosen staple, so it is seen worn rather than beside loose pieces.
/// Tap a look to open the lookbook at it; the closing card opens it from the first look.
struct StapleLooks: View {
    let staple: Staple
    @State private var cover: Cover?

    enum Cover: Identifiable {
        case look(Int), studio
        var id: Int {
            switch self {
            case .look(let i): i
            case .studio: -1
            }
        }
    }

    private let size = CGSize(width: 232, height: 320)

    private func lookName(_ i: Int) -> String { "Look \(String(format: "%02d", i + 1))" }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace8) {
                ForEach(staple.looks.indices, id: \.self) { i in
                    Button { cover = .look(i) } label: { card(i) }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(lookName(i)), styled with the \(staple.title.lowercased())")
                        .accessibilityHint("Opens the lookbook")
                }
                mixAndMatch
            }
            .scrollTargetLayout()
        }
        .carousel()
        .sensoryFeedback(.impact(weight: .light), trigger: cover?.id)
        .readerCover(item: $cover) { cover in
            switch cover {
            case .look(let i): StapleLookbookView(staple: staple, start: i)
            case .studio: StapleLookbookView(staple: staple, start: 0)
            }
        }
    }

    /// The look, with the staple it is built on pinned in the corner.
    private func card(_ i: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            ArtView(art: staple.looks[i], parallax: 0.06)
            ImageScrim(strength: 0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(lookName(i))
                    .backstageText(.label1)
                    .foregroundStyle(M.textWhite)
                Text("with the \(staple.title.lowercased())")
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
            }
            .padding(R.spacingSpace16)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(EditorialCard.shape)
        .overlay(alignment: .topLeading) {
            ArtView(art: staple.thumb)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(M.iconWhite, lineWidth: R.stroke1PlusHalfPx))
                .elevation(.shadow100)
                .padding(R.spacingSpace12)
                .accessibilityHidden(true)
        }
    }

    /// Closes the rail: a blurred peek of the last look, opening the lookbook from the start.
    private var mixAndMatch: some View {
        Button { cover = .studio } label: {
            ZStack {
                ArtView(art: staple.looks.last ?? staple.thumb)
                    .blur(radius: 16, opaque: true)
                M.proposedOverlayScrim.opacity(0.45)
                VStack(spacing: R.spacingSpace12) {
                    CircleArrow()
                    VStack(spacing: 2) {
                        Text("See every look")
                            .backstageText(.label1)
                            .foregroundStyle(M.textWhite)
                        Text("\(staple.looks.count) ways to wear it")
                            .backstageText(.label2)
                            .foregroundStyle(M.textSecondary)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(EditorialCard.shape)
            .contentShape(EditorialCard.shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("See every way to wear the \(staple.title.lowercased())")
    }
}

// MARK: - Cop these looks

struct LooksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 4, lines: ["cop these looks"])
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace4) {
                    ForEach(EditorialData.looks) { LookCard(look: $0) }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }
}

/// A look with pulsing "+" pins on each piece. A pin opens the shop sheet on that piece.
struct LookCard: View {
    let look: Look
    @State private var shopping: Shopping?

    struct Shopping: Identifiable {
        let id: Int
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtView(art: look.art, parallax: 0.1)
            ImageScrim()

            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                Text(look.title)
                    .backstageText(.label1)
                    .foregroundStyle(M.textWhite)
                    .accessibilityAddTraits(.isHeader)
                Button { shopping = Shopping(id: 0) } label: {
                    HStack(spacing: 2) {
                        Text("Shop \(look.spots.count) pieces")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
                    // 44pt hit area without padding out the layout.
                    .contentShape(Rectangle().inset(by: -14))
                }
                .buttonStyle(.plain)
            }
            .padding(R.spacingSpace16)

            GeometryReader { geo in
                ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                    HotspotPin(spot: spot, isActive: shopping?.id == i) {
                        shopping = Shopping(id: i)
                    }
                    .position(x: spot.x * geo.size.width, y: spot.y * geo.size.height)
                }
            }
        }
        .frame(width: 280, height: 400)
        .clipShape(EditorialCard.shape)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sensoryFeedback(.impact(weight: .light), trigger: shopping?.id)
        .sheet(item: $shopping) { ShopTheLookView(look: look, start: $0.id) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(look.title)
    }
}

// MARK: - Fits for every plan

/// Swipeable occasion collections: a cover photo with the occasion name, and a strip of its
/// looks beneath. Nothing overlaps; every card shares the same frame.
struct PlansSection: View {
    @State private var opened: Plan?
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 5, lines: ["fits for every plan"]) // Not on the page; see EditorialView.
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace12) {
                    ForEach(EditorialData.plans) { plan in
                        PlanCollectionCard(plan: plan) { opened = plan }
                            .zoomSource(id: plan.id, in: zoom)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
        .readerCover(item: $opened) { plan in
            PlanGalleryView(plan: plan)
                .zoomTransition(id: plan.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }
}

/// An occasion's collection: a cover photo with its name and look count, then a strip of its
/// looks ending in a blurred "+N" tile.
struct PlanCollectionCard: View {
    let plan: Plan
    var open: () -> Void = {}

    private let width: CGFloat = 260
    private let gap = R.spacingSpace4 / 2

    var body: some View {
        let gallery = plan.gallery
        let shown = min(3, gallery.count)
        Button(action: open) {
            VStack(spacing: gap) {
                ZStack(alignment: .bottomLeading) {
                    ArtView(art: gallery[0], parallax: 0.1)
                    ImageScrim(strength: 0.75)
                    VStack(alignment: .leading, spacing: R.spacingSpace4) {
                        Text(plan.title)
                            .backstageText(.label1)
                            .foregroundStyle(M.textWhite)
                        Text("\(plan.count) looks")
                            .backstageText(.label2)
                            .foregroundStyle(M.textSecondary)
                    }
                    .padding(R.spacingSpace16)
                }
                .frame(height: 260)

                HStack(spacing: gap) {
                    ForEach(1..<shown, id: \.self) { i in
                        ArtView(art: gallery[i])
                    }
                    // "+N more", over a blurred peek of the next look.
                    ZStack {
                        if gallery.count > shown {
                            ArtView(art: gallery[shown])
                                .blur(radius: 10, opaque: true)
                        }
                        M.proposedOverlayScrim.opacity(0.4)
                        Text("+\(max(0, gallery.count - shown))")
                            .backstageText(.title3)
                            .foregroundStyle(M.textWhite)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
                .frame(height: 84)
            }
            .frame(width: width)
            .clipShape(EditorialCard.shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plan.title), \(plan.count) looks")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Shop by vibe

/// Each card leads with an illustrated vibe, then three pieces to wear to it. Tapping a card opens that plan's gallery.
struct VibeSection: View {
    @State private var opened: Plan?
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 5, lines: ["fits for every plan"])
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace8) {
                    ForEach(Vibe.all) { vibe in
                        if let plan = EditorialData.plans.first(where: { $0.title == vibe.plan }) {
                            VibeCard(vibe: vibe, plan: plan) { opened = plan }
                                .zoomSource(id: "vibe-\(vibe.id)", in: zoom)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
        .readerCover(item: $opened) { plan in
            PlanGalleryView(plan: plan)
                .zoomTransition(id: "vibe-\(Vibe.all.first { $0.plan == plan.title }?.id ?? "")", in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }
}

/// One vibe: its illustration, name and the colours drawn for it while the illustration loads
/// (illustration colours, not UI tokens).
struct Vibe: Identifiable {
    let id: String
    let name: String
    /// The plan whose looks the card shows.
    let plan: String
    let image: String
    /// Deep and accent colours from the illustration, for its placeholder.
    let ground: UInt32
    let accent: UInt32

    static let all: [Vibe] = [
        Vibe(id: "diwali", name: "Diwali", plan: "Diwali parties", image: "vibe_diwali", ground: 0x2A1210, accent: 0xF4C25B),
        Vibe(id: "concert", name: "Concert", plan: "Concert night", image: "vibe_concert", ground: 0x1F0B2C, accent: 0xFF6BC4),
        Vibe(id: "active", name: "Active", plan: "Activewear", image: "vibe_active", ground: 0x0E2216, accent: 0xA8E27A),
        Vibe(id: "brunch", name: "Brunch", plan: "Sunday brunch", image: "vibe_brunch", ground: 0x2E2219, accent: 0xF7B98C),
    ]
}

/// A vibe in the house style: its illustration as the cover with the name set in display type,
/// then three pieces listed like a contents page, on the shared card surface.
struct VibeCard: View {
    let vibe: Vibe
    let plan: Plan
    var open: () -> Void = {}

    private let width: CGFloat = 300
    private let artHeight: CGFloat = 140

    var body: some View {
        let pieces = Array(plan.looks.prefix(3))
        Button(action: open) {
            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                ZStack(alignment: .bottomLeading) {
                    ArtView(art: Art(vibe.image, [vibe.ground, vibe.accent]), parallax: 0.1)
                        .frame(width: width, height: artHeight)
                        .clipped()
                    ImageScrim(strength: 0.75)
                    Text(vibe.name.lowercased())
                        .editorialDisplay(DisplaySize.section)
                        .foregroundStyle(M.textWhite)
                        .padding(R.spacingSpace16)
                }
                .frame(height: artHeight)

                VStack(spacing: R.spacingSpace0) {
                    ForEach(pieces.indices, id: \.self) { i in
                        row(pieces[i])
                        if i < pieces.count - 1 {
                            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                        }
                    }
                }
                .padding(.horizontal, R.spacingSpace16)
                .padding(.vertical, R.spacingSpace4)

                HStack(spacing: R.spacingSpace4) {
                    Text("See all \(plan.count) looks")
                        .backstageText(.label2)
                        .foregroundStyle(M.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(M.iconTertiary)
                    Spacer(minLength: 0)
                }
                .padding(R.spacingSpace16)
                .overlay(alignment: .top) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
            }
            .frame(width: width)
            .background(M.surfacePrimary)
            .clipShape(EditorialCard.shape)
            .overlay(EditorialCard.shape.strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vibe.name). \(pieces.map { "\($0.name) by \($0.brand)" }.joined(separator: ", "))")
        .accessibilityHint("Opens the \(plan.title.lowercased()) looks")
        .accessibilityAddTraits(.isButton)
    }

    /// A piece: thumbnail, brand, name, and where to find it.
    private func row(_ look: FeedLook) -> some View {
        HStack(spacing: R.spacingSpace12) {
            ArtView(art: look.art)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
            VStack(alignment: .leading, spacing: 2) {
                Text(look.name)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                Text(look.brand)
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
                Text("In store at \(EditorialData.storeAreas[look.brand] ?? "Cyberhub, Gurugram")")
                    .backstageText(.body3)
                    .foregroundStyle(M.textTertiary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, R.spacingSpace12)
    }
}

// MARK: - Pick your palette

/// Centre-snapping, endlessly looping palette carousel.
struct PaletteSection: View {
    /// One slot in the looped rail: the same palettes repeated, each with a unique id.
    private struct Slot: Identifiable {
        let id: String
        let palette: Palette
        let number: Int
    }

    private static let loops = 20
    private static let slots: [Slot] = (0..<loops).flatMap { lap in
        EditorialData.palettes.enumerated().map { i, p in Slot(id: "\(lap)-\(p.id)", palette: p, number: i + 1) }
    }

    /// Opens in the middle lap so there are palettes on both sides from the start.
    @State private var focused: String? = PaletteSection.slots[(PaletteSection.loops / 2) * EditorialData.palettes.count].id
    @State private var opened: Slot?
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardSize = CGSize(width: 280, height: 400)

    private var currentSlot: Slot { Self.slots.first { $0.id == focused } ?? Self.slots[0] }
    private var current: Palette { currentSlot.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 6, lines: ["pick your palette"])

            VStack(spacing: R.spacingSpace20) {
                GeometryReader { geo in
                    ScrollViewReader { reader in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: R.spacingSpace8) {
                            ForEach(Self.slots) { slot in
                                PaletteCard(palette: slot.palette, number: slot.number, size: cardSize) {
                                    open(slot)
                                }
                                .zoomSource(id: slot.id, in: zoom)
                                    .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                                        card
                                            .scaleEffect(1 - abs(phase.value) * 0.1)
                                            .opacity(1 - abs(phase.value) * 0.4)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, max(0, (geo.size.width - cardSize.width) / 2), for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $focused)
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    // Open centred in the middle lap, with neighbours on both sides. Retried while
                    // layout settles, since one early scrollTo can be dropped.
                    .task(id: geo.size.width) {
                        guard geo.size.width > 0 else { return }
                        let target = focused
                        for delay in [0.0, 0.12, 0.35] {
                            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                            guard !Task.isCancelled, focused == target else { return }
                            reader.scrollTo(target, anchor: .center)
                        }
                    }
                    }
                }
                .frame(height: cardSize.height)

                Button { opened = currentSlot } label: {
                    HStack(spacing: R.spacingSpace4) {
                        Text("Shop the \(current.name) edit")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .buttonStyle(BackstageTextButtonStyle())
                .id(current.id)
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.4), value: current.id)
        }
        .sensoryFeedback(.selection, trigger: focused)
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
        .readerCover(item: $opened) { slot in
            PaletteDetailView(palette: slot.palette)
                .zoomTransition(id: slot.id, in: zoom)
        }
    }

    /// Tapping the centred card opens it; tapping a side card brings it to the centre first.
    private func open(_ slot: Slot) {
        if slot.id == focused {
            opened = slot
        } else {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { focused = slot.id }
        }
    }
}

/// Four looks in one palette, its colours as a row of swatch chips, and the palette name on a
/// soft blur, with a plain hairline border.
struct PaletteCard: View {
    let palette: Palette
    let number: Int
    let size: CGSize
    var open: () -> Void = {}

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                grid
                grid
                    .blur(radius: 18, opaque: true)
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.55), .init(color: .black, location: 0.8)],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                ImageScrim(strength: 0.65)

                PaletteSwatches(hexes: palette.hexes)
                    // Sits exactly where the four photos meet.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    Text(palette.name)
                        .backstageText(.label1)
                        .foregroundStyle(M.textWhite)
                    Text("\(palette.looks.count) looks")
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                }
                .padding(R.spacingSpace16)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(EditorialCard.shape)
            .overlay(EditorialCard.shape.strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(palette.name) palette, \(palette.looks.count) looks")
        .accessibilityAddTraits(.isButton)
    }

    private var grid: some View {
        let looks = Array(palette.looks.prefix(4))
        let gap = R.spacingSpace4 / 2
        return VStack(spacing: gap) {
            HStack(spacing: gap) { ArtView(art: looks[0], parallax: 0.06); ArtView(art: looks[1], parallax: 0.06) }
            HStack(spacing: gap) { ArtView(art: looks[2], parallax: 0.06); ArtView(art: looks[3], parallax: 0.06) }
        }
    }
}
