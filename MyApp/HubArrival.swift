import SwiftUI
import MapKit
import CoreImage
import AVFoundation
import CoreHaptics

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// What a person standing inside a hub sees on Home: a welcome sheet (Figma 6993:47912) and a card under the
// tile grid (Figma 6993:47625). Both are extended from the Figma with what matters on site: what's on right now, rather than a
// pitch for a place they've already reached. All content is sample data.

// MARK: - Data

struct HubArrival {
    struct Stat: Identifiable {
        var id: String { label }
        let symbol: String
        let tint: Color
        let value: String
        let unit: String
        var label: String { "\(value) \(unit)" }
    }

    struct Spot: Identifiable {
        var id: String { title }
        let title: String
        let image: String
        let coordinate: CLLocationCoordinate2D
    }

    let hub: Hub
    let openLine: String
    let liveLine: String
    let stats: [Stat]
    let spots: [Spot]
    /// The map's centre, and where the person is standing in it. Approximate, sample positions.
    let center: CLLocationCoordinate2D
    let you: CLLocationCoordinate2D
    /// The card's rotating updates.
    let updates: [String]
    /// The card's tags.
    let tags: [String]
    /// The card's nudge into the hub.
    let nudge: String
    /// The icon in the card's photo chips.
    var symbol = "leaf.fill"
    /// Quick destinations inside the hub. An indoor hub has these, and gets in-hub navigation in place of a street map.
    var waypoints: [Waypoint] = []
    var wayLine = ""
    /// Things to do here that the hub page has no tab for (movies, events, play, comedy…), shown after its tabs in the sheet.
    var moreLinks: [MoreLink] = []
    /// The one word the entry beside the tab bar keeps once it has closed, so it still says where it goes.
    var shortName: String? = nil

    struct MoreLink: Identifiable {
        var id: String { title }
        let title: String
        let symbol: String
    }

    struct Waypoint: Identifiable {
        var id: String { title }
        let title: String
        let symbol: String
    }

    static let dlfEmporio = HubArrival(
        hub: HubsData.hub(named: "DLF Emporio")!,
        openLine: "Open till 9 PM",
        liveLine: "Couture week is on, with 12 designers on the floor",
        stats: [Stat(symbol: "bag", tint: Color(hex: 0xF0699E), value: "80", unit: "stores"),
                Stat(symbol: "square.stack.3d.up", tint: Color(hex: 0x6AA5F5), value: "4", unit: "floors"),
                Stat(symbol: "fork.knife", tint: M.hubTextSuccess, value: "10", unit: "restaurants")],
        spots: [],
        center: .init(latitude: 28.5418, longitude: 77.1557),
        you: .init(latitude: 28.5418, longitude: 77.1557),
        updates: [],
        tags: [],
        nudge: "3 offers live",
        symbol: "bag.fill",
        waypoints: [Waypoint(title: "Stores", symbol: "bag"),
                    Waypoint(title: "Food", symbol: "fork.knife"),
                    Waypoint(title: "Restrooms", symbol: "figure.dress.line.vertical.figure"),
                    Waypoint(title: "Parking", symbol: "parkingsign")],
        wayLine: "Stores, food, restrooms",
        moreLinks: [MoreLink(title: "Events", symbol: "ticket"),
                    MoreLink(title: "Spa & salon", symbol: "sparkles"),
                    MoreLink(title: "Play", symbol: "gamecontroller"),
                    MoreLink(title: "Comedy", symbol: "theatermasks")],
        shortName: "Emporio"
    )

    static let sunderNursery = HubArrival(
        hub: HubsData.hub(named: "Sunder Nursery")!,
        openLine: "Open till 7 PM",
        liveLine: "Winter blooms are at their peak right now",
        stats: [Stat(symbol: "building.columns", tint: Color(hex: 0x6AA5F5), value: "15", unit: "monuments"),
                Stat(symbol: "leaf", tint: M.hubTextSuccess, value: "90", unit: "acres"),
                Stat(symbol: "fork.knife", tint: Color(hex: 0xF0699E), value: "7", unit: "restaurants")],
        spots: [Spot(title: "Bloom walk", image: "hub_buzz_blooms", coordinate: .init(latitude: 28.5946, longitude: 77.2474)),
                Spot(title: "Picnic lawns", image: "hub_buzz_lawns", coordinate: .init(latitude: 28.5931, longitude: 77.2492)),
                Spot(title: "Heritage trail", image: "hub_sunder", coordinate: .init(latitude: 28.5942, longitude: 77.2496))],
        center: .init(latitude: 28.5937, longitude: 77.2484),
        you: .init(latitude: 28.5927, longitude: 77.2477),
        updates: ["Winter blooms are at their peak", "Picnic lawns are open today", "Heritage trail is open till sunset"],
        tags: ["🕌 Mughal tombs", "🌸 Blooms", "🧺 Picnics", "☕ Cafés"],
        nudge: "3 offers live"
    )
}

// MARK: - Shared pieces

/// A live marker: a solid dot with a ring that keeps expanding from it.
struct HubLiveDot: View {
    var color: Color = M.hubTextSuccess
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: 14, height: 14)
                .scaleEffect(pulsing ? 1 : 0.45)
                .opacity(pulsing ? 0 : 1)
            Circle().fill(color).frame(width: 6, height: 6)
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulsing = true }
        }
    }
}

/// The way back to the hub while reading down Home: the hub's photo in a tab beside the bottom bar, with a right arrow and the
/// hub's short name on it. Rounded like the bar where it meets the page, and flat where it meets the screen's edge, as if tucked
/// in from just off screen. When `open`, it widens (pushing the bar a little way left to make room), the photo dims, and
/// "Explore" and the hub's full name sit beside the arrow.
struct HubEdgeEntry: View {
    let arrival: HubArrival
    let height: CGFloat
    var open = false
    let onTap: () -> Void

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: height / 2, bottomLeadingRadius: height / 2, style: .continuous)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: R.spacingSpace8) {
                if open {
                    words
                        // In once there's room for them; out quickly, so they're gone before it narrows.
                        .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.22).delay(0.2)),
                                                removal: .opacity.animation(.easeOut(duration: 0.12))))
                }
                VStack(spacing: 3) {
                    arrow
                    if !open {
                        label
                            .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.3)),
                                                    removal: .opacity.animation(.easeOut(duration: 0.12))))
                    }
                }
            }
            .padding(.leading, open ? 14 : 0)
            .padding(.trailing, open ? 12 : 0)
            // Closed it takes what's left beside the bar, up to 70pt; open it's as wide as the words need.
            .frame(minWidth: 44, maxWidth: open ? nil : 70)
            .frame(height: height)
            .background { ground }
            .clipShape(shape)
            // The same faint rim as the bar; its right side falls just off screen.
            .overlay(shape.stroke(M.hubPureWhite.opacity(0.22), lineWidth: R.stroke1Px))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Explore \(arrival.hub.name)")
        .accessibilityHint("You’re here. Opens the hub")
    }

    /// The photo, shaded so the arrow and name hold on it, and dimmed further while the words are up so they read cleanly.
    private var ground: some View {
        Image(arrival.hub.hero)
            .resizable()
            .scaledToFill()
            .overlay(Color.black.opacity(open ? 0.6 : 0.22))
            .overlay {
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.4)], startPoint: .center, endPoint: .bottom)
            }
    }

    /// What it is, once it has closed: the hub's short name under the arrow.
    private var label: some View {
        Text(arrival.shortName ?? arrival.hub.name)
            .font(.custom("BeVietnamPro-SemiBold", size: 10, relativeTo: .caption2))
            .foregroundStyle(M.hubPureWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 4)
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }

    /// A plain right arrow, with only a soft shadow so it holds on the photo.
    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(M.hubPureWhite)
            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Explore")
                .backstageText(.label3)
                .foregroundStyle(M.hubPureWhite.opacity(0.7))
            Text(arrival.hub.name)
                .font(.custom("BeVietnamPro-SemiBold", size: 13, relativeTo: .footnote))
                .foregroundStyle(M.hubPureWhite)
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        // A long name is cut short rather than pushing the whole bar off screen.
        .modifier(WidthCap(max: 180))
    }
}

