import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// District Vogue's Explore tab: the District Stores edit printed as a newspaper. The Explore header
// sits on top with the nameplate under it; each section is a page. Scroll to read a page, and
// scrolling on past its end turns to the next one. A page menu rests as ticks on the right edge and
// pops out while pages change.

struct VogueNewspaperView: View {
    @State private var page = 0
    @State private var pageTops: [Int: CGFloat] = [:]
    @State private var location = "Vatika City"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let locations = ["Vatika City", "Golf Course Extension Road", "Cyberhub, DLF Phase 2", "Sector 29"]

    /// The edition's pages, in print order.
    private let pages: [(title: String, short: String)] = [
        ("Homegrown & unfiltered", "Brands"),
        ("Hot off the rack", "Rack"),
        ("What goes well with?", "Staples"),
        ("The quote", "Quote"),
        ("Cop these looks", "Looks"),
        ("Fits for every plan", "Plans"),
        ("Pick your palette", "Colour"),
        ("In this issue", "Index"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "Explore", location: $location, locations: locations)
            masthead
            GeometryReader { area in
                ZStack(alignment: .trailing) {
                    pager(height: area.size.height)
                    pageRail
                }
                .environment(\.editorialViewport, area.size.height)
            }
        }
        .environment(\.editorialStyle, .newspaper)
        .background { Newsprint().ignoresSafeArea() }
        .sensoryFeedback(.selection, trigger: page)
        #if DEBUG
        // Debug builds accept `-startPage N` so a simulator can open on a given page.
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-startPage"), i + 1 < args.count, let n = Int(args[i + 1]) {
                try? await Task.sleep(for: .seconds(2))
                jumpTarget = max(0, min(pages.count - 1, n - 1))
            }
        }
        #endif
    }

    // MARK: Masthead

    /// The full nameplate on the front page; a one-line nameplate on the pages after it.
    private var masthead: some View {
        let front = page == 0
        return VStack(spacing: front ? R.spacingSpace8 : 4) {
            if front {
                HStack {
                    Text("VOL. 01 · NO. 07")
                    Spacer()
                    Text("GURUGRAM EDITION")
                }
                .font(NewsType.condensed(11))
                .tracking(1.4)
                .foregroundStyle(M.textSecondary)
                .transition(.opacity)
            }

            HStack(alignment: .firstTextBaseline) {
                if !front {
                    Text("P. \(String(format: "%02d", page + 1))")
                        .font(NewsType.condensed(12))
                        .tracking(1.2)
                        .foregroundStyle(M.textSecondary)
                        .frame(width: 44, alignment: .leading)
                }
                Spacer(minLength: 0)
                Text("The District Edit")
                    .font(NewsType.serif(front ? 40 : 20, .black))
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if !front { Color.clear.frame(width: 44, height: 1) }
            }

            // The classic thick-and-thin double rule under a nameplate.
            VStack(spacing: 2) {
                Rectangle().fill(M.textPrimary).frame(height: front ? 2.5 : 1.5)
                Rectangle().fill(M.textPrimary).frame(height: R.stroke1Px)
            }
            .accessibilityHidden(true)

            if front {
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).uppercased())
                    Spacer()
                    Text("\(pages.count) PAGES")
                }
                .font(NewsType.condensed(11))
                .tracking(1.4)
                .foregroundStyle(M.textSecondary)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, front ? R.spacingSpace24 : R.spacingSpace12)
        .padding(.bottom, front ? R.spacingSpace12 : R.spacingSpace8)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.88), value: front)
    }

    // MARK: Pages

    private func pager(height: CGFloat) -> some View {
        ScrollViewReader { reader in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(i, reader: reader)
                            .frame(minHeight: height, alignment: .top)
                            .background {
                                GeometryReader { g in
                                    Color.clear.preference(key: PageTopsKey.self, value: [i: g.frame(in: .named("edition")).minY])
                                }
                            }
                            .modifier(PageTurn(enabled: !reduceMotion))
                            .id(i)
                    }
                }
                .coordinateSpace(name: "edition")
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(PageSnap(tops: pages.indices.compactMap { pageTops[$0] }))
            .onPreferenceChange(PageTopsKey.self) { tops in
                if tops != pageTops { pageTops = tops }
            }
            .modifier(CurrentPageTracker(tops: pages.indices.compactMap { pageTops[$0] }) { i in
                if i != page { page = i }
            })
            .onChange(of: jumpTarget) { _, target in
                guard let target else { return }
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.55)) { reader.scrollTo(target, anchor: .top) }
                jumpTarget = nil
            }
        }
    }

    @State private var jumpTarget: Int?

    private func pageView(_ i: Int, reader: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace32) {
            content(i)
                .environment(\.newspaperPage, i + 1)
            Spacer(minLength: 0)
            if i < pages.count - 1 { continued(to: i + 1) }
        }
        .padding(.top, R.spacingSpace20)
        .padding(.bottom, R.spacingSpace80 + R.spacingSpace24)   // clears the floating tab bar
        .padding(.trailing, railWidth)                          // room for the sticky page rail
    }

    @ViewBuilder
    private func content(_ i: Int) -> some View {
        switch i {
        case 0: FrontPage()
        case 1:
            VStack(spacing: R.spacingSpace32) {
                RackSection()
                TickerStrip()
            }
        case 2: StaplesSection()
        case 3:
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                NewspaperSectionHeader(number: 4, title: "The quote")
                PullQuote()
            }
        case 4: LooksSection()
        case 5: OccasionFeatures()
        case 6: PaletteSpread()
        default:
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                NewspaperSectionHeader(number: 8, title: "In this issue")
                Colophon(jump: jump(to:))
            }
        }
    }

    /// "Continued on page N", newspaper fashion; turns the page.
    private func continued(to next: Int) -> some View {
        Button { jumpTarget = next } label: {
            HStack(spacing: R.spacingSpace8) {
                Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
                Text("CONTINUED ON PAGE \(next + 1)")
                    .font(NewsType.condensed(12))
                    .tracking(1.6)
                Image(systemName: "arrow.down").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(M.textSecondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, R.spacingSpace16)
        .accessibilityLabel("Continued on page \(next + 1), \(pages[next].title)")
    }

    // MARK: Page rail

    private let railWidth: CGFloat = 30

    /// A sticky running head down the right edge: page numbers on a hairline, the current page an
    /// ink tab with its name set vertically along the rail. Tap a number to turn to that page.
    private var pageRail: some View {
        VStack(spacing: 0) {
            ForEach(pages.indices, id: \.self) { i in
                let active = i == page
                Button { jumpTarget = i } label: {
                    VStack(spacing: R.spacingSpace8) {
                        Text(String(format: "%02d", i + 1))
                            .font(NewsType.condensed(11))
                            .foregroundStyle(active ? M.textInverse : M.textTertiary)
                        if active {
                            Text(pages[i].short.uppercased())
                                .font(NewsType.condensed(10))
                                .tracking(1.6)
                                .foregroundStyle(M.textInverse)
                                .fixedSize()
                                .rotationEffect(.degrees(90))
                                .frame(width: 12, height: CGFloat(pages[i].short.count) * 7.5 + 8)
                                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
                        }
                    }
                    .padding(.vertical, active ? R.spacingSpace8 : 6)
                    .frame(width: railWidth - 8)
                    .background {
                        if active { Rectangle().fill(M.textPrimary) }
                    }
                    .frame(width: railWidth)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(i + 1), \(pages[i].title)")
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: page)
        .padding(.vertical, R.spacingSpace4)
        .background(alignment: .leading) {
            Rectangle().fill(M.borderModerate).frame(width: R.stroke1Px)
        }
        .padding(.top, R.spacingSpace16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Navigation

    /// The contents list jumps to the page that carries each section.
    private func jump(to section: EditorialSection) {
        switch section {
        case .stories: jumpTarget = 0
        case .rack: jumpTarget = 1
        case .staples: jumpTarget = 2
        case .looks: jumpTarget = 4
        case .vibes: jumpTarget = 5
        case .palette: jumpTarget = 6
        }
    }
}

// MARK: - Page mechanics

private struct PageTopsKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Read freely within a page; when a scroll would show the seam between two pages, settle on one:
/// scrolling down lands on the next page's top, scrolling up on the previous page's end.
private struct PageSnap: ScrollTargetBehavior {
    let tops: [CGFloat]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let viewport = context.containerSize.height
        let y = target.rect.minY
        // A page seam inside the window the scroll would come to rest on.
        guard let seam = tops.first(where: { $0 > y + 1 && $0 < y + viewport - 1 }) else { return }
        let goingDown: Bool
        if context.velocity.dy > 0.05 { goingDown = true }
        else if context.velocity.dy < -0.05 { goingDown = false }
        else { goingDown = seam - y < viewport / 2 }
        target.rect.origin.y = goingDown ? seam : max(0, seam - viewport)
    }
}

/// The page whose top has passed a little way under the top of the window.
private struct CurrentPageTracker: ViewModifier {
    let tops: [CGFloat]
    let update: (Int) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: Int.self) { geo in
                let line = geo.contentOffset.y + geo.contentInsets.top + geo.containerSize.height * 0.35
                return max(0, (tops.lastIndex { $0 <= line }) ?? 0)
            } action: { _, index in
                update(index)
            }
        } else {
            content
        }
    }
}

/// The page lifts away as it leaves the top and the next rises in from below.
private struct PageTurn: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.scrollTransition(.interactive.threshold(.visible(0.25)), axis: .vertical) { view, phase in
            view
                .scaleEffect(enabled ? 1 - abs(phase.value) * 0.06 : 1, anchor: phase.value < 0 ? .bottom : .top)
                .rotation3DEffect(.degrees(enabled ? phase.value * 10 : 0), axis: (x: 1, y: 0, z: 0),
                                  anchor: phase.value < 0 ? .bottom : .top, perspective: 0.6)
                .opacity(1 - abs(phase.value) * 0.45)
        }
    }
}

