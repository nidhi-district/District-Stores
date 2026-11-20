import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Info sheets

/// Bottom sheets on the hub page: the address (14234:97271), opening hours (14234:97341) and facilities (14234:97860).
enum HubInfoSheet: String, Identifiable {
    case address, hours, facilities
    var id: String { rawValue }

    var title: String {
        switch self {
        case .address: "Address"
        case .hours: "Opening Hours"
        case .facilities: "Facilities"
        }
    }

    var height: CGFloat {
        switch self {
        case .address: 288
        case .hours: 362
        case .facilities: 524
        }
    }
}

struct HubInfoSheetView: View {
    let kind: HubInfoSheet
    let hub: Hub
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch kind {
            case .address: address
            case .hours: hours
            case .facilities: facilities
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(kind.height)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(R.cornerRadiusCorner16)
        .presentationBackground(M.backgroundSecondary)
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            Text(kind.title)
                .backstageText(.hubTitle2)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image("hub_ic_close")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -12)
            .accessibilityLabel("Close")
        }
        .padding(.top, 14)
        .padding(.bottom, 6)
        .padding(.horizontal, R.spacingSpace16)
    }

    private var address: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(hub.name)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                Text("\(hub.detailDistance.replacingOccurrences(of: "km", with: " km")) away")
                    .backstageText(.hubBody2)
                    .foregroundStyle(M.textPrimary.opacity(0.5))
                    .padding(.bottom, R.spacingSpace4)
                Text(hub.address)
                    .backstageText(.body3)
                    .foregroundStyle(M.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(R.spacingSpace16)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                Button { openDirections() } label: {
                    HStack(spacing: R.spacingSpace4) {
                        Text("Get direction")
                            .backstageText(.label1)
                        Image("hub_ic_open")
                            .resizable()
                            .frame(width: 21, height: 21)
                    }
                    .foregroundStyle(M.buttonPrimaryLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(M.textPrimary, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace16)
                .padding(.bottom, R.spacingSpace40)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func openDirections() {
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [URLQueryItem(name: "q", value: "\(hub.name), \(hub.locality)")]
        if let url = parts?.url { openURL(url) }
    }

    private var hours: some View {
        VStack(spacing: R.spacingSpace16) {
            ForEach(HubsData.hours) { row in
                HStack {
                    Text(row.day)
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                    Spacer(minLength: R.spacingSpace12)
                    Text(row.time)
                        .backstageText(.hubBody2)
                        .foregroundStyle(M.textPrimary)
                }
                .frame(minHeight: 18)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(R.spacingSpace16)
    }

    private var facilities: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                ForEach(Array(HubsData.facilities.enumerated()), id: \.element.id) { index, facility in
                    if index > 0 {
                        Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                    }
                    HStack(spacing: R.spacingSpace12) {
                        Image(facility.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        Text(facility.title)
                            .backstageText(.hubBody2)
                            .foregroundStyle(M.textPrimary)
                    }
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace12)
            .padding(.bottom, R.spacingSpace24)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Floors directory

/// Floors directory (Figma "Floors", 14234:98980): a floor picker over collapsible categories.
/// It's a sheet rising over the hub page rather than a new screen, so the hero and header stay put. Its pills and rows arrive
/// in sequence, and the image grid opens once the sheet has nearly settled, so decoding photos never interrupts the rise.
struct HubFloorsSheet: View {
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floor = HubsData.floors[0]
    @State private var expanded: Set<String> = []
    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0
    @Namespace private var line

    private func places(_ category: HubCategory) -> [HubPlace] {
        let all = HubsData.places(category.kind)
        guard let number = floor.floor else { return all }
        return all.filter { $0.floor == number }
    }

    /// A delayed spring for the item at `index` of a sequence.
    private func stagger(_ index: Int, base: Double) -> Animation {
        .spring(response: 0.42, dampingFraction: 0.85).delay(base + Double(index) * 0.04)
    }

    var body: some View {
        VStack(spacing: 0) {
            floorPicker
                .contentShape(Rectangle())
                .simultaneousGesture(dismissDrag)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(Array(HubsData.floorCategories.enumerated()), id: \.element.id) { index, category in
                        let found = places(category)
                        HubCategorySection(category: category, subtitle: "\(found.count) \(category.countNoun)", places: found,
                                           lineFor: { $0.floorLabel }, chevronSize: 32,
                                           isExpanded: Binding(get: { expanded.contains(category.id) }, set: { value in
                            if value { expanded.insert(category.id) } else { expanded.remove(category.id) }
                        }))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 16)
                        .animation(reduceMotion ? nil : stagger(index, base: 0.1), value: appeared)
                    }
                }
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace12)
                .padding(.bottom, R.spacingSpace40)
            }
            .scrollIndicators(.hidden)
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: R.cornerRadiusCorner24, topTrailingRadius: R.cornerRadiusCorner24)
                .fill(M.backgroundPrimary)
                .ignoresSafeArea(edges: .bottom)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: R.cornerRadiusCorner24, topTrailingRadius: R.cornerRadiusCorner24))
        .offset(y: dragOffset)
        .task {
            appeared = true
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 300))
            withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.9)) {
                _ = expanded.insert(HubsData.floorCategories[0].id)
            }
        }
    }

    /// Pulling down on the picker follows the finger and dismisses past a threshold. Sideways drags stay with the picker's scroll.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let t = value.translation
                if t.height > 0, t.height > abs(t.width) { dragOffset = t.height }
            }
            .onEnded { value in
                if dragOffset > 110 || (dragOffset > 0 && value.predictedEndTranslation.height > 260) {
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { dragOffset = 0 }
                }
            }
    }

    private var floorPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace4) {
                ForEach(Array(HubsData.floors.enumerated()), id: \.element.id) { index, item in
                    let selected = item == floor
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { floor = item }
                    } label: {
                        VStack(spacing: R.spacingSpace8) {
                            HubFloorBadge(text: item.badge)
                                .scaleEffect(appeared || reduceMotion ? (selected ? 1.06 : 1) : 0.8)
                                .opacity(appeared ? 1 : 0)
                                .animation(reduceMotion ? nil : stagger(index, base: 0.04), value: appeared)
                            Text(item.title)
                                .backstageText(selected ? .button3 : .body3)
                                .foregroundStyle(selected ? M.textPrimary : M.textSecondary)
                                .lineLimit(1)
                                .fixedSize()
                                .opacity(appeared ? 1 : 0)
                                .animation(reduceMotion ? nil : stagger(index, base: 0.08), value: appeared)
                        }
                        .frame(minWidth: 64)
                        .padding(.horizontal, R.spacingSpace4)
                        .padding(.bottom, R.spacingSpace12)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Rectangle()
                                    .fill(M.textPrimary)
                                    .frame(height: R.stroke2Px)
                                    .matchedGeometryEffect(id: "floor-line", in: line)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .contentMargins(.horizontal, 12, for: .scrollContent)
        .scrollIndicators(.hidden)
        .padding(.top, R.spacingSpace16)
        .background(alignment: .bottom) {
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
        }
        .sensoryFeedback(.selection, trigger: floor)
    }
}