/// Lays its content out at its natural width, but never wider than `max`, even when nothing has offered it a width (inside
/// `fixedSize`, say), so a line of text truncates there instead of running on.
private struct WidthCap: ViewModifier {
    let max: CGFloat

    func body(content: Content) -> some View {
        Capped(max: max) { content }
    }

    private struct Capped: Layout {
        let max: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = min(proposal.width ?? max, max)
            return subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: proposal.height)) ?? .zero
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}

/// A hub's highlight tag.
struct HubTagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .backstageText(.label3)
            .foregroundStyle(M.textPrimary.opacity(0.64))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, R.spacingSpace8)
            .frame(height: 22)
            .background(M.hubSurfaceChip, in: Capsule())
            .opacity(0.9)
    }
}

/// The hub's photo, flipped and blurred under the dark ground, so the image melts into whatever sits below it.
private struct HubMeltedPhoto: View {
    let image: String
    let height: CGFloat
    let meltHeight: CGFloat
    var zoomed = false
    /// How much of the blurred reflection shows. Lower it where a colourful photo would muddy what sits on it.
    var meltStrength: Double = 1

    var body: some View {
        ZStack(alignment: .top) {
            M.backgroundSecondary
            Color.clear
                .frame(height: height)
                .overlay {
                    Image(image).resizable().scaledToFill()
                        .scaleEffect(zoomed ? 1.08 : 1)
                }
                .clipped()
                // Fades the photo before the text starts, so what sits on it stays readable whatever the image.
                .overlay {
                    LinearGradient(stops: [.init(color: M.backgroundSecondary.opacity(0), location: 0.3),
                                           .init(color: M.backgroundSecondary.opacity(0.72), location: 0.62),
                                           .init(color: M.backgroundSecondary.opacity(0.96), location: 0.85)],
                                   startPoint: .top, endPoint: .bottom)
                }
            Color.clear
                .frame(height: meltHeight)
                .overlay {
                    Image(image).resizable().scaledToFill().rotationEffect(.degrees(180))
                }
                .clipped()
                .overlay {
                    LinearGradient(stops: [.init(color: M.backgroundSecondary.opacity(0), location: 0),
                                           .init(color: M.backgroundSecondary.opacity(0.37), location: 0.17),
                                           .init(color: M.backgroundSecondary.opacity(0.6), location: 0.3),
                                           .init(color: M.backgroundSecondary.opacity(0.9), location: 0.5),
                                           .init(color: M.backgroundSecondary, location: 0.75)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .blur(radius: 21)
                .opacity(meltStrength)
                .padding(.top, height - meltHeight * 0.3)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Welcome sheet

/// Full width and above the tab bar, so it's drawn by the app root rather than as a system sheet, which floats inset on iOS 26.
/// It arrives as one piece and never overshoots, with the photo settling behind the content as it comes up.
struct HubWelcomeSheet: View {
    let arrival: HubArrival
    /// 0 at rest, 1 when pulled well down. The root fades its scrim with this, so the sheet feels attached to the page behind it.
    @Binding var dragProgress: CGFloat
    let onClose: () -> Void
    let onExplore: () -> Void
    /// Opens the hub straight on its floors directory.
    var onNavigate: () -> Void = {}
    /// Opens the hub on one of its tabs.
    var onOpenTab: (HubTab) -> Void = { _ in }

    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0
    /// Decided by a drag's first movement: true pulls the sheet, false leaves it to the sideways rail.
    @State private var dragIsVertical: Bool?
    @State private var pastDismissPoint = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dismissDistance: CGFloat = 110
    private let topRadius = R.cornerRadiusCorner20

    var body: some View {
        VStack(spacing: 0) {
            // They're already standing at the hub, so the photo is only a mood strip behind the welcome, not the subject.
            Color.clear.frame(minHeight: 80, maxHeight: 150)
            VStack(spacing: 0) {
                identity
                    .padding(.horizontal, R.spacingSpace16)
                // The same tags as the hub's card on the listing page, full width so they can scroll sideways off both edges.
                HubTagRows(tags: arrival.hub.chips)
                    .padding(.top, R.spacingSpace20)
                if arrival.waypoints.isEmpty {
                    HubArrivalMap(arrival: arrival)
                        .padding(.top, R.spacingSpace24)
                        .padding(.horizontal, R.spacingSpace16)
                }
                // Three steps down the sheet: who it is, what's here, what to do. The buttons get the most air above them.
                actions
                    .padding(.top, R.spacingSpace32)
                    .padding(.horizontal, R.spacingSpace16)
                    .padding(.bottom, 34)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.1), value: appeared)
        }
        .frame(maxWidth: .infinity)
        .background {
            HubMeltedPhoto(image: arrival.hub.hero, height: 290, meltHeight: 240, zoomed: !appeared && !reduceMotion, meltStrength: 0.6)
                .animation(.easeOut(duration: 1.4), value: appeared)
        }
        .overlay(alignment: .top) { grabber }
        .overlay(alignment: .topTrailing) { closeButton }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: topRadius, topTrailingRadius: topRadius))
        .overlay {
            // A lit top edge lifts the sheet off the dark scrim.
            UnevenRoundedRectangle(topLeadingRadius: topRadius, topTrailingRadius: topRadius)
                .strokeBorder(LinearGradient(stops: [.init(color: M.hubPureWhite.opacity(0.22), location: 0),
                                                     .init(color: M.hubPureWhite.opacity(0), location: 0.25)],
                                             startPoint: .top, endPoint: .bottom),
                              lineWidth: R.stroke1Px)
                .allowsHitTesting(false)
        }
        .offset(y: dragOffset)
        .simultaneousGesture(dismissDrag)
        .padding(.top, 56)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityAddTraits(.isModal)
        .sensoryFeedback(trigger: pastDismissPoint) { _, past in past ? .impact(weight: .medium) : nil }
        .onAppear { appeared = true }
    }

    private var grabber: some View {
        Capsule()
            .fill(M.hubPureWhite.opacity(0.56))
            .frame(width: 36, height: 4)
            .padding(.top, R.spacingSpace8)
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(M.iconWhite)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.56), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(R.spacingSpace8)
        .accessibilityLabel("Close")
    }

    /// A cursive "Welcome to" (the same hand as the cards' "Explore"), the name, whether it's open, and what's here with the same
    /// icons as the Home card. A soft dark pool behind the words keeps them readable over the photo.
    private var identity: some View {
        VStack(spacing: R.spacingSpace8) {
            VStack(spacing: 0) {
                Text("Welcome to")
                    .font(.custom("SnellRoundhand-Bold", size: 19))
                    .foregroundStyle(M.hubPureWhite)
                    .shadow(color: .black.opacity(0.8), radius: 4, y: 1)
                Text(arrival.hub.name)
                    .font(.custom("BeVietnamPro-SemiBold", size: 28, relativeTo: .title))
                    .tracking(-0.28)
                    .foregroundStyle(M.hubPureWhite)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                    .accessibilityAddTraits(.isHeader)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: R.spacingSpace12) {
                ForEach(Array(arrival.stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 {
                        Rectangle().fill(M.hubPureWhite.opacity(0.24)).frame(width: 1, height: 13)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: stat.symbol).font(.system(size: 11, weight: .medium))
                        Text(stat.label).backstageText(.label2)
                    }
                    .foregroundStyle(M.hubPureWhite.opacity(0.8))
                    .fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
        }
        .multilineTextAlignment(.center)
    }

    /// Explore is the main way in. An indoor hub also gets a way to find their way around, as a quieter button beside it.
    /// Stacked, so each reads as its own choice: finding the way around (secondary, outlined in solid white) above exploring
    /// everything (primary, solid white) at the bottom.
    private var actions: some View {
        VStack(spacing: R.spacingSpace12) {
            if !arrival.waypoints.isEmpty {
                Button(action: onNavigate) {
                    HStack(spacing: R.spacingSpace8) {
                        // The listing tag's route, drawing itself from where they are to where they're going: the one moving
                        // thing on the button, so it reads as the thing to try while they're standing inside.
                        HubIndoorMapIcon(size: 18, ink: M.iconPrimary, accent: M.iconPrimary)
                        Text("Navigate in \(arrival.hub.name)")
                            .backstageText(.label1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    // Lifted off the sheet with a translucent white fill.
                    .background(M.hubPureWhite.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.32), lineWidth: R.stroke1Px))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Opens the floor map")
            }
            Button(action: onExplore) {
                Text("Explore all")
                    .backstageText(.label1)
                    .foregroundStyle(M.buttonPrimaryLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(M.textPrimary, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragIsVertical == nil {
                    dragIsVertical = abs(value.translation.height) > abs(value.translation.width)
                }
                guard dragIsVertical == true else { return }
                let y = value.translation.height
                // Follows the finger down; barely gives when pulled up.
                dragOffset = y > 0 ? y : y * 0.08
                dragProgress = min(max(y, 0) / 420, 1)
                pastDismissPoint = y > Self.dismissDistance
            }
            .onEnded { value in
                let wasVertical = dragIsVertical == true
                dragIsVertical = nil
                pastDismissPoint = false
                guard wasVertical else { return }
                if value.translation.height > Self.dismissDistance || value.predictedEndTranslation.height > 280 {
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 1)) {
                        dragOffset = 0
                        dragProgress = 0
                    }
                }
            }
    }
}

private struct HubArrivalStats: View {
    let stats: [HubArrival.Stat]
    let style: BackstageTextStyle

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Rectangle().fill(M.borderIntense).frame(width: R.stroke1Px, height: 9)
                }
                HStack(spacing: R.spacingSpace4) {
                    Image(systemName: stat.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(stat.tint)
                    Text(stat.label)
                        .backstageText(style)
                        .foregroundStyle(M.textPrimary.opacity(0.8))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Wraps its items onto as many rows as they need, each row centred.
private struct HubCenteredFlow: Layout {
    var spacing: CGFloat = 6

    private func rows(_ subviews: Subviews, width: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].isEmpty, x + spacing + size.width > width {
                rows.append([])
                x = 0
            }
            x += (rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width
            rows[rows.count - 1].append((index, size))
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(subviews, width: width)
        let height = rows.reduce(0) { $0 + ($1.map(\.size.height).max() ?? 0) } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(row.count - 1, 0))
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            let rowHeight = row.map(\.size.height).max() ?? 0
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
}

/// Getting around inside the hub: a heading with walking directions, over a quiet map with the hub's spots as native Apple Maps
/// markers around the person. The map doesn't take gestures, so dragging on it still moves the sheet; a tap opens the directions.
private struct HubArrivalMap: View {
    let arrival: HubArrival
    @Environment(\.openURL) private var openURL

    private func openDirections() {
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [URLQueryItem(name: "daddr", value: "\(arrival.center.latitude),\(arrival.center.longitude)"),
                             URLQueryItem(name: "q", value: arrival.hub.name),
                             URLQueryItem(name: "dirflg", value: "w")]
        if let url = parts?.url { openURL(url) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack {
                Text("Find your way around")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: R.spacingSpace8)
                Button(action: openDirections) {
                    HStack(spacing: R.spacingSpace4) {
                        Image(systemName: "figure.walk").font(.system(size: 11, weight: .semibold))
                        Text("Directions").backstageText(.button3)
                    }
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Walking directions")
            }
            Map(initialPosition: .region(MKCoordinateRegion(center: arrival.center,
                                                            span: MKCoordinateSpan(latitudeDelta: 0.0036, longitudeDelta: 0.006))),
                interactionModes: []) {
                ForEach(arrival.spots) { spot in
                    Marker(spot.title, systemImage: "sparkles", coordinate: spot.coordinate)
                        .tint(M.brandPurple)
                }
                UserLikeMarker(coordinate: arrival.you)
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .frame(height: 150)
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
            .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
            .onTapGesture(perform: openDirections)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map of \(arrival.hub.name), showing \(arrival.spots.map(\.title).joined(separator: ", "))")
            .accessibilityHint("Opens walking directions")
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// Getting around inside an indoor hub: a heading with a way into the floors directory, and quick tiles for what people look for.
/// Tap gestures rather than Buttons, so pulling the sheet down from a tile doesn't open anything.
private struct HubIndoorNavigation: View {
    let arrival: HubArrival
    let onNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack {
                Text("Find your way inside")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: R.spacingSpace8)
                HStack(spacing: R.spacingSpace4) {
                    Image(systemName: "map").font(.system(size: 11, weight: .semibold))
                    Text("Floor map").backstageText(.button3)
                }
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace12)
                .frame(height: 30)
                .background(Color.white.opacity(0.1), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture(perform: onNavigate)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
            }
            HStack(spacing: R.spacingSpace8) {
                ForEach(arrival.waypoints) { point in
                    VStack(spacing: 6) {
                        Image(systemName: point.symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(M.textPrimary)
                        Text(point.title)
                            .backstageText(.label3)
                            .foregroundStyle(M.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onNavigate)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens the floor map")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
}

/// "Happening here": events, sales and offers as horizontal cards, the photo whole at the hub page's 3:4 on the left and the
/// details on the right. One per page, swiped sideways, with dots when there's more than one.
struct HubHappeningRail: View {
    let items: [HubBuzz]
    let onOpen: () -> Void

    @State private var page: String?

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: 6) {
                HubLiveDot()
                Text("Happening here")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                Spacer(minLength: 0)
                if items.count > 1 { dots }
            }
            .padding(.horizontal, R.spacingSpace16)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace8) {
                    ForEach(items) { item in
                        card(item)
                            .containerRelativeFrame(.horizontal) { width, _ in width - R.spacingSpace16 * 2 }
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .scrollDisabled(items.count < 2)
            .frame(height: 112 + R.spacingSpace8 * 2)
        }
    }

    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Capsule()
                    .fill(M.hubPureWhite.opacity((page ?? items.first?.id) == item.id ? 0.9 : 0.3))
                    .frame(width: (page ?? items.first?.id) == item.id ? 12 : 5, height: 5)
            }
        }
        .animation(.smooth(duration: 0.25), value: page)
        .accessibilityHidden(true)
    }

    private func card(_ item: HubBuzz) -> some View {
        HStack(spacing: R.spacingSpace12) {
            // The whole picture, at the hub page's 3:4.
            Image(item.image)
                .resizable()
                .aspectRatio(3 / 4, contentMode: .fill)
                .frame(width: 84, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                    .strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(item.title)
                    .backstageText(.hubTitle2)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .backstageText(.label2)
                        .foregroundStyle(M.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: R.spacingSpace8)
                HStack(spacing: R.spacingSpace4) {
                    Text("View details").backstageText(.button3)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(M.textPrimary)
            }
            .padding(.vertical, R.spacingSpace4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
        }
        .frame(height: 112)
        .padding(R.spacingSpace8)
        .background(M.hubPureWhite.opacity(0.06), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .contentShape(Rectangle())
        // A tap, not a Button, so pulling the sheet down never fires it.
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// "Jump right in": every way into the hub as a sideways row of tiles, so a hub with movies, events or play fits as easily as
/// one with four categories. On arrival the row nudges left and settles back, hinting that there's more.
struct HubQuickLinkRail: View {
    enum Icon {
        case asset(String)
        case symbol(String)
    }

    struct Link: Identifiable {
        var id: String { title }
        let title: String
        let icon: Icon
        let action: () -> Void
    }

    let links: [Link]
    var title: String? = "Jump right in"

    @State private var nudge: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            if let title {
                Text(title)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace16)
                    .accessibilityAddTraits(.isHeader)
            }
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(links) { tile($0) }
                }
                .offset(x: nudge)
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
        .task {
            guard !reduceMotion, links.count > 4 else { return }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 0.45)) { nudge = -56 }
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { nudge = 0 }
        }
    }

    private func tile(_ link: Link) -> some View {
        VStack(spacing: R.spacingSpace8) {
            Group {
                switch link.icon {
                case .asset(let name):
                    Image(name).resizable().scaledToFit()
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(M.iconPrimary)
                }
            }
            .frame(width: 32, height: 32)
            Text(link.title)
                .backstageText(.label2)
                .foregroundStyle(M.textPrimary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 84, height: 82)
        .background(M.hubPureWhite.opacity(0.06), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .contentShape(Rectangle())
        .onTapGesture(perform: link.action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The person's position, drawn like the system location dot.
private struct UserLikeMarker: MapContent {
    let coordinate: CLLocationCoordinate2D

    var body: some MapContent {
        Annotation("You", coordinate: coordinate, anchor: .center) {
            Circle()
                .fill(Color(hex: 0x3D8BFF))
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(M.hubPureWhite, lineWidth: R.stroke2Px))
                .background(Circle().fill(Color(hex: 0x3D8BFF).opacity(0.22)).frame(width: 34, height: 34))
        }
        .annotationTitles(.hidden)
    }
}

// MARK: - "You're here" card

/// The card under Home's "You're here" heading (Figma 1-Nidhi-Workspace 3884:7483): the photo inset with the name, what's inside and
/// the hub's tags melting into a mirrored blur at its bottom; under it, "Find your way inside" over a faded floor plan that slowly turns,
/// all lit by a glow in the photo's own colour.
struct HubHereCard: View {
    let arrival: HubArrival
    let onOpen: () -> Void
    /// Opens the hub straight on its floors directory.
    var onNavigate: () -> Void = {}

    @State private var nudging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var indoor: Bool { !arrival.waypoints.isEmpty }

    private let outer = RoundedRectangle(cornerRadius: 20, style: .continuous)
    private static let photoInset: CGFloat = 8
    private static let photoRadius: CGFloat = 20 - photoInset
    private let inner = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Group {
            if indoor { navigable } else { full }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { if !reduceMotion { nudging = true } }
    }

    /// A hub you can find your way around: the photo as a pin over a turning street map, with the way in underneath.
    private var navigable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) { photo }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityName)
                .accessibilityHint("Opens the hub's details")
                .accessibilityAddTraits(.isButton)
                // The tags scroll sideways, so the words sit over the button rather than inside it, where a scroll would fight
                // the press. The button's label already reads them out.
                .overlay(alignment: .bottomLeading) { details(full: false).accessibilityHidden(true) }
                // Behind the photo, centred on the pin's point.
                .background(alignment: .bottom) { beacon }
            Button(action: onNavigate) { footer }
                .buttonStyle(PressableStyle())
        }
        // The photo sits in the card with even air on three sides; its corners are the card's 20 less this inset, so they run parallel.
        .padding(.horizontal, Self.photoInset)
        .padding(.top, Self.photoInset)
        .background { backdrop }
        .clipShape(outer)
        .overlay(outer.strokeBorder(M.hubPureWhite.opacity(0.06), lineWidth: R.stroke1Px))
        .contentShape(outer)
    }

    /// A hub without in-hub navigation: the photo fills the card, with every tag in two rows like the listing cards.
    private var full: some View {
        Button(action: onOpen) {
            Color.clear
                .frame(height: 292)
                .overlay { Image(arrival.hub.hero).resizable().scaledToFill() }
                .overlay(alignment: .top) { mirror(height: 250, from: 166) }
                .overlay(alignment: .topTrailing) { cornerArrow }
                .clipShape(outer)
        }
        .buttonStyle(PressableStyle())
        // The tag rows scroll, so they sit over the button rather than inside it.
        .overlay(alignment: .bottomLeading) { details(full: true) }
        .overlay { photoRim }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityName)
    }

    /// The full card's outline: a faint white hairline, a touch brighter at the top-left where the light catches it.
    private var photoRim: some View {
        outer
            .strokeBorder(LinearGradient(colors: [M.hubPureWhite.opacity(0.16), M.hubPureWhite.opacity(0.06)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                          lineWidth: 0.75)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A white rim painted only where `stroke` draws: brightest at the bottom centre and fading out towards both edges,
    /// so it sits just around the pin's base.
    private func photoRim<S: View>(_ stroke: S, opacity: Double) -> some View {
        M.hubPureWhite.opacity(0.22)
            .mask(stroke)
            .mask {
                GeometryReader { geo in
                    RadialGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black.opacity(0.8), location: 0.45),
                                           .init(color: .clear, location: 1)],
                                   center: .bottom, startRadius: 0, endRadius: geo.size.width * 0.8)
                }
            }
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var accessibilityName: String {
        "\(arrival.hub.name). \(arrival.stats.map(\.label).joined(separator: ", "))"
    }

    // MARK: Photo

    private var photo: some View {
        Color.clear
            .frame(height: 232 + HubPinCallout.pointer)
            .overlay {
                Image(arrival.hub.hero).resizable().scaledToFill()
            }
            .overlay(alignment: .top) { mirror(height: 210, from: 160) }
            .overlay(alignment: .topTrailing) { cornerArrow }
            .clipShape(HubPinCallout(radius: Self.photoRadius))
            // A white rim along the base: brightest at the pointer, fading out to both edges.
            .overlay { photoRim(HubPinCallout(radius: Self.photoRadius).stroke(lineWidth: 1), opacity: 0.95) }
            // Lifted off the map like a pin, gently.
            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    /// The photo, mirrored, blurred and dimmed, rising behind the words so the bottom melts into them.
    private func mirror(height: CGFloat, from top: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .padding(.horizontal, -76)
            .overlay { Image(arrival.hub.hero).resizable().scaledToFill() }
            .clipped()
            .rotationEffect(.degrees(180))
            .overlay(Color.black.opacity(0.62))
            .blur(radius: 28)
            .offset(y: top)
            .allowsHitTesting(false)
    }

    private var cornerArrow: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(M.hubPureWhite)
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(M.hubPureWhite.opacity(0.18), lineWidth: 0.5))
            .padding(10)
            .accessibilityHidden(true)
    }

    private func details(full: Bool) -> some View {
        // A clear gap between what's here and the tags.
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    // A small cursive kicker (iOS's Snell Roundhand, bold cut so it reads), shadowed so it holds on the photo.
                    Text("Explore")
                        .font(.custom("SnellRoundhand-Bold", size: 18))
                        .foregroundStyle(M.hubPureWhite.opacity(0.92))
                        .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    Text(arrival.hub.name)
                        .backstageText(.hubTitle2)
                        .foregroundStyle(M.hubPureWhite)
                        .lineLimit(1)
                }
                HStack(spacing: R.spacingSpace12) {
                    ForEach(Array(arrival.stats.reversed().enumerated()), id: \.element.id) { index, stat in
                        if index > 0 {
                            Rectangle()
                                .fill(M.hubPureWhite.opacity(0.24))
                                .frame(width: 1, height: 15)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: stat.symbol)
                                .font(.system(size: 11, weight: .medium))
                            Text(stat.label).backstageText(.label2)
                        }
                        .foregroundStyle(M.hubPureWhite.opacity(0.8))
                        .fixedSize()
                    }
                }
            }
            .padding(.leading, 11)
            .allowsHitTesting(false)
            if full {
                HubTagRows(tags: arrival.hub.chips, margin: 11)
            } else {
                // One row that scrolls sideways and runs off the right edge, fading there, so the last tag reads as cut off: there's more.
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        // Short tags only: a long one would take the whole row on its own.
                        ForEach(Array(arrival.hub.chips.filter { $0.count <= 18 }.enumerated()), id: \.offset) { _, chip in
                            Text(chip)
                                .backstageText(.label3)
                                .foregroundStyle(M.hubPureWhite.opacity(0.7))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(M.hubPureWhite.opacity(0.08), in: Capsule())
                                .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                        }
                    }
                }
                .contentMargins(.horizontal, 11, for: .scrollContent)
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.03),
                                           .init(color: .black, location: 0.84), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                }
                // A tap on the tags still opens the hub, like the rest of the photo.
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
            }
        }
        .padding(.bottom, full ? 14 : 14 + HubPinCallout.pointer)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Text("Navigate inside \(arrival.hub.name)")
                .backstageText(.title4)
                .foregroundStyle(M.hubPureWhite)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.45), radius: 6)
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(M.hubPureWhite)
                .offset(x: nudging ? 2 : -1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: nudging)
            Spacer(minLength: 0)
        }
        .padding(.leading, 16 - Self.photoInset)
        .padding(.top, 16 - HubPinCallout.pointer)
        .padding(.bottom, 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Navigate inside \(arrival.hub.name)")
        .accessibilityHint("Opens the floor map")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Backdrop

    /// Dark ground with the street map under the footer. The ground stays dark and clean; all the light comes from the beacon
    /// at the pin's point, so the card reads as lit rather than washed out.
    private var backdrop: some View {
        M.backgroundSecondary
            .overlay(alignment: .bottom) {
                HubStreetMap()
                    .frame(height: 150)
                    // Fades out going up into the card.
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: .clear, location: 0.3),
                                               .init(color: .black, location: 0.8),
                                               .init(color: .black, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    // Clearest under the beacon and falling off into the dark around it, like streets caught in a lamp's light.
                    .mask {
                        RadialGradient(stops: [.init(color: .black, location: 0),
                                               .init(color: .black.opacity(0.55), location: 0.45),
                                               .init(color: .clear, location: 1)],
                                       center: UnitPoint(x: 0.5, y: 0.66), startRadius: 0, endRadius: 200)
                    }
                    .opacity(0.8)
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// The light under the pin: a small sphere of light at its point, half hidden behind the photo so the pin seems to rest on it,
    /// and a pool it throws across the map, flattened to the map's tilt. Added to what's beneath rather than laid over it, so it
    /// brightens the streets instead of greying the card. Breathes very slowly, like a live location.
    private var beacon: some View {
        ZStack {
            // A faint rise of the same light up the card's frame, so the edges around the photo catch a little of it, all the
            // way to the top, but only just.
            RadialGradient(stops: [.init(color: M.hubPureWhite.opacity(0.08), location: 0),
                                   .init(color: M.hubPureWhite.opacity(0.05), location: 0.45),
                                   .init(color: M.hubPureWhite.opacity(0.025), location: 0.75),
                                   .init(color: M.hubPureWhite.opacity(0), location: 1)],
                           center: .center, startRadius: 0, endRadius: 340)
                .frame(width: 680, height: 680)
                .scaleEffect(x: 0.8, y: 1)
            // A broad, even wash with a long, gentle falloff: the light spreads along the footer rather than gathering in the middle.
            RadialGradient(stops: [.init(color: M.hubPureWhite.opacity(0.11), location: 0),
                                   .init(color: M.hubPureWhite.opacity(0.09), location: 0.3),
                                   .init(color: M.hubPureWhite.opacity(0.05), location: 0.6),
                                   .init(color: M.hubPureWhite.opacity(0.015), location: 0.82),
                                   .init(color: M.hubPureWhite.opacity(0), location: 1)],
                           center: .center, startRadius: 0, endRadius: 230)
                .frame(width: 460, height: 460)
                .scaleEffect(x: 1, y: 0.36)
            // The sphere: soft and low, only a hint brighter than the wash, so it reads as the source without becoming a hotspot.
            RadialGradient(stops: [.init(color: M.hubPureWhite.opacity(0.13), location: 0),
                                   .init(color: M.hubPureWhite.opacity(0.07), location: 0.35),
                                   .init(color: M.hubPureWhite.opacity(0.02), location: 0.7),
                                   .init(color: M.hubPureWhite.opacity(0), location: 1)],
                           center: .center, startRadius: 0, endRadius: 58)
                .frame(width: 116, height: 116)
                .scaleEffect(x: 1.3, y: 1)
                .opacity(nudging ? 1 : 0.75)
                .scaleEffect(nudging ? 1.06 : 0.94)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: nudging)
        }
        // The whole light, turned down as one, so its shape stays the same.
        .opacity(0.6)
        .blendMode(.plusLighter)
        // A zero-size anchor on the photo's bottom edge, a little above the pointer's tip, so the sphere sits up into the pin.
        .frame(width: 0, height: 0)
        .offset(y: -4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Live photo

/// The hub's photo in a circle, with a thin ring of the photo's own colour slowly sweeping round it: live, and here.
struct HubLiveThumb: View {
    let image: String
    var size: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = HubPhotoTint.of(image).ink
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(AngularGradient(stops: [.init(color: tint.opacity(0), location: 0),
                                                              .init(color: tint.opacity(0.35), location: 0.5),
                                                              .init(color: M.hubPureWhite, location: 1)],
                                                      center: .center),
                                      lineWidth: 1.5)
                        .rotationEffect(.degrees(turn * 360))
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(M.hubTextSuccess)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.7), lineWidth: 1.5))
                        .offset(x: -1, y: -1)
                }
        }
        .accessibilityHidden(true)
    }
}

