import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Going back to the landing

/// Lets Stores mode's home button return to the Home landing.
struct DistrictHomeAction {
    let run: () -> Void
    func callAsFunction() { run() }
}

private struct DistrictHomeActionKey: EnvironmentKey {
    static let defaultValue = DistrictHomeAction {}
}

extension EnvironmentValues {
    var districtHomeAction: DistrictHomeAction {
        get { self[DistrictHomeActionKey.self] }
        set { self[DistrictHomeActionKey.self] = newValue }
    }
}

// MARK: - App root

/// App root: Home, Hubs, Maps, Hotlists and Search behind the bottom nav. Home's Stores tile opens Stores mode, the existing
/// Stores, Edit and Search tabs.
struct DistrictRootView: View {
    enum Tab: Hashable, CaseIterable {
        case forYou, hubs, maps, hotlists, search

        var title: String {
            switch self {
            case .forYou: "Home"
            case .hubs: "Hubs"
            case .maps: "Maps"
            case .hotlists: "Hotlists"
            case .search: "Search"
            }
        }

        var icon: String {
            switch self {
            case .forYou: "hub_nav_foryou"
            case .hubs: "hub_nav_hubs"
            case .maps: "hub_nav_maps"
            case .hotlists: "hub_nav_hotlists"
            case .search: "hub_nav_search"
            }
        }
    }

    private struct StoresMode: Identifiable {
        let id = "stores-mode"
    }

    /// A hub opening, with the hubs to swipe between.
    private struct HubOpening: Identifiable {
        let start: Hub
        let hubs: [Hub]
        /// Lands on the hub's floors directory.
        var floors = false
        /// Lands with the hub's search open.
        var search = false
        /// Lands on this tab.
        var tab: HubTab? = nil
        /// The zoom source to grow from, when the hub appears in more than one card on the same screen.
        var source: String? = nil
        var id: String { start.id }
    }

    @State private var tab: Tab = DistrictRootView.launchTab
    @State private var storesMode: StoresMode? = DistrictRootView.launchStoresMode ? StoresMode() : nil
    @State private var hub: HubOpening? = DistrictRootView.launchHub.map { HubOpening(start: $0, hubs: HubsData.hubs) }
    @State private var compactBar = DistrictRootView.forcesCompactBar
    /// `-compactBar` holds the bar compact for the screen it launches on, and lets go the moment they go anywhere, so
    /// scrolling drives the bar again rather than being ignored for the rest of the session.
    @State private var holdsCompactBar = DistrictRootView.forcesCompactBar
    @State private var showsWelcome = false
    @State private var welcomeDrag: CGFloat = 0
    @State private var hubsHighlight: DistrictTabBar.HubsHighlight = DistrictRootView.arrivalEnabled ? .pending : .none
    @State private var homeLocation = HomeData.locations[0]
    @State private var arrivalTask: Task<Void, Never>?
    /// The Maps tab is the hub's standing way back in: it carries a live dot for as long as they're at the hub, and the first
    /// time they move on from Home's "You're here" card it speaks up once, pointing at itself. That waits its turn behind
    /// the Hubs tab reveal.
    @State private var mapsNudgeReady = DistrictRootView.forcesMapsCallout
    @State private var hereCardVisible = false
    @State private var mapsCallout = false
    @State private var mapsCalloutPlayed = false
    @State private var calloutTask: Task<Void, Never>?
    @Namespace private var zoom

    private let arrival = HubArrival.dlfEmporio