/// The metallic floor pill. The Figma sets the numbers in Impact; Anton is the bundled face closest to it.
private struct HubFloorBadge: View {
    let text: String
    private static let face = LinearGradient(colors: [Color(hex: 0xFAFAFA), Color(hex: 0xFAFAFA), Color(hex: 0x3A3A44)],
                                             startPoint: .top, endPoint: .bottom)

    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(stops: [.init(color: Color(hex: 0x3E3E43), location: 0.09),
                                             .init(color: Color(hex: 0x535360), location: 0.28),
                                             .init(color: Color(hex: 0x24242A), location: 0.72)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Capsule().strokeBorder(Color(hex: 0x2F2F34), lineWidth: 0.5)
            if text.isEmpty {
                VStack(spacing: R.spacingSpace4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0xFAFAFA), Color(hex: 0xB7B7D1)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 20, height: 3)
                    }
                }
            } else {
                Text(text)
                    .font(.custom("Anton-Regular", fixedSize: 21))
                    .tracking(0.7)
                    .foregroundStyle(Self.face)
            }
        }
        .frame(width: 54, height: 38.6)
    }
}

// MARK: - Collapsible category

/// A group row with its tinted icon that expands into a sideways-scrolling grid of places.
/// Used by the floors directory and the airport page.
struct HubCategorySection: View {
    let category: HubCategory
    let subtitle: String
    let places: [HubPlace]
    let lineFor: (HubPlace) -> String
    let chevronSize: CGFloat
    @Binding var isExpanded: Bool

