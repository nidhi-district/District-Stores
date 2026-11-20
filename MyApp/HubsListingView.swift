import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Hubs listing (Figma "hub listing new", 14220:31227): the "Worth stepping out for" carousel, then every
/// type of hub, filterable by the category tiles and the vibe chips.
struct HubsListingView: View {
    let zoom: Namespace.ID
    let onBack: () -> Void
    /// Opens a hub, with the hubs to swipe between.
    let openHub: (Hub, [Hub]) -> Void
    /// Opens a hub straight on its floor map, from the card's in-hub navigation tag.
    let openFloorMap: (Hub, [Hub]) -> Void
    /// Opens the hub in the "You're here" card. Separate from `openHub` so the page zooms out of that card, not the same hub's
    /// card further down the list.
    var openHereHub: (Hub) -> Void = { _ in }
    /// The same page inside the Maps tab: no back button, a Map/List switch in its place (`onBack` goes back to the map),
    /// and the list drawn with postcard cards.
    var inMaps = false

    /// The hub you're at, shown first. The variant without in-hub navigation.
    private static let here = HubArrival.sunderNursery
    static func hereSource(_ hub: Hub) -> String { "here-\(hub.id)" }

    /// Nil means "All".
    @State private var type: HubType? = HubsListingView.launchType
    @State private var vibe: String?
    @State private var sort: HubSort = .recommended
    @State private var region = HubsData.regions[0]
    @State private var filtersStuck = false
    @State private var isScrolled = false
    @State private var headerHeight: CGFloat = 62
    @State private var headerBottom: CGFloat = 124
    @State private var lastY: CGFloat = 0
    /// Shared by both copies of the chips, so swapping between them keeps your place.
    @State private var railPosition: String? = "Filters"
    /// The "Worth stepping out for" card whose details sheet is up.
    @State private var openedPick: HubsData.Pick?
    /// Set by the sheet's Explore button; the hub opens once the sheet has gone, so the two transitions don't overlap.
    @State private var exploringHub: Hub?
    @Environment(\.tabBarCompactHandler) private var setTabBarCompact
    @Environment(\.colorScheme) private var colorScheme

    private enum HubSort: String, CaseIterable {
        case recommended = "Recommended", distance = "Distance", name = "Name"
    }

    private func matches(_ hub: Hub, _ vibe: String) -> Bool {
        if vibe == "Under 5kms" { return hub.distanceKm < 5 }
        return hub.vibes.contains(vibe)
    }

    /// Hubs in the chosen city come first; the rest stay available below, so every type of hub is always reachable.
    private var hubs: [Hub] {
        let all = filtered
        return all.filter { $0.region == region } + all.filter { $0.region != region }
    }

    private var firstElsewhere: String? { hubs.first { $0.region != region }?.id }

    private var filtered: [Hub] {
        var result = HubsData.hubs
        if let type { result = result.filter { $0.type == type } }
        if let vibe { result = result.filter { matches($0, vibe) } }
        switch sort {
        case .recommended: break
        case .distance: result.sort { $0.distanceKm < $1.distanceKm }
        case .name: result.sort { $0.name < $1.name }
        }
        return result
    }

    /// The kids rail sits after the fifth hub of the unfiltered list.
    private var showsKidsRail: Bool { type == nil && vibe == nil && sort == .recommended && region == HubsData.regions[0] }

