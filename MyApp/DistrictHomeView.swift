import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Going back to the landing

/// Lets Stores mode's home button return to the For You landing.
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

/// App root: For You, Hubs, Hotlists and Search behind the Hub mode bottom nav (Figma 14220:31787).
/// The For You landing's Stores entry opens Stores mode, the existing Stores, Edit and Search tabs.
struct DistrictRootView: View {
    enum Tab: Hashable, CaseIterable {
        case forYou, hubs, hotlists, search

        var title: String {
            switch self {
            case .forYou: "For you"
            case .hubs: "Hubs"
            case .hotlists: "Hotlists"
            case .search: "Search"
            }
        }

        var icon: String {
            switch self {
            case .forYou: "hub_nav_foryou"
            case .hubs: "hub_nav_hubs"
            case .hotlists: "hub_nav_hotlists"
            case .search: "hub_nav_search"
            }
        }
    }

    private struct StoresMode: Identifiable {
        let id = "stores-mode"
    }

    @State private var tab: Tab = DistrictRootView.launchTab
    @State private var storesMode: StoresMode? = DistrictRootView.launchStoresMode ? StoresMode() : nil
    @State private var hub: Hub? = DistrictRootView.launchHub
    @Namespace private var zoom

    var body: some View {
        if Self.opensStoresDirectly {
            ContentView()
        } else {
            shell
        }
    }

    private var shell: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { item in
                screen(for: item)
                    .tag(item)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
            }
        }
        .overlay(alignment: .bottom) { DistrictTabBar(selection: $tab) }
        .tint(M.iconPrimary)
        .sensoryFeedback(.selection, trigger: tab)
        .readerCover(item: $hub) { hub in
            HubDetailView(hub: hub).zoomTransition(id: hub.id, in: zoom)
        }
        .readerCover(item: $storesMode) { _ in
            ContentView()
                .environment(\.districtHomeAction, DistrictHomeAction { storesMode = nil })
                .zoomTransition(id: "stores-mode", in: zoom)
        }
    }

    @ViewBuilder
    private func screen(for item: Tab) -> some View {
        switch item {
        case .forYou:
            DistrictHomeView(zoom: zoom, openStores: { storesMode = StoresMode() },
                             openHubs: { tab = .hubs }, openHub: { hub = $0 })
        case .hubs:
            HubsListingView(zoom: zoom, onBack: { tab = .forYou }, openHub: { hub = $0 })
        case .hotlists:
            HotlistsPlaceholderView()
        case .search:
            SearchView()
        }
    }

    // MARK: Debug launch arguments

    /// The flows that live inside Stores mode keep their debug arguments: these open straight on it, as the app did before.
    private static var opensStoresDirectly: Bool {
        #if DEBUG
        let storeFlags = ["-startTab", "-openProductDrops", "-openGiftVouchers", "-openTryOn", "-openStorePDP", "-openStore",
                          "-openOccasion", "-storesBottom", "-bannerPage", "-dropsRoute", "-dropsSheet", "-dropsPlan",
                          "-startSection", "-startPage", "-focusLook", "-openPiece", "-pairSelect", "-openDupe", "-openReel",
                          "-vtoNewUser", "-vtoRepeatUser"]
        return ProcessInfo.processInfo.arguments.contains { storeFlags.contains($0) }
        #else
        return false
        #endif
    }

    /// Debug builds accept `-rootTab hubs|hotlists|search`.
    private static var launchTab: Tab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-rootTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "hubs": return .hubs
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

// MARK: - Hub mode bottom nav

struct DistrictTabBar: View {
    @Binding var selection: DistrictRootView.Tab
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: R.spacingSpace0) {
            ForEach(DistrictRootView.Tab.allCases, id: \.self) { item in
                let selected = item == selection
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { selection = item }
                } label: {
                    VStack(spacing: R.spacingSpace4) {
                        Image(item.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(item.title)
                            .backstageText(.hubNavLabel)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .foregroundStyle(selected ? M.textPrimary : M.textSecondary)
                    .opacity(selected ? 1 : 0.7)
                    .frame(width: 76, height: 56)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, R.spacingSpace4)
        .frame(height: 64)
        .liquidGlass(in: Capsule(), interactive: true)
        .frame(maxWidth: .infinity)
        .padding(.bottom, R.spacingSpace8)
        .background(alignment: .bottom) {
            LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0), location: 0),
                                   .init(color: M.backgroundPrimary, location: 0.88)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

// MARK: - For You landing

/// The new District home. It has no Figma of its own yet, so it follows the Hub mode look:
/// one entry into Stores mode, one into the hubs listing, and a rail of the closest hubs.
struct DistrictHomeView: View {
    let zoom: Namespace.ID
    let openStores: () -> Void
    let openHubs: () -> Void
    let openHub: (Hub) -> Void

    @State private var location = "Vatika City"
    private let locations = ["Vatika City", "Golf Course Extension Road", "Cyberhub, DLF Phase 2", "Sector 29"]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace32) {
                entries
                nearby
            }
            .padding(.top, R.spacingSpace12)
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            TabHeader(title: "For you", location: $location, locations: locations, showsHomeButton: false)
        }
        .background(alignment: .top) { DistrictGlow() }
        .background(M.backgroundPrimary.ignoresSafeArea())
    }

    private var entries: some View {
        HStack(spacing: R.spacingSpace12) {
            EntryTile(title: "Stores", line: "Fashion, beauty and more near you", image: "look_quiet_luxury", action: openStores)
                .zoomSource(id: "stores-mode", in: zoom)
            EntryTile(title: "Hubs", line: "Malls, high streets, markets and more", image: "hub_select", action: openHubs)
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private var nearby: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack {
                Text("Hubs near you")
                    .backstageText(.hubTitle2)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: R.spacingSpace8)
                Button("See all", action: openHubs)
                    .buttonStyle(BackstageTextButtonStyle())
            }
            .padding(.horizontal, R.spacingSpace16)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                    ForEach(HubsData.nearby) { hub in
                        Button { openHub(hub) } label: {
                            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                                Color.clear
                                    .frame(width: 160, height: 120)
                                    .overlay {
                                        Image(hub.image).resizable().scaledToFill()
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                                    Text(hub.name)
                                        .backstageText(.title4)
                                        .foregroundStyle(M.textPrimary)
                                        .lineLimit(1)
                                    Text("\(hub.distance) • \(hub.locality)")
                                        .backstageText(.label3)
                                        .foregroundStyle(M.textTertiary)
                                        .lineLimit(1)
                                }
                                .frame(width: 160, alignment: .leading)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }
}

/// A tall photo tile that opens a mode of the app.
private struct EntryTile: View {
    let title: String
    let line: String
    let image: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 232)
                .overlay {
                    Image(image).resizable().scaledToFill()
                }
                .overlay {
                    LinearGradient(stops: [.init(color: .black.opacity(0), location: 0.35),
                                           .init(color: .black.opacity(0.82), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: R.spacingSpace4) {
                        HStack(spacing: R.spacingSpace4) {
                            Text(title)
                                .backstageText(.hubTitle2)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(M.textWhite)
                        Text(line)
                            .backstageText(.label3)
                            .foregroundStyle(M.textWhite.opacity(0.76))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(R.spacingSpace12)
                }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title). \(line)")
    }
}

// MARK: - Hotlists

/// The Figma's nav has a Hotlists tab, but the screen isn't designed yet.
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
