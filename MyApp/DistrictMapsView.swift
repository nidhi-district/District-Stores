import SwiftUI
import MapKit

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Maps tab

/// The Maps tab: the hubs around you on one dark map. While you're standing in a hub it opens on that hub, lit, with the way
/// around it inside one tap away. It's the standing way back into the hub that Home can't keep on screen: the tab stays in the
/// bar, and carries a live dot for as long as you're there.
struct DistrictMapsView: View {
    let zoom: Namespace.ID
    let arrival: HubArrival
    /// Whether the person is standing in `arrival.hub` right now.
    let atHub: Bool
    let openHub: (Hub) -> Void
    let openFloors: (Hub) -> Void

    @State private var camera: MapCameraPosition
    /// A hub picked on the map. Nil shows the hub they're in, or the nearby list when they're not in one.
    @State private var selected: Hub?
    @State private var filter: HubType?
    /// The Hubs listing, in place of the map.
    @State private var showsList = DistrictMapsView.launchesList
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(zoom: Namespace.ID, arrival: HubArrival, atHub: Bool, openHub: @escaping (Hub) -> Void, openFloors: @escaping (Hub) -> Void) {
        self.zoom = zoom
        self.arrival = arrival
        self.atHub = atHub
        self.openHub = openHub
        self.openFloors = openFloors
        _camera = State(initialValue: .region(Self.region(around: arrival.center, span: 0.16)))
    }

    private var hereHub: Hub? { atHub ? arrival.hub : nil }

    private var pins: [(hub: Hub, at: CLLocationCoordinate2D)] {
        HubsData.hubs.compactMap { hub in
            guard let at = HubMapPlaces.coordinate[hub.name], hub.id != hereHub?.id else { return nil }
            guard filter == nil || hub.type == filter else { return nil }
            return (hub, at)
        }
    }

    /// Only the kinds that are on this map.
    private var filters: [HubType] {
        HubType.allCases.filter { type in HubsData.hubs.contains { $0.type == type && HubMapPlaces.coordinate[$0.name] != nil } }
    }

    var body: some View {
        ZStack {
            if showsList {
                HubsListingView(zoom: zoom, onBack: { setList(false) }, openHub: { hub, _ in openHub(hub) },
                                openFloorMap: { hub, _ in openFloors(hub) }, openHereHub: { openHub($0) }, inMaps: true)
                    .transition(.opacity)
            } else {
                map
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: showsList)
    }

    private func setList(_ on: Bool) {
        withAnimation(.smooth(duration: 0.3)) {
            showsList = on
            selected = nil
        }
    }

    /// Debug builds accept `-mapsList`, which opens the Maps tab on its list.
    private static var launchesList: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-mapsList")
        #else
        return false
        #endif
    }