    /// Debug builds accept `-hubsType <HubType>` to open on a category.
    private static var launchType: HubType? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-hubsType"), i + 1 < args.count { return HubType(rawValue: args[i + 1]) }
        #endif
        return nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            scrollView
                .task {
                    #if DEBUG
                    // `-hubsScroll explore|kids|end` opens the page further down.
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-hubsScroll"), i + 1 < args.count {
                        try? await Task.sleep(for: .milliseconds(400))
                        proxy.scrollTo(args[i + 1], anchor: .top)
                    }
                    #endif
                }
        }
        .sheet(item: $openedPick, onDismiss: {
            guard let hub = exploringHub else { return }
            exploringHub = nil
            openHub(hub, HubsData.hubs)
        }) { pick in
            HubPickSheet(pick: pick) { hub in
                exploringHub = hub
                openedPick = nil
            }
        }
        #if DEBUG
        // `-hubsPick <index>` opens on a card's details sheet.
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-hubsPick"), i + 1 < args.count, let n = Int(args[i + 1]), HubsData.picks.indices.contains(n) {
                try? await Task.sleep(for: .milliseconds(500))
                openedPick = HubsData.picks[n]
            }
        }
        #endif
    }

    private var scrollView: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: R.spacingSpace0) {
                heading("You’re here")
                    .padding(.top, R.spacingSpace24)
                HubHereCard(arrival: Self.here, onOpen: { openHereHub(Self.here.hub) })
                    .zoomSource(id: Self.hereSource(Self.here.hub), in: zoom)
                    .padding(.horizontal, R.spacingSpace16)
                    .padding(.top, R.spacingSpace16)

                heading("Worth stepping out for")
                    .padding(.top, R.spacingSpace32)
                HubPicksCarousel { openedPick = $0 }
                .padding(.top, R.spacingSpace16)

                heading("Explore hubs")
                    .padding(.top, R.spacingSpace24)
                    .id("explore")
                categoryTiles
                    .padding(.top, 18)

                // Tells the header when the chips below have reached it.
                Color.clear
                    .frame(height: 0)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("hubsPage")).minY } action: { y in
                        let stuck = y <= headerBottom + 1
                        if stuck != filtersStuck { filtersStuck = stuck }
                    }

                // Stays in the page at rest so a vertical drag on it still scrolls; the header takes over once it reaches the top.
                filterRail(glass: false)
                    .opacity(filtersStuck ? 0 : 1)
                list
                    .padding(.top, 10)
                Color.clear.frame(height: 1).id("end")
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .modifier(ExploreScrollTracker { y in
            // Same rule as the Stores bar: shrink reading down, grow on the way back up or near the top.
            let delta = y - lastY
            if y > -40 { setTabBarCompact(false) }
            else if delta < -6 { setTabBarCompact(true) }
            else if delta > 6 { setTabBarCompact(false) }
            lastY = y
            let scrolled = y < -1
            if scrolled != isScrolled { isScrolled = scrolled }
        })
        // The header floats over the page; this only reserves its space, so showing the chips in it never shifts the content.
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: headerHeight) }
        .overlay(alignment: .top) { floatingHeader }
        // Home's indigo at the top, on the dark page only: the light listing (Figma "hub listing new", Light) has a plain top.
        .background(alignment: .top) { if colorScheme == .dark { DistrictTopWash() } }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .coordinateSpace(name: "hubsPage")
    }

    // MARK: Header

    private var floatingHeader: some View {
        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("hubsPage")).maxY } action: { headerBottom = $0 }
            if filtersStuck { filterRail(glass: true) }
        }
        .background(alignment: .top) {
            HubProgressiveBlur()
                // Runs a little past the content, where the blur tapers away to nothing.
                .padding(.bottom, -36)
                .ignoresSafeArea(edges: .top)
                .opacity(isScrolled ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: isScrolled)
                .allowsHitTesting(false)
        }
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            if !inMaps {
                Button(action: onBack) {
                    // hub_ic_back, drawn with tokens so it follows light and dark mode: a faint disc, a hairline and the arrow.
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 38, height: 38)
                        .background(M.surfaceTransparent, in: Circle())
                        .overlay(Circle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            Menu {
                Picker("Location", selection: $region.animation(.snappy(duration: 0.25))) {
                    ForEach(HubsData.regions, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: R.spacingSpace4) {
                        Text("Hubs in \(region)")
                            .backstageText(.hubTitle2)
                            .foregroundStyle(M.textPrimary)
                            .contentTransition(.opacity)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(M.iconPrimary)
                    }
                    Text("Malls, high streets, markets and more")
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Location, \(region)")
            .accessibilityHint("Changes the city")
            Spacer(minLength: 0)
            if inMaps {
                MapsViewSwitch(showsList: true) { if !$0 { onBack() } }
            }
        }
        .padding(.leading, inMaps ? R.spacingSpace16 : 13)
        .padding(.trailing, R.spacingSpace16)
        .padding(.vertical, 9)
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .backstageText(.hubTitle2)
            .foregroundStyle(M.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, R.spacingSpace16)
    }

    // MARK: Category tiles

    private var categoryTiles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace12) {
                HubCategoryTile(title: "All", art: "hub_cat_all", emoji: "", artSize: 45, selected: type == nil) {
                    setType(nil)
                }
                ForEach(HubType.allCases) { item in
                    HubCategoryTile(title: item.title, art: item.art, emoji: item.emoji, artSize: item.artSize,
                                    selected: type == item) {
                        setType(item)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func setType(_ value: HubType?) {
        withAnimation(.snappy(duration: 0.25)) { type = value }
    }

    // MARK: Filters

    private func filterRail(glass: Bool) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(HubSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HubFiltersChipLabel(glass: glass)
                }
                .accessibilityLabel("Filters")
                .id("Filters")

                ForEach(HubsData.vibes, id: \.self) { item in
                    Button(item) {
                        withAnimation(.snappy(duration: 0.25)) { vibe = vibe == item ? nil : item }
                    }
                    .buttonStyle(BackstageFilterButtonStyle(isActive: vibe == item, compact: true, glass: glass))
                    .accessibilityAddTraits(vibe == item ? .isSelected : [])
                    .id(item)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $railPosition, anchor: .leading)
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: vibe)
    }

    // MARK: List

    private var list: some View {
        LazyVStack(spacing: inMaps ? R.spacingSpace16 : R.spacingSpace24) {
            if hubs.isEmpty {
                Text("No hubs match this filter yet")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, R.spacingSpace40)
            }
            ForEach(Array(hubs.enumerated()), id: \.element.id) { index, hub in
                if hub.id == firstElsewhere {
                    heading(index == 0 ? "No matches in \(region), but across India" : "More across India")
                }
                // Not a Button: its tags scroll sideways, and a scroll view inside a button fights the press.
                Group {
                    if inMaps {
                        HubPostcard(hub: hub, onNavigate: { openFloorMap(hub, hubs) }) { openHub(hub, hubs) }
                    } else {
                        HubCard(hub: hub, onNavigate: { openFloorMap(hub, hubs) }) { openHub(hub, hubs) }
                    }
                }
                .zoomSource(id: hub.id, in: zoom)
                .padding(.horizontal, R.spacingSpace16)

                if showsKidsRail && index == 4 {
                    HubKidsRail().id("kids")
                }
            }
        }
    }
}