    /// Only a plain launch onto Home plays the arrival; debug launches into a specific screen skip it, as does `-noArrival`.
    private static var arrivalEnabled: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if ["-noArrival", "-rootTab", "-openHub", "-openStoresMode", "-mapsCallout"].contains(where: args.contains) { return false }
        #endif
        return true
    }

    var body: some View {
        if Self.opensStoresDirectly {
            ContentView()
                .preferredColorScheme(.dark)
        } else {
            shell
                // The app is dark, except the Hubs tab, which follows the system's Light/Dark choice. Set here rather than on
                // the tab so the status bar and system menus follow it too.
                .preferredColorScheme(tab == .hubs ? SystemAppearance.shared.scheme : .dark)
                .task { SystemAppearance.shared.start() }
                .onChange(of: scenePhase) { if scenePhase == .active { SystemAppearance.shared.start() } }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    private var shell: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { item in
                screen(for: item)
                    // Only the Hubs tab follows the system; the rest stay dark, even for the moment the window turns over.
                    .environment(\.colorScheme, item == .hubs ? SystemAppearance.shared.scheme : .dark)
                    .tag(item)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 64 + (item == .forYou && aerobarOnHome ? aerobarClearance : 0))
                    }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                if showsAerobar {
                    // Edge to edge, so the bars either side can peek in from the screen's edges.
                    DistrictAerobar(items: aerobarItems, arrival: arrival, collapsed: compactBar,
                                    openHub: { hub = HubOpening(start: arrival.hub, hubs: HubsData.hubs) })
                        .padding(.bottom, R.spacingSpace8)
                        .transition(.offset(y: 24).combined(with: .opacity))
                }
                DistrictTabBar(selection: $tab, compact: compactBar, highlight: hubsHighlight,
                               onHubsCallout: { tab = .hubs }, onRevealEnd: { mapsNudgeReady = true },
                               live: atHub ? .maps : nil,
                               callout: mapsCallout ? "Navigate in \(arrival.hub.name)" : nil,
                               onCallout: { mapsCallout = false; tab = .maps })
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mapsCallout)
            }
            // The bar rides down with the tab bar as it shrinks, and comes up from behind it.
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: compactBar)
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: showsAerobar)
            // The bars are dark glass in both modes, over the light Hubs tab too.
            .environment(\.colorScheme, .dark)
        }
        .sensoryFeedback(trigger: mapsCallout) { _, shown in shown ? .impact(flexibility: .soft, intensity: 0.5) : nil }
        .onChange(of: wantsMapsCallout, initial: true) { _, wants in playMapsCallout(wants) }
        .overlay { welcomeOverlay.environment(\.colorScheme, .dark) }
        // Waits for the splash to clear.
        .task { landOnHome(after: 2.1) }
        .onChange(of: hub?.id) {
            holdsCompactBar = false
            introduceHubsTab()
        }
        .onChange(of: storesMode?.id) {
            holdsCompactBar = false
            if storesMode == nil { landOnHome(after: 0.45) }
        }
        .environment(\.tabBarCompactHandler, TabBarCompactHandler { value in
            if compactBar != value, !holdsCompactBar { compactBar = value }
        })
        .environment(\.hubHereCardVisible, HubHereVisibility { hereCardVisible = $0 })
        .onChange(of: tab) {
            holdsCompactBar = false
            compactBar = false
            arrivalTask?.cancel()
            if tab == .forYou { landOnHome(after: 0.35) }
            // Standing on the tab is what clears the highlight; coming back to Home brings it back.
            if tab == .hubs { withAnimation(.smooth(duration: 0.25)) { hubsHighlight = .none } }
        }
        .tint(M.iconPrimary)
        .sensoryFeedback(.selection, trigger: tab)
        // The sheet lands softly and leaves crisply.
        .sensoryFeedback(trigger: showsWelcome) { _, showing in
            showing ? .impact(flexibility: .soft, intensity: 0.85) : .impact(flexibility: .solid, intensity: 0.6)
        }
        .readerCover(item: $hub) { opening in
            // HubPagerView(hubs: opening.hubs, start: opening.start)  // Swiping between hubs is disabled, see HubPagerView.swift.
            HubDetailView(hub: opening.start, opensFloors: opening.floors, opensSearch: opening.search, startTab: opening.tab)
                // The page's own scroll owns downward drags; a pull past the top closes it instead.
                .interactiveDismissDisabled()
                .zoomTransition(id: opening.source ?? opening.start.id, in: zoom)
        }
        .readerCover(item: $storesMode) { _ in
            ContentView()
                .environment(\.districtHomeAction, DistrictHomeAction { storesMode = nil })
                .preferredColorScheme(.dark)
                .zoomTransition(id: "stores-mode", in: zoom)
        }
    }

    // MARK: Arrival

    @ViewBuilder
    private var welcomeOverlay: some View {
        ZStack(alignment: .bottom) {
            if showsWelcome {
                // A light frost, so Home stays recognisable behind the sheet.
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.35)
                    Color.black.opacity(0.5)
                }
                .ignoresSafeArea()
                .opacity(1 - welcomeDrag * 0.7)
                .onTapGesture { closeWelcome() }
                .accessibilityHidden(true)
                .transition(.opacity)

                HubWelcomeSheet(arrival: arrival, dragProgress: $welcomeDrag,
                                onClose: { closeWelcome() }, onExplore: { closeWelcome(openingHub: true) },
                                onNavigate: { closeWelcome(openingHub: true, floors: true) },
                                onOpenTab: { closeWelcome(openingHub: true, tab: $0) })
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var atHub: Bool { homeLocation == arrival.hub.name }

    /// Home always has an aerobar, there from the start: the welcome sheet comes up over it, and the Hubs tab reveal plays
    /// over it. It isn't taken down for the hub or Stores mode, so it's already there when they come back.
    private var aerobarOnHome: Bool { tab == .forYou }

    /// While they read down the page (the tab bar goes compact) it draws in to a small "Explore" pill for the hub, centred over
    /// the tab bar, and opens back out as soon as they scroll up or reach the top. Away from a hub there's nothing to draw in
    /// to, so it steps aside instead.
    private var showsAerobar: Bool { aerobarOnHome && (!compactBar || atHub) }

    /// Their nearest booking leads, then the hub they're standing in, then the table they've booked.
    private var aerobarItems: [DistrictAerobar.Item] { atHub ? [.movie, .hub, .table] : [.movie, .table] }

    private var aerobarClearance: CGFloat { DistrictAerobar.blockHeight(count: aerobarItems.count) + R.spacingSpace8 }

    /// On Home, at the hub, once the "You're here" card is off screen and the Hubs tab has had its moment. Never over the sheet
    /// or the hub itself. The aerobar holds that spot on Home, so this stays quiet wherever there's one, shown or stepped aside.
    private var wantsMapsCallout: Bool {
        mapsNudgeReady && atHub && tab == .forYou && !hereCardVisible && !showsWelcome && hub == nil && storesMode == nil
            && !aerobarOnHome
    }

    /// Once per landing, a beat after they've moved on, for long enough to read, then gone. The tab's live dot stays.
    private func playMapsCallout(_ wants: Bool) {
        calloutTask?.cancel()
        guard wants, !mapsCalloutPlayed else {
            mapsCallout = false
            return
        }
        calloutTask = Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            mapsCalloutPlayed = true
            mapsCallout = true
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            mapsCallout = false
        }
    }

    private func closeWelcome(openingHub: Bool = false, floors: Bool = false, tab: HubTab? = nil) {
        withAnimation(.spring(response: 0.38, dampingFraction: 1)) { showsWelcome = false }
        if openingHub {
            hub = HubOpening(start: arrival.hub, hubs: HubsData.hubs, floors: floors, tab: tab)
        } else {
            introduceHubsTab()
        }
    }

    /// Every landing on Home replays the arrival, while the person is at the hub. Deliberate for now, so it can be reviewed;
    /// a real release would show it far less often.
    private func landOnHome(after delay: Double) {
        guard Self.arrivalEnabled else { return }
        arrivalTask?.cancel()
        hubsHighlight = .pending
        mapsNudgeReady = false
        mapsCalloutPlayed = false
        guard homeLocation == arrival.hub.name, !Self.skipsWelcome else {
            introduceHubsTab()
            return
        }
        arrivalTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, tab == .forYou, hub == nil, storesMode == nil else { return }
            welcomeDrag = 0
            // Critically damped: it stops where it lands, with no overshoot to bounce the text on it.
            withAnimation(.spring(response: 0.5, dampingFraction: 1)) { showsWelcome = true }
        }
    }

    /// One thing at a time: the sheet, then the card lights up, then the Hubs tab introduces itself.
    private func introduceHubsTab() {
        guard hubsHighlight == .pending, !showsWelcome, hub == nil else { return }
        arrivalTask?.cancel()
        arrivalTask = Task {
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled, tab != .hubs else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { hubsHighlight = .showing }
        }
    }

    @ViewBuilder
    private func screen(for item: Tab) -> some View {
        switch item {
        case .forYou:
            DistrictHomeView(zoom: zoom, location: $homeLocation, arrival: arrival, openStores: { storesMode = StoresMode() },
                             openHub: { hub = HubOpening(start: arrival.hub, hubs: HubsData.hubs) },
                             openNavigation: { hub = HubOpening(start: arrival.hub, hubs: HubsData.hubs, floors: true) },
                             openOtherHub: { hub = HubOpening(start: $0, hubs: HubsData.hubs) },
                             introDone: (mapsNudgeReady || !Self.arrivalEnabled) && !showsWelcome)
        case .hubs:
            HubsListingView(zoom: zoom, onBack: { tab = .forYou }, openHub: { hub = HubOpening(start: $0, hubs: $1) },
                            openFloorMap: { hub = HubOpening(start: $0, hubs: $1, floors: true) },
                            openHereHub: { hub = HubOpening(start: $0, hubs: HubsData.hubs, source: HubsListingView.hereSource($0)) })
        case .maps:
            DistrictMapsView(zoom: zoom, arrival: arrival, atHub: atHub,
                             openHub: { hub = HubOpening(start: $0, hubs: HubsData.hubs) },
                             openFloors: { hub = HubOpening(start: $0, hubs: HubsData.hubs, floors: true) })
        case .hotlists:
            HotlistsPlaceholderView()
        case .search:
            SearchView()
        }
    }

    // MARK: Debug launch arguments

    /// Debug builds accept `-skipWelcome`, which goes straight to the Hubs tab reveal.
    private static var skipsWelcome: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-skipWelcome")
        #else
        return false
        #endif
    }

    /// Debug builds accept `-compactBar`, which opens with the tab bar in its scrolled, compact form and holds it there until
    /// they go to another tab or page.
    fileprivate static var forcesCompactBar: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-compactBar")
        #else
        return false
        #endif
    }

    /// Debug builds accept `-mapsCallout`, which opens Home ready to point at the Maps tab once the "You're here" card is off screen.
    private static var forcesMapsCallout: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-mapsCallout")
        #else
        return false
        #endif
    }

    /// The flows that live inside Stores mode keep their debug arguments: these open straight on it, as the app did before.
    private static var opensStoresDirectly: Bool {
        #if DEBUG
        let storeFlags = ["-startTab", "-openProductDrops", "-openStorePDP", "-openStore",
                          "-openOccasion", "-storesBottom", "-bannerPage", "-dropsRoute", "-dropsSheet", "-dropsPlan",
                          "-startSection", "-startPage", "-focusLook", "-openPiece", "-pairSelect", "-openDupe", "-openReel",
                          "-vtoNewUser", "-vtoRepeatUser", "-openMall"]
        return ProcessInfo.processInfo.arguments.contains { storeFlags.contains($0) }
        #else
        return false
        #endif
    }

    /// Debug builds accept `-rootTab hubs|maps|hotlists|search`.
    private static var launchTab: Tab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-rootTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "hubs": return .hubs
            case "maps": return .maps
            case "hotlists": return .hotlists
            case "search": return .search
            default: break
            }
        }
        #endif
        return .forYou
    }

    /// Debug builds accept `-openStoresMode`.
    private static var launchStoresMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-openStoresMode")
        #else
        return false
        #endif
    }

    /// Debug builds accept `-openHub <name>`.
    private static var launchHub: Hub? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-openHub"), i + 1 < args.count {
            return HubsData.hub(named: args[i + 1])
        }
        #endif
        return nil
    }
}

