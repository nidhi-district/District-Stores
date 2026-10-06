import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

struct EditorialView: View {
    @State private var scrollY: CGFloat = 0
    @Environment(\.tabBarCompactHandler) private var setTabBarCompact

    var body: some View {
        GeometryReader { screen in
            let viewport = screen.size.height

            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    M.backgroundPrimary.ignoresSafeArea()
                    DotField(scrollY: scrollY)
                    Spotlight(scrollY: scrollY)

                    ScrollView(.vertical) {
                        VStack(spacing: R.spacingSpace0) {
                            GeometryReader { g in
                                Color.clear.preference(key: ScrollOffsetKey.self, value: g.frame(in: .named("editorial")).minY)
                            }
                            .frame(height: 0)
                            .id("top")

                            VStack(spacing: R.spacingSpace72) {
                                HomegrownSection().id(EditorialSection.stories)
                                RackSection().id(EditorialSection.rack).revealOnScroll()
                                // The strip's own height already leaves air around the tilted tapes,
                                // so it sits closer to its neighbours than a full section gap.
                                TickerStrip().padding(.vertical, -R.spacingSpace40)
                                StaplesSection().id(EditorialSection.staples).revealOnScroll()
                                PullQuote()
                                LooksSection().id(EditorialSection.looks).revealOnScroll()
                                // Collage rail retired; the vibe cards now carry "fits for every plan".
                                // PlansSection().id(EditorialSection.plans).revealOnScroll()
                                VibeSection().id(EditorialSection.vibes).revealOnScroll()
                                PaletteSection().id(EditorialSection.palette).revealOnScroll()
                            }
                            .padding(.top, R.spacingSpace80 + R.spacingSpace16)

                            Colophon(
                                jump: { section in withAnimation(.smooth) { proxy.scrollTo(section, anchor: .top) } }
                            )
                            .padding(.top, R.spacingSpace64)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .coordinateSpace(name: "editorial")
                    // iOS 18+: read the offset straight from the scroll view; the preference is
                    // the iOS 17 path, and on newer systems it can stop reporting after layout.
                    .modifier(ExploreScrollTracker(onScroll: scrolled(to:)))
                    .onPreferenceChange(ScrollOffsetKey.self) { y in
                        if #available(iOS 18.0, macOS 15.0, *) { return }
                        scrolled(to: y)
                    }

                    TopBar(scrolled: scrollY < -8)
                }
            }
            .environment(\.editorialViewport, viewport)
        }
    }

    /// `y` is the content's top edge: 0 at rest, negative as the page scrolls down.
    private func scrolled(to y: CGFloat) {
        // Shrink the floating tab bar while reading down; expand on the way back up or near the top.
        let delta = y - scrollY
        if y > -40 { setTabBarCompact(false) }
        else if delta < -6 { setTabBarCompact(true) }
        else if delta > 6 { setTabBarCompact(false) }
        scrollY = y
    }

}