// MARK: - Carousel

/// Centre card at 290×300, neighbours settling to 232×240 at 40%.
private struct HubPicksCarousel: View {
    let onSelect: (HubsData.Pick) -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: R.spacingSpace16) {
            PeekCarousel(items: HubsData.picks, cardWidth: 290, cardHeight: 300, gap: 16, page: $page) { pick in
                Button { onSelect(pick) } label: { HubPickCard(pick: pick) }
                    .buttonStyle(.plain)
            }
            CarouselDots(count: HubsData.picks.count, page: page)
        }
    }
}

private struct HubPickCard: View {
    let pick: HubsData.Pick

    var body: some View {
        ZStack(alignment: .topLeading) {
            M.backgroundPrimary
            Color.clear
                .frame(height: 223)
                .overlay { Image(pick.image).resizable().scaledToFill() }
                .clipped()
            HubBlurredReflection(image: pick.image, top: 176, height: 134, blur: 18)
            // Anchored to the bottom, so one line or three, the copy keeps the same 16pt margin inside the card.
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(pick.title)
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text("\(pick.hub), Gurugram")
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
                Text(pick.line)
                    .font(.custom("BeVietnamPro-Italic", size: 12, relativeTo: .subheadline))
                    .foregroundStyle(M.textPrimary.opacity(0.8))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(R.spacingSpace16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: 290, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderIntense.opacity(0.66), lineWidth: R.stroke1Px))
    }
}

