import Observation
import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Hub detail page (Figma "Hub Detail Page", 14234:95159). The layout follows the hub's type: the mall "anatomy" with
/// Top finds, the "Less tabs" and "Only 1 tab" lists, and the airport page. The sheet behaves like a bottom sheet: it rises
/// over the hub's info, widens to the screen edges, snaps to either rest or stuck, and the action bar drops to icons.
/// Scroll-driven values live in `HubScrollState` and only small leaf views read them, so scrolling never re-renders the page,
/// and nothing inside the scroll view changes layout while it scrolls.
struct HubDetailView: View {
    let hub: Hub

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: HubTab
    @State private var scroll = HubScrollState()
    @State private var infoHeight: CGFloat = 320
    @State private var tabForward = true
    @State private var infoSheet: HubInfoSheet? = HubDetailView.launchSheet
    @State private var cover: HubCover? = HubDetailView.launchCover
    @State private var showsFloors = HubDetailView.launchFloors
    @State private var showsMore = HubDetailView.launchMore
    @State private var storePage: StoreDetail?
    @State private var saved: Set<String> = []
    @State private var placeFilters: Set<String> = []
    @State private var terminal = "International"
    @State private var zone = "All"
    @Namespace private var tabLine

    /// Distance from the status bar's bottom to where the sheet sticks (Figma: 123 − 62).
    private static let pinOffset: CGFloat = 61
    /// Gap between the sticking line and the hub's title at rest (Figma: 169 − 123).
    private static let infoTop: CGFloat = 46