    private var map: some View {
        Map(position: $camera) {
            ForEach(pins, id: \.hub.id) { pin in
                Annotation(pin.hub.name, coordinate: pin.at, anchor: .bottom) {
                    HubMapPin(hub: pin.hub, selected: selected?.id == pin.hub.id) { select(pin.hub, at: pin.at) }
                }
                .annotationTitles(.hidden)
            }
            // Drawn last, so it sits over its neighbours.
            if let here = hereHub {
                Annotation(here.name, coordinate: arrival.center, anchor: .center) {
                    HubMapHerePin(image: here.hero, selected: selected == nil) { recentre() }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {}
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { panel }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: selected?.id)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace8) {
                Text("Maps")
                    .backstageText(.hubTitle1)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if atHub {
                    HStack(spacing: 4) {
                        HubLiveDot()
                        Text("At \(arrival.hub.name)")
                            .backstageText(.label2)
                            .foregroundStyle(M.textPrimary)
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 10)
                    .frame(height: 30)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.1), lineWidth: R.stroke1Px))
                    .accessibilityElement(children: .combine)
                }
                MapsViewSwitch(showsList: false) { if $0 { setList(true) } }
            }
            .padding(.horizontal, R.spacingSpace16)
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    chip("All", selected: filter == nil) { filter = nil }
                    ForEach(filters) { type in
                        chip(type.title, selected: filter == type) { filter = filter == type ? nil : type }
                    }
                }
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
        .padding(.top, R.spacingSpace8)
        .padding(.bottom, R.spacingSpace24)
        .background {
            // Lets the title read over the map, and fades away before the pins.
            LinearGradient(stops: [.init(color: M.backgroundPrimary, location: 0),
                                   .init(color: M.backgroundPrimary.opacity(0.85), location: 0.5),
                                   .init(color: M.backgroundPrimary.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) {
                action()
                self.selected = nil
            }
        } label: {
            Text(title)
                .backstageText(.label2)
                .foregroundStyle(selected ? M.buttonPrimaryLabel : M.textPrimary)
                .padding(.horizontal, R.spacingSpace12)
                .frame(height: 32)
                .background {
                    if selected {
                        Capsule().fill(M.textPrimary)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().strokeBorder(M.hubPureWhite.opacity(0.12), lineWidth: R.stroke1Px)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Panel

    @ViewBuilder
    private var panel: some View {
        VStack(alignment: .trailing, spacing: R.spacingSpace12) {
            if atHub, selected != nil {
                recentreButton
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            Group {
                if let hub = selected {
                    HubMapCard(hub: hub, onOpen: { openHub(hub) }, onNavigate: { openFloors(hub) },
                               onClose: { withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { selected = nil } })
                        .id(hub.id)
                } else if atHub {
                    HubMapHereCard(arrival: arrival, onOpen: { openHub(arrival.hub) }, onNavigate: { openFloors(arrival.hub) })
                } else {
                    nearbyHint
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .padding(.horizontal, R.spacingSpace16)
        // Clears the tab bar, which sits a little proud of the inset every tab gets.
        .padding(.bottom, R.spacingSpace16)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: selected?.id)
    }

    private var recentreButton: some View {
        Button(action: recentre) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill").font(.system(size: 12, weight: .semibold))
                Text("Back to \(arrival.hub.name)").backstageText(.label2)
            }
            .foregroundStyle(M.hubPureWhite)
            .padding(.horizontal, R.spacingSpace12)
            .frame(height: 36)
            .background(Color.black.opacity(0.55), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.14), lineWidth: R.stroke1Px))
            .frame(height: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .environment(\.colorScheme, .dark)
    }

    private var nearbyHint: some View {
        HStack(spacing: R.spacingSpace8) {
            Image(systemName: "hand.tap").font(.system(size: 14, weight: .medium))
            Text("Tap a hub to see what’s on").backstageText(.label2)
        }
        .foregroundStyle(M.hubPureWhite.opacity(0.8))
        .padding(.horizontal, R.spacingSpace16)
        .frame(height: 40)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Camera

    private func select(_ hub: Hub, at coordinate: CLLocationCoordinate2D) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { selected = hub }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.6)) {
            camera = .region(Self.region(around: coordinate, span: 0.06))
        }
    }

    private func recentre() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { selected = nil }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.6)) {
            camera = .region(Self.region(around: arrival.center, span: atHub ? 0.03 : 0.16))
        }
    }

    /// Centred a little south of the point, so the pin sits above the card at the bottom rather than behind it.
    private static func region(around c: CLLocationCoordinate2D, span: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: c.latitude - span * 0.22, longitude: c.longitude),
                           span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }
}

// MARK: - Pins

/// A hub on the map: its photo in a white-rimmed circle. Picked, it grows and takes its name.
private struct HubMapPin: View {
    let hub: Hub
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(hub.hero)
                    .resizable()
                    .scaledToFill()
                    .frame(width: selected ? 46 : 34, height: selected ? 46 : 34)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(selected ? M.hubPureWhite : M.hubPureWhite.opacity(0.85), lineWidth: selected ? 2.5 : 1.5))
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                if selected {
                    Text(hub.name)
                        .backstageText(.label3)
                        .foregroundStyle(M.hubPureWhite)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(response: 0.34, dampingFraction: 0.7), value: selected)
        .accessibilityLabel(hub.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Where they're standing: the hub's photo in its live ring, over a slow green beacon, with "You're here" under it.
private struct HubMapHerePin: View {
    let image: String
    let selected: Bool
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            ZStack {
                beacon
                HubLiveThumb(image: image, size: 48)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                    .scaleEffect(selected ? 1 : 0.85)
            }
            .overlay(alignment: .bottom) {
                Text("You’re here")
                    .backstageText(.label3)
                    .foregroundStyle(M.buttonPrimaryLabel)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(M.hubPureWhite, in: Capsule())
                    .offset(y: 14)
            }
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(response: 0.34, dampingFraction: 0.7), value: selected)
        .accessibilityLabel("You’re here")
    }

    /// Two rings of the live green, expanding out of the pin in turn.
    private var beacon: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0.3 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    let phase = (t / 2.4 + Double(ring) * 0.5).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .fill(M.hubTextSuccess.opacity(0.28 * (1 - phase)))
                        .overlay(Circle().strokeBorder(M.hubTextSuccess.opacity(0.6 * (1 - phase)), lineWidth: 1))
                        .frame(width: 54 + 70 * phase, height: 54 + 70 * phase)
                }
            }
        }
        .frame(width: 124, height: 124)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

