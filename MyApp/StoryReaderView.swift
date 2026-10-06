import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Reader (pager)

/// Brand-story reader: swipe sideways between stories, scroll down to read. Each story sits on a
/// soft, darkened backdrop of its own cover photo.
struct StoryReaderView: View {
    private let stories = EditorialData.stories
    @State private var current: String?
    /// Reading progress per story, present only once the reader has scrolled past the cover.
    @State private var reading: [String: CGFloat] = [:]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(story: Story) {
        _current = State(initialValue: story.id)
    }

    private var index: Int { stories.firstIndex { $0.id == current } ?? 0 }
    private var currentStory: Story { stories[index] }
    private var readingProgress: CGFloat? { reading[currentStory.id] }

    var body: some View {
        GeometryReader { screen in
            let topInset = screen.safeAreaInsets.top
            ZStack(alignment: .top) {
                ScrollViewReader { pager in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: R.spacingSpace0) {
                            ForEach(stories) { story in
                                StoryPage(story: story, next: next(after: story), topInset: topInset) {
                                    go(to: next(after: story).id)
                                } onReading: { state in
                                    reading[story.id] = state.isReading ? state.progress : nil
                                }
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(story.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $current)
                    .scrollIndicators(.hidden)
                    .onAppear { pager.scrollTo(current) }
                }
                .ignoresSafeArea()

                // Soft fade behind the header while reading, so it stays legible over the text.
                LinearGradient(colors: [M.backgroundPrimary, M.backgroundPrimary.opacity(0.85), M.backgroundPrimary.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: topInset + 84)
                    .ignoresSafeArea(edges: .top)
                    .opacity(readingProgress == nil ? 0 : 1)
                    .allowsHitTesting(false)

                VStack(spacing: R.spacingSpace8) {
                    controls
                    progressLine
                }

                // Story position sits at the foot of the cover and steps aside once reading starts.
                if readingProgress == nil {
                    dotsPill
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, R.spacingSpace8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: readingProgress == nil)
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: current)
        .accessibilityAction(named: "Next story") { go(to: next(after: currentStory).id) }
        .accessibilityAction(named: "Previous story") { go(to: stories[(index - 1 + stories.count) % stories.count].id) }
    }

    private func next(after story: Story) -> Story {
        let i = stories.firstIndex { $0.id == story.id } ?? 0
        return stories[(i + 1) % stories.count]
    }

    private func go(to id: String) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { current = id }
    }

    /// Close and share, floating over every page; the brand's name joins them while reading.
    private var controls: some View {
        GlassGroup(spacing: R.spacingSpace8) {
            HStack(spacing: R.spacingSpace8) {
                GlassIconButton(systemName: "xmark", label: "Close story") { dismiss() }
                Spacer(minLength: 0)
                if readingProgress != nil {
                    titlePill
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Spacer(minLength: 0)
                ShareLink(item: "\(currentStory.title) — \(currentStory.brand), on District Editorial") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 44, height: 44)
                        .liquidGlass(in: Circle(), interactive: true, clear: true)
                }
                .accessibilityLabel("Share story")
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace4)
    }

    /// While reading: the brand's logo in a circle and its name.
    private var titlePill: some View {
        HStack(spacing: R.spacingSpace8) {
            BrandMark(brand: currentStory.brand, mark: currentStory.mark, size: 30)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            Text(currentStory.brand)
                .backstageText(.title4)
                .foregroundStyle(M.textPrimary)
                .lineLimit(1)
        }
        .padding(.leading, R.spacingSpace8)
        .padding(.trailing, R.spacingSpace16)
        .frame(minHeight: 44)
        .liquidGlass(in: Capsule(), clear: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// A progress bar under the header that fills as the story is read.
    private var progressLine: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(M.borderModerate)
                Capsule().fill(M.textPrimary)
                    .frame(width: g.size.width * min(1, max(0, readingProgress ?? 0)))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, R.spacingSpace16)
        .opacity(readingProgress == nil ? 0 : 1)
        .animation(.linear(duration: 0.1), value: readingProgress)
        .accessibilityElement()
        .accessibilityLabel("Reading progress")
        .accessibilityValue("\(Int(((readingProgress ?? 0) * 100).rounded())) percent")
    }

    /// Story position dots; tap one to jump to that story.
    private var dotsPill: some View {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(stories.indices, id: \.self) { i in
                        Button { go(to: stories[i].id) } label: {
                            Capsule()
                                .fill(i == index ? M.iconPrimary : M.iconTertiary)
                                .frame(width: i == index ? 18 : 6, height: 6)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Story \(i + 1) of \(stories.count), \(stories[i].brand)")
                        .accessibilityAddTraits(i == index ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, R.spacingSpace16)
                .liquidGlass(in: Capsule(), clear: true)
                .animation(.snappy, value: index)
    }
}

// MARK: - Scroll tracking

private struct StoryScrollTracker: ViewModifier {
    let heroHeight: CGFloat
    let onReading: (StoryPage.ReadingState) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: StoryPage.ReadingState.self) { geo in
                let offset = geo.contentOffset.y + geo.contentInsets.top
                let readable = max(1, geo.contentSize.height - geo.containerSize.height)
                return StoryPage.ReadingState(isReading: offset > heroHeight * 0.5,
                                              progress: min(1, max(0, offset / readable)))
            } action: { _, state in
                onReading(state)
            }
        } else {
            content
        }
    }
}

// MARK: - One story

struct StoryPage: View {
    let story: Story
    let next: Story
    let topInset: CGFloat
    let onNext: () -> Void
    /// Reports whether the reader is past the cover and how far through the story they are.
    var onReading: (ReadingState) -> Void = { _ in }

