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
                    .background(M.textPrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                    .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
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
                        .resizable()
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

/// Search inside a hub. The Figma stops at the action bar's Search button, so this is a simple filter over the hub's places.
struct HubSearchView: View {
    let hub: Hub
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var saved: Set<String> = []
    @State private var storePage: StoreDetail?
    @FocusState private var focused: Bool

    private var results: [HubPlace] {
        guard !query.isEmpty else { return HubsData.places }
        return HubsData.places.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.cuisine.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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
                .background(M.surfacePrimary, in: Capsule())
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
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace12)

            ScrollView(.vertical) {
                LazyVStack(spacing: R.spacingSpace20) {
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
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace8)
                .padding(.bottom, R.spacingSpace40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .readerCover(item: $storePage) { StoreDetailView(detail: $0) }
    }
}