/// Lets Home tell the root whether the "You're here" card is in view, which is what decides if the hub dock is needed.
struct HubHereVisibility {
    let report: (Bool) -> Void
    func callAsFunction(_ visible: Bool) { report(visible) }
}

private struct HubHereVisibilityKey: EnvironmentKey {
    static let defaultValue = HubHereVisibility { _ in }
}

extension EnvironmentValues {
    var hubHereCardVisible: HubHereVisibility {
        get { self[HubHereVisibilityKey.self] }
        set { self[HubHereVisibilityKey.self] = newValue }
    }
}

// MARK: - Bottom nav

/// Icons with labels at rest; icons only while reading down the page.
struct DistrictTabBar: View {
    /// The new Hubs tab draws attention by glowing, with hub types rising out of that light, for as long as it's not the open tab.
    enum HubsHighlight { case none, pending, showing }

    @Binding var selection: DistrictRootView.Tab
    let compact: Bool
    var highlight: HubsHighlight = .none
    var onHubsCallout: () -> Void = {}
    /// Called once the reveal has played through and cleared, or been cut short by scrolling.
    var onRevealEnd: () -> Void = {}
    /// A tab that's live right now (Maps, while they're at a hub), which carries a pulsing dot whatever else is going on.
    var live: DistrictRootView.Tab? = nil
    /// A one-line nudge pointing down at the Maps tab, in the middle of the bar.
    var callout: String? = nil
    var onCallout: () -> Void = {}
    /// The hub they're at, shown beside the bar against the screen's right edge. The bar moves aside to make room.
    var edgeHub: HubArrival? = nil
    /// The hub page zooms out of the entry when it's tapped.
    var edgeZoom: Namespace.ID? = nil
    /// Whether the entry should open up and say what it is when it comes in.
    var edgePeeks = false
    var onEdgePeeked: () -> Void = {}
    var onEdgeHub: () -> Void = {}
    @Namespace private var pill
    /// Counts up as hub types take turns rising out of the tab.
    @State private var revealIndex = 0
    /// One pass, then the art and the blur behind it clear, so Home isn't left covered. The tab keeps its glow and NEW tag.
    @State private var revealFinished = false
    @State private var revealAnnounced = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Five slots across: 70pt at rest (350pt with the rim, inside a 390pt screen's gutters), 58pt compact.
    static let slot: CGFloat = 70
    static let compactSlot: CGFloat = 58
    /// The hub entry beside the bar opening to say what it is. The bar slides off screen for it rather than being covered.
    @State private var edgeOpen = false

    private var slotWidth: CGFloat { compact ? Self.compactSlot : Self.slot }

    private var revealing: Bool { highlight == .showing && !compact && selection == .forYou && !revealFinished }

    /// How long the entry sits beside the bar, while they keep reading down the page, before it opens to say what it is. It
    /// leaves whenever they scroll back up, and the wait starts over the next time it comes in.
    static let edgePeekDelay: Double = 4

    private func peekEdgeHub() async {
        guard edgeHub != nil, edgePeeks, !reduceMotion else { return }
        // Not the moment it slides in: once they've been scrolling a while, so it lands mid-read.
        try? await Task.sleep(for: .seconds(Self.edgePeekDelay))
        guard !Task.isCancelled else { return }
        onEdgePeeked()
        // One timing for both: the entry opening is what pushes the bar along, so they move as one.
        withAnimation(.smooth(duration: 0.5)) { edgeOpen = true }
        try? await Task.sleep(for: .seconds(2.6))
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: 0.5)) { edgeOpen = false }
    }

    var body: some View {
        HStack(spacing: R.spacingSpace0) {
            ForEach(DistrictRootView.Tab.allCases, id: \.self) { item in
                let selected = item == selection
                let highlighted = item == .hubs && !selected && highlight == .showing
                // Only while the torch is on. Once it's off the tab looks like any other, apart from its NEW tag.
                let lit = highlighted && revealing
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { selection = item }
                } label: {
                    VStack(spacing: compact ? 0 : R.spacingSpace4) {
                        Image(item.icon)
                            .renderingMode(lit ? .template : .original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(item.title)
                            .backstageText(.label3)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(height: compact ? 0 : 14)
                            .opacity(compact ? 0 : 1)
                    }
                    .foregroundStyle(lit ? M.hubPureWhite : (selected ? M.textPrimary : M.textSecondary))
                    .opacity(selected || lit ? 1 : 0.7)
                    .frame(width: slotWidth, height: compact ? 44 : 56)
                    .background {
                        if highlighted {
                            HubsTabPill(revealIndex: revealIndex, rising: revealing)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                        if selected {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .overlay(alignment: .top) {
                        if item == live, !lit {
                            HubLiveDot()
                                .offset(x: 13, y: compact ? 1 : 3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if highlighted {
                            HubsNewTag()
                                .padding(.top, compact ? -2 : 1)
                                .padding(.trailing, compact ? -2 : 2)
                                .transition(.opacity)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityValue(highlighted ? "New" : "")
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, R.spacingSpace4)
        .frame(height: compact ? 52 : 64)
        .frostedBar(in: Capsule())
        .overlay(alignment: .bottomLeading) {
            if revealing {
                HubsTabSign(index: revealIndex, onTap: onHubsCallout)
                    // A fixed width keeps the words centred over the Hubs tab, the second slot, as they change length.
                    .frame(width: 300)
                    .offset(x: R.spacingSpace4 + Self.slot * 1.5 - 150)
                    .padding(.bottom, 64 + 16)
                    .transition(.opacity)
            }
        }
        .task(id: revealing) {
            guard revealing else { return }
            if !revealAnnounced {
                revealAnnounced = true
                HubsRevealFeedback.shared.play(step: 0)
            }
            while revealIndex < HubsTabReveal.items.count - 1, !reduceMotion {
                // Long enough for the colour to turn and the hub type to settle and hold.
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }
                withAnimation(.smooth(duration: 0.25)) { revealIndex += 1 }
                HubsRevealFeedback.shared.play(step: revealIndex)
            }
            try? await Task.sleep(for: .seconds(reduceMotion ? 5 : 1.6))
            guard !Task.isCancelled else { return }
            // The art and words clear first, then the light goes out.
            withAnimation(.smooth(duration: 0.4)) { revealFinished = true }
            // A beat after the light goes out, so the two never share the screen.
            try? await Task.sleep(for: .seconds(0.5))
            onRevealEnd()
        }
        // Once they start reading down the page the moment has passed: the reveal ends rather than replaying when they scroll back.
        .onChange(of: compact) {
            if compact, highlight == .showing, !revealFinished {
                revealFinished = true
                onRevealEnd()
            }
        }
        .onChange(of: highlight) {
            if highlight == .showing {
                revealIndex = 0
                revealAnnounced = false
                // Already reading down the page when its turn came: the moment has passed, same as scrolling during it.
                revealFinished = compact
                if compact { onRevealEnd() }
            }
        }
        // Maps is the middle slot, so the callout centres on the bar.
        .overlay(alignment: .top) {
            if let callout, !revealing {
                TabCallout(text: callout, onTap: onCallout)
                    .fixedSize()
                    .offset(y: -(TabCallout.height + 8))
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
            }
        }
        .modifier(EdgeHubSlot(arrival: edgeHub, height: compact ? 52 : 64, open: edgeOpen, zoom: edgeZoom, onTap: onEdgeHub))
        // The first time the entry comes in after a landing, it opens to say what it is, holds, and closes again.
        .task(id: edgeHub?.hub.id) { await peekEdgeHub() }
        .onChange(of: edgeHub == nil) { if edgeHub == nil { edgeOpen = false } }
        .padding(.bottom, R.spacingSpace8)
        .background(alignment: .bottom) {
            if revealing {
                HubsRevealBackdrop()
                    // Ends around the top of the beam, so the rest of the page is left alone.
                    .frame(height: 360)
                    // Runs off the bottom of the screen, so nothing stays sharp under the bar.
                    .offset(y: 60)
                    // Comes up and goes down with the torch.
                    .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.72)), removal: .opacity.animation(.easeIn(duration: 0.65))))
            }
        }
        .background(alignment: .bottom) {
            LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0), location: 0),
                                   .init(color: M.backgroundPrimary, location: 0.88)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: compact)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// Lays the bar out with the hub entry beside it: centred on its own, or moved left with the entry flush against the screen's
/// right edge. The entry gives up width on narrower phones so the bar never loses its side margin.
private struct EdgeHubSlot: ViewModifier {
    let arrival: HubArrival?
    let height: CGFloat
    /// Opened out to say what it is. It pushes the bar left by just the extra width it needs, so the bar's far end slides a
    /// little way off the screen and comes back as it closes. Nothing overlaps and nothing squeezes.
    let open: Bool
    let zoom: Namespace.ID?
    let onTap: () -> Void

    func body(content: Content) -> some View {
        // A full-width row for the bar and entry to hang from, held to the screen's width. So when the open entry needs more
        // room than there is, the row runs off the left only, taking the bar with it, rather than growing and being centred.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: arrival == nil ? .center : .trailing) {
                HStack(spacing: R.spacingSpace8) {
                    content
                    if let arrival {
                        HubEdgeEntry(arrival: arrival, height: height, open: open, onTap: onTap)
                            // Closed it takes what's left beside the bar; open it's as wide as its words.
                            .fixedSize(horizontal: open, vertical: false)
                            .modifier(OptionalZoomSource(id: "edge-hub", zoom: zoom))
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.leading, arrival == nil ? 0 : R.spacingSpace16)
            }
    }
}

private struct OptionalZoomSource: ViewModifier {
    let id: String
    let zoom: Namespace.ID?

    func body(content: Content) -> some View {
        if let zoom { content.zoomSource(id: id, in: zoom) } else { content }
    }
}

/// A small dark speech bubble pointing down at a tab: a live dot, what to do, and an arrow. Tapping it goes there.
private struct TabCallout: View {
    static let height: CGFloat = 34 + 7
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: -0.5) {
                HStack(spacing: 6) {
                    HubIndoorMapIcon(size: 15, ink: M.hubPureWhite, accent: M.hubPureWhite)
                    Text(text)
                        .backstageText(.label2)
                        .foregroundStyle(M.hubPureWhite)
                        .lineLimit(1)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(M.hubPureWhite.opacity(0.7))
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .frame(height: 34)
                .background(Color.black.opacity(0.86), in: Capsule())
                .overlay(Capsule().strokeBorder(M.hubPureWhite.opacity(0.14), lineWidth: R.stroke1Px))
                TabCalloutTail()
                    .fill(Color.black.opacity(0.86))
                    .frame(width: 14, height: 7)
            }
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .environment(\.colorScheme, .dark)
        .accessibilityHint("Opens Maps")
    }
}

private struct TabCalloutTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX - 1, y: rect.minY + 1))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX + 1, y: rect.minY + 1))
        p.closeSubpath()
        return p
    }
}