    init(hub: Hub) {
        self.hub = hub
        var first = hub.tabs.first ?? .restaurants
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-hubTab"), i + 1 < args.count,
           let tab = hub.tabs.first(where: { $0.title == args[i + 1] }) {
            first = tab
        }
        #endif
        _tab = State(initialValue: first)
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            ZStack(alignment: .top) {
                M.backgroundPrimary
                glow
                HubHeroView(hub: hub, scroll: scroll, height: safeTop + 141, dimmed: showsFloors)

                VStack(spacing: 0) {
                    Color.clear.frame(height: safeTop + Self.pinOffset)
                    content(minBodyHeight: geo.size.height)
                }
                .opacity(showsFloors ? 0 : 1)
                .scaleEffect(showsFloors && !reduceMotion ? 0.97 : 1, anchor: .top)
                .allowsHitTesting(!showsFloors)
                .accessibilityHidden(showsFloors)

                if showsFloors {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: safeTop + Self.pinOffset).allowsHitTesting(false)
                        HubFloorsSheet(onClose: closeFloors)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    .zIndex(1)
                }

                header
                    .padding(.top, safeTop + 12)
                    .zIndex(2)
                bottomBar
                    .zIndex(3)
            }
            .ignoresSafeArea()
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $infoSheet) { HubInfoSheetView(kind: $0, hub: hub) }
        .readerCover(item: $cover) { _ in HubSearchView(hub: hub) }
        .readerCover(item: $storePage) { StoreDetailView(detail: $0) }
    }

    private func openFloors() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.46, dampingFraction: 0.88)) { showsFloors = true }
    }

    private func closeFloors() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.36, dampingFraction: 1)) { showsFloors = false }
    }

    // MARK: Background

    /// Figma "Dominant Colour Glow in background" at 20%.
    private var glow: some View {
        // Drawn as an overlay: the ellipse is wider than the screen and mustn't widen the page's layout.
        Color.clear
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(hub.glow.opacity(0.2))
                    .frame(width: 540, height: 678)
                    .blur(radius: 75)
                    .offset(y: 300)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "arrow.left", label: "Back") {
                if showsFloors { closeFloors() } else { dismiss() }
            }
            ZStack {
                HubHeaderTitle(title: hub.name, scroll: scroll, hidden: showsFloors)
                if showsFloors {
                    Text("Floors")
                        .backstageText(.hubTitle2)
                        .foregroundStyle(M.hubPureWhite)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            ZStack {
                if showsFloors {
                    GlassIconButton(systemName: "magnifyingglass", label: "Search in \(hub.name)") { cover = .search }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    ShareLink(item: "\(hub.name), \(hub.locality)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(M.iconPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .liquidGlass(in: Circle(), interactive: true, clear: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share \(hub.name)")
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .padding(.horizontal, 13)
    }

    // MARK: Scroll content

    private func content(minBodyHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    HubInfoBlock(hub: hub, sheet: $infoSheet)
                        .padding(.top, hub.brandLogo == nil ? Self.infoTop : Self.infoTop - 36)
                        .padding(.bottom, R.spacingSpace24)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            infoHeight = $0
                            scroll.stick = $0
                        }
                        // Lags behind the scroll and fades, so the sheet slides up over it instead of pushing it off.
                        .visualEffect { view, geo in
                            let y = max(-geo.frame(in: .scrollView).minY, 0)
                            return view
                                .offset(y: y * 0.45)
                                .opacity(1 - min(y / 90, 1))
                        }

                    Color.clear.frame(height: 0).id("sheetTop")

                    Section {
                        sheetBody
                            .padding(.bottom, 140)
                            // Short lists still run the sheet to the bottom and can reach the stuck position.
                            .frame(maxWidth: .infinity, minHeight: minBodyHeight, alignment: .top)
                            .modifier(HubSheetChrome(scroll: scroll, radius: 0))
                    } header: {
                        sheetHeader
                            .modifier(HubSheetChrome(scroll: scroll, radius: R.cornerRadiusCorner24))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(HubSheetSnap(stick: infoHeight))
            // Rounds the top so rows passing under the stuck tabs never show through its corners.
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: R.cornerRadiusCorner24, topTrailingRadius: R.cornerRadiusCorner24))
            .modifier(ExploreScrollTracker { [scroll] in scroll.update(y: -$0) })
            .onChange(of: tab) {
                // A shorter tab mustn't make the page jump: stay stuck at the top of the new tab.
                if scroll.stickProgress == 1 { proxy.scrollTo("sheetTop", anchor: .top) }
            }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-hubScrolled") {
                    try? await Task.sleep(for: .milliseconds(450))
                    proxy.scrollTo("sheetTop", anchor: .top)
                }
                #endif
            }
        }
    }

    // MARK: Sheet

    @ViewBuilder
    private var sheetHeader: some View {
        switch hub.layout {
        case .full, .fewTabs:
            tabRow.padding(.top, R.spacingSpace16)
        case .singleList:
            HubPlaceFilterRail(active: $placeFilters)
                .padding(.top, R.spacingSpace12)
                .padding(.bottom, R.spacingSpace4)
        case .airport:
            airportHeader
        }
    }

    @ViewBuilder
    private var sheetBody: some View {
        switch hub.layout {
        case .full, .fewTabs:
            // A ZStack so the outgoing tab fades in place while the new one comes in from the side it was tapped on.
            ZStack(alignment: .top) {
                Group {
                    if tab == .topFinds {
                        HubTopFinds(hub: hub) { storePage = $0 }
                    } else {
                        HubPlaceList(title: tab.listTitle, places: HubsData.places(tab.kind), active: $placeFilters, saved: $saved) { storePage = $0 }
                    }
                }
                .id(tab)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(x: tabForward ? 28 : -28)),
                                                                  removal: .opacity))
            }
        case .singleList:
            HubPlaceList(title: nil, places: HubsData.gardenPlaces, active: $placeFilters, saved: $saved) { storePage = $0 }
        case .airport:
            HubAirportList(zone: zone, terminal: terminal)
        }
    }

    // MARK: Tabs

    private var tabRow: some View {
        // A fixed choice, not ViewThatFits: the row's layout must not depend on the sheet's width.
        Group {
            if hub.layout == .fewTabs {
                HStack(spacing: R.spacingSpace8) { tabButtons }
                    .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: R.spacingSpace8) { tabButtons }
                    }
                    .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .onChange(of: tab) {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { proxy.scrollTo(tab, anchor: .center) }
                    }
                }
            }
        }
        .background(alignment: .bottom) {
            Rectangle()
                .fill(M.borderSubtle)
                .frame(height: R.stroke1Px)
                .padding(.horizontal, R.spacingSpace16)
        }
        .sensoryFeedback(.selection, trigger: tab)
        .onChange(of: tab) { placeFilters = [] }
    }

    private var tabButtons: some View {
        ForEach(hub.tabs) { item in
            let selected = item == tab
            Button {
                let from = hub.tabs.firstIndex(of: tab) ?? 0
                let to = hub.tabs.firstIndex(of: item) ?? 0
                tabForward = to >= from
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.28)) { tab = item }
            } label: {
                VStack(spacing: 6) {
                    Image(item.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(selected ? 1 : 0.8)
                    Text(item.title)
                        .backstageText(.label3)
                        .foregroundStyle(selected ? M.textPrimary : M.textTertiary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 60)
                .padding(.top, 3)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    if selected {
                        Rectangle()
                            .fill(M.textPrimary)
                            .frame(width: 57, height: R.stroke2Px)
                            .matchedGeometryEffect(id: "tab-line", in: tabLine)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .id(item)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
    }

    // MARK: Airport

    private var airportHeader: some View {
        VStack(spacing: R.spacingSpace12) {
            HStack(spacing: 0) {
                ForEach(["Domestic", "International"], id: \.self) { item in
                    let selected = item == terminal
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { terminal = item }
                    } label: {
                        Text(item)
                            .backstageText(.label2)
                            .foregroundStyle(selected ? M.textPrimary : M.textSecondary)
                            .frame(width: 109, height: 40)
                            .background {
                                if selected {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule().strokeBorder(M.borderIntense, lineWidth: R.stroke1Px)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, R.spacingSpace4)
            .padding(.vertical, 2)
            .background(M.surfaceSecondary, in: Capsule())

            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace24) {
                    ForEach(HubsData.airportTabs, id: \.self) { item in
                        let selected = item == zone
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { zone = item }
                        } label: {
                            Text(item)
                                .backstageText(.hubBody2)
                                .foregroundStyle(selected ? M.textPrimary : M.textSecondary)
                                .fixedSize()
                                .frame(minWidth: 24)
                                .padding(.top, R.spacingSpace12)
                                .padding(.bottom, 11)
                                .overlay(alignment: .bottom) {
                                    if selected {
                                        Rectangle()
                                            .fill(M.textPrimary)
                                            .frame(height: R.stroke2Px)
                                            .padding(.horizontal, -8)
                                            .matchedGeometryEffect(id: "zone-line", in: tabLine)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .contentMargins(.horizontal, 25, for: .scrollContent)
            .scrollIndicators(.hidden)
            .background(alignment: .bottom) {
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            }
        }
        .padding(.top, R.spacingSpace16)
    }

    // MARK: Action bar

    private var bottomBar: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [M.backgroundPrimary.opacity(0), M.backgroundPrimary],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 170)
                .opacity(showsFloors ? 0 : 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if showsMore {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { setMore(false) }
                    .accessibilityHidden(true)
            }

            VStack(spacing: 6) {
                if showsMore {
                    moreMenu
                        .offset(x: 46)
                        .transition(reduceMotion ? .opacity : .modifier(active: HubMenuMotion(shown: false),
                                                                        identity: HubMenuMotion(shown: true)))
                }
                HubActionBar(scroll: scroll, items: actionItems)
                    .opacity(showsFloors ? 0 : 1)
                    .offset(y: showsFloors && !reduceMotion ? 28 : 0)
                    .allowsHitTesting(!showsFloors)
                    .accessibilityHidden(showsFloors)
            }
            .padding(.bottom, 37)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var actionItems: [HubActionBar.Item] {
        var items: [HubActionBar.Item] = []
        if hub.hasFindInHub {
            items.append(.init(icon: "hub_ic_route", size: 22, title: "Find in hub", action: openFloors))
        }
        items.append(.init(icon: "hub_ic_search", size: 22, title: "Search") { cover = .search })
        items.append(.init(icon: "hub_ic_ellipsis", size: 20, title: "More") { setMore(!showsMore) })
        return items
    }

    private func setMore(_ value: Bool) {
        // In with the Figma's overshoot, out quickly so it never competes with whatever was just opened.
        withAnimation(reduceMotion ? nil : (value ? .spring(duration: 0.35, bounce: 0.3) : .easeOut(duration: 0.14))) { showsMore = value }
    }

    private var moreMenu: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) {
            moreRow(icon: "hub_ic_directions", size: 20, title: "Directions") { infoSheet = .address }
            if hub.type != .park && hub.type != .beach {
                moreRow(icon: "hub_ic_notebook", size: 22, title: "Floors directory", action: openFloors)
            }
            moreRow(icon: "hub_ic_info", size: 24, title: "Facilities") { infoSheet = .facilities }
        }
        .padding(R.spacingSpace12)
        .frame(width: 169)
        .background(M.surfaceSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
    }

    private func moreRow(icon: String, size: CGFloat, title: String, action: @escaping () -> Void) -> some View {
        Button {
            setMore(false)
            action()
        } label: {
            HStack(spacing: R.spacingSpace12) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .frame(width: 24, height: 24)
                Text(title)
                    .backstageText(.hubLabel1)
                    .foregroundStyle(Color(hex: 0xFAFAFA))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.vertical, R.spacingSpace8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Debug launch arguments

    /// Debug builds accept `-hubSheet address|hours|facilities`.
    private static var launchSheet: HubInfoSheet? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-hubSheet"), i + 1 < args.count {
            return HubInfoSheet(rawValue: args[i + 1])
        }
        #endif
        return nil
    }

    /// Debug builds accept `-hubCover floors|search`.
    private static var launchCover: HubCover? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-hubCover"), i + 1 < args.count {
            return HubCover(rawValue: args[i + 1])
        }
        #endif
        return nil
    }

    private static var launchFloors: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-hubCover"), i + 1 < args.count { return args[i + 1] == "floors" }
        #endif
        return false
    }

    /// Debug builds accept `-hubMore` to open with the More menu showing.
    private static var launchMore: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-hubMore")
        #else
        return false
        #endif
    }
}

private enum HubCover: String, Identifiable {
    case search
    var id: String { rawValue }
}

// MARK: - Scroll-driven pieces

/// Everything that follows the scroll position. Each value only publishes when it actually changes, and only the leaf views
/// below read them, so a scroll frame touches those views and nothing else.
@Observable
private final class HubScrollState {
    private(set) var overscroll: CGFloat = 0
    private(set) var heroLift: CGFloat = 0
    private(set) var titleProgress: CGFloat = 0
    /// 0 at rest, 1 once the sheet has reached the top.
    private(set) var stickProgress: CGFloat = 0
    private(set) var compactBar = false
    /// Scroll distance at which the sheet sticks.
    @ObservationIgnored var stick: CGFloat = 320

    func update(y: CGFloat) {
        set(\.overscroll, max(-y, 0))
        set(\.heroLift, min(max(y, 0) * 0.18, 40))
        set(\.titleProgress, min(max((y - 56) / 36, 0), 1))
        set(\.stickProgress, min(max((y - (stick - 90)) / 90, 0), 1))
        // Two thresholds, so resting near one point can't make the bar flicker.
        if !compactBar, stickProgress > 0.6 { compactBar = true }
        if compactBar, stickProgress < 0.3 { compactBar = false }
    }

    private func set(_ path: ReferenceWritableKeyPath<HubScrollState, CGFloat>, _ value: CGFloat) {
        if self[keyPath: path] != value { self[keyPath: path] = value }
    }
}

/// Stops the sheet landing halfway: a drag that ends between rest and stuck settles on the nearer one.
private struct HubSheetSnap: ScrollTargetBehavior {
    let stick: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.minY
        guard y > 0, y < stick else { return }
        target.rect.origin.y = y < stick / 2 ? 0 : stick
    }
}

/// A rectangle inset from the sides with optional rounded top corners.
private struct HubSheetShape: Shape {
    var inset: CGFloat
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius)
            .path(in: rect.insetBy(dx: inset, dy: 0))
    }
}