/// A photo's dominant colour: in its lower half, the hue that carries the most saturated, lit pixels, as a rich mid-dark glow (white text stays readable
/// on it) and a lighter tone. Cached per image.
struct HubPhotoTint {
    let glow: Color
    let ink: Color

    private static var cache: [String: HubPhotoTint] = [:]

    static func of(_ name: String) -> HubPhotoTint {
        if let hit = cache[name] { return hit }
        let made = read(name) ?? HubPhotoTint(glow: Color(hue: 0.63, saturation: 0.6, brightness: 0.6), ink: Color(hex: 0x707DBC))
        cache[name] = made
        return made
    }

    private static func read(_ name: String) -> HubPhotoTint? {
        guard let cg = UIImage(named: name)?.cgImage else { return nil }
        let n = 36
        var px = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))

        let bins = 18
        var weight = [CGFloat](repeating: 0, count: bins)
        var sums = [(r: CGFloat, g: CGFloat, b: CGFloat)](repeating: (0, 0, 0), count: bins)
        // The lower half only: that's the part of the photo the glow sits against.
        for i in stride(from: px.count / 2, to: px.count, by: 4) {
            let r = CGFloat(px[i]) / 255, g = CGFloat(px[i + 1]) / 255, b = CGFloat(px[i + 2]) / 255
            var h: CGFloat = 0, sat: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &sat, brightness: &v, alpha: &a)
            guard sat > 0.18, v > 0.2 else { continue }
            let w = sat * v
            let k = min(Int(h * CGFloat(bins)), bins - 1)
            weight[k] += w
            sums[k].r += r * w; sums[k].g += g * w; sums[k].b += b * w
        }
        guard let top = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[top] > 0 else { return nil }
        let c = sums[top]
        var h: CGFloat = 0, sat: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        UIColor(red: c.r / weight[top], green: c.g / weight[top], blue: c.b / weight[top], alpha: 1)
            .getHue(&h, saturation: &sat, brightness: &v, alpha: &a)
        let glow = Color(hue: h, saturation: min(max(sat * 1.4, 0.75), 0.95), brightness: 0.78)
        let ink = Color(hue: h, saturation: min(max(sat, 0.35), 0.6), brightness: 0.85)
        return HubPhotoTint(glow: glow, ink: ink)
    }
}

