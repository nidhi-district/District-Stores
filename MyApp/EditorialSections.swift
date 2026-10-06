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
            SectionHeader(number: 1, lines: ["homegrown &", "unfiltered"])
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
            SectionHeader(number: 2, lines: ["hot off", "the rack"])

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
            Text(current.brand)
                .backstageText(.label2)
                .foregroundStyle(M.textSecondary)
            Text(current.name)
                .backstageText(.caption)
                .foregroundStyle(M.textPrimary)
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

/// Magazine pull quote set in the display face: the line breaks are composed, words light up as
/// the quote scrolls into view, and the key word lands in District purple. A quieter aside answers
/// it from the right.
struct PullQuote: View {
    @Environment(\.editorialViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    /// Composed lines of the main quote; the last word is the accent.
    private let lines = [["dress", "like"], ["the", "city", "is"], ["watching."]]
    private var wordCount: Int { lines.joined().count }

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace16) {
            Rectangle()
                .fill(LinearGradient(colors: [M.iconBrand, M.iconBrand.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: R.stroke2Px)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                Text("“")
                    .editorialDisplay(96)
                    .foregroundStyle(M.textPurple)
                    .frame(height: 48, alignment: .top)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: -DisplaySize.quote * 0.22) {
                    ForEach(lines.indices, id: \.self) { i in
                        line(i)
                            .editorialDisplay(DisplaySize.quote)
                            .modifier(KineticLine(index: i))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: progress)

                HStack(spacing: R.spacingSpace12) {
                    Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
                    Text("it usually is.")
                        .editorialDisplay(DisplaySize.title)
                        .foregroundStyle(progress >= 1 ? M.textSecondary : M.textTertiary)
                        .fixedSize()
                }
                .padding(.top, R.spacingSpace16)
                .animation(.easeOut(duration: 0.3), value: progress >= 1)

                Text("The District Style Desk")
                    .backstageText(.specialTitle)
                    .foregroundStyle(M.textPurple)
                    .padding(.top, R.spacingSpace16)
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
        .accessibilityLabel("Dress like the city is watching. It usually is. The District Style Desk")
    }

    /// One composed line; words before the reading point are lit, the accent word turns purple.
    private func line(_ i: Int) -> Text {
        let lit = reduceMotion ? wordCount : Int((progress * CGFloat(wordCount)).rounded(.up))
        let start = lines[..<i].joined().count
        return lines[i].enumerated().reduce(Text("")) { text, word in
            let index = start + word.offset
            let isAccent = index == wordCount - 1
            let colour: Color = index < lit ? (isAccent ? M.textPurple : M.textPrimary) : M.textTertiary
            let piece = Text(word.offset == 0 ? word.element : " " + word.element).foregroundStyle(colour)
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
            SectionHeader(number: 3, lines: ["what goes", "well with?"])
            tabs

            PairingSplit(staple: staple)
                .id(staple.id)
                .transition(.opacity)
                .padding(.horizontal, R.spacingSpace16)
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

/// The split card: fixed staple on the left, a swipeable deck of pairings on the right.
struct PairingSplit: View {
    let staple: Staple
    @State private var page: Int? = 0
    @State private var studio: Studio?
    @Namespace private var zoom

    /// Opens the full-screen mix-and-match on a given pairing.
    struct Studio: Identifiable {
        let id: Int
    }
    @State private var onScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.editorialViewport) private var viewport

    private let height: CGFloat = 340
    /// Seconds each pairing stays before the deck turns on its own.
    private let dwell: Double = 1.8
    private let seam = R.spacingSpace4 / 2

    private var index: Int { page ?? 0 }
    private var pairs: [Pairing] { staple.pairs }
    private var onViewAll: Bool { index >= pairs.count }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            GeometryReader { geo in
                let left = (geo.size.width - seam) * 0.42
                HStack(spacing: seam) {
                    stapleSide.frame(width: left)
                    deck
                }
                .overlay(alignment: .topLeading) {
                    coin.position(x: left + seam / 2, y: geo.size.height / 2)
                }
            }
            .frame(height: height)
            .clipShape(EditorialCard.shape)
            .zoomSource(id: "studio-\(staple.id)", in: zoom)
            .onGeometryChange(for: Bool.self) { proxy in
                let frame = proxy.frame(in: .global)
                let screen = viewport > 0 ? viewport : 900
                return frame.minY < screen * 0.85 && frame.maxY > screen * 0.15
            } action: { onScreen = $0 }

            caption
        }
        // Turn to the next page after a pause (pairings, then "View all", then round again); any swipe
        // restarts the countdown.
        .task(id: Autoplay(page: index, running: autoplays)) {
            guard autoplays, pairs.count > 1 else { return }
            // Rest a little longer on "View all" before looping back to the first pairing.
            try? await Task.sleep(for: .seconds(onViewAll ? dwell * 1.6 : dwell))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.45)) { page = (index + 1) % (pairs.count + 1) }
        }
        .readerCover(item: $studio) { s in
            StapleStudioView(staple: staple, start: s.id)
                .zoomTransition(id: "studio-\(staple.id)", in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: studio?.id)
    }

    private struct Autoplay: Equatable {
        let page: Int
        let running: Bool
    }

    private var autoplays: Bool { onScreen && studio == nil && !reduceMotion && !voiceOver }

    private func openStudio() {
        studio = Studio(id: min(index, pairs.count - 1))
    }

    private var stapleSide: some View {
        ArtView(art: staple.thumb)
        .contentShape(Rectangle())
        .onTapGesture(perform: openStudio)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(staple.title)
        .accessibilityHint("Opens mix and match")
        .accessibilityAddTraits(.isButton)
    }

    /// Pairings page past behind a clipped window; each photo eases in from a slight zoom.
    private var deck: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace0) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { i, pairing in
                    ArtView(art: pairing.art)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 + abs(phase.value) * 0.18)
                                .offset(x: phase.value * -40)
                        }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { studio = Studio(id: i) }
                    .id(i)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(pairing.name) from \(pairing.brand)")
                    .accessibilityHint("Opens mix and match")
                    .accessibilityAddTraits(.isButton)
                }
                viewAll
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(pairs.count)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) { dots.padding(.bottom, R.spacingSpace12) }
        .sensoryFeedback(.selection, trigger: page)
    }

    /// Progress dots on the photo, on a small glass pill.
    private var dots: some View {
        HStack(spacing: R.spacingSpace4) {
            ForEach(0...pairs.count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? M.iconWhite : M.iconWhite.opacity(0.45))
                    .frame(width: i == index ? 14 : 5, height: 5)
            }
        }
        .padding(.horizontal, R.spacingSpace8)
        .frame(height: 18)
        .liquidGlass(in: Capsule(), clear: true)
        .animation(.snappy, value: index)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var viewAll: some View {
        Button { studio = Studio(id: 0) } label: {
            ZStack {
                // A blurred peek of the pairings closes the deck.
                ArtView(art: (pairs.last ?? pairs[0]).art)
                    .blur(radius: 16, opaque: true)
                M.proposedOverlayScrim.opacity(0.45)
                VStack(spacing: R.spacingSpace12) {
                    CircleArrow()
                    Text("View all")
                        .backstageText(.label2)
                        .foregroundStyle(M.textWhite)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("View all pieces that pair with the \(staple.title.lowercased())")
    }

    /// The "+" on the seam, a quarter turn per swipe.
    private var coin: some View {
        Image(systemName: onViewAll ? "chevron.right" : "plus")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(M.iconInverse)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 36, height: 36)
            .background(M.surfaceInverse, in: Circle())
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(index) * 90))
            .elevation(.shadow100)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: index)
            .accessibilityHidden(true)
    }

    /// The pairing's name and brand (the staple is already named in the tab above).
    private var caption: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace0) {
            if onViewAll {
                Text("Every way to wear the \(staple.title.lowercased())")
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
            } else {
                Text(pairs[index].name)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text(pairs[index].brand)
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
            }
        }
        .id(index)
        .transition(.opacity)
        .animation(.snappy, value: index)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cop these looks

