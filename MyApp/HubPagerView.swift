import Observation
import SwiftUI

/// What the pager tracks: which hub is in front and how far it has opened from its minimal card (0) to the full page (1).
@Observable
final class HubPagerState {
    private(set) var expansion: CGFloat = 0
    /// Paging stops once a hub has started opening.
    private(set) var isLocked = false
    var current: String?
    private var floorsOpen = false
    private var scrollExpansion: CGFloat = 0

    init(current: String) { self.current = current }

    func report(scroll value: CGFloat, from id: String) {
        guard id == current else { return }
        scrollExpansion = value
        publish()
    }

    /// The floors directory always shows on the full page.
    func setFloorsOpen(_ open: Bool, from id: String) {
        guard id == current else { return }
        floorsOpen = open
        publish()
    }

    private func publish() {
        let value = floorsOpen ? 1 : scrollExpansion
        if value != expansion { expansion = value }
        let locked = value > 0.01
        if locked != isLocked { isLocked = locked }
    }
}

// Disabled: hub pages already have a lot of horizontal scrolling inside them, which competed with swiping between hubs.
// To bring it back, uncomment this and present `HubPagerView` from `DistrictRootView`, passing `pager:` and `safeTop:` to each page.
/*
/// Hub pages as a swipeable row of minimal cards. Swiping sideways moves between hubs; scrolling a card up opens it into the
/// full page, and scrolling back to the top returns it to a card. Everything here is a transform, so nothing re-lays out.
struct HubPagerView: View {
    let hubs: [Hub]

    private let start: String
    @State private var state: HubPagerState
    @State private var position: String?

    /// How far a minimal card is scaled down, and the gap between it and its neighbours.
    static let minimalScale: CGFloat = 0.88
    private static let gap: CGFloat = 10

    init(hubs: [Hub], start: Hub) {
        self.hubs = hubs
        self.start = start.id
        _state = State(initialValue: HubPagerState(current: start.id))
        _position = State(initialValue: start.id)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
            let height = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let safeTop = geo.safeAreaInsets.top
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: Self.gap - width * (1 - Self.minimalScale)) {
                        ForEach(hubs) { hub in
                            HubPageFrame(state: state, id: hub.id, safeTop: safeTop) {
                                HubDetailView(hub: hub, pager: state, safeTop: safeTop)
                            }
                            .frame(width: width, height: height)
                            .zIndex(state.current == hub.id ? 1 : 0)
                            .id(hub.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $position, anchor: .center)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollIndicators(.hidden)
                .scrollDisabled(state.isLocked)
                .scrollClipDisabled()
                .ignoresSafeArea()
                // A lazy row can't reach an unbuilt page from its initial position alone.
                .onAppear { proxy.scrollTo(start, anchor: .center) }
                .onChange(of: position) { if let position { state.current = position } }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: state.current)
    }
}

/// Applies a page's card transform. Reads the expansion here, so a scroll frame only updates this wrapper.
private struct HubPageFrame<Content: View>: View {
    let state: HubPagerState
    let id: String
    let safeTop: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        let isCurrent = state.current == id
        let progress = isCurrent ? state.expansion : 0
        let scale = HubPagerView.minimalScale + (1 - HubPagerView.minimalScale) * progress
        content()
            .clipShape(RoundedRectangle(cornerRadius: 28 * (1 - progress), style: .continuous))
            .scaleEffect(scale, anchor: .top)
            .offset(y: (safeTop - 8) * (1 - progress))
            // Neighbours step back behind the card that's opening.
            .opacity(isCurrent ? 1 : 1 - state.expansion)
    }
}
*/