/// The card for the hub they're in: who and where, quick ways to what they're after, and the way around it as the main action.
private struct HubMapHereCard: View {
    let arrival: HubArrival
    let onOpen: () -> Void
    let onNavigate: () -> Void

    private var indoor: Bool { !arrival.waypoints.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Button(action: onOpen) {
                HStack(spacing: R.spacingSpace12) {
                    HubLiveThumb(image: arrival.hub.hero, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You’re here · \(arrival.openLine)")
                            .backstageText(.label3)
                            .foregroundStyle(M.hubTextSuccess)
                            .lineLimit(1)
                        Text(arrival.hub.name)
                            .backstageText(.hubTitle2)
                            .foregroundStyle(M.hubPureWhite)
                            .lineLimit(1)
                        Text(arrival.stats.map(\.label).joined(separator: " · "))
                            .backstageText(.body3)
                            .foregroundStyle(M.hubPureWhite.opacity(0.64))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(M.hubPureWhite)
                        .frame(width: 32, height: 32)
                        .background(M.hubPureWhite.opacity(0.1), in: Circle())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the hub")

            if indoor {
                // Straight to what they came for. Each opens the floors directory, the hub's way around.
                HStack(spacing: R.spacingSpace8) {
                    ForEach(arrival.waypoints) { point in
                        Button(action: onNavigate) {
                            VStack(spacing: 6) {
                                Image(systemName: point.symbol)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 20)
                                Text(point.title)
                                    .backstageText(.label3)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(M.hubPureWhite.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(M.hubPureWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(M.hubPureWhite.opacity(0.08), lineWidth: R.stroke1Px))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Find \(point.title.lowercased())")
                    }
                }

                Button(action: onNavigate) {
                    HStack(spacing: R.spacingSpace8) {
                        HubIndoorMapIcon(size: 18, ink: M.buttonPrimaryLabel, accent: M.buttonPrimaryLabel)
                        Text("Navigate in \(arrival.hub.name)")
                            .backstageText(.label1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(M.buttonPrimaryLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(M.hubPureWhite, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Opens the floor map")
            }
        }
        .padding(R.spacingSpace16)
        .background { HubMapCardGround(image: arrival.hub.hero) }
        .environment(\.colorScheme, .dark)
    }
}

/// The card for a hub picked on the map.
private struct HubMapCard: View {
    let hub: Hub
    let onOpen: () -> Void
    let onNavigate: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Image(hub.hero)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(hub.name)
                        .backstageText(.title3)
                        .foregroundStyle(M.hubPureWhite)
                        .lineLimit(1)
                    Text("\(hub.locality) · \(hub.distance)")
                        .backstageText(.body3)
                        .foregroundStyle(M.hubPureWhite.opacity(0.64))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 10))
                            .foregroundStyle(Color(hex: 0xF5C451))
                        Text(hub.googleRating).backstageText(.label3)
                            .foregroundStyle(M.hubPureWhite.opacity(0.8))
                        Text("· \(hub.type.title)").backstageText(.label3)
                            .foregroundStyle(M.hubPureWhite.opacity(0.5))
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(M.hubPureWhite.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(M.hubPureWhite.opacity(0.1), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, -8)
                .padding(.trailing, -8)
                .accessibilityLabel("Close")
            }
            HStack(spacing: R.spacingSpace8) {
                if hub.hasFindInHub {
                    Button(action: onNavigate) {
                        HStack(spacing: 6) {
                            HubIndoorMapIcon(size: 16, ink: M.hubPureWhite, accent: M.hubPureWhite)
                            Text("Navigate").backstageText(.label1)
                        }
                        .foregroundStyle(M.hubPureWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(M.hubPureWhite.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.28), lineWidth: R.stroke1Px))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Navigate in \(hub.name)")
                }
                Button(action: onOpen) {
                    Text("View hub")
                        .backstageText(.label1)
                        .foregroundStyle(M.buttonPrimaryLabel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(M.hubPureWhite, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(R.spacingSpace16)
        .background { HubMapCardGround(image: hub.hero) }
        .environment(\.colorScheme, .dark)
    }
}

/// Dark glass, warmed at the top-left by the hub photo's own colour.
private struct HubMapCardGround: View {
    let image: String
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        ZStack {
            shape.fill(M.backgroundSecondary.opacity(0.9))
            RadialGradient(colors: [HubPhotoTint.of(image).glow.opacity(0.35), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 260)
                .clipShape(shape)
        }
        .background(.ultraThinMaterial, in: shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [M.hubPureWhite.opacity(0.18), M.hubPureWhite.opacity(0.04)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: R.stroke1Px))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

// MARK: - Map / List switch

/// Two icon segments on glass, Map and List, with the current one lit white. Sits in the same place on both views.
struct MapsViewSwitch: View {
    let showsList: Bool
    let onChange: (Bool) -> Void
    @Namespace private var lit

    var body: some View {
        HStack(spacing: 2) {
            segment("Map", symbol: "map", on: !showsList) { onChange(false) }
            segment("List", symbol: "list.bullet", on: showsList) { onChange(true) }
        }
        .padding(3)
        .background(Color.black.opacity(0.35), in: Capsule())
        .liquidGlass(in: Capsule())
        .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.12), lineWidth: R.stroke1Px))
        .environment(\.colorScheme, .dark)
    }

    private func segment(_ title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? M.buttonPrimaryLabel : M.hubPureWhite.opacity(0.8))
                .frame(width: 38, height: 30)
            .background {
                if on { Capsule().fill(M.hubPureWhite).matchedGeometryEffect(id: "lit", in: lit) }
            }
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .padding(.vertical, -8)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Postcard

/// The Maps list's hub card, editorial style: a short photo banner that melts into a ground tinted with the photo's own colour,
/// the name set over that fade, then the blurb in full and the tags. Each card takes on its hub's colour, so the list reads like
/// a set of postcards rather than rows. Around 230pt tall, with the same facts as the Hubs card.
struct HubPostcard: View {
    let hub: Hub
    let onNavigate: () -> Void
    let onTap: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    private static let banner: CGFloat = 132

    private var tint: Color { HubPhotoTint.of(hub.image).glow }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: Self.banner)
                .overlay(alignment: .bottomLeading) { title.padding(.horizontal, 16).padding(.bottom, 2) }
                .overlay(alignment: .topLeading) {
                    if hub.hasFindInHub { navigate.padding(12) }
                }
            VStack(alignment: .leading, spacing: 14) {
                Text(hub.blurb)
                    .font(.system(size: 14))
                    .foregroundStyle(M.hubPureWhite.opacity(0.76))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                tags
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background { ground }
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [M.hubPureWhite.opacity(0.18), M.hubPureWhite.opacity(0.04)],
                                                   startPoint: .top, endPoint: .bottom), lineWidth: R.stroke1Px))
        .shadow(color: tint.opacity(0.18), radius: 18, y: 8)
        .contentShape(shape)
        .onTapGesture(perform: onTap)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hub.name), \(hub.type.title), rated \(hub.googleRating) on Google, \(hub.distance) away, \(hub.locality)."
                            + (hub.hasFindInHub ? " Has in-hub navigation." : "") + " \(hub.blurb)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
        .accessibilityActions {
            if hub.hasFindInHub { Button("Navigate in hub", action: onNavigate) }
        }
    }

    // MARK: Ground

    /// The photo across the top, fading out into the hub's own colour, which deepens to near-black at the foot of the card.
    private var ground: some View {
        ZStack(alignment: .top) {
            Color(hex: 0x0E0E11)
            LinearGradient(colors: [tint.opacity(0.42), tint.opacity(0.16), .clear],
                           startPoint: .top, endPoint: .bottom)
            Color.clear
                .frame(height: Self.banner + 40)
                .overlay(alignment: hub.imageAlignment) { Image(hub.image).resizable().scaledToFill() }
                // Settles the bottom of the photo so the name reads cleanly; masked with it, so it fades out with the photo.
                .overlay { LinearGradient(colors: [.clear, Color.black.opacity(0.5)], startPoint: .top, endPoint: .bottom) }
                .clipped()
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.35),
                                           .init(color: .black.opacity(0.35), location: 0.72), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .accessibilityHidden(true)
    }

    // MARK: Title

    private var title: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(hub.type.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(M.hubPureWhite.opacity(0.7))
            Text(hub.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(M.hubPureWhite)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF5C451))
                    Text(hub.googleRating).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(M.hubPureWhite)
                }
                Image("hub_logo_google").resizable().scaledToFit().frame(width: 32, height: 11)
                dot
                Text(hub.distance)
                dot
                Text(hub.locality).lineLimit(1)
            }
            .font(.system(size: 12))
            .foregroundStyle(M.hubPureWhite.opacity(0.72))
        }
    }

    private var dot: some View {
        Circle().fill(M.hubPureWhite.opacity(0.4)).frame(width: 3, height: 3)
    }

    private var navigate: some View {
        Button(action: onNavigate) {
            HStack(spacing: 5) {
                HubIndoorMapIcon(size: 13, ink: M.hubPureWhite, accent: M.hubPureWhite)
                Text("Navigate in hub")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(M.hubPureWhite)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .frame(height: 26)
            .background(Color.black.opacity(0.25), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [M.hubTextNew.opacity(0.85), M.hubTextNew.opacity(0.3)],
                                                           startPoint: .top, endPoint: .bottom), lineWidth: R.stroke1Px))
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .padding(.vertical, -9)
        }
        .buttonStyle(PressableStyle())
    }