    @State private var active: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filtered: [HubPlace] {
        places.filter { place in
            active.allSatisfy { $0 == "Rated 4+" ? place.ratedFourPlus : place.tags.contains($0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: R.spacingSpace12) {
                    category.tint
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(category.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .backstageText(.title3)
                            .foregroundStyle(M.textPrimary)
                        Text(subtitle)
                            .backstageText(.body3)
                            .foregroundStyle(M.textTertiary)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 0)
                    Image(chevronSize > 24 ? "hub_ic_chev32" : "hub_ic_chev24")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: chevronSize, height: chevronSize)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, R.spacingSpace12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isExpanded ? .isSelected : [])

            if isExpanded {
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    HubPlaceFilterRail(active: $active)
                        .padding(.horizontal, -R.spacingSpace16)
                    if filtered.isEmpty {
                        Text("Nothing here matches those filters")
                            .backstageText(.body3)
                            .foregroundStyle(M.textSecondary)
                            .padding(.vertical, R.spacingSpace16)
                    } else {
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: Array(repeating: GridItem(.fixed(64), spacing: R.spacingSpace20),
                                                  count: min(filtered.count, 4)),
                                      alignment: .top, spacing: 28) {
                                ForEach(filtered) { HubCompactRow(place: $0, line: lineFor($0)) }
                            }
                        }
                        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
                        .padding(.horizontal, -R.spacingSpace16)
                        .scrollIndicators(.hidden)
                        // Each floor's places crossfade in place of the last, starting from the first column.
                        .id(filtered.map(\.id))
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, R.spacingSpace24)
                .transition(.opacity.combined(with: .offset(y: -10)))
            } else {
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            }
        }
    }
}

/// An 80×58 place row from the floors grid (Figma 14234:99059).
struct HubCompactRow: View {
    let place: HubPlace
    let line: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .backstageText(.button3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                HStack(spacing: R.spacingSpace4) {
                    if let rating = place.rating {
                        Text(rating)
                            .backstageText(.finePrint2)
                            .foregroundStyle(M.hubTextRating)
                        Image("hub_ic_star_floor")
                            .resizable()
                            .frame(width: 8, height: 8)
                        Circle().fill(M.textTertiary).frame(width: 2, height: 2)
                    }
                    Text(place.cuisine)
                        .backstageText(.finePrint2)
                        .foregroundStyle(M.textTertiary)
                        .lineLimit(1)
                }
                Text(line)
                    .backstageText(.finePrint2)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
                if let offer = place.offer { HubOfferLine(offer: offer, compact: true) }
            }
            .frame(width: 145, alignment: .leading)
        }
        .frame(width: 235, height: 64, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photo = place.photo {
            Color.clear
                .frame(width: 80, height: 58)
                .overlay { Image(photo).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                .overlay(alignment: .bottomTrailing) {
                    if place.isAd {
                        Text("Ad")
                            .backstageText(.finePrint2)
                            .foregroundStyle(M.textSecondary)
                            .padding(.horizontal, 2)
                            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner4))
                            .padding(R.spacingSpace4)
                    }
                }
        } else {
            HubLogoTile(logo: place.logo, width: 80, height: 58, radius: R.cornerRadiusCorner8)
        }
    }
}

// MARK: - Search in hub

/// Search inside a hub, as a half-height glass sheet: what's trending here until you type, then matches from the whole hub.
/// Focusing the field opens it to full height, so results aren't squeezed by the keyboard.
struct HubSearchView: View {
    let hub: Hub
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var saved: Set<String> = []
    @State private var storePage: StoreDetail?
    @State private var detent: PresentationDetent = .medium
    @FocusState private var focused: Bool