private struct ExploreScrollTracker: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                -(geo.contentOffset.y + geo.contentInsets.top)
            } action: { _, y in
                onScroll(y)
            }
        } else {
            content
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Top bar (navigation layer: Liquid Glass)

/// Explore tab header: the shared tab header titled "Explore". Its content never changes; once
/// the page scrolls it sits on a frosted bar with a bottom hairline.
struct TopBar: View {
    let scrolled: Bool
    @State private var location = "Vatika City"
    private let locations = ["Vatika City", "Golf Course Extension Road", "Cyberhub, DLF Phase 2", "Sector 29"]

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TabHeader(title: "Explore", location: $location, locations: locations)
        .background {
            if scrolled {
                backdrop
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: scrolled)
    }

    /// Once the page moves, the header becomes a frosted bar running up under the status bar,
    /// lit by the same neutral spotlight as the page so it stays one stage.
    private var backdrop: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .top) {
                if reduceTransparency {
                    M.backgroundPrimary
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                    M.backgroundPrimary.opacity(0.55)
                }
                // The page's spotlight, carried onto the bar.
                RadialGradient(
                    colors: [M.iconWhite.opacity(0.12), M.iconWhite.opacity(0.03), M.iconWhite.opacity(0)],
                    center: .top, startRadius: 0, endRadius: w * 0.75
                )
                Ellipse()
                    .fill(M.iconWhite.opacity(0.14))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 20)
                    .offset(y: -12)
            }
            .frame(width: w, height: g.size.height)
            .overlay(alignment: .bottom) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct TickerStrip: View {
    /// Phrases on the front tape, each followed by a little photo cut-out.
    private let phrases: [(text: String, photo: String)] = [
        ("new drops", "rack_adidas_popper"),
        ("homegrown labels", "story_gully_labs"),
        ("shop the look", "look_parisian_edge"),
        ("colour stories", "palette_rose-clay_1"),
        ("festive '26", "plan_diwali_1"),
    ]

    var body: some View {
        // The tapes are drawn as an overlay so their extra width (enough that the ends never show
        // when tilted) can't widen the page.
        Color.clear
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            .overlay { tapes.frame(width: 520) }
            .clipped()
            .accessibilityHidden(true)
    }

    private var tapes: some View {
        ZStack {
            // Back tape: small caps drifting the other way, in barely-there white so it reads as texture.
            M.textWhite.opacity(0.06)
                .frame(height: 30)
                .overlay(alignment: .leading) {
                    Marquee(speed: 24, reversed: true) {
                        Text("NEW IN  ✦  THE DISTRICT EDIT  ✦  FESTIVE '26  ✦  ")
                            .font(.custom("BeVietnamPro-Regular", size: 12, relativeTo: .caption))
                            .tracking(2.4)
                            .foregroundStyle(M.textWhite.opacity(0.45))
                    }
                }
                .rotationEffect(.degrees(7))

            // Front tape: words with photo stickers between them, on a solid band with no shadow so
            // it reads as decoration, not a control.
            M.surfaceSecondary
                .frame(height: 46)
                .overlay(alignment: .leading) {
                    Marquee(speed: 36) {
                        HStack(spacing: R.spacingSpace12) {
                            ForEach(Array(phrases.enumerated()), id: \.offset) { i, phrase in
                                Text(phrase.text)
                                    .backstageText(.body2)
                                    .foregroundStyle(M.textSecondary)
                                sticker(phrase.photo, tilt: i.isMultiple(of: 2) ? -8 : 6)
                            }
                        }
                        .padding(.trailing, R.spacingSpace12)
                    }
                }
                .rotationEffect(.degrees(-2.5))
        }
    }

    private func sticker(_ photo: String, tilt: Double) -> some View {
        ArtView(art: Art(photo, [0x444444, 0x888888]))
            .frame(width: 46, height: 30)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(M.borderModerate, lineWidth: R.stroke1PlusHalfPx))
            .rotationEffect(.degrees(tilt))
    }
}

// MARK: - Colophon

/// Magazine back page: an "in this issue" contents list that jumps to each section, signed off
/// "Curated by" District Stores.
struct Colophon: View {
    let jump: (EditorialSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            OrnamentRule()

            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("In this issue")
                    .backstageText(.specialTitle)
                    .foregroundStyle(M.textTertiary)
                    .padding(.bottom, R.spacingSpace8)

                ForEach(Array(EditorialSection.allCases.enumerated()), id: \.element) { i, section in
                    Button { jump(section) } label: {
                        HStack(spacing: R.spacingSpace12) {
                            Text(String(format: "%02d", i + 1))
                                .backstageText(.label3)
                                .foregroundStyle(M.textTertiary)
                                .frame(width: R.spacingSpace24, alignment: .leading)
                            Text(section.title)
                                .backstageText(.title4)
                                .foregroundStyle(M.textPrimary)
                                .lineLimit(1)
                                .layoutPriority(1)
                            DottedLeader()
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(M.iconTertiary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Go to \(section.title)")
                }
            }

            curatedBy
                .padding(.top, R.spacingSpace24)
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    /// Sign-off: the issue is curated by District Stores.
    private var curatedBy: some View {
        VStack(spacing: R.spacingSpace16) {
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                .padding(.bottom, R.spacingSpace16)
            Text("Curated by")
                .backstageText(.specialTitle)
                .foregroundStyle(M.textTertiary)
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 148)
                .opacity(0.92)
            Text("Fresh fits from the stores around you")
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, R.spacingSpace24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Curated by District Stores. Fresh fits from the stores around you.")
    }
}

#Preview {
    EditorialView().preferredColorScheme(.dark)
}