// MARK: - Home

/// The District home, built from the production app's screens: everything District does as a tile grid, then the spotlight
/// carousel and "Continue where you left off". Only Stores has a destination in this app so far.
struct DistrictHomeView: View {
    let zoom: Namespace.ID
    @Binding var location: String
    let arrival: HubArrival
    let openStores: () -> Void
    let openHub: () -> Void
    let openNavigation: () -> Void
    var openOtherHub: (Hub) -> Void = { _ in }
    /// The arrival (sheet, then the Hubs tab reveal) has had its turn, so the curtain can peek.
    var introDone = true

    @Environment(\.tabBarCompactHandler) private var setTabBarCompact
    @Environment(\.hubHereCardVisible) private var reportHereVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastY: CGFloat = 0
    /// How far past the top they're pulling.
    @State private var pull: CGFloat = 0
    /// How far Home has slid down on its own to show the hub behind it.
    @State private var peek: CGFloat = DistrictHomeView.holdsCurtainPeek ? HubCurtain.peek : 0
    @State private var curtainArmed = false
    /// Set once they've read well down the page, so coming back to the top can show them the hub again.
    @State private var wentDeep = false
    @State private var lastPeek = Date.distantPast
    @State private var peekTask: Task<Void, Never>?

    private var atHub: Bool { location == arrival.hub.name }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace32) {
                // Scrolls away with the page, as in the production app.
                header
                    .padding(.bottom, -R.spacingSpace8)
                grid
                if location == arrival.hub.name {
                    VStack(alignment: .leading, spacing: R.spacingSpace16) {
                        Text("You’re here")
                            .homeText(.section)
                            .foregroundStyle(M.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        // Hidden for now: the DLF Emporio card ("Navigate inside DLF Emporio"). Only the Sunder Nursery card shows.
                        // HubHereCard(arrival: arrival, onOpen: openHub, onNavigate: openNavigation)
                        //     .zoomSource(id: arrival.hub.id, in: zoom)
                        //     .onGeometryChange(for: Bool.self) { proxy in
                        //         // In view when at least a third of the card shows within the scroll view.
                        //         guard let view = proxy.bounds(of: .scrollView) else { return false }
                        //         let shown = CGRect(origin: .zero, size: proxy.size).intersection(view)
                        //         return !shown.isNull && shown.height > proxy.size.height / 3
                        //     } action: { reportHereVisible($0) }
                        //     .onDisappear { reportHereVisible(false) }
                        // The variant for a hub without in-hub navigation.
                        HubHereCard(arrival: .sunderNursery, onOpen: { openOtherHub(HubArrival.sunderNursery.hub) })
                            .zoomSource(id: HubArrival.sunderNursery.hub.id, in: zoom)
                    }
                    .padding(.horizontal, R.spacingSpace16)
                    .transition(.opacity)
                }
                HomeSpotlight()
                continueSection
                HomeRails(openStores: openStores)
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        // Hub curtain (pull down at the top to open the hub) — hidden for now.
        // The whole page slides when it peeks, so the hub shows above it and can be tapped there.
        // .offset(y: peek)
        // Debug: `-homeScrolled` opens Home at the bottom, where the "You're here" card is in view; `-homeScrollAnchor <0…1>`
        // opens it at any depth.
        .defaultScrollAnchor(Self.debugScrollAnchor)
        .modifier(ExploreScrollTracker { y in
            let delta = y - lastY
            if y > -40 { setTabBarCompact(false) }
            else if delta < -6 { setTabBarCompact(true) }
            else if delta > 6 { setTabBarCompact(false) }
            lastY = y
            // trackCurtain(y)
        })
        // Hub curtain — hidden for now.
        // .modifier(ScrollReleaseTracker { if curtainArmed { openFromCurtain() } })
        // .sensoryFeedback(trigger: curtainArmed) { _, armed in armed ? .impact(flexibility: .solid, intensity: 0.8) : nil }
        // .onChange(of: introDone, initial: true) { if introDone { schedulePeek(after: 0.8) } }
        // .onDisappear { peekTask?.cancel(); peek = 0 }
        // .background(alignment: .top) {
        //     if atHub {
        //         HubCurtain(arrival: arrival, reveal: max(pull, peek), armed: curtainArmed, onOpen: openFromCurtain)
        //     }
        // }
        .background(alignment: .top) { DistrictTopWash() }
        .background(M.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: Curtain

    private func trackCurtain(_ y: CGFloat) {
        guard atHub else { return }
        pull = max(y, 0)
        let armed = y >= HubCurtain.threshold
        if armed != curtainArmed { curtainArmed = armed }
        if y < -700 { wentDeep = true }
        // Back at the top after reading well down: a good moment to show the hub again, at most every half minute.
        if wentDeep, y > -8 {
            wentDeep = false
            if Date().timeIntervalSince(lastPeek) > 30 { schedulePeek(after: 0.35) }
        }
    }

    /// Home slides down to show the hub behind it, holds long enough to read, and settles back.
    private func schedulePeek(after delay: Double) {
        guard atHub, !reduceMotion, !Self.holdsCurtainPeek else { return }
        peekTask?.cancel()
        peekTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, lastY > -8, pull == 0 else { return }
            lastPeek = Date()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) { peek = HubCurtain.peek }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) { peek = 0 }
        }
    }

    private func openFromCurtain() {
        peekTask?.cancel()
        curtainArmed = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { peek = 0 }
        openHub()
    }

    /// Debug builds accept `-curtainPeek`, which holds Home slid down with the hub showing above it.
    private static var holdsCurtainPeek: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-curtainPeek")
        #else
        return false
        #endif
    }

    private static var debugScrollAnchor: UnitPoint {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-homeScrollAnchor"), i + 1 < args.count, let y = Double(args[i + 1]) { return UnitPoint(x: 0.5, y: y) }
        return args.contains("-homeScrolled") ? UnitPoint(x: 0.5, y: 0.72) : .top
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            Image("home_ic_location")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 22)
                .foregroundStyle(M.iconPrimary)
                .accessibilityHidden(true)
            Menu {
                Picker("Location", selection: $location.animation(.smooth(duration: 0.3))) {
                    ForEach(HomeData.locations, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: R.spacingSpace4) {
                        Text(location)
                            .backstageText(.title3)
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(M.textPrimary)
                    }
                    Text(HomeData.addresses[location] ?? "")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Location, \(location)")
            Spacer(minLength: 0)
            Button {} label: {
                Text("N")
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(M.surfaceSecondary, in: Circle())
                    .overlay(Circle().strokeBorder(M.textPurple, lineWidth: R.stroke2Px))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace4)
    }

    // MARK: Grid

    private var grid: some View {
        VStack(spacing: R.spacingSpace8) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(HomeData.topRow) { HomeTile(tile: $0) }
            }
            .padding(.bottom, R.spacingSpace8)
            HStack(spacing: R.spacingSpace8) {
                HomeTile(tile: HomeData.stores, action: openStores)
                    .zoomSource(id: "stores-mode", in: zoom)
                ForEach(HomeData.middleRow) { HomeTile(tile: $0) }
            }
            HStack(spacing: R.spacingSpace8) {
                ForEach(HomeData.wideRow) { HomeWideTile(tile: $0) }
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    // MARK: Continue

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Continue where you left off")
                .homeText(.section)
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace16) {
                    ForEach(HomeData.recents) { HomeRecentCard(item: $0) }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }
}