/// The photo's outline: a rounded rectangle with a small pointer at the bottom centre, like a map pin's callout.
struct HubPinCallout: Shape {
    static let pointer: CGFloat = 8
    var radius: CGFloat = 16
    var halfWidth: CGFloat = 9

    /// The body uses continuous corners, the same as the card around it, so the two outlines run parallel all the way round.
    /// The pointer is joined on as one outline, so a stroke follows the whole shape without a seam.
    func path(in rect: CGRect) -> Path {
        let p = Self.pointer
        let bottom = rect.maxY - p
        let mid = rect.midX
        let body = RoundedRectangle(cornerRadius: radius, style: .continuous)
            .path(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bottom - rect.minY))
        var pointer = Path()
        // Starts a little inside the body so the two overlap and join cleanly.
        pointer.move(to: CGPoint(x: mid + halfWidth, y: bottom - 1))
        pointer.addLine(to: CGPoint(x: mid + halfWidth, y: bottom))
        // Soft-tipped pointer.
        pointer.addQuadCurve(to: CGPoint(x: mid, y: rect.maxY), control: CGPoint(x: mid + 2, y: rect.maxY - 1))
        pointer.addQuadCurve(to: CGPoint(x: mid - halfWidth, y: bottom), control: CGPoint(x: mid - 2, y: rect.maxY - 1))
        pointer.addLine(to: CGPoint(x: mid - halfWidth, y: bottom - 1))
        pointer.closeSubpath()
        return body.union(pointer)
    }
}