/// The card's own photo, flipped and blurred, fading the image into the text area below it.
/// It overflows the card on purpose, so it's drawn as an overlay and never widens the card's layout.
struct HubBlurredReflection: View {
    let image: String
    let top: CGFloat
    let height: CGFloat
    let blur: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .frame(height: height)
            .overlay {
                ZStack {
                    Image(image).resizable().scaledToFill().rotationEffect(.degrees(180))
                    // Washed in the page's own colour, so the copy on it reads in both modes; a touch stronger on the light
                    // page, where the copy is dark.
                    M.backgroundPrimary.opacity(colorScheme == .dark ? 0.62 : 0.74)
                }
                .frame(width: 507, height: height)
                .clipped()
                .blur(radius: blur)
            }
            .offset(y: top)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

// MARK: - Category tile

/// Figma 14300:101282. The fill and the selected border are both gradients, faintest at the top and brightest towards the bottom.
/// Both are measured from the rendered Figma frame. The one departure: Figma's fill is fully clear at the top, and here it keeps
/// a faint 4% so the tile's top edge stays visible and the art reads as sitting inside the box.
private struct HubCategoryTile: View {
    let title: String
    let art: String?
    let emoji: String
    let artSize: CGFloat
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// The dark page's gradient, or on the light page a plain white tile with a hairline (Figma "hub listing new", Light).
    @ViewBuilder private var ground: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).fill(Self.fill)
        } else {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).fill(M.surfacePrimary)
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
    }

    private static let fill = LinearGradient(stops: [.init(color: .white.opacity(0.04), location: 0),
                                                     .init(color: .white.opacity(0.05), location: 0.35),
                                                     .init(color: .white.opacity(0.1), location: 0.62),
                                                     .init(color: .white.opacity(0.11), location: 0.78),
                                                     .init(color: .white.opacity(0.1), location: 1)],
                                             startPoint: .top, endPoint: .bottom)
    private static let border = LinearGradient(stops: [.init(color: M.textPrimary.opacity(0.08), location: 0),
                                                       .init(color: M.textPrimary.opacity(0.69), location: 0.75),
                                                       .init(color: M.textPrimary.opacity(0.8), location: 1)],
                                               startPoint: .top, endPoint: .bottom)

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                ground
                Group {
                    if let art {
                        Image(art).resizable().scaledToFit()
                            .frame(width: artSize, height: artSize)
                    } else {
                        Text(emoji)
                            .font(.system(size: artSize))
                    }
                }
                // Centred in the space above the label. With `artSize`, this keeps the visible art inside the tile.
                .frame(height: 51)
                Text(title)
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 7)
                if selected {
                    RoundedRectangle(cornerRadius: R.cornerRadiusCorner12)
                        .strokeBorder(Self.border, lineWidth: R.stroke1Px)
                }
            }
            .frame(width: 75, height: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// iOS-style progressive blur: stacked materials, each masked to fade out sooner, so the blur is strongest at the top and
/// tapers to nothing with no visible edge. System materials only; true variable blur is a private API.
private struct HubProgressiveBlur: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            layer(.ultraThinMaterial, until: 1)
            layer(.ultraThinMaterial, until: 0.82)
            layer(.thinMaterial, until: 0.62)
            // A base in the page's colour keeps the header's text readable over bright photos, then, on the dark page, the same
            // indigo as the top of Home.
            LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0.5), location: 0),
                                   .init(color: M.backgroundPrimary.opacity(0.3), location: 0.6),
                                   .init(color: M.backgroundPrimary.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            if colorScheme == .dark {
                LinearGradient(stops: [.init(color: M.districtWash.opacity(0.3), location: 0),
                                       .init(color: M.districtWash.opacity(0.14), location: 0.6),
                                       .init(color: M.districtWash.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .accessibilityHidden(true)
    }

    private func layer(_ material: Material, until end: CGFloat) -> some View {
        Rectangle()
            .fill(material)
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: end * 0.6),
                                       .init(color: .clear, location: end)],
                               startPoint: .top, endPoint: .bottom)
            }
    }
}

/// The leading "Filters" chip: sliders icon, label and chevron, sized like every other chip.
struct HubFiltersChipLabel: View {
    var glass = false

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Image("hub_ic_filter")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(M.iconSecondary)
                .frame(width: 16, height: 16)
            Text("Filters")
                .backstageText(.label2)
                .foregroundStyle(M.textPrimary)
            Image("hub_ic_chev16")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(M.iconSecondary)
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, R.spacingSpace12)
        .frame(height: 32)
        .chipSurface(glass: glass)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Hub card