/// The sheet's ground and edges. The width change is only a clip and a fill: the content keeps its layout as the sheet widens.
private struct HubSheetChrome: ViewModifier {
    let scroll: HubScrollState
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = HubSheetShape(inset: 8 * (1 - scroll.stickProgress), radius: radius)
        content
            .clipShape(shape)
            .background { shape.fill(M.backgroundPrimary) }
    }
}

private struct HubHeroView: View {
    let hub: Hub
    let scroll: HubScrollState
    let height: CGFloat
    let dimmed: Bool

    var body: some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: hub.heroAlignment) {
                Image(hub.hero).resizable().scaledToFill()
            }
            .clipped()
            .overlay {
                LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0), location: 0.33),
                                       .init(color: M.backgroundPrimary.opacity(0.6), location: 0.75),
                                       .init(color: M.backgroundPrimary, location: 0.99)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(M.backgroundPrimary.opacity(0.32 * (dimmed ? 1 : scroll.titleProgress)))
            // Stretches on pull-down and drifts up slowly as the sheet rises.
            .scaleEffect(1 + scroll.overscroll / height, anchor: .top)
            .offset(y: -scroll.heroLift)
            .accessibilityHidden(true)
    }
}

private struct HubHeaderTitle: View {
    let title: String
    let scroll: HubScrollState
    let hidden: Bool