/// Calls back when a finger lifts off the scroll view, so a pull held past the curtain's threshold opens the hub on release.
/// Before iOS 18 there's no lift to hear, so the curtain stays a peek and a tap.
private struct ScrollReleaseTracker: ViewModifier {
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { old, new in
                if old == .interacting, new != .interacting { onRelease() }
            }
        } else {
            content
        }
    }
}

/// The indigo wash at the top of the screen, matched to the production app: low and short, gone about 120pt down.
struct DistrictTopWash: View {
    var body: some View {
        LinearGradient(stops: [.init(color: M.districtWash.opacity(0.17), location: 0),
                               .init(color: M.districtWash.opacity(0.155), location: 0.25),
                               .init(color: M.districtWash.opacity(0.1), location: 0.45),
                               .init(color: M.districtWash.opacity(0.055), location: 0.65),
                               .init(color: M.districtWash.opacity(0.015), location: 0.85),
                               .init(color: M.districtWash.opacity(0), location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 124)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Tiles

private struct HomeTile: View {
    let tile: HomeData.Tile
    var action: (() -> Void)? = nil

    private var content: some View {
        VStack(spacing: 2) {
            Text(tile.title)
                .backstageText(.title3)
                .foregroundStyle(M.textPrimary)
            Text(tile.line)
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 38)
        .padding(.bottom, R.spacingSpace12)
        .background {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner16)
                .fill(LinearGradient(colors: [tile.tint.opacity(0.16), M.backgroundPrimary.opacity(0)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
        .overlay(alignment: .top) {
            Image(tile.art)
                .resizable()
                .scaledToFit()
                .frame(height: 42)
                .offset(y: -10)
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(tile.title). \(tile.line)")
        } else {
            content.accessibilityElement(children: .combine)
        }
    }
}

private struct HomeWideTile: View {
    let tile: HomeData.Tile

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tile.title)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                Text(tile.line)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            Image(tile.art)
                .resizable()
                .scaledToFit()
                .frame(height: 46)
                .padding(.trailing, 4)
                .accessibilityHidden(true)
        }
        .background(LinearGradient(colors: [tile.tint.opacity(0.1), M.backgroundPrimary.opacity(0)], startPoint: .trailing, endPoint: .leading))
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Spotlight

private struct HomeSpotlight: View {
    @State private var page = 0

    private var current: HomeData.Spot { HomeData.spots[page] }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("In the spotlight")
                .homeText(.section)
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)

            PeekCarousel(items: HomeData.spots, cardWidth: 237, cardHeight: 316, gap: 16, page: $page) { spot in
                Color.clear
                    .overlay { Image(spot.image).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                    .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                    .frame(width: 237, height: 316)
                    .accessibilityElement()
                    .accessibilityLabel(spot.title)
            }

            VStack(spacing: R.spacingSpace4) {
                Text(current.title)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                Text(current.line)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .id(page)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: page)

            CarouselDots(count: HomeData.spots.count, page: page)
        }
    }
}

private struct HomeRecentCard: View {
    let item: HomeData.Recent
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            HStack(alignment: .top) {
                Image(item.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                Spacer(minLength: 0)
                Button { saved.toggle() } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: saved)
                .accessibilityLabel(saved ? "Saved" : "Save \(item.title)")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .backstageText(.hubLabel1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text(item.line)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
            }
            HStack(spacing: R.spacingSpace8) {
                Text("View details")
                    .backstageText(.title4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(M.textOffer)
        }
        .padding(10)
        .frame(width: 154, alignment: .leading)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }
}

// MARK: - Carousel

/// A looping carousel: the centre card at full size, its neighbours stepped back to 80% and dimmed, with the same gap on both
/// sides on any screen width. `page` is the card's index in `items`.
struct PeekCarousel<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let gap: CGFloat
    @Binding var page: Int
    @ViewBuilder let card: (Item) -> Card

    private static var loops: Int { 40 }
    @State private var position: Int?
    @State private var width: CGFloat = 0

    init(items: [Item], cardWidth: CGFloat, cardHeight: CGFloat, gap: CGFloat, page: Binding<Int>,
         @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.gap = gap
        _page = page
        self.card = card
        // Set up front: moving it after appearing also drags any scroll view the carousel sits inside.
        _position = State(initialValue: items.count * Self.loops / 2)
    }

    /// Neighbours shrink around their centres, so the layout overlaps by what they lose to keep the visible gap.
    private var spacing: CGFloat { gap - cardWidth * 0.1 }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                ForEach(0..<items.count * Self.loops, id: \.self) { index in
                    card(items[index % items.count])
                        .frame(width: cardWidth, height: cardHeight)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.8)
                                .opacity(phase.isIdentity ? 1 : 0.4)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .frame(height: cardHeight)
        .contentMargins(.horizontal, max((width - cardWidth) / 2, 0), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $position, anchor: .center)
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: position) { if let position { page = position % items.count } }
        .sensoryFeedback(.selection, trigger: page)
    }
}

struct CarouselDots: View {
    let count: Int
    let page: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(M.iconPrimary.opacity(index == page ? 1 : 0.32))
                    .frame(width: index == page ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.25), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(page + 1) of \(count)")
    }
}

// MARK: - Data

enum HomeData {
    struct Tile: Identifiable {
        var id: String { title }
        let title: String
        let line: String
        let art: String
        let tint: Color
    }