/// A street map drawn as lines only, laid back in perspective and turning very slowly, like the faded city grid under a navigation pin.
/// The streets are a fixed, seeded subdivision: a few arterial roads, then smaller streets splitting the blocks at slight angles.
struct HubStreetMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let side: CGFloat = 640
    private static let streets = HubStreetGrid(side: side)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(t.truncatingRemainder(dividingBy: 140) / 140 * 360)
            Canvas { ctx, _ in
                let s = Self.streets
                ctx.stroke(s.lanes, with: .color(.white.opacity(0.2)), lineWidth: 1.4)
                ctx.stroke(s.streets, with: .color(.white.opacity(0.3)), lineWidth: 2.2)
                ctx.stroke(s.arterials, with: .color(.white.opacity(0.38)), lineWidth: 3.8)
                for place in s.places { draw(place, in: ctx, upright: -angle) }
            }
            .frame(width: Self.side, height: Self.side)
            .rotationEffect(angle)
            .scaleEffect(0.6)
            .rotation3DEffect(.degrees(58), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: 10)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A small icon in a soft circle, turned against the map so it stays upright. No names: the map is a mood, not a directory.
    private func draw(_ place: HubStreetGrid.Place, in ctx: GraphicsContext, upright: Angle) {
        var ctx = ctx
        ctx.translateBy(x: place.point.x, y: place.point.y)
        ctx.rotate(by: upright)
        ctx.opacity = 0.8
        let disc = CGRect(x: -13, y: -13, width: 26, height: 26)
        ctx.fill(Path(ellipseIn: disc), with: .color(.white.opacity(0.16)))
        ctx.stroke(Path(ellipseIn: disc), with: .color(.white.opacity(0.3)), lineWidth: 1)
        var icon = ctx.resolve(Image(systemName: place.icon))
        icon.shading = .color(.white.opacity(0.85))
        ctx.draw(icon, in: CGRect(x: -7.5, y: -7.5, width: 15, height: 15))
    }
}