    var body: some View {
        let progress = hidden ? 0 : scroll.titleProgress
        Text(title)
            .backstageText(.hubTitle2)
            .foregroundStyle(M.hubPureWhite)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .opacity(progress)
            .offset(y: 8 * (1 - progress))
            .accessibilityHidden(progress == 0)
    }
}

/// The floating bar. Labels collapse by size and fade rather than being removed, so the capsule morphs in one motion.
private struct HubActionBar: View {
    struct Item: Identifiable {
        var id: String { title }
        let icon: String
        let size: CGFloat
        let title: String
        let action: () -> Void
    }

    let scroll: HubScrollState
    let items: [Item]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let compact = scroll.compactBar
        HStack(spacing: compact ? R.spacingSpace4 : R.spacingSpace8) {
            ForEach(items) { item in
                Button(action: item.action) {
                    VStack(spacing: compact ? 0 : 7) {
                        Image(item.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: item.size, height: item.size)
                        Text(item.title)
                            .backstageText(.label3)
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(height: compact ? 0 : 14)
                            .opacity(compact ? 0 : 1)
                    }
                    .frame(width: compact ? 40 : 61, height: compact ? 44 : 43)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .padding(.horizontal, compact ? R.spacingSpace8 : R.spacingSpace16)
        .padding(.vertical, compact ? R.spacingSpace4 : R.spacingSpace12)
        .liquidGlass(in: Capsule(), interactive: true)
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: compact)
    }
}

/// The More menu's entrance from Figma 14234:96807: it rises from a squashed 96% × 70% and overshoots slightly.
private struct HubMenuMotion: ViewModifier {
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: shown ? 1 : 0.96, y: shown ? 1 : 0.7, anchor: .bottom)
            .offset(x: shown ? 0 : 3.8, y: shown ? 0 : 25.8)
            .opacity(shown ? 1 : 0)
    }
}

// MARK: - Hub info

