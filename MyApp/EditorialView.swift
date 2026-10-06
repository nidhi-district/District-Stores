import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

struct EditorialView: View {
    @State private var scrollY: CGFloat = 0
    @State private var sectionTops: [EditorialSection: CGFloat] = [:]
    @State private var contentHeight: CGFloat = 1
    @Environment(\.tabBarCompactHandler) private var setTabBarCompact

    var body: some View {
        GeometryReader { screen in
            let viewport = screen.size.height
            let active = activeSection(viewport: viewport)
            let progress = -scrollY / max(1, contentHeight - viewport)

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

                            VStack(spacing: R.spacingSpace40) {
                                HomegrownSection().trackSection(.stories).id(EditorialSection.stories)
                                RackSection().trackSection(.rack).id(EditorialSection.rack).revealOnScroll()
                                TickerStrip()
                                StaplesSection().trackSection(.staples).id(EditorialSection.staples).revealOnScroll()
                                PullQuote()
                                LooksSection().trackSection(.looks).id(EditorialSection.looks).revealOnScroll()
                                InOutList().revealOnScroll()
                                PlansSection().trackSection(.plans).id(EditorialSection.plans).revealOnScroll()
                                PaletteSection().trackSection(.palette).id(EditorialSection.palette).revealOnScroll()
                            }
                            .padding(.top, R.spacingSpace80 + R.spacingSpace16)

                            Colophon(
                                jump: { section in withAnimation(.smooth) { proxy.scrollTo(section, anchor: .top) } }
                            )
                            .padding(.top, R.spacingSpace64)
                        }
                        .background {
                            GeometryReader { g in Color.clear.preference(key: ContentHeightKey.self, value: g.size.height) }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .coordinateSpace(name: "editorial")
                    .onPreferenceChange(ScrollOffsetKey.self) { y in
                        // Shrink the floating tab bar while reading down; expand on the way back up or near the top.
                        let delta = y - scrollY
                        if y > -40 { setTabBarCompact(false) }
                        else if delta < -6 { setTabBarCompact(true) }
                        else if delta > 6 { setTabBarCompact(false) }
                        scrollY = y
                    }
                    .onPreferenceChange(SectionFramesKey.self) { sectionTops = $0 }
                    .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }

                    TopBar(scrolled: scrollY < -8, section: active, progress: progress)
                }
            }
            .environment(\.editorialViewport, viewport)
        }
    }

    /// The last section whose top has passed ~40% of the screen.
    private func activeSection(viewport: CGFloat) -> EditorialSection? {
        let line = viewport * 0.4
        return EditorialSection.allCases.last { (sectionTops[$0] ?? .infinity) < line }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Top bar (navigation layer: Liquid Glass)

/// Explore tab header: the shared tab header titled "Explore". While reading, the location line
/// names the section in view, with a reading-progress hairline underneath.
struct TopBar: View {
    let scrolled: Bool
    let section: EditorialSection?
    let progress: CGFloat
    @State private var location = "Vatika City"
    private let locations = ["Vatika City", "Golf Course Extension Road", "Cyberhub, DLF Phase 2", "Sector 29"]

    var body: some View {
        VStack(spacing: R.spacingSpace0) {
            TabHeader(title: "Explore", location: $location, locations: locations,
                      subtitle: scrolled ? section?.title : nil)
            ReadingProgress(progress: progress)
                .padding(.horizontal, R.spacingSpace16)
                .opacity(scrolled ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.25), value: scrolled)
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
            // Back tape: small caps, drifting the other way.
            // Back tape: barely-there white, so it reads as texture.
            M.textWhite.opacity(0.06)
                .frame(height: 30)
                .overlay(alignment: .leading) {
                    Marquee(speed: 24, reversed: true) {
                        Text("NEW IN  ✦  THE DISTRICT EDIT  ✦  FESTIVE '26  ✦  ")
                            .font(.custom("BeVietnamPro-Bold", size: 12, relativeTo: .caption))
                            .tracking(2.4)
                            .foregroundStyle(M.textWhite.opacity(0.45))
                    }
                }
                .rotationEffect(.degrees(4))

            // Front tape: big words with photo stickers between them.
            M.surfaceSecondary
                .frame(height: 46)
                .overlay(alignment: .leading) {
                    Marquee(speed: 36) {
                        HStack(spacing: R.spacingSpace12) {
                            ForEach(Array(phrases.enumerated()), id: \.offset) { i, phrase in
                                Text(phrase.text)
                                    .editorialDisplay(DisplaySize.card)
                                    .foregroundStyle(M.textPrimary)
                                sticker(phrase.photo, tilt: i.isMultiple(of: 2) ? -8 : 6)
                            }
                        }
                        .padding(.trailing, R.spacingSpace12)
                    }
                }
                .rotationEffect(.degrees(-2.5))
                .elevation(.shadow100)
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