    struct Spot: Identifiable {
        var id: String { title }
        let title: String
        let line: String
        let image: String
    }

    struct Recent: Identifiable {
        var id: String { title }
        let title: String
        let line: String
        let image: String
    }

    /// The first one is where the person is right now, a hub, which is what brings up the arrival sheet and card.
    static let locations = ["DLF Emporio", "Sunder Nursery", "International Tech Park", "Vatika City", "Cyberhub, DLF Phase 2"]
    static let addresses = ["DLF Emporio": "Vasant Kunj, New Delhi",
                            "Sunder Nursery": "Nizamuddin, New Delhi",
                            "International Tech Park": "Near Sec 59, Off, Golf Course Ext Rd, Gurugram",
                            "Vatika City": "Sector 49, Gurugram",
                            "Cyberhub, DLF Phase 2": "DLF Cyber City, Gurugram"]

    static let topRow = [
        Tile(title: "Dining", line: "Eat out & save", art: "home_ic_dining", tint: Color(hex: 0xE5534B)),
        Tile(title: "Movies", line: "Grab best seats", art: "home_ic_movies", tint: Color(hex: 0x5B50E0)),
        Tile(title: "Events", line: "Buy tickets", art: "home_ic_events", tint: Color(hex: 0xC9A227)),
    ]
    static let stores = Tile(title: "Stores", line: "Shop in-store", art: "home_ic_stores", tint: Color(hex: 0x1FB5A8))
    static let middleRow = [
        Tile(title: "Activities", line: "Try fun outings", art: "home_ic_activities", tint: Color(hex: 0xC56BD1)),
        Tile(title: "Play", line: "Book courts", art: "home_ic_play", tint: Color(hex: 0x2FBF71)),
    ]
    static let wideRow = [
        Tile(title: "Comedy", line: "Catch stand-ups", art: "home_ic_comedy", tint: Color(hex: 0xE8A33D)),
        Tile(title: "Salons", line: "Book appointment", art: "home_ic_salons", tint: Color(hex: 0x8A63E6)),
    ]