    private var results: [HubPlace] {
        HubsData.places.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.cuisine.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            field
            ScrollView(.vertical) {
                Group {
                    if query.isEmpty { trending } else { matches }
                }
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace8)
                .padding(.bottom, R.spacingSpace40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(.top, R.spacingSpace12)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .modifier(HubGlassSheetBackground())
        .preferredColorScheme(.dark)
        .onChange(of: focused) { if focused { detent = .large } }
        .readerCover(item: $storePage) { StoreDetailView(detail: $0) }
    }

    private var field: some View {
        HStack(spacing: R.spacingSpace8) {
            HStack(spacing: R.spacingSpace8) {
                Image("hub_ic_search")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                TextField("Search in \(hub.name)", text: $query)
                    .backstageText(.hubLabel1)
                    .foregroundStyle(M.textPrimary)
                    .focused($focused)
                    .submitLabel(.search)
            }
            .padding(.horizontal, R.spacingSpace12)
            .frame(height: 44)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))

            Button { dismiss() } label: {
                Image("hub_ic_close")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.leading, R.spacingSpace16)
        .padding(.trailing, R.spacingSpace8)
        .padding(.bottom, R.spacingSpace8)
    }

    private var trending: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Trending in \(hub.name)")
                .backstageText(.hubTitle2)
                .foregroundStyle(M.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            ForEach(HubsData.trending) { place in
                HubOpensStore(place: place, openStore: { storePage = $0 }) {
                    HubCompactRow(place: place, line: place.floorLabel)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var matches: some View {
        VStack(spacing: R.spacingSpace20) {
            if results.isEmpty {
                Text("No places match “\(query)”")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .padding(.vertical, R.spacingSpace40)
            }
            ForEach(results) { place in
                HubPlaceRow(place: place, isSaved: saved.contains(place.id), openStore: { storePage = $0 }) {
                    if saved.contains(place.id) { saved.remove(place.id) } else { saved.insert(place.id) }
                }
            }
        }
    }
}

/// iOS 26's partial-height sheets are Liquid Glass by default, so only older systems need a material.
private struct HubGlassSheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.presentationBackground(.ultraThinMaterial)
        }
    }
}

// MARK: - Worth stepping out for

/// The details sheet behind a "Worth stepping out for" card. It works for any kind of pick: a celebrity promoting a film, a
/// live gig, a market, an offer, a place to eat or something to do. It shows when, where and what entry costs, who's
/// appearing, what it's about, and the hub it's at. "Explore" opens that hub.
struct HubPickSheet: View {
    let pick: HubsData.Pick
    let onExplore: (Hub) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reminded = false
    @State private var detent: PresentationDetent = .fraction(0.86)

    private var hub: Hub? { HubsData.hub(named: pick.hub) }

    /// One-off things get a reminder; ongoing ones (a café, a rink) get saved instead.
    private var isDated: Bool {
        switch pick.kind {
        case .moviePromo, .liveEvent, .market: true
        case .offer, .dining, .activity: false
        }
    }

    private static let heroHeight: CGFloat = 300

