import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Full-screen gallery for "Fits for every plan". Switch occasions with the chips or by swiping
/// sideways; tap any look to view it full screen.
struct PlanGalleryView: View {
    private let plans = EditorialData.plans
    @State private var current: String?
    @State private var viewing: Viewing?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Viewing: Equatable {
        let planID: String
        let index: Int
    }

    init(plan: Plan) {
        _current = State(initialValue: plan.id)
    }

    private var currentPlan: Plan { plans.first { $0.id == current } ?? plans[0] }

    var body: some View {
        GeometryReader { screen in
            let headerHeight = screen.safeAreaInsets.top + 132
            ZStack(alignment: .top) {
                ScrollViewReader { pager in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: R.spacingSpace0) {
                            ForEach(plans) { plan in
                                PlanGalleryPage(plan: plan, topInset: headerHeight) { index in
                                    withAnimation(.smooth(duration: 0.3)) {
                                        viewing = Viewing(planID: plan.id, index: index)
                                    }
                                }
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(plan.id)
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

                header
            }
            .overlay {
                if let viewing, let plan = plans.first(where: { $0.id == viewing.planID }) {
                    Lightbox(looks: plan.looks, start: viewing.index) {
                        withAnimation(.smooth(duration: 0.25)) { self.viewing = nil }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: current)
    }

    /// Close button and the plan switcher.
    private var header: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(.horizontal, R.spacingSpace16)

            ScrollViewReader { chips in
                ScrollView(.horizontal) {
                    GlassGroup(spacing: R.spacingSpace8) {
                        HStack(spacing: R.spacingSpace8) {
                            ForEach(plans) { plan in
                                planChip(plan)
                                    .id(plan.id)
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
                .scrollIndicators(.hidden)
                .onChange(of: current) { _, id in
                    withAnimation(.snappy) { chips.scrollTo(id, anchor: .center) }
                }
            }
        }
        .padding(.top, R.spacingSpace4)
        .padding(.bottom, R.spacingSpace12)
        .background {
            LinearGradient(
                colors: [M.backgroundPrimary, M.backgroundPrimary.opacity(0.85), M.backgroundPrimary.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    private func planChip(_ plan: Plan) -> some View {
        let active = plan.id == current
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { current = plan.id }
        } label: {
            HStack(spacing: R.spacingSpace8) {
                ArtView(art: plan.gallery[0])
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                Text(plan.title)
                    .backstageText(.label2)
                    .lineLimit(1)
            }
            .foregroundStyle(active ? M.buttonPrimaryLabel : M.textPrimary)
            .padding(.leading, R.spacingSpace8)
            .padding(.trailing, R.spacingSpace16)
            .frame(height: 44)
            .background {
                if active { Capsule().fill(M.buttonPrimaryBackground) }
            }
            .liquidGlass(in: Capsule(), interactive: true, clear: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.title), \(plan.count) looks")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - One plan

struct PlanGalleryPage: View {
    let plan: Plan
    let topInset: CGFloat
    let onSelect: (Int) -> Void

    var body: some View {
        let looks = plan.looks
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace20) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    EditorialHeadline(lines: plan.lines, size: DisplaySize.title)
                        .foregroundStyle(M.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(plan.count) looks, styled for \(plan.title.lowercased())")
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                }
                .padding(.horizontal, R.spacingSpace16)

                LookFeed(looks: looks, onSelect: onSelect)
                    .padding(.horizontal, R.spacingSpace16)
            }
            .padding(.top, topInset + R.spacingSpace8)
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Feed

/// Two-column Pinterest-style feed: staggered photos with the product name and brand underneath.
struct LookFeed: View {
    let looks: [FeedLook]
    let onSelect: (Int) -> Void

    /// Staggered image heights for the two columns.
    private let heights: [CGFloat] = [240, 190, 215, 260, 200, 230]

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace8) {
            column(offset: 0)
            column(offset: 1)
        }
    }

    /// One column of the Pinterest-style feed: photo, then product name and brand underneath.
    private func column(offset: Int) -> some View {
        VStack(spacing: R.spacingSpace16) {
            ForEach(Array(stride(from: offset, to: looks.count, by: 2)), id: \.self) { i in
                let look = looks[i]
                Button { onSelect(i) } label: {
                    VStack(alignment: .leading, spacing: R.spacingSpace8) {
                        ArtView(art: look.art, parallax: 0.06)
                            .frame(height: heights[(i + offset) % heights.count])
                            .clipShape(EditorialCard.shape)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(look.name)
                                .backstageText(.label2)
                                .foregroundStyle(M.textPrimary)
                                .lineLimit(2)
                            Text(look.brand)
                                .backstageText(.label2)
                                .foregroundStyle(M.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, R.spacingSpace4)
                        .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(look.name), \(look.brand)")
                .accessibilityValue("Look \(i + 1) of \(looks.count)")
                .accessibilityHint("Opens full screen")
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}

// MARK: - Lightbox

/// Full-screen viewer for a feed of looks; swipe between them.
struct Lightbox: View {
    let looks: [FeedLook]
    let close: () -> Void
    @State private var index: Int?

    init(looks: [FeedLook], start: Int, close: @escaping () -> Void) {
        self.looks = looks
        self.close = close
        _index = State(initialValue: start)
    }

    var body: some View {
        ZStack(alignment: .top) {
            M.backgroundPrimary.opacity(0.97).ignoresSafeArea()

            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: R.spacingSpace0) {
                        ForEach(looks.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                                ArtView(art: looks[i].art)
                                    .aspectRatio(0.75, contentMode: .fit)
                                    .clipShape(EditorialCard.shape)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(looks[i].name)
                                        .backstageText(.title3)
                                        .foregroundStyle(M.textPrimary)
                                    Text(looks[i].brand)
                                        .backstageText(.label2)
                                        .foregroundStyle(M.textSecondary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                            .padding(.horizontal, R.spacingSpace16)
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $index)
                .scrollIndicators(.hidden)
                .onAppear { reader.scrollTo(index) }
            }

            HStack {
                GlassIconButton(systemName: "xmark", label: "Close photo", action: close)
                Spacer()
                Text("\((index ?? 0) + 1) / \(looks.count)")
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                    .monospacedDigit()
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(height: 44)
                    .liquidGlass(in: Capsule(), clear: true)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace4)
        }
        .sensoryFeedback(.selection, trigger: index)
        .accessibilityAction(.escape, close)
    }
}

#Preview {
    PlanGalleryView(plan: EditorialData.plans[0]).preferredColorScheme(.dark)
}