// MARK: - Front page

/// The brand stories set as a newspaper front page: one lead story across the full width, then
/// the rest in two columns split by a rule. Every story opens the reader.
private struct FrontPage: View {
    @State private var reading: Story?
    private let stories = EditorialData.stories

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            NewspaperSectionHeader(number: 1, title: "Homegrown & unfiltered")
            if let lead = stories.first { leadStory(lead) }
            moreStories
        }
        .readerCover(item: $reading) { StoryReaderView(story: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: reading?.id)
    }

    private func leadStory(_ story: Story) -> some View {
        let article = story.article
        return Button { reading = story } label: {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                ArtView(art: story.art)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Text("From the \(story.brand) story")
                    .font(NewsType.serif(12, .italic))
                    .foregroundStyle(M.textTertiary)

                Text(story.brand.uppercased())
                    .font(NewsType.condensed(12))
                    .tracking(1.8)
                    .foregroundStyle(M.textSecondary)
                    .padding(.top, R.spacingSpace4)
                Text(story.title)
                    .font(NewsType.serif(30, .bold))
                    .foregroundStyle(M.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(article.dek)
                    .font(NewsType.serif(17, .italic))
                    .foregroundStyle(M.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: R.spacingSpace8) {
                    Text("BY THE DISTRICT STYLE DESK")
                    Text("·")
                    Text(article.readTime.uppercased())
                    Spacer(minLength: 0)
                    Text("READ")
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .semibold))
                }
                .font(NewsType.condensed(11))
                .tracking(1.2)
                .foregroundStyle(M.textTertiary)
                .padding(.top, R.spacingSpace4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, R.spacingSpace16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lead story: \(story.title), by \(story.brand). \(article.dek)")
        .accessibilityAddTraits(.isButton)
    }

    /// The remaining stories in two newspaper columns with a rule between them.
    private var moreStories: some View {
        let rest = Array(stories.dropFirst())
        let left = rest.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
        let right = rest.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
        return VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(spacing: R.spacingSpace8) {
                Text("ALSO IN THIS ISSUE")
                    .font(NewsType.condensed(12))
                    .tracking(1.6)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize()
                Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
            }
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                column(left)
                Rectangle().fill(M.borderModerate).frame(width: R.stroke1Px)
                column(right)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private func column(_ items: [Story]) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            ForEach(items) { story in
                Button { reading = story } label: {
                    VStack(alignment: .leading, spacing: R.spacingSpace8) {
                        ArtView(art: story.art)
                            .frame(height: 110)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        Text(story.brand.uppercased())
                            .font(NewsType.condensed(10.5))
                            .tracking(1.4)
                            .foregroundStyle(M.textSecondary)
                        Text(story.title)
                            .font(NewsType.serif(17, .bold))
                            .foregroundStyle(M.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(story.article.readTime)
                            .font(NewsType.serif(12, .italic))
                            .foregroundStyle(M.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(story.title), by \(story.brand), \(story.article.readTime)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Newsprint

/// The edition's paper: the app's own near-black, with a whisper of neutral grain so it reads as
/// a printed sheet rather than a screen.
private struct Newsprint: View {
    var body: some View {
        ZStack {
            M.backgroundPrimary
            Canvas { ctx, size in
                var seed: UInt64 = 0x9E3779B97F4A7C15
                func next() -> CGFloat {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat((seed >> 33) % 10_000) / 10_000
                }
                let flecks = Int(size.width * size.height / 140)
                var grain = Path()
                for _ in 0..<flecks {
                    let r = next() * 0.8 + 0.3
                    grain.addEllipse(in: CGRect(x: next() * size.width, y: next() * size.height, width: r, height: r))
                }
                ctx.fill(grain, with: .color(.white.opacity(0.03)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Fits for every plan, as features

/// The occasions set as a run of newspaper features: the illustration, a numbered kicker, a
/// headline written for the occasion, and what to wear as a printed list with dotted leaders.
/// Features alternate a full-width picture with a picture beside the headline.
private struct OccasionFeatures: View {
    @State private var opened: Plan?

    /// A headline for each occasion, keyed by vibe id.
    private let headlines = [
        "diwali": "Dressed for the festival of lights",
        "concert": "Front row, all night",
        "active": "Built to move, made to be seen",
        "brunch": "Slow mornings, easy layers",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            NewspaperSectionHeader(number: 6, title: "Fits for every plan")
            ForEach(Array(Vibe.all.enumerated()), id: \.element.id) { n, vibe in
                if let plan = EditorialData.plans.first(where: { $0.title == vibe.plan }) {
                    if n > 0 { doubleRule }
                    feature(n, vibe: vibe, plan: plan)
                }
            }
        }
        .readerCover(item: $opened) { PlanGalleryView(plan: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }

    private var doubleRule: some View {
        VStack(spacing: 2) {
            Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
            Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
        }
        .padding(.horizontal, R.spacingSpace16)
        .accessibilityHidden(true)
    }

    private func feature(_ n: Int, vibe: Vibe, plan: Plan) -> some View {
        let wide = n.isMultiple(of: 2)
        return VStack(alignment: .leading, spacing: R.spacingSpace12) {
            if wide {
                illustration(vibe, height: 210)
                titleBlock(n, vibe: vibe, plan: plan)
            } else {
                HStack(alignment: .top, spacing: R.spacingSpace12) {
                    illustration(vibe, height: 190)
                        .frame(width: 140)
                    titleBlock(n, vibe: vibe, plan: plan)
                }
            }
            wearList(plan)
            Button { opened = plan } label: {
                HStack(spacing: R.spacingSpace8) {
                    Text("SEE ALL \(plan.count) LOOKS")
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .semibold))
                }
                .font(NewsType.condensed(12))
                .tracking(1.4)
                .foregroundStyle(M.textSecondary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See all \(plan.count) looks for \(plan.title.lowercased())")
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private func illustration(_ vibe: Vibe, height: CGFloat) -> some View {
        ArtView(art: Art(vibe.image, [vibe.ground, vibe.accent]))
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }

    private func titleBlock(_ n: Int, vibe: Vibe, plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            Text("NO. \(n + 1) · \(plan.title.uppercased())")
                .font(NewsType.condensed(11))
                .tracking(1.4)
                .foregroundStyle(M.textTertiary)
            Text(headlines[vibe.id] ?? plan.title)
                .font(NewsType.serif(24, .bold))
                .foregroundStyle(M.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "What to wear", set as a printed list: item, dotted leader, brand.
    private func wearList(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            Text("WHAT TO WEAR")
                .font(NewsType.condensed(11))
                .tracking(1.6)
                .foregroundStyle(M.textSecondary)
            ForEach(Array(plan.looks.prefix(4).enumerated()), id: \.offset) { _, look in
                Button { opened = plan } label: {
                    HStack(alignment: .lastTextBaseline, spacing: R.spacingSpace8) {
                        Text(look.name)
                            .font(.custom("SourceSerif4Roman-Regular", size: 16, relativeTo: .body))
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        DottedLeader()
                        Text(look.brand.uppercased())
                            .font(NewsType.condensed(11))
                            .tracking(1.2)
                            .foregroundStyle(M.textSecondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(look.name), \(look.brand)")
                .accessibilityHint("Opens the \(plan.title.lowercased()) looks")
            }
        }
    }
}

// MARK: - Pick your palette, one picture at a time

/// Palettes as a flat carousel: one photo each, a strip of the palette's colours, its name and a
/// line to shop it. No scaling or fading as cards move.
private struct PaletteSpread: View {
    @State private var opened: Palette?
    private let palettes = EditorialData.palettes

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            NewspaperSectionHeader(number: 7, title: "Pick your palette")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace16) {
                    ForEach(palettes) { palette in
                        Button { opened = palette } label: { card(palette) }
                            .buttonStyle(PressableStyle())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(palette.name) palette, \(palette.looks.count) looks")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
        .readerCover(item: $opened) { PaletteDetailView(palette: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }

    private func card(_ palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            ArtView(art: palette.looks[0])
                .frame(width: 250, height: 320)
                .clipped()
            // The palette as a strip of chips, edge to edge under the photo.
            HStack(spacing: 0) {
                ForEach(palette.hexes.indices, id: \.self) { i in
                    Rectangle().fill(Color(hex: palette.hexes[i]))
                }
            }
            .frame(width: 250, height: 14)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(palette.name)
                    .font(NewsType.serif(22, .bold))
                    .foregroundStyle(M.textPrimary)
                Text("\(palette.looks.count) LOOKS · SHOP THE EDIT")
                    .font(NewsType.condensed(11))
                    .tracking(1.4)
                    .foregroundStyle(M.textSecondary)
            }
        }
        .frame(width: 250, alignment: .leading)
    }
}