    static let spots = [
        Spot(title: "The Ramayana Game", line: "Play the game & win rewards", image: "home_spot_ramayana"),
        Spot(title: "The Diwali edit", line: "Discover feasts, flavours & festive tables", image: "home_spot_diwali"),
        Spot(title: "Dining Carnival", line: "40+ restaurants, all on offer", image: "hub_buzz_dining"),
        Spot(title: "1+1 on Starbucks", line: "Till 22 Sept", image: "hub_buzz_starbucks"),
    ]

    static let recents = [
        Recent(title: "Unico", line: "Global Foyer Mall, Gurgaon", image: "home_cont_unico"),
        Recent(title: "JOYALUKKAS JEWELLERY", line: "Sector 44, Gurgaon", image: "home_cont_joyalukkas"),
        Recent(title: "Ambience Mall", line: "DLF Phase 3, Gurgaon", image: "hub_ambience"),
    ]
}

// MARK: - Hotlists

/// The nav has a Hotlists tab, but the screen isn't designed yet.
struct HotlistsPlaceholderView: View {
    var body: some View {
        VStack(spacing: R.spacingSpace12) {
            Image("hub_nav_hotlists")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .opacity(0.7)
                .accessibilityHidden(true)
            Text("Hotlists are coming soon")
                .backstageText(.hubTitle2)
                .foregroundStyle(M.textPrimary)
            Text("The places you can't stop talking about, all in one list.")
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, R.spacingSpace40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(M.backgroundPrimary.ignoresSafeArea())
    }
}

#Preview {
    DistrictRootView().preferredColorScheme(.dark)
}