    /// Soft glass tags on one row that scrolls sideways.
    private var tags: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(hub.chips, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(M.hubPureWhite.opacity(0.86))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(M.hubPureWhite.opacity(0.07), in: Capsule())
                        .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.08), lineWidth: R.stroke1Px))
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                                   .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Places

/// Approximate positions for the hubs in Delhi NCR, sample data for the map. Hubs elsewhere are left off it.
enum HubMapPlaces {
    static let coordinate: [String: CLLocationCoordinate2D] = [
        "DLF Emporio": .init(latitude: 28.5418, longitude: 77.1557),
        "DLF Promenade": .init(latitude: 28.5440, longitude: 77.1525),
        "Select Citywalk": .init(latitude: 28.5286, longitude: 77.2190),
        "The Chanakya": .init(latitude: 28.5970, longitude: 77.1880),
        "Taj Palace": .init(latitude: 28.5952, longitude: 77.1690),
        "Khan Market": .init(latitude: 28.6003, longitude: 77.2270),
        "Sunder Nursery": .init(latitude: 28.5937, longitude: 77.2484),
        "Pacific Mall": .init(latitude: 28.6430, longitude: 77.1060),
        "Ambience Mall": .init(latitude: 28.5050, longitude: 77.0965),
        "The Leela Ambience": .init(latitude: 28.5030, longitude: 77.0920),
        "Cyber Hub": .init(latitude: 28.4950, longitude: 77.0890),
        "MGF Metropolitan Mall": .init(latitude: 28.4810, longitude: 77.0800),
        "Galleria Market": .init(latitude: 28.4672, longitude: 77.0817),
        "32nd Avenue": .init(latitude: 28.4720, longitude: 77.0490),
        "Good Earth City Center": .init(latitude: 28.4180, longitude: 77.0600),
        "Omaxe Celebration Mall": .init(latitude: 28.4250, longitude: 77.0430),
        "AIPL Business Club": .init(latitude: 28.4120, longitude: 77.0920),
    ]
}