struct LooksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: headerGap) {
            SectionHeader(number: 4, lines: ["cop", "these looks"])
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

// MARK: - The In / Out list

/// A fashion-magazine In / Out list set as two drifting strips: what's in glides by in bright display
/// type, what's out drifts the other way, struck through and muted. Static under Reduce Motion.
struct InOutList: View {
    private let ins = ["butter yellow", "barrel-leg denim", "mesh flats", "quiet tailoring", "polka dots", "sheer layers"]
    private let outs = ["skinny jeans", "logo mania", "chunky dad sneakers", "neon everything", "micro bags", "matchy sets"]

    var body: some View {
        VStack(spacing: R.spacingSpace16) {
            title
            VStack(spacing: R.spacingSpace12) {
                row(label: "In", items: ins, isIn: true)
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                    .padding(.horizontal, R.spacingSpace16)
                row(label: "Out", items: outs, isIn: false)
            }
            .padding(.vertical, R.spacingSpace16)
            .overlay(alignment: .top) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
            .overlay(alignment: .bottom) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The in and out list. In: \(ins.joined(separator: ", ")). Out: \(outs.joined(separator: ", ")).")
    }

    private var title: some View {
        HStack(spacing: R.spacingSpace12) {
            Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
            Text("THE IN / OUT LIST")
                .font(.custom("BeVietnamPro-SemiBold", size: 12, relativeTo: .caption))
                .tracking(2.4)
                .foregroundStyle(M.textSecondary)
                .fixedSize()
            Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    /// A pinned tag on the left, and the items drifting past behind a soft fade.
    private func row(label: String, items: [String], isIn: Bool) -> some View {
        HStack(spacing: R.spacingSpace12) {
            Text(label.uppercased())
                .backstageText(.specialTitle)
                .foregroundStyle(isIn ? M.textInverse : M.textSecondary)
                .frame(width: 44, height: 24)
                .background(isIn ? M.surfaceInverse : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isIn ? Color.clear : M.borderModerate, lineWidth: R.stroke1Px))

            Color.clear
                .frame(height: 32)
                .overlay(alignment: .leading) {
                    Marquee(speed: isIn ? 28 : 22, reversed: !isIn) {
                        HStack(spacing: R.spacingSpace16) {
                            ForEach(items, id: \.self) { item in
                                Text(item)
                                    .editorialDisplay(DisplaySize.title)
                                    .foregroundStyle(isIn ? M.textPrimary : M.textTertiary)
                                    .strikethrough(!isIn, color: M.textTertiary)
                                Text(isIn ? "✦" : "—")
                                    .backstageText(.label2)
                                    .foregroundStyle(isIn ? M.textPurple : M.textTertiary)
                            }
                        }
                        .padding(.trailing, R.spacingSpace16)
                    }
                }
                .clipped()
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                                           .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                }
        }
        .padding(.leading, R.spacingSpace16)
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
            CoverHeader(number: 5, lead: "fits for", headline: "every plan")
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

// MARK: - Pick your palette

/// Centre-snapping, endlessly looping palette carousel. The focused palette's colours bloom
/// faintly behind it.
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
            SectionHeader(number: 6, lines: ["pick your", "palette"])

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
            .background { bloom }
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

    /// Soft orbs of the focused palette's colours behind the carousel.
    private var bloom: some View {
        let hexes = current.hexes
        let mid = CGFloat(hexes.count - 1) / 2
        return ZStack {
            ForEach(hexes.indices, id: \.self) { i in
                Circle()
                    .fill(Color(hex: hexes[i]))
                    .frame(width: 180, height: 180)
                    .offset(x: (CGFloat(i) - mid) * 80, y: (i.isMultiple(of: 2) ? -1 : 1) * 24)
            }
        }
        .blur(radius: 90)
        .opacity(0.1)
        .id(current.id)
        .transition(.opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Four looks in one palette, a colour wheel that turns with the swipe, and the palette name on a
/// soft blur. Framed by a hairline ring of its own colours.
struct PaletteCard: View {
    let palette: Palette
    let number: Int
    let size: CGSize
    var open: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let spin: CGFloat = reduceMotion ? 0 : 0.6
        let colours = palette.hexes.map { Color(hex: $0) }

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

                PaletteWheel(hexes: palette.hexes, lineWidth: 12)
                    .frame(width: 68, height: 68)
                    .padding(R.spacingSpace8)
                    .background(M.surfacePrimary, in: Circle())
                    .visualEffect { content, proxy in
                        content.rotationEffect(.degrees(proxy.frame(in: .scrollView).minX * spin))
                    }
                    .elevation(.floating)
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
            .overlay(
                EditorialCard.shape.strokeBorder(
                    AngularGradient(colors: colours + [colours[0]], center: .center),
                    lineWidth: R.stroke1PlusHalfPx
                )
                .opacity(0.85)
            )
            .shadow(color: colours[0].opacity(0.15), radius: 18, y: 10)
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