    var body: some View {
        ScrollViewReader { proxy in
            scroll
                #if DEBUG
                // `-hubsPickScroll` opens the sheet scrolled to the end.
                .task {
                    guard ProcessInfo.processInfo.arguments.contains("-hubsPickScroll") else { return }
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo("pickEnd", anchor: .bottom)
                }
                #endif
        }
        .presentationDetents([.fraction(0.86), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(R.cornerRadiusCorner24)
        .presentationBackground(M.backgroundPrimary)
        .sensoryFeedback(.success, trigger: reminded) { _, new in new }
    }

    private var scroll: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: R.spacingSpace32) {
                    titleBlock
                    facts
                    if !pick.featuring.isEmpty { people }
                    about
                    if !pick.highlights.isEmpty { highlights }
                    if let hub { happeningAt(hub) }
                }
                .padding(.horizontal, R.spacingSpace16)
                // The title rises into the photo's fade.
                .padding(.top, -R.spacingSpace40)
                .padding(.bottom, R.spacingSpace24)
                Color.clear.frame(height: 0).id("pickEnd")
            }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) { closeButton }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(M.backgroundPrimary)
    }

    // MARK: Hero

    private var hero: some View {
        Color.clear
            .frame(height: Self.heroHeight)
            .overlay { Image(pick.image).resizable().scaledToFill() }
            .overlay {
                // The bottom of the photo softens into a blur as it fades, so it dissolves into the sheet instead of
                // showing a hard tonal band.
                Image(pick.image).resizable().scaledToFill()
                    .blur(radius: 20)
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0.45), .init(color: .black, location: 0.8)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
            .clipped()
            .overlay {
                // An eased (smoothstep) ramp to the sheet colour: it starts gently, so there's no visible line where it
                // begins, and lands softly on solid.
                LinearGradient(stops: Self.fadeStops, startPoint: .top, endPoint: .bottom)
                    // Runs a little past the photo, so its antialiased bottom row can't show as a line.
                    .padding(.bottom, -2)
            }
            .overlay(alignment: .topLeading) { kindBadge.padding(R.spacingSpace16).padding(.top, R.spacingSpace8) }
            .accessibilityHidden(true)
    }

    private static let fadeStops: [Gradient.Stop] = {
        let start = 0.3, end = 0.97, steps = 12
        return (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let eased = t * t * (3 - 2 * t)
            return .init(color: M.backgroundPrimary.opacity(eased), location: start + (end - start) * t)
        }
    }()

    private var kindBadge: some View {
        HStack(spacing: R.spacingSpace4) {
            LucideIcon(name: pick.kind.icon, size: 12)
            Text(pick.kind.label)
                .backstageText(.label3)
        }
        .foregroundStyle(M.hubPureWhite)
        .padding(.horizontal, R.spacingSpace8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.32), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [M.hubTextNew.opacity(0.85), M.hubTextNew.opacity(0.3)],
                                                       startPoint: .top, endPoint: .bottom),
                                        lineWidth: R.stroke1Px))
        .environment(\.colorScheme, .dark)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            LucideIcon(name: "lc_x", size: 16)
                .foregroundStyle(M.hubPureWhite)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.32), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, R.spacingSpace16)
        .padding(.trailing, R.spacingSpace8)
        .accessibilityLabel("Close")
    }

    // MARK: Copy

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            Text(pick.title)
                .backstageText(.hubTitle1)
                .foregroundStyle(M.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                LucideIcon(name: "lc_map_pin", size: 13)
                    .foregroundStyle(M.iconSecondary)
                    .accessibilityHidden(true)
                Text(hub.map { "\($0.name) · \($0.locality)" } ?? pick.hub)
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
            }
            Text(pick.line)
                .font(.custom("BeVietnamPro-Italic", size: 13, relativeTo: .subheadline))
                .foregroundStyle(M.textPrimary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, R.spacingSpace4)
        }
    }

    /// When, where and entry, as one card.
    private var facts: some View {
        VStack(spacing: 0) {
            factRow(icon: "lc_calendar", label: "When", value: pick.when, detail: pick.time)
            divider
            factRow(icon: "lc_map_pin", label: "Where", value: pick.spot, detail: hub?.name)
            divider
            factRow(icon: "lc_ticket", label: "Entry", value: pick.entry, detail: nil)
        }
        .padding(.horizontal, R.spacingSpace16)
        .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }

    private var divider: some View {
        Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px).padding(.leading, 48)
    }

    /// `label` isn't shown (the icon says it); VoiceOver reads it before the value.
    private func factRow(icon: String, label: String, value: String, detail: String?) -> some View {
        HStack(spacing: R.spacingSpace12) {
            // White on the dark sheet (icon/primary flips to near-black on the light one, where white wouldn't show).
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(M.iconPrimary)
                .frame(width: 36, height: 36)
                .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, R.spacingSpace12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)" + (detail.map { ", \($0)" } ?? ""))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .backstageText(.title3)
            .foregroundStyle(M.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var people: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            sectionTitle(pick.kind.peopleTitle)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: R.spacingSpace16) {
                    ForEach(Array(pick.featuring.enumerated()), id: \.element.id) { index, person in
                        HubPickPersonView(person: person, tint: Self.tints[index % Self.tints.count])
                    }
                }
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .padding(.horizontal, -R.spacingSpace16)
            .scrollIndicators(.hidden)
        }
    }

    private static let tints: [Color] = [Color(hex: 0x8E6CFF), Color(hex: 0xE0607E), Color(hex: 0x3FA7D6), Color(hex: 0xE59A3C)]

    private var about: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            sectionTitle("About")
            Text(pick.about)
                .backstageText(.hubBody2)
                .foregroundStyle(M.textPrimary.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            sectionTitle("Highlights")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: R.spacingSpace8), GridItem(.flexible(), spacing: R.spacingSpace8)],
                      spacing: R.spacingSpace8) {
                ForEach(pick.highlights, id: \.self) { item in
                    Text(item)
                        .backstageText(.label2)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, R.spacingSpace12)
                        .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                }
            }
        }
    }

    /// The hub the pick is at, tappable like the CTA.
    private func happeningAt(_ hub: Hub) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            sectionTitle("Happening at")
            Button { onExplore(hub) } label: {
                HStack(spacing: R.spacingSpace12) {
                    Color.clear
                        .frame(width: 64, height: 64)
                        .overlay(alignment: hub.imageAlignment) { Image(hub.image).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                    VStack(alignment: .leading, spacing: R.spacingSpace4) {
                        Text(hub.name)
                            .backstageText(.title4)
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: R.spacingSpace4) {
                            LucideIcon(name: "lc_star", size: 10)
                                .foregroundStyle(M.textPrimary)
                            Text(hub.googleRating)
                            Circle().fill(M.textTertiary).frame(width: 3, height: 3)
                            Text("\(hub.distance) away")
                        }
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                        Text(hub.type.title.hasSuffix("s") ? String(hub.type.title.dropLast()) : hub.type.title)
                            .backstageText(.label3)
                            .foregroundStyle(M.textTertiary)
                    }
                    Spacer(minLength: 0)
                    LucideIcon(name: "lc_chevron_right", size: 18)
                        .foregroundStyle(M.iconSecondary)
                }
                .padding(R.spacingSpace12)
                .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the hub")
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: R.spacingSpace12) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { reminded.toggle() }
            } label: {
                // Lucide is outline-only, so the "on" state swaps to its ringing bell / checked bookmark in the accent.
                LucideIcon(name: isDated ? (reminded ? "lc_bell_ring" : "lc_bell") : (reminded ? "lc_bookmark_check" : "lc_bookmark"),
                           size: 20)
                    .foregroundStyle(reminded ? M.textOffer : M.iconPrimary)
                    .id(reminded)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .frame(width: 48, height: 48)
                    .background(M.surfaceTransparent, in: Circle())
                    .overlay(Circle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDated ? "Remind me" : "Save")
            .accessibilityAddTraits(reminded ? .isSelected : [])

            Button {
                if let hub { onExplore(hub) }
            } label: {
                HStack(spacing: R.spacingSpace8) {
                    Text("Explore \(pick.hub)")
                        .backstageText(.label1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    LucideIcon(name: "lc_arrow_up_right", size: 16)
                }
                .foregroundStyle(M.buttonPrimaryLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(M.textPrimary, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(hub == nil)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace12)
        .padding(.bottom, R.spacingSpace8)
        .background {
            M.backgroundPrimary
                .overlay(alignment: .top) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// A Lucide icon from the asset catalog's Lucide folder, tinted by the foreground style.
struct LucideIcon: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A person appearing at a pick. There are no photos, so a tinted disc carries their initials.
private struct HubPickPersonView: View {
    let person: HubsData.Pick.Person
    let tint: Color

    private var initials: String {
        person.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        VStack(spacing: R.spacingSpace8) {
            Text(initials)
                .font(.custom("BeVietnamPro-SemiBold", size: 20, relativeTo: .title3))
                .foregroundStyle(M.hubPureWhite)
                .frame(width: 68, height: 68)
                .background(LinearGradient(colors: [tint, tint.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: R.stroke1Px))
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text(person.name)
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(person.role)
                    .backstageText(.label3)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 88)
        .accessibilityElement(children: .combine)
    }
}
