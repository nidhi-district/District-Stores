import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Hubs listing (Figma "hub listing new", 14220:31227): the "Worth stepping out for" carousel, then every
/// type of hub, filterable by the category tiles and the vibe chips.
struct HubsListingView: View {
    let zoom: Namespace.ID
    let onBack: () -> Void
    let openHub: (Hub) -> Void

    /// Nil means "All".
    @State private var type: HubType? = HubsListingView.launchType
    @State private var vibe: String?
    @State private var sort: HubSort = .recommended

    private enum HubSort: String, CaseIterable {
        case recommended = "Recommended", distance = "Distance", name = "Name"
    }

    private var hubs: [Hub] {
        var result = HubsData.hubs
        if let type { result = result.filter { $0.type == type } }
        if let vibe { result = result.filter { $0.vibes.contains(vibe) } }
        switch sort {
        case .recommended: break
        case .distance: result.sort { $0.distanceKm < $1.distanceKm }
        case .name: result.sort { $0.name < $1.name }
        }
        return result
    }

    /// The kids rail sits after the fifth hub of the unfiltered list.
    private var showsKidsRail: Bool { type == nil && vibe == nil && sort == .recommended }

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
    }

    private var scrollView: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                heading("Worth stepping out for")
                    .padding(.top, R.spacingSpace12)
                HubPicksCarousel { pick in
                    if let hub = HubsData.hub(named: pick.hub) { openHub(hub) }
                }
                .padding(.top, R.spacingSpace16)

                heading("Explore hubs")
                    .padding(.top, R.spacingSpace24)
                    .id("explore")
                categoryTiles
                    .padding(.top, 18)
                filterRail
                    .padding(.top, 10)
                list
                    .padding(.top, 10)
                Color.clear.frame(height: 1).id("end")
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(alignment: .top) { topGlow }
        .background(M.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            Button(action: onBack) {
                Image("hub_ic_back")
                    .resizable()
                    .frame(width: 38, height: 38)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text("Hubs in Delhi NCR")
                    .backstageText(.hubTitle2)
                    .foregroundStyle(M.hubPureWhite)
                Text("Malls, high streets, markets and more")
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 13)
        .padding(.trailing, R.spacingSpace16)
        .padding(.vertical, 9)
        .background {
            // Solid behind the title so scrolling content never collides with it, with a short fade below.
            LinearGradient(stops: [.init(color: M.backgroundPrimary, location: 0),
                                   .init(color: M.backgroundPrimary, location: 0.86),
                                   .init(color: M.backgroundPrimary.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -16)
                .ignoresSafeArea(edges: .top)
        }
    }

    /// Figma "Ellipse 12315": a faint white column of light behind the carousel.
    private var topGlow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: 370))
            .frame(width: 440, height: 742)
            .offset(y: -40)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
                HubCategoryTile(title: "All", art: "hub_cat_all", emoji: "", artSize: 49, selected: type == nil) {
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

    private var filterRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(HubSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HubFiltersChipLabel(prominent: true)
                }
                .accessibilityLabel("Filters")

                ForEach(HubsData.vibes, id: \.self) { item in
                    Button(item) {
                        withAnimation(.snappy(duration: 0.25)) { vibe = vibe == item ? nil : item }
                    }
                    .buttonStyle(BackstageFilterButtonStyle(isActive: vibe == item, compact: true))
                    .accessibilityAddTraits(vibe == item ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: vibe)
    }

    // MARK: List

    private var list: some View {
        LazyVStack(spacing: R.spacingSpace16) {
            if hubs.isEmpty {
                Text("No hubs match this filter yet")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, R.spacingSpace40)
            }
            ForEach(Array(hubs.enumerated()), id: \.element.id) { index, hub in
                Button { openHub(hub) } label: {
                    HubCard(hub: hub)
                }
                .buttonStyle(PressableStyle())
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

/// Centre card at 290×300, neighbours settling to 232×240 at 40%. The cards loop, so there's always one to peek on each side.
private struct HubPicksCarousel: View {
    let onSelect: (HubsData.Pick) -> Void

    private static let picks = HubsData.picks
    private static let loops = 40
    @State private var position: Int? = picks.count * loops / 2

    private var page: Int { (position ?? 0) % Self.picks.count }

    var body: some View {
        VStack(spacing: R.spacingSpace16) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: -13) {
                    ForEach(0..<Self.picks.count * Self.loops, id: \.self) { index in
                        let pick = Self.picks[index % Self.picks.count]
                        Button { onSelect(pick) } label: {
                            HubPickCard(pick: pick)
                        }
                        .buttonStyle(.plain)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                .opacity(phase.isIdentity ? 1 : 0.4)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: 300)
            .contentMargins(.horizontal, 42.5, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $position, anchor: .center)
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: page)

            dots
        }
    }

    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(Self.picks.indices, id: \.self) { index in
                Capsule()
                    .fill(Color(hex: 0xFAFAFA).opacity(index == page ? 1 : 0.32))
                    .frame(width: index == page ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.25), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(page + 1) of \(Self.picks.count)")
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
            HubBlurredReflection(image: pick.image, top: 181, height: 129, blur: 18)
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(pick.title)
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text("\(pick.hub), Gurugram")
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                }
                Text(pick.line)
                    .font(.custom("BeVietnamPro-Italic", size: 12, relativeTo: .subheadline))
                    .lineSpacing(3)
                    .foregroundStyle(M.textPrimary.opacity(0.8))
                    .lineLimit(3)
            }
            .padding(.horizontal, 15)
            .padding(.top, 203)
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

    var body: some View {
        Color.clear
            .frame(height: height)
            .overlay {
                ZStack {
                    Image(image).resizable().scaledToFill().rotationEffect(.degrees(180))
                    Color.black.opacity(0.62)
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

private struct HubCategoryTile: View {
    let title: String
    let art: String?
    let emoji: String
    let artSize: CGFloat
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: R.cornerRadiusCorner12)
                    .fill(LinearGradient(stops: [.init(color: M.surfacePrimary, location: 0.09),
                                                 .init(color: Color(rgba: 0x8E8E9400), location: 0.77)],
                                         startPoint: .bottom, endPoint: .top))
                Group {
                    if let art {
                        Image(art).resizable().scaledToFit()
                            .frame(width: artSize, height: artSize)
                    } else {
                        Text(emoji)
                            .font(.system(size: artSize))
                            .frame(height: 46)
                    }
                }
                .offset(y: -4)
                Text(title)
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 7)
            }
            .frame(width: 75, height: 70)
            .opacity(selected ? 1 : 0.8)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: R.cornerRadiusCorner12)
                        .strokeBorder(M.textPrimary, lineWidth: R.stroke1Px)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The leading "Filters" chip: sliders icon, label and chevron.
struct HubFiltersChipLabel: View {
    /// The listing sets its label in the primary colour; the lists inside a hub use secondary.
    var prominent = false

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Image("hub_ic_filter")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text("Filters")
                .backstageText(.label2)
                .foregroundStyle(prominent ? M.textPrimary : M.textSecondary)
            Image("hub_ic_chev16")
                .resizable()
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, R.spacingSpace8)
        .frame(height: 32)
        .background(Color(rgba: 0x1C1C22B3), in: Capsule())
        .overlay(Capsule().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Hub card

/// A listing card (Figma 14220:31411): photo fading through its own blurred reflection into the copy.
struct HubCard: View {
    let hub: Hub

    var body: some View {
        ZStack(alignment: .topLeading) {
            M.backgroundPrimary
            Color.clear
                .frame(height: 203)
                .overlay(alignment: hub.imageAlignment) {
                    Image(hub.image).resizable().scaledToFill()
                }
                .clipped()
            Image("hub_card_overlay")
                .resizable()
                .frame(height: 205)
                .accessibilityHidden(true)
            HubBlurredReflection(image: hub.image, top: 162, height: 178, blur: 30)
            distancePill
                .padding(.leading, 12)
                .padding(.top, 14)
            copy
                .padding(.horizontal, 15)
                .padding(.top, hub.googleRating == nil ? 141 : 138)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 313, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hub.name), \(hub.type.title), \(hub.distance) away, \(hub.locality). \(hub.blurb)")
        .accessibilityAddTraits(.isButton)
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
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hub.name)
                    .backstageText(.hubTitle2)
                    .foregroundStyle(M.hubPureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let rating = hub.googleRating {
                    googleLine(rating)
                } else {
                    Text(hub.locality)
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text(hub.blurb)
                    .backstageText(.body3)
                    .foregroundStyle(M.textPrimary.opacity(0.76))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                EditFlowLayout(spacing: R.spacingSpace8, rowSpacing: R.spacingSpace8) {
                    ForEach(hub.chips, id: \.self) { chip in
                        Text(chip)
                            .backstageText(.label3)
                            .foregroundStyle(M.textPrimary.opacity(0.8))
                            .lineLimit(1)
                            .padding(.horizontal, R.spacingSpace8)
                            .frame(height: 26)
                            .background(M.hubSurfaceChip, in: Capsule())
                            .opacity(0.9)
                    }
                }
            }
        }
    }

    /// Rated hubs swap the plain locality for star, score, Google mark and locality.
    private func googleLine(_ rating: String) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Image("hub_ic_star_white")
                    .resizable()
                    .frame(width: 10, height: 10)
                Text(rating)
                    .backstageText(.label3)
                    .foregroundStyle(M.hubPureWhite)
            }
            Rectangle()
                .fill(M.borderIntense)
                .frame(width: R.stroke1Px, height: 10)
            Image("hub_logo_google")
                .resizable()
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

// MARK: - Kids rail

/// "Perfect for Kid's day out" (Figma 14220:31747).
private struct HubKidsRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Perfect for Kid’s day out")
                .backstageText(.title3)
                .foregroundStyle(M.hubPureWhite)
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