/// Builds the street lines once by recursively splitting quads between points on opposite edges.
private struct HubStreetGrid {
    var arterials = Path()
    var streets = Path()
    var lanes = Path()
    /// A few shops and restaurants on block centres.
    var places: [Place] = []
    private var blocks: [CGPoint] = []

    struct Place {
        let point: CGPoint
        let icon: String
        let name: String?
    }

    private static let kinds: [(icon: String, name: String?)] = [
        ("bag.fill", "Gucci"), ("fork.knife", nil), ("cup.and.saucer.fill", "Café Delhi Heights"), ("bag.fill", nil),
        ("tshirt.fill", "Burberry"), ("fork.knife", "Indian Accent"), ("sparkles", nil), ("bag.fill", "Dior"),
        ("cup.and.saucer.fill", nil), ("tshirt.fill", "Louis Vuitton"), ("fork.knife", nil), ("gift.fill", "Tiffany & Co."),
        ("bag.fill", nil), ("fork.knife", "Pa Pa Ya"), ("eyeglasses", nil), ("cup.and.saucer.fill", "Blue Tokai"),
    ]

    init(side: CGFloat) {
        var rng = HubStreetRandom(seed: 7)
        let quad = [CGPoint(x: 0, y: 0), CGPoint(x: side, y: 0), CGPoint(x: side, y: side), CGPoint(x: 0, y: side)]
        split(quad, depth: 0, rng: &rng)
        // Spread them out: skip blocks too close to one already chosen.
        var chosen: [CGPoint] = []
        for b in blocks.shuffledSeeded(&rng) where chosen.allSatisfy({ hypot($0.x - b.x, $0.y - b.y) > 170 }) {
            chosen.append(b)
        }
        places = chosen.enumerated().map { i, point in
            let kind = Self.kinds[i % Self.kinds.count]
            return Place(point: point, icon: kind.icon, name: kind.name)
        }
    }

    private mutating func split(_ q: [CGPoint], depth: Int, rng: inout HubStreetRandom) {
        func len(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ f: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f) }
        let w = (len(q[0], q[1]) + len(q[3], q[2])) / 2
        let h = (len(q[1], q[2]) + len(q[0], q[3])) / 2
        let centre = CGPoint(x: (q[0].x + q[1].x + q[2].x + q[3].x) / 4, y: (q[0].y + q[1].y + q[2].y + q[3].y) / 4)
        guard min(w, h) > 22, depth < 11 else { blocks.append(centre); return }
        if depth >= 5 && rng.next() < 0.18 { blocks.append(centre); return }   // leave some blocks whole

        let a = 0.5 + (rng.next() - 0.5) * 0.36
        let b = min(max(a + (rng.next() - 0.5) * 0.2, 0.2), 0.8)
        let start: CGPoint, end: CGPoint
        let first: [CGPoint], second: [CGPoint]
        if w >= h {
            start = lerp(q[0], q[1], a); end = lerp(q[3], q[2], b)
            first = [q[0], start, end, q[3]]; second = [start, q[1], q[2], end]
        } else {
            start = lerp(q[1], q[2], a); end = lerp(q[0], q[3], b)
            first = [q[0], q[1], start, end]; second = [end, start, q[2], q[3]]
        }
        var line = Path()
        line.move(to: start)
        if depth < 2 {
            // Arterial roads bend gently.
            let mid = lerp(start, end, 0.5)
            line.addQuadCurve(to: end, control: CGPoint(x: mid.x + (rng.next() - 0.5) * 60, y: mid.y + (rng.next() - 0.5) * 60))
        } else {
            line.addLine(to: end)
        }
        switch depth {
        case 0..<2: arterials.addPath(line)
        case 2..<4: streets.addPath(line)
        default: lanes.addPath(line)
        }
        split(first, depth: depth + 1, rng: &rng)
        split(second, depth: depth + 1, rng: &rng)
    }
}