/// Name, address, rating, hours, counts and the one-liner above the sheet.
private struct HubInfoBlock: View {
    let hub: Hub
    @Binding var sheet: HubInfoSheet?

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: R.spacingSpace4) {
                if let logo = hub.brandLogo {
                    Image(logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 18)
                        .padding(2)
                        .background(Color(hex: 0xEEEEEE), in: RoundedRectangle(cornerRadius: 3.6))
                        .padding(.bottom, 10)
                }
                Text(hub.name)
                    .backstageText(.hubTitle1)
                    .foregroundStyle(M.hubPureWhite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, R.spacingSpace24)
                    .accessibilityAddTraits(.isHeader)
                addressRow
                statusRow
            }
            VStack(spacing: R.spacingSpace8) {
                stats
                Text(hub.blurb)
                    .font(.custom("BeVietnamPro-Regular", size: 12, relativeTo: .subheadline))
                    .lineSpacing(4.8)
                    .foregroundStyle(M.textTertiary)
                    .opacity(0.9)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 310)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, R.spacingSpace8)
    }

    private var addressRow: some View {
        Button { sheet = .address } label: {
            HStack(spacing: R.spacingSpace4) {
                (Text("\(hub.detailDistance)  ")
                    + Text("•  ").foregroundStyle(M.textPrimary.opacity(0.27))
                    + Text(hub.detailArea))
                    .backstageText(.body3)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
                Image("hub_ic_navigation")
                    .resizable()
                    .frame(width: 13, height: 13)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(hub.detailDistance) away, \(hub.detailArea)")
        .accessibilityHint("Shows the address")
    }

    @ViewBuilder
    private var statusRow: some View {
        if hub.rating != nil || hub.status != nil {
            HStack(spacing: 10) {
                if let rating = hub.rating {
                    HStack(spacing: R.spacingSpace4) {
                        HStack(spacing: 3) {
                            Image("hub_ic_star_green")
                                .resizable()
                                .frame(width: 10, height: 10)
                            Text(rating)
                                .backstageText(.label2)
                                .foregroundStyle(M.hubTextRating)
                        }
                        Text(hub.ratingCount)
                            .backstageText(.label2)
                            .foregroundStyle(M.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rated \(rating)")
                }
                if hub.rating != nil, hub.status != nil {
                    RoundedRectangle(cornerRadius: 1.7)
                        .fill(M.surfaceInverse.opacity(0.3))
                        .frame(width: 1.4, height: 15)
                }
                if let status = hub.status {
                    Button { sheet = .hours } label: {
                        HStack(spacing: R.spacingSpace8) {
                            statusText(status)
                                .backstageText(.body3)
                            Image("hub_ic_hours_chev")
                                .resizable()
                                .frame(width: 4, height: 7)
                                .rotationEffect(.degrees(90))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows opening hours")
                }
            }
            .padding(.top, R.spacingSpace4)
        }
    }

    private func statusText(_ status: HubStatus) -> Text {
        let dot = Text("  •  ").foregroundStyle(M.textPrimary.opacity(0.27))
        switch status {
        case .open(let until):
            return Text("Open now").foregroundStyle(M.hubTextSuccess) + dot + Text(until).foregroundStyle(M.textSecondary)
        case .closed(let opens):
            return Text("Closed").foregroundStyle(M.hubTextClosed) + dot + Text(opens).foregroundStyle(M.textSecondary)
        }
    }

    private var stats: some View {
        HStack(spacing: R.spacingSpace12) {
            ForEach(Array(hub.stats.enumerated()), id: \.element) { index, stat in
                if index > 0 {
                    Rectangle()
                        .fill(M.borderIntense)
                        .frame(width: R.stroke1Px, height: 15)
                }
                HStack(spacing: 6) {
                    Image(stat.icon)
                        .resizable()
                        .frame(width: 12, height: 12)
                    Text(stat.label)
                        .backstageText(.label2)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, 6)
        .background(M.surfaceTransparent, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Top finds

/// The mall page's default tab: what's buzzing, offers and the themed rails.
private struct HubTopFinds: View {
    let hub: Hub
    let openStore: (StoreDetail) -> Void

    @State private var offerFilter = HubsData.offerFilters[0].title
    @State private var dineFilter = "Popular"
    @State private var shopFilter = "Popular"
    @State private var funFilter = "Must-Do"
    @State private var salonFilter = "Salons"

    /// A chip with no matches falls back to everything in that rail, so a rail never goes empty.
    private func places(_ kind: HubPlace.Kind, tag: String) -> [HubPlace] {
        let all = HubsData.places(kind)
        let matches = all.filter { $0.tags.contains(tag) }
        return logosFirst(matches.isEmpty ? all : matches)
    }

    /// The tiles carry a logo in the corner; places that have one lead the rails, as in the Figma.
    private func logosFirst(_ places: [HubPlace]) -> [HubPlace] {
        places.filter { $0.logo != nil } + places.filter { $0.logo == nil }
    }

    private var offerPlaces: [HubPlace] {
        let kind = HubsData.offerFilters.first { $0.title == offerFilter }?.kind ?? .restaurant
        return logosFirst(HubsData.places(kind).filter { $0.offer != nil })
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: R.spacingSpace40) {
            buzzing
            section("Best offers", chips: HubsData.offerFilters.map(\.title), selection: $offerFilter, chipHeight: 32) {
                rail(spacing: R.spacingSpace16) {
                    ForEach(offerPlaces) { HubOfferTile(place: $0, openStore: openStore) }
                }
            }
            section("🍽️ Drink and Dine", chips: ["Popular", "Fine Dining", "Casual", "Quick Bites"], selection: $dineFilter) {
                rail(spacing: R.spacingSpace16) {
                    ForEach(places(.restaurant, tag: dineFilter)) { HubOfferTile(place: $0, openStore: openStore) }
                }
            }
            section("🛍️ Shop n shine", chips: ["Popular", "Luxury", "Fashion", "Ethnic", "Sports"], selection: $shopFilter) {
                ScrollView(.horizontal) {
                    LazyHGrid(rows: [GridItem(.fixed(70), spacing: R.spacingSpace16), GridItem(.fixed(70))], spacing: 27) {
                        ForEach(places(.store, tag: shopFilter)) { HubShopTile(place: $0, openStore: openStore) }
                    }
                    .scrollTargetLayout()
                }
                .carousel()
            }
            section("🎮 Entertainment", chips: ["Must-Do", "Movies", "Gaming", "Special Events", "Sports"], selection: $funFilter) {
                rail(spacing: R.spacingSpace16) {
                    ForEach(places(.entertainment, tag: funFilter)) { HubFunTile(place: $0) }
                }
            }
            section("💆 Salon n Spa", chips: ["Salons", "Spas", "Wellness"], selection: $salonFilter) {
                rail(spacing: R.spacingSpace16) {
                    ForEach(places(.salon, tag: salonFilter)) { HubSalonTile(place: $0) }
                }
            }
        }
        .padding(.top, R.spacingSpace24)
    }

    private var buzzing: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            sectionTitle("What’s buzzing here?")
            rail(spacing: R.spacingSpace12) {
                ForEach(hub.buzz) { HubBuzzTile(item: $0) }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .backstageText(.hubTitle2)
            .foregroundStyle(M.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, R.spacingSpace16)
            .accessibilityAddTraits(.isHeader)
    }

    private func section<Content: View>(_ title: String, chips: [String], selection: Binding<String>, chipHeight: CGFloat = 40,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            sectionTitle(title)
            HubSectionChips(titles: chips, selection: selection, height: chipHeight)
            content()
        }
    }

    private func rail<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: spacing) { content() }
                .scrollTargetLayout()
        }
        .carousel()
    }
}

/// A section's chips: an outline that brightens on the selected one.
private struct HubSectionChips: View {
    let titles: [String]
    @Binding var selection: String
    var height: CGFloat = 40

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(titles, id: \.self) { title in
                    let selected = title == selection
                    Button {
                        withAnimation(.snappy(duration: 0.22)) { selection = title }
                    } label: {
                        Text(title)
                            .backstageText(.label2)
                            .foregroundStyle(selected ? M.textPrimary : M.textSecondary)
                            .padding(.horizontal, R.spacingSpace12)
                            .frame(height: height)
                            .background(selected ? Color.black.opacity(0.16) : .clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? M.buttonPrimaryBackgroundPressed : M.borderModerate, lineWidth: R.stroke1Px))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct HubBuzzTile: View {
    let item: HubBuzz

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Color.clear
                .frame(width: 138.5, height: 184.7)
                .overlay { Image(item.image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 10.7))
                .overlay(RoundedRectangle(cornerRadius: 10.7).strokeBorder(M.borderModerate, lineWidth: 0.9))
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(item.title)
                    .backstageText(.hubLabel1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .backstageText(.label3)
                        .foregroundStyle(M.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, R.spacingSpace4)
            .frame(width: 138.5, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A photo with a corner logo and a rating cut into the opposite corner (Figma 14234:95273).
private struct HubOfferTile: View {
    let place: HubPlace
    let openStore: (StoreDetail) -> Void

    var body: some View {
        HubOpensStore(place: place, openStore: openStore) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let photo = place.photo {
                            Color.clear.overlay { Image(photo).resizable().scaledToFill() }
                        } else if let logo = place.logo {
                            Color.white.overlay { Image(logo).resizable().scaledToFit().padding(R.spacingSpace16) }
                        }
                    }
                    .frame(width: 132, height: 125)
                    .clipShape(RoundedRectangle(cornerRadius: 13.4))

                    if let rating = place.rating {
                        HubRatingBadge(rating: rating)
                            .padding(.leading, 2)
                            .padding(.trailing, 5)
                            .padding(.top, R.spacingSpace4)
                            .padding(.bottom, R.spacingSpace4)
                            .background(M.backgroundSecondary, in: UnevenRoundedRectangle(bottomLeadingRadius: 13.4, topTrailingRadius: R.cornerRadiusCorner8))
                    }
                }
                .frame(width: 132, height: 125)
                .overlay(alignment: .bottomTrailing) {
                    if place.photo != nil, let logo = place.logo {
                        Image(logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 9.4))
                            .overlay(RoundedRectangle(cornerRadius: 9.4).strokeBorder(M.borderSubtle, lineWidth: 0.7))
                            .offset(x: 8, y: 5)
                    }
                }

                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(place.name)
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    if !place.cuisine.isEmpty {
                        Text(place.cuisine)
                            .backstageText(.finePrint2)
                            .foregroundStyle(M.textTertiary)
                            .lineLimit(1)
                    }
                    if let offer = place.offer { HubOfferLine(offer: offer) }
                    HubFloorLine(place: place)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}

private struct HubShopTile: View {
    let place: HubPlace
    let openStore: (StoreDetail) -> Void

    var body: some View {
        HubOpensStore(place: place, openStore: openStore) {
            HStack(spacing: R.spacingSpace12) {
                HubLogoTile(logo: place.logo, width: 62, height: 63)
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(place.name)
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text(place.floorLabel)
                        .backstageText(.label3)
                        .foregroundStyle(M.textTertiary)
                    if let offer = place.offer { HubOfferLine(offer: offer) }
                }
            }
            .frame(width: 218, height: 70, alignment: .leading)
        }
    }
}

private struct HubFunTile: View {
    let place: HubPlace

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace16) {
            Color.clear
                .frame(width: 140, height: 140)
                .overlay {
                    if let photo = place.photo { Image(photo).resizable().scaledToFill() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12.9))
                .overlay(alignment: .bottomTrailing) {
                    if let logo = place.logo {
                        Image(logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).strokeBorder(M.borderSubtle, lineWidth: 0.9))
                            .offset(x: 5, y: 11)
                    }
                }
                .padding(.bottom, 11)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(place.name)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(place.floorLabel) • \(place.cuisine)")
                    .backstageText(.hubBody2)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
                if let offer = place.offer { HubOfferLine(offer: offer) }
            }
            .frame(width: 174, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HubSalonTile: View {
    let place: HubPlace

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Color.clear
                .frame(width: 126, height: 120)
                .overlay {
                    if let photo = place.photo { Image(photo).resizable().scaledToFill() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12.9))
                .overlay(alignment: .bottomTrailing) {
                    Group {
                        if let logo = place.logo {
                            Color.white
                                .overlay { Image(logo).resizable().scaledToFit().padding(2) }
                        }
                    }
                    .frame(width: 49, height: 49)
                    .clipShape(RoundedRectangle(cornerRadius: 10.5))
                    .overlay(RoundedRectangle(cornerRadius: 10.5).strokeBorder(M.borderSubtle, lineWidth: 0.8))
                    .offset(x: 7, y: 5)
                }
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(place.name)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text(place.shopNumber ?? place.floorLabel)
                    .backstageText(.finePrint2)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 134, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared place pieces

/// Wraps a store's tile in a button when the app has a store page for it; anything else stays a plain tile.
struct HubOpensStore<Content: View>: View {
    let place: HubPlace
    let openStore: (StoreDetail) -> Void
    @ViewBuilder let content: () -> Content

    private var store: Store? {
        guard place.kinds.contains(.store) else { return nil }
        return StoresData.stores.first { $0.name.caseInsensitiveCompare(place.name) == .orderedSame }
    }

    var body: some View {
        if let store {
            Button { openStore(StoreDetail.of(store)) } label: { content() }
                .buttonStyle(PressableStyle())
        } else {
            content().accessibilityElement(children: .combine)
        }
    }
}

struct HubRatingBadge: View {
    let rating: String

    var body: some View {
        HStack(spacing: 2) {
            Text(rating)
                .font(.custom("BeVietnamPro-Bold", size: 10, relativeTo: .caption2))
                .foregroundStyle(M.hubTextSuccess)
            Image("hub_ic_star_badge")
                .resizable()
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 1.5)
        .background(M.hubSurfaceRating, in: RoundedRectangle(cornerRadius: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(rating)")
    }
}

struct HubNewBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Text("New")
                .font(.custom("BeVietnamPro-Bold", size: 11, relativeTo: .caption2))
                .foregroundStyle(M.hubTextNew)
            Image("hub_ic_star_new")
                .resizable()
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, R.spacingSpace4)
        .padding(.vertical, 2)
        .background(M.hubSurfaceNew, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner4))
    }
}

struct HubOfferLine: View {
    let offer: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? R.spacingSpace4 : 5) {
            Image("hub_ic_offer")
                .resizable()
                .frame(width: compact ? 12 : 16, height: compact ? 12 : 16)
            Text(offer)
                .backstageText(compact ? .finePrint2 : .body3)
                .foregroundStyle(M.textOffer)
                .lineLimit(1)
        }
    }
}

struct HubFloorLine: View {
    let place: HubPlace

    var body: some View {
        HStack(spacing: R.spacingSpace4) {
            Text(place.floorLabel)
            if let price = place.price {
                Text("•").foregroundStyle(M.iconQuaternary)
                Text(price)
            }
        }
        .backstageText(.label3)
        .foregroundStyle(M.textTertiary)
        .lineLimit(1)
    }
}

struct HubLogoTile: View {
    let logo: String?
    let width: CGFloat
    let height: CGFloat
    var radius: CGFloat = 13.5

    /// White logos that need a dark tile, as in `BrandMark`.
    private static let onDark: Set<String> = ["logo_nicobar"]

    var body: some View {
        (logo.map(Self.onDark.contains) == true ? Color.black : Color.white)
            .overlay {
                if let logo { Image(logo).resizable().scaledToFit().padding(R.spacingSpace4) }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

/// The "Filters" chip plus quick toggles above a list of places.
struct HubPlaceFilterRail: View {
    @Binding var active: Set<String>

    private static let quick = [("🔅 Dim lights", "Dim lights"), ("Under 5km", "Under 5km"), ("Rated 4+", "Rated 4+")]

    private func isOn(_ tag: String) -> Binding<Bool> {
        Binding(get: { active.contains(tag) }, set: { on in
            withAnimation(.snappy(duration: 0.22)) {
                if on { active.insert(tag) } else { active.remove(tag) }
            }
        })
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Menu {
                    ForEach(Self.quick, id: \.1) { title, tag in
                        Toggle(title, isOn: isOn(tag))
                    }
                } label: {
                    HubFiltersChipLabel()
                }
                .accessibilityLabel("Filters")

                ForEach(Self.quick, id: \.1) { title, tag in
                    Button(title) { isOn(tag).wrappedValue.toggle() }
                        .buttonStyle(BackstageFilterButtonStyle(isActive: active.contains(tag), compact: true))
                        .accessibilityAddTraits(active.contains(tag) ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Place list

/// The list shown on every tab but Top finds ("All restaurants" in the Figma's Less tabs case).
private struct HubPlaceList: View {
    /// Nil on the single-list layout, where the filter rail is the sheet's pinned header.
    let title: String?
    let places: [HubPlace]
    @Binding var active: Set<String>
    @Binding var saved: Set<String>
    let openStore: (StoreDetail) -> Void

    private var filtered: [HubPlace] {
        places.filter { place in
            active.allSatisfy { $0 == "Rated 4+" ? place.ratedFourPlus : place.tags.contains($0) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            if let title {
                Text(title)
                    .backstageText(.hubTitle2)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace16)
                    .padding(.top, R.spacingSpace16)
                    .accessibilityAddTraits(.isHeader)
                HubPlaceFilterRail(active: $active)
            }
            LazyVStack(spacing: R.spacingSpace20) {
                if filtered.isEmpty {
                    Text("Nothing here matches those filters")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .padding(.vertical, R.spacingSpace40)
                }
                ForEach(filtered) { place in
                    HubPlaceRow(place: place, isSaved: saved.contains(place.id), openStore: openStore) {
                        if saved.contains(place.id) { saved.remove(place.id) } else { saved.insert(place.id) }
                    }
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, title == nil ? R.spacingSpace4 : 0)
        }
    }
}

/// A place with an 88pt thumbnail and a save button (Figma 14234:99330).
struct HubPlaceRow: View {
    let place: HubPlace
    let isSaved: Bool
    let openStore: (StoreDetail) -> Void
    let toggleSaved: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace8) {
            HubOpensStore(place: place, openStore: openStore) {
                HStack(alignment: .top, spacing: R.spacingSpace12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 5) {
                        VStack(alignment: .leading, spacing: R.spacingSpace4) {
                            Text(place.name)
                                .backstageText(.title4)
                                .foregroundStyle(M.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                if place.isNew {
                                    HubNewBadge()
                                } else if let rating = place.rating {
                                    HubRatingBadge(rating: rating)
                                }
                                Text(place.cuisine)
                                    .backstageText(.label3)
                                    .foregroundStyle(M.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        HubFloorLine(place: place)
                        if let offer = place.offer { HubOfferLine(offer: offer) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .multilineTextAlignment(.leading)
            }
            Button(action: toggleSaved) {
                Group {
                    if isSaved {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(M.iconPrimary)
                    } else {
                        Image("hub_ic_bookmark")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                .frame(width: 44, height: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isSaved)
            .accessibilityLabel(isSaved ? "Saved" : "Save \(place.name)")
            .accessibilityAddTraits(isSaved ? .isSelected : [])
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photo = place.photo {
            Color.clear
                .frame(width: 88, height: 88)
                .overlay { Image(photo).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            HubLogoTile(logo: place.logo, width: 88, height: 88, radius: 14)
        }
    }
}

// MARK: - Airport

/// The airport page's collapsible groups, filtered by the zone tabs.
private struct HubAirportList: View {
    let zone: String
    let terminal: String
    @State private var expanded: Set<String> = []

    private var categories: [HubCategory] {
        HubsData.airportCategories.filter { category in
            // Shops stand in for duty free, which only the international side has.
            (zone == "All" || category.zone == zone) && (terminal == "International" || category.kind != .store)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            if categories.isEmpty {
                Text("Nothing in this zone yet")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .padding(.vertical, R.spacingSpace40)
            }
            ForEach(categories) { category in
                HubCategorySection(category: category, subtitle: category.zone, places: HubsData.places(category.kind),
                                   lineFor: { _ in "Near gate number 5" }, chevronSize: 24,
                                   isExpanded: Binding(get: { expanded.contains(category.id) }, set: { value in
                    if value { expanded.insert(category.id) } else { expanded.remove(category.id) }
                }))
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace24)
    }
}

#Preview {
    HubDetailView(hub: HubsData.hubs[12])
}