/// A listing card (Figma 14220:31411): photo fading through its own blurred reflection into the copy.
struct HubCard: View {
    let hub: Hub
    /// Opens the hub on its floor map. Only reachable on hubs with in-hub navigation.
    let onNavigate: () -> Void
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            M.backgroundPrimary
            Color.clear
                .frame(height: 203)
                .overlay(alignment: hub.imageAlignment) {
                    Image(hub.image).resizable().scaledToFill()
                }
                .clipped()
            // hub_card_overlay, rebuilt in the page's colour so it fades the photo into either mode: the same stops, measured from
            // the PNG, which was background/primary (dark) fading in from halfway down.
            LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0), location: 0.47),
                                   .init(color: M.backgroundPrimary.opacity(0.09), location: 0.5),
                                   .init(color: M.backgroundPrimary.opacity(0.33), location: 0.6),
                                   .init(color: M.backgroundPrimary.opacity(0.57), location: 0.7),
                                   .init(color: M.backgroundPrimary.opacity(0.78), location: 0.8),
                                   .init(color: M.backgroundPrimary.opacity(0.91), location: 0.9),
                                   .init(color: M.backgroundPrimary, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 205)
                .accessibilityHidden(true)
            HubBlurredReflection(image: hub.image, top: 162, height: 178, blur: 30)
            HStack(spacing: 6) {
                distancePill
                if hub.hasFindInHub { indoorMapTag }
            }
            .padding(R.spacingSpace12)
            copy
                .padding(.top, 138)
                .padding(.bottom, R.spacingSpace16)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hub.name), \(hub.type.title), rated \(hub.googleRating), \(hub.distance) away, \(hub.locality)."
                            + (hub.hasFindInHub ? " Has in-hub navigation." : "") + " \(hub.blurb)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
        .accessibilityActions {
            if hub.hasFindInHub { Button("Navigate in hub", action: onNavigate) }
        }
    }

    private static let tagReach: CGFloat = 9

    /// Paired with the distance: how far the hub is, then that you can find your way once inside. Dark glass against the
    /// distance's solid white, so it reads as a feature rather than another fact, with the photo showing through. District purple
    /// is kept to the edge; the route lights up from dim to full white as the dot travels.
    /// Tapping it skips the page and lands on the floor map.
    private var indoorMapTag: some View {
        Button(action: onNavigate) {
            HStack(spacing: R.spacingSpace4) {
                HubIndoorMapIcon(size: 14, ink: M.hubPureWhite, accent: M.hubPureWhite)
                Text("Navigate in hub")
                    .backstageText(.label3)
                    .foregroundStyle(M.hubPureWhite)
            }
            .padding(.leading, 6)
            .padding(.trailing, R.spacingSpace8)
            .padding(.vertical, 6)
            // Frosted dark glass, with a soft purple light along the top edge.
            .background(Color.black.opacity(0.32), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [M.hubTextNew.opacity(0.85), M.hubTextNew.opacity(0.3)],
                                                           startPoint: .top, endPoint: .bottom),
                                            lineWidth: R.stroke1Px))
            .environment(\.colorScheme, .dark)
            // A tall enough target for a small pill, without making the row taller: the pills sit 12pt from the top on every card.
            .padding(.vertical, Self.tagReach)
            .contentShape(Rectangle())
            .padding(.vertical, -Self.tagReach)
        }
        .buttonStyle(PressableStyle())
    }

    private var distancePill: some View {
        HStack(spacing: R.spacingSpace4) {
            Image("hub_ic_distance")
                .resizable()
                .frame(width: 8, height: 10)
            Text(hub.distance)
                .backstageText(.label3)
                .foregroundStyle(Color(hex: 0x2D2724))
        }
        .padding(.leading, 6)
        .padding(.trailing, R.spacingSpace8)
        .padding(.vertical, 6)
        .background(M.surfaceInverse, in: Capsule())
        // It sits on the photo, so it's the same light pill in both modes.
        .environment(\.colorScheme, .dark)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hub.name)
                    .backstageText(.hubTitle2)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                googleLine(hub.googleRating)
            }
            .padding(.horizontal, R.spacingSpace16)
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text(hub.blurb)
                    .backstageText(.body3)
                    .foregroundStyle(M.textPrimary.opacity(0.76))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, R.spacingSpace16)
                HubTagRows(tags: hub.chips)
            }
        }
    }

    /// Star, score, Google mark and locality.
    private func googleLine(_ rating: String) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image("hub_ic_star_white")
                    .resizable()
                    .frame(width: 10, height: 10)
                Text(rating)
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
            }
            Rectangle()
                .fill(M.borderIntense)
                .frame(width: R.stroke1Px, height: 10)
            Image("hub_logo_google")
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(M.textPrimary)
                .scaledToFit()
                .frame(width: 32, height: 11)
            Circle()
                .fill(M.textTertiary)
                .frame(width: 3, height: 3)
            Text(hub.locality)
                .backstageText(.label3)
                .foregroundStyle(M.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Indoor map icon

/// The route icon (hub_ic_route, lucide "route") redrawn from its SVG path so it can move. A dot leaves the start ring and
/// lights the route in the accent behind it; when it reaches the destination, that ring fills and sends out one pulse. The route
/// rests lit for a beat, fades, and goes again. With Reduce Motion it's the lit route, still.
struct HubIndoorMapIcon: View {
    var size: CGFloat = 14
    let ink: Color
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    fileprivate struct Phase {
        /// How much of the route is lit, 0 to 1.
        var trace: CGFloat
        /// The lit route, dot and destination, faded in and out around each trip so the loop never jumps.
        var shown: Double
        /// The arrival, 0 to 1: the destination fills at the start of it and its pulse spreads out over it.
        var arrive: CGFloat
    }

    var body: some View {
        Group {
            if reduceMotion {
                glyph(Phase(trace: 1, shown: 1, arrive: 1))
            } else {
                // Read off one shared clock, so every tag on screen moves together rather than each on its own beat.
                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    glyph(Self.phase(at: timeline.date.timeIntervalSinceReferenceDate))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// A 3.2s loop: the dot fades in on the start ring and waits, makes the trip, rests on arrival, then everything fades.
    private static func phase(at time: TimeInterval) -> Phase {
        let t = time.truncatingRemainder(dividingBy: 3.2)
        func progress(_ from: Double, _ length: Double) -> Double { min(max((t - from) / length, 0), 1) }
        let trip = progress(0.4, 1.3)
        let landing = progress(1.7, 0.8)
        let fadeOut = progress(2.75, 0.35)
        return Phase(trace: trip < 0.5 ? 2 * trip * trip : 1 - pow(-2 * trip + 2, 2) / 2,   // ease in-out
                     shown: progress(0, 0.3) * (1 - fadeOut * fadeOut),                     // ease in on the way out
                     arrive: 1 - (1 - landing) * (1 - landing))                              // ease out
    }

    // The SVG's geometry, in its 22×22 box.
    private static let start = CGPoint(x: 5.5, y: 17.4167)
    private static let end = CGPoint(x: 16.5, y: 4.5833)
    private static let radius: CGFloat = 2.75
    private static let bleed: CGFloat = 4

    private static var route: Path {
        var path = Path()
        path.move(to: CGPoint(x: 8.25, y: 17.4167))
        path.addLine(to: CGPoint(x: 16.0417, y: 17.4167))
        path.addCurve(to: CGPoint(x: 18.3103, y: 16.477), control1: CGPoint(x: 16.8926, y: 17.4167), control2: CGPoint(x: 17.7086, y: 17.0786))
        path.addCurve(to: CGPoint(x: 19.25, y: 14.2083), control1: CGPoint(x: 18.912, y: 15.8753), control2: CGPoint(x: 19.25, y: 15.0592))
        path.addCurve(to: CGPoint(x: 18.3103, y: 11.9397), control1: CGPoint(x: 19.25, y: 13.3574), control2: CGPoint(x: 18.912, y: 12.5414))
        path.addCurve(to: CGPoint(x: 16.0417, y: 11), control1: CGPoint(x: 17.7086, y: 11.338), control2: CGPoint(x: 16.8926, y: 11))
        path.addLine(to: CGPoint(x: 5.95833, y: 11))
        path.addCurve(to: CGPoint(x: 3.6897, y: 10.0603), control1: CGPoint(x: 5.10743, y: 11), control2: CGPoint(x: 4.29138, y: 10.662))
        path.addCurve(to: CGPoint(x: 2.75, y: 7.79167), control1: CGPoint(x: 3.08802, y: 9.45862), control2: CGPoint(x: 2.75, y: 8.64257))
        path.addCurve(to: CGPoint(x: 3.6897, y: 5.52303), control1: CGPoint(x: 2.75, y: 6.94076), control2: CGPoint(x: 3.08802, y: 6.12471))
        path.addCurve(to: CGPoint(x: 5.95833, y: 4.58333), control1: CGPoint(x: 4.29138, y: 4.92135), control2: CGPoint(x: 5.10743, y: 4.58333))
        path.addLine(to: CGPoint(x: 13.75, y: 4.58333))
        return path
    }

    private static func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    private func glyph(_ p: Phase) -> some View {
        Canvas { context, canvas in
            // The canvas runs 4 units past the icon on every side, so the arrival pulse can spread without being cut off.
            context.scaleBy(x: canvas.width / (22 + Self.bleed * 2), y: canvas.height / (22 + Self.bleed * 2))
            context.translateBy(x: Self.bleed, y: Self.bleed)
            // A touch heavier than the SVG's 1.5, which goes hairline at this size.
            let line = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            let route = Self.route

            // The way, faint, so you can see where it's headed.
            context.stroke(route, with: .color(ink.opacity(0.3)), style: line)
            context.stroke(Self.circle(Self.end, Self.radius), with: .color(ink.opacity(0.3)), style: line)
            context.stroke(Self.circle(Self.start, Self.radius), with: .color(ink), style: line)

            let lit = route.trimmedPath(from: 0, to: p.trace)
            if p.trace > 0 {
                context.stroke(lit, with: .color(accent.opacity(p.shown)), style: line)
            }
            // The dot leads the line until it arrives.
            if p.trace < 1 {
                let head = p.trace > 0 ? (lit.currentPoint ?? Self.start) : CGPoint(x: 8.25, y: 17.4167)
                context.fill(Self.circle(head, 2.2), with: .color(accent.opacity(p.shown)))
            }
            if p.arrive > 0 {
                let filled = min(p.arrive * 4, 1) * p.shown
                context.fill(Self.circle(Self.end, Self.radius + 1), with: .color(accent.opacity(filled)))
                let pulse = Self.circle(Self.end, Self.radius + 1 + 3.5 * p.arrive)
                context.stroke(pulse, with: .color(accent.opacity((1 - p.arrive) * 0.7 * p.shown)), lineWidth: 1.2)
            }
        }
        .padding(-size * Self.bleed / 22)
        .allowsHitTesting(false)
    }
}

/// A hub's tags as two rows that scroll sideways together. The rows start on the card's text margin and fade at the card's
/// edges, so a tag running off reads as "there's more" rather than as something cut off.
struct HubTagRows: View {
    let tags: [String]
    /// Side inset of the rows inside their scroll view.
    var margin: CGFloat = R.spacingSpace16

    private var rows: ([String], [String]) {
        var top: [String] = [], bottom: [String] = []
        for (index, tag) in tags.enumerated() {
            if index % 2 == 0 { top.append(tag) } else { bottom.append(tag) }
        }
        return (top, bottom)
    }

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 6) {
                row(rows.0)
                row(rows.1)
            }
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.035),
                                   .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
    }

    private func row(_ tags: [String]) -> some View {
        HStack(spacing: R.spacingSpace8) {
            ForEach(tags, id: \.self) { tag in
                HubTagPill(text: tag)
            }
        }
    }
}

// MARK: - Kids rail

/// "Perfect for Kid's day out" (Figma 14220:31747).
private struct HubKidsRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Perfect for Kid’s day out")
                .backstageText(.title3)
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace24) {
                    ForEach(HubsData.kidSpots) { spot in
                        VStack(alignment: .leading, spacing: R.spacingSpace8) {
                            Color.clear
                                .frame(width: 132, height: 125)
                                .overlay { Image(spot.image).resizable().scaledToFill() }
                                .clipShape(RoundedRectangle(cornerRadius: 13.4))
                            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                                Text(spot.name)
                                    .backstageText(.title4)
                                    .foregroundStyle(M.textPrimary)
                                    .lineLimit(1)
                                Text(spot.line)
                                    .backstageText(.label3)
                                    .foregroundStyle(M.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 132, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
        .padding(.top, R.spacingSpace24)
        .padding(.bottom, R.spacingSpace20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [M.surfaceSecondary.opacity(0.2), M.surfaceSecondary.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                Image("hub_rail_glow")
                    .resizable()
                    .frame(height: 219)
                    .offset(y: 54)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .clipped()
        }
    }
}