private extension Array {
    func shuffledSeeded(_ rng: inout HubStreetRandom) -> [Element] {
        var a = self
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, Int(rng.next() * CGFloat(i + 1)) % (i + 1))
        }
        return a
    }
}

/// A small deterministic generator, so the street map is the same on every launch.
private struct HubStreetRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 1_000_000) / 1_000_000
    }
}

// MARK: - Highlighting the Hubs tab

/// Quiets the page behind the reveal so its words stay readable: a dark gradient and a soft blur, rising from the bottom of the screen and
/// ending around the top of the beam. Everything above stays untouched.
struct HubsRevealBackdrop: View {
    var body: some View {
        ZStack {
            // Sharp and blurred mixed together: a full-strength material would wipe out the page behind it.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black, location: 0.62),
                                           .init(color: .clear, location: 1)],
                                   startPoint: .bottom, endPoint: .top)
                }
            LinearGradient(stops: [.init(color: .black.opacity(0.78), location: 0),
                                   .init(color: .black.opacity(0.66), location: 0.62),
                                   .init(color: .black.opacity(0), location: 1)],
                           startPoint: .bottom, endPoint: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The Hubs tab while it's being introduced: a torch inside the nav. There's no fill and no shape around the tab. While the reveal plays,
/// one unbroken beam starts at the bar's bottom edge and shines straight up out of it, its colour turning to each hub type's as it comes up. Afterwards
/// the light goes out completely, leaving just the NEW tag.
struct HubsTabPill: View {
    let revealIndex: Int
    /// False once the reveal has played or while the bar is compact: no light at all.
    let rising: Bool

    var body: some View {
        ZStack {
            HubsTorchLight(index: revealIndex, shining: rising)
            if rising {
                HubsTabRising(index: revealIndex)
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct HubsTorchLight: View {
    let index: Int
    let shining: Bool
    /// Whether the torch is on. It grows up out of the bar and brightens, then dims and sinks back, rather than simply appearing and vanishing.
    @State private var lit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The bottom edge of the bar, measured from the top of the tab. The light is cut off exactly here.
    private static let barBottom: CGFloat = 60
    /// The beam carries on past that edge, so it's at full strength where it's cut rather than tapering away above it.
    private static let pastBar: CGFloat = 22
    private static let beamHeight = HubsTabReveal.artSize + 188
    private static let windowHeight = beamHeight + 20

    private struct Cone: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX - rect.width * 0.05, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.05, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }

    /// The light itself. Its colour is animated value by value in OKLCH, so moving from one hub type's colour to the next keeps the
    /// beam's brightness steady and only turns the hue: no dip from two beams cross-fading, and no muddy grey halfway between.
    private struct Beam: View, Animatable {
        var tint: BeamTint

        var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
            get { .init(tint.lightness, .init(tint.chroma, tint.hue)) }
            set { tint = BeamTint(lightness: newValue.first, chroma: newValue.second.first, hue: newValue.second.second) }
        }

        var body: some View {
            let colour = tint.color
            Cone()
                .fill(LinearGradient(colors: [colour.opacity(0.72), colour.opacity(0)], startPoint: .bottom, endPoint: .top))
                .blur(radius: 13)
        }
    }

    @State private var tint: BeamTint

    init(index: Int, shining: Bool) {
        self.index = index
        self.shining = shining
        _tint = State(initialValue: BeamTint(HubsTabReveal.item(index).tint))
    }

    /// The hue turns the short way round, slowly and evenly, landing as the new hub type finishes rising.
    private func changeColour(to index: Int) {
        var next = BeamTint(HubsTabReveal.item(index).tint)
        next.hue = tint.hue + remainder(next.hue - tint.hue, 2 * .pi)
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.9)) { tint = next }
    }

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                Color.clear
                    .frame(width: 560, height: Self.windowHeight)
                    .overlay(alignment: .bottom) {
                        Beam(tint: tint)
                            .frame(width: 230, height: Self.beamHeight)
                            // Switching on and off are mirror images: it grows up out of the bar's bottom edge and sinks back into it.
                            .scaleEffect(x: lit ? 1 : 0.55, y: lit ? 1 : 0.1, anchor: .bottom)
                            .opacity(lit ? 1 : 0)
                            .offset(y: Self.pastBar)
                    }
                    .clipped()
                    .offset(y: Self.barBottom - Self.windowHeight)
            }
            .allowsHitTesting(false)
            .onChange(of: index) { changeColour(to: index) }
            .onChange(of: shining) { switchLight(on: shining) }
            .onAppear { if shining { switchLight(on: true) } }
    }

    private func switchLight(on: Bool) {
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.2) : on ? .easeOut(duration: 0.72) : .easeIn(duration: 0.65)
        withAnimation(animation) { lit = on }
    }
}

/// A colour as OKLCH: perceived lightness, colourfulness and hue angle (radians, left unwrapped so animations can turn past 2π).
private struct BeamTint {
    var lightness: Double
    var chroma: Double
    var hue: Double

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    init(_ colour: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(colour).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let (lr, lg, lb) = (linear(r), linear(g), linear(b))
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        let okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        chroma = hypot(okA, okB)
        hue = atan2(okB, okA)
    }

    var color: Color {
        let okA = chroma * cos(hue), okB = chroma * sin(hue)
        let l = pow(lightness + 0.3963377774 * okA + 0.2158037573 * okB, 3)
        let m = pow(lightness - 0.1055613458 * okA - 0.0638541728 * okB, 3)
        let s = pow(lightness - 0.0894841775 * okA - 1.2914855480 * okB, 3)
        func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
        return Color(.sRGBLinear,
                     red: clamp(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                     green: clamp(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                     blue: clamp(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }
}

/// The sound and haptics of each hub type arriving, both shaped by the beam's swing: stronger as it moves fastest, easing off at the turn,
/// then landing as it comes back to centre, about 0.8s in. The sound is ambient: silent mode mutes it and it mixes with other audio.
final class HubsRevealFeedback {
    static let shared = HubsRevealFeedback()

    private var players: [Int: AVAudioPlayer] = [:]
    private var engine: CHHapticEngine?
    private var sessionReady = false

    func play(step: Int) {
        playSound(step % HubsTabReveal.items.count)
        playHaptics()
    }

    private func playSound(_ step: Int) {
        if !sessionReady {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try? AVAudioSession.sharedInstance().setActive(true)
            sessionReady = true
        }
        if players[step] == nil, let asset = NSDataAsset(name: "hub_rise_\(step)") {
            let player = try? AVAudioPlayer(data: asset.data, fileTypeHint: AVFileType.wav.rawValue)
            player?.volume = 0.6
            player?.prepareToPlay()
            players[step] = player
        }
        players[step]?.currentTime = 0
        players[step]?.play()
    }

    private func playHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                engine.isAutoShutdownEnabled = true
                engine.resetHandler = { [weak self] in self?.engine = nil }
                self.engine = engine
            }
            try engine?.start()
            let swing = CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)],
                                      relativeTime: 0, duration: 0.82)
            let landing = CHHapticEvent(eventType: .hapticTransient,
                                        parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                                                     CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)],
                                        relativeTime: 0.82)
            let speed = CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                               controlPoints: [.init(relativeTime: 0, value: 0),
                                                               .init(relativeTime: 0.2, value: 0.34),
                                                               .init(relativeTime: 0.4, value: 0.04),
                                                               .init(relativeTime: 0.62, value: 0.28),
                                                               .init(relativeTime: 0.82, value: 0)],
                                               relativeTime: 0)
            let pattern = try CHHapticPattern(events: [swing, landing], parameterCurves: [speed])
            try engine?.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil
        }
    }
}

/// The hub types the tab reveals in turn, with the light each one rises in.
enum HubsTabReveal {
    struct Item {
        let art: String
        let word: String
        let tint: Color
        let tilt: Double
    }