    struct ReadingState: Equatable {
        let isReading: Bool
        let progress: CGFloat
    }

    @State private var scrollY: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let heroHeight: CGFloat = 600
    private var article: StoryArticle { story.article }
    private var space: String { "story-\(story.id)" }

    var body: some View {
        GeometryReader { page in
            let progress = min(1, max(0, -scrollY / max(1, contentHeight - page.size.height)))
            ZStack(alignment: .top) {
                backdrop

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: R.spacingSpace0) {
                        GeometryReader { g in
                            Color.clear.preference(key: PageOffsetKey.self, value: g.frame(in: .named(space)).minY)
                        }
                        .frame(height: 0)

                        hero

                        VStack(alignment: .leading, spacing: R.spacingSpace24) {
                            byline
                            Text(article.lede)
                                .backstageText(.caption)
                                .foregroundStyle(M.textPrimary)
                            ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                                render(block)
                            }
                            endMark
                            if !article.shop.isEmpty { shopRail }
                            storeCard
                            upNext
                        }
                        .padding(.horizontal, R.spacingSpace16)
                        .padding(.bottom, R.spacingSpace80)
                    }
                    .background {
                        GeometryReader { g in Color.clear.preference(key: PageHeightKey.self, value: g.size.height) }
                    }
                }
                .coordinateSpace(name: space)
                .scrollIndicators(.hidden)
                .onPreferenceChange(PageOffsetKey.self) { scrollY = $0 }
                .onPreferenceChange(PageHeightKey.self) { contentHeight = $0 }
                // iOS 18+: read the offset straight from the scroll view, which reports every
                // movement even inside the story pager (the preference above is the iOS 17 path).
                .modifier(StoryScrollTracker(heroHeight: heroHeight, onReading: onReading))

            }
            .onChange(of: ReadingState(isReading: scrollY < -heroHeight * 0.5, progress: progress)) { _, state in
                onReading(state)
            }
        }
    }

    // MARK: Backdrop & cover

    /// The cover photo, blurred and darkened, filling the whole page behind the text.
    private var backdrop: some View {
        ArtView(art: story.art)
            .scaleEffect(1.3)
            .blur(radius: 60, opaque: true)
            .overlay(M.backgroundPrimary.opacity(reduceTransparency ? 0.94 : 0.78))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            coverImage
                .mask {
                    // Melt the cover into the backdrop instead of ending on a hard edge.
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    BrandMark(brand: story.brand, mark: story.mark, size: 36)
                    Text(story.brand)
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                }
                Text(story.title)
                    .editorialDisplay(DisplaySize.hero)
                    .foregroundStyle(M.textWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !article.dek.isEmpty {
                    Text(article.dek)
                        .backstageText(.body2)
                        .foregroundStyle(M.textSecondary)
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.bottom, R.spacingSpace32)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .mask(Rectangle().padding(.top, -1000))
    }

    /// Stretches on overscroll, drifts slower than the page when scrolling up.
    private var coverImage: some View {
        let height = heroHeight
        return ArtView(art: story.art)
            .visualEffect { content, proxy in
                let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                return content
                    .scaleEffect(y > 0 ? 1 + y / height : 1, anchor: .bottom)
                    .offset(y: y > 0 ? 0 : -y * 0.35)
            }
    }

    // MARK: Article

    private var byline: some View {
        HStack(spacing: R.spacingSpace8) {
            Text("Words by The District Style Desk")
                .backstageText(.label2)
                .foregroundStyle(M.textSecondary)
            Text("·").foregroundStyle(M.textTertiary)
            Text(article.readTime)
                .backstageText(.label2)
                .foregroundStyle(M.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func render(_ block: StoryArticle.Block) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .backstageText(.body1)
                .foregroundStyle(M.textSecondary)
        case .heading(let text):
            Text(text)
                .backstageText(.label1)
                .foregroundStyle(M.textPrimary)
                .padding(.top, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)
        case .quote(let text, let attribution):
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text("“\(text)”")
                    .editorialDisplay(DisplaySize.card)
                    .foregroundStyle(M.textPrimary)
                Text(attribution)
                    .backstageText(.specialTitle)
                    .foregroundStyle(M.textPurple)
            }
            .padding(.vertical, R.spacingSpace16)
            .overlay(alignment: .top) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
            .overlay(alignment: .bottom) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
            .accessibilityElement(children: .combine)
        case .image(let art, let caption):
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                ArtView(art: art, parallax: 0.1)
                    .frame(height: 320)
                    .clipShape(EditorialCard.shape)
                Text(caption)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
            }
            .padding(.vertical, R.spacingSpace8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Photo: \(caption)")
        }
    }

    /// Small closing mark, as at the end of a magazine feature.
    private var endMark: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 1)
                .fill(M.iconBrand)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(45))
            Spacer()
        }
        .padding(.vertical, R.spacingSpace8)
        .accessibilityHidden(true)
    }

    // MARK: Shop, store, next

    private var shopRail: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Text("Shop \(story.brand)")
                .backstageText(.title3)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                    ForEach(article.shop) { item in
                        Button {} label: {
                            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                                ArtView(art: item.art)
                                    .frame(width: 150, height: 190)
                                    .clipShape(EditorialCard.shape)
                                Text(item.name)
                                    .backstageText(.label2)
                                    .foregroundStyle(M.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .frame(width: 150, alignment: .leading)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Shop \(item.name)")
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -R.spacingSpace16)
        }
    }

    private var storeCard: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Image(systemName: "storefront")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 44, height: 44)
                    .background(M.surfaceTransparent, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: R.spacingSpace0) {
                    Text("Visit \(story.brand)")
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                    Text(article.storeArea)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                    Text(article.storeHours)
                        .backstageText(.body3)
                        .foregroundStyle(M.textTertiary)
                }
            }
            Button {} label: {
                Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BackstageSecondaryButtonStyle())
        }
        .padding(R.spacingSpace16)
        .background(M.surfaceTransparent, in: EditorialCard.shape)
        .overlay(EditorialCard.shape.strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }

    private var upNext: some View {
        Button(action: onNext) {
            ZStack(alignment: .bottomLeading) {
                ArtView(art: next.art, parallax: 0.08)
                ImageScrim(strength: 0.85)
                HStack(alignment: .bottom, spacing: R.spacingSpace12) {
                    VStack(alignment: .leading, spacing: R.spacingSpace4) {
                        Text("Up next · \(next.brand)")
                            .backstageText(.specialTitle)
                            .foregroundStyle(M.textWhite)
                        Text(next.title)
                            .backstageText(.title2)
                            .foregroundStyle(M.textWhite)
                            .multilineTextAlignment(.leading)
                        Text("Tap, or swipe left")
                            .backstageText(.finePrint1)
                            .foregroundStyle(M.textWhite)
                    }
                    Spacer(minLength: 0)
                    CircleArrow(systemName: "chevron.right")
                }
                .padding(R.spacingSpace16)
            }
            .frame(height: 220)
            .clipShape(EditorialCard.shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Up next: \(next.title), by \(next.brand)")
    }
}

private struct PageOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct PageHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Presentation

extension View {
    /// Full-screen presentation on iOS (sheet elsewhere).
    @ViewBuilder
    func readerCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item, content: content)
        #endif
    }

    /// Marks a card as the source of the zoom transition (iOS 18+).
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Zooms the presented view out of its source card (iOS 18+).
    @ViewBuilder
    func zoomTransition(id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#Preview {
    StoryReaderView(story: EditorialData.stories[0]).preferredColorScheme(.dark)
}