    static let items = [Item(art: "hub_cat_malls", word: "Malls", tint: Color(hex: 0x57E0C8), tilt: 0),
                        Item(art: "hub_cat_highstreet", word: "High street", tint: Color(hex: 0xFFB866), tilt: 0),
                        Item(art: "hub_cat_markets", word: "Markets", tint: Color(hex: 0x5EA8FF), tilt: 0),
                        Item(art: "hub_cat_hotels", word: "Hotels", tint: Color(hex: 0xFF7A7A), tilt: 0),
                        Item(art: "hub_cat_beaches", word: "Beaches", tint: Color(hex: 0x7AD7FF), tilt: 0)]

    /// A little smaller on shorter phones.
    static let artSize: CGFloat = UIScreen.main.bounds.height < 860 ? 80 : 92

    static func item(_ index: Int) -> Item { items[index % items.count] }
}

/// A hub type rising in the tab's light. A window that fades out at the bottom sits just above the text, so each one comes up out of the
/// light as the last sinks back into it. The old one drops as the beam starts turning colour, and the new one reaches the
/// top as the colour lands. Positions are from the top of the tab.
private struct HubsTabRising: View {
    let index: Int
    /// What's on stage. Nil for the beat between one hub type leaving and the next arriving.
    @State private var shown: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let artSize = HubsTabReveal.artSize
    private static let hiddenOffset = artSize + 12
    private static let windowHeight = artSize + 36
    /// The top of the text below, which sits clear of the bar.
    private static let windowBottom: CGFloat = -66
    private static let fade: CGFloat = 16
    /// When the new art starts up, so it rises through the colour change.
    private static let arrival: Double = 0.27

    private func bringIn(_ value: Int) async {
        guard !reduceMotion else {
            shown = value
            return
        }
        if shown != nil {
            withAnimation(.easeIn(duration: 0.17)) { shown = nil }
        }
        try? await Task.sleep(for: .seconds(Self.arrival))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { shown = value }
    }

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                ZStack(alignment: .bottom) {
                    if let shown {
                        let item = HubsTabReveal.item(shown)
                        Image(item.art)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Self.artSize, height: Self.artSize)
                            .rotationEffect(.degrees(item.tilt))
                            .shadow(color: item.tint.opacity(0.35), radius: 12)
                            .padding(.bottom, 6)
                            .id(shown)
                            .transition(.offset(y: Self.hiddenOffset))
                    }
                }
                .frame(width: 220, height: Self.windowHeight, alignment: .bottom)
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black, location: 1 - Self.fade / Self.windowHeight),
                                           .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .offset(y: Self.windowBottom - Self.windowHeight)
            }
            .overlay(alignment: .top) {
                if !reduceMotion, let shown {
                    ZStack {
                        Sparkle(trigger: shown, delay: 0.3).offset(x: -Self.artSize * 0.62, y: -72 - Self.artSize * 0.85)
                        Sparkle(trigger: shown, delay: 0.42).offset(x: Self.artSize * 0.64, y: -72 - Self.artSize * 0.45)
                    }
                }
            }
            .allowsHitTesting(false)
            .task(id: index) { await bringIn(index) }
    }
}

/// A glint that flares once as each hub type comes up.
private struct Sparkle: View {
    let trigger: Int
    let delay: Double

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(M.hubPureWhite)
            .phaseAnimator([0.0, 1.0, 0.0], trigger: trigger) { view, phase in
                view
                    .scaleEffect(phase)
                    .opacity(phase)
                    .rotationEffect(.degrees(phase * 40))
            } animation: { phase in
                phase == 1 ? .easeOut(duration: 0.26).delay(delay) : .easeIn(duration: 0.34)
            }
            .accessibilityHidden(true)
    }
}

/// The words under the rising art, all plain white: a tiny, letter-spaced EXPLORE over a much larger hub type. The hub type rolls in step
/// with the art, and the art above is part of the tap target.
struct HubsTabSign: View {
    let index: Int
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var word: String {
        reduceMotion ? "Hubs" : HubsTabReveal.item(index).word
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Color.clear.frame(width: HubsTabReveal.artSize, height: HubsTabReveal.artSize)
                Text("EXPLORE")
                    .backstageText(.finePrint2)
                    .tracking(2.4)
                    .foregroundStyle(M.hubPureWhite)
                    .padding(.bottom, 2)
                Text(word)
                    .backstageText(.hubTitle1)
                    .foregroundStyle(M.hubPureWhite)
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.36).delay(0.38), value: index)
            }
            // Neutral and tight: keeps the words readable over a sharp page.
            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("New: Explore hubs")
        .accessibilityHint("Opens Hubs")
    }
}

/// Marks the Hubs tab as new.
struct HubsNewTag: View {
    var body: some View {
        Text("NEW")
            .backstageText(.finePrint2)
            .foregroundStyle(M.hubPureWhite)
            .padding(.horizontal, 5)
            .frame(height: 14)
            .background(M.hubBadgeNew, in: Capsule())
            .accessibilityHidden(true)
    }
}

// MARK: - Curtain

/// The hub behind Home. It sits fixed behind the top of the page, so pulling Home down (or Home sliding down on its own to
/// peek) uncovers it from the top, with a line pinned to the page's edge saying what's there. Pulled far enough, it arms; let
/// go and the hub opens.
struct HubCurtain: View {
    let arrival: HubArrival
    /// How far Home has come down.
    let reveal: CGFloat
    let armed: Bool
    var onOpen: () -> Void = {}

    /// How far down a pull has to come to open the hub.
    static let threshold: CGFloat = 120
    /// How far Home slides when it peeks on its own: enough for the line, not enough to arm.
    static let peek: CGFloat = 112

    var body: some View {
        let progress = min(max(reveal / Self.threshold, 0), 1)
        GeometryReader { geo in
            // This sits at the top of the safe area; the photo runs on up under the status bar to the screen's edge.
            let top = max(geo.frame(in: .global).minY, 0)
            Color.clear
                .frame(width: geo.size.width, height: top + max(reveal, 0))
                // Fixed in place, like a layer the page slides off; it settles from slightly zoomed as more of it shows.
                .background(alignment: .top) {
                    Image(arrival.hub.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: top + Self.threshold * 1.6)
                        .scaleEffect(1.12 - 0.12 * progress, anchor: .top)
                }
                .overlay {
                    LinearGradient(stops: [.init(color: .black.opacity(0.5), location: 0),
                                           .init(color: .black.opacity(0.25), location: 0.5),
                                           .init(color: M.backgroundPrimary, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                // Pinned to the page's edge, so it rides down with it.
                .overlay(alignment: .bottom) {
                    VStack(spacing: R.spacingSpace4) {
                        HStack(spacing: 2) {
                            HubLiveDot()
                            Text("You're at \(arrival.hub.name)")
                                .backstageText(.label2)
                                .foregroundStyle(M.hubPureWhite.opacity(0.8))
                        }
                        HStack(spacing: R.spacingSpace8) {
                            Text(armed ? "Let go to step inside" : "Pull down to step inside")
                                .backstageText(.title3)
                                .foregroundStyle(M.hubPureWhite)
                                .contentTransition(.opacity)
                            Image(systemName: "arrow.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(armed ? Color.black : M.hubPureWhite)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(M.hubPureWhite.opacity(armed ? 1 : 0.16)))
                                .overlay {
                                    // Fills round as the pull nears the point where it opens.
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(M.hubPureWhite, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        .opacity(armed ? 0 : 1)
                                }
                        }
                    }
                    .padding(.bottom, R.spacingSpace16)
                    .opacity(Double(min(max((reveal - 36) / 48, 0), 1)))
                    .offset(y: (1 - progress) * 10)
                }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .animation(.snappy(duration: 0.22), value: armed)
            .offset(y: -top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens \(arrival.hub.name)")
    }
}
