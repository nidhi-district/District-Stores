import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Full-screen mix-and-match for "Goes with everything": the staple holds still on top while its
/// pairings swipe past underneath, flip-book style. Switch staples with the chips, shuffle for a
/// surprise, open a piece, or browse the staple's styled looks below.
struct StapleStudioView: View {
    private let staples = EditorialData.staples
    @State private var stapleID: String?
    @State private var pair: Int?
    @State private var opened: Product?
    @State private var viewing: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(staple: Staple, start: Int) {
        _stapleID = State(initialValue: staple.id)
        _pair = State(initialValue: start)
    }

    private var staple: Staple { staples.first { $0.id == stapleID } ?? staples[0] }
    private var index: Int { min(pair ?? 0, staple.pairs.count - 1) }
    private var pairing: Pairing { staple.pairs[index] }

    /// The staple's styled looks, captioned for the full-screen viewer.
    private var styled: [FeedLook] {
        staple.looks.enumerated().map { i, art in
            FeedLook(art: art, name: "Look \(String(format: "%02d", i + 1))", brand: staple.title)
        }
    }

    var body: some View {
        GeometryReader { screen in
            let headerHeight = screen.safeAreaInsets.top + 132
            ZStack(alignment: .top) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: R.spacingSpace32) {
                        VStack(alignment: .leading, spacing: R.spacingSpace20) {
                            composer(height: max(440, screen.size.height * 0.58))
                            details
                        }
                        .id(staple.id)
                        .transition(.opacity)

                        styledRail
                    }
                    .padding(.top, headerHeight + R.spacingSpace8)
                    .padding(.bottom, R.spacingSpace48)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)

                header
            }
            .overlay {
                if let viewing {
                    Lightbox(looks: styled, start: viewing) {
                        withAnimation(.smooth(duration: 0.25)) { self.viewing = nil }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: stapleID)
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.selection, trigger: pair)
        .sensoryFeedback(.selection, trigger: stapleID)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(.horizontal, R.spacingSpace16)

            ScrollView(.horizontal) {
                GlassGroup(spacing: R.spacingSpace8) {
                    HStack(spacing: R.spacingSpace8) {
                        ForEach(staples) { stapleChip($0) }
                    }
                }
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)
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

    private func stapleChip(_ s: Staple) -> some View {
        let active = s.id == stapleID
        return Button {
            stapleID = s.id
            pair = 0
        } label: {
            HStack(spacing: R.spacingSpace8) {
                ArtView(art: s.thumb)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                Text(s.title)
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
        .accessibilityLabel("\(s.title), \(s.pairs.count) pairings")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Composer

    /// Staple on top, a swipeable deck of pairings below, a "+" on the seam.
    private func composer(height: CGFloat) -> some View {
        let seam = R.spacingSpace4 / 2
        let top = (height - seam) * 0.5
        return VStack(spacing: seam) {
            ZStack(alignment: .topLeading) {
                ArtView(art: staple.thumb, parallax: 0.06)
                Text(staple.title)
                    .backstageText(.label1)
                    .foregroundStyle(M.textWhite)
                    .shadow(color: M.textBlack.opacity(0.35), radius: 8)
                    .padding(R.spacingSpace16)
            }
            .frame(height: top)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(staple.title)

            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace0) {
                    ForEach(Array(staple.pairs.enumerated()), id: \.offset) { i, p in
                        ArtView(art: p.art)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(1 + abs(phase.value) * 0.16)
                                    .offset(x: phase.value * -50)
                            }
                            .containerRelativeFrame([.horizontal, .vertical])
                            .clipped()
                            .id(i)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(p.name) from \(p.brand)")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $pair)
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottomTrailing) {
                Text("\(String(format: "%02d", index + 1)) / \(String(format: "%02d", staple.pairs.count))")
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
                    .monospacedDigit()
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(height: 28)
                    .liquidGlass(in: Capsule(), clear: true)
                    .padding(R.spacingSpace12)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: height)
        .clipShape(EditorialCard.shape)
        .overlay(alignment: .top) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(M.iconInverse)
                .frame(width: 40, height: 40)
                .background(M.surfaceInverse, in: Circle())
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(index) * 90))
                .elevation(.shadow100)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: index)
                .offset(y: top + seam / 2 - 20)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    /// The pairing's name, shuffle and a link to the piece.
    private var details: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(pairing.brand)
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
                Text("\(staple.title) + \(pairing.name)")
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
            }
            .id(index)
            .transition(.opacity)
            .animation(.snappy, value: index)
            .accessibilityElement(children: .combine)

            HStack(spacing: R.spacingSpace12) {
                Button(action: shuffle) {
                    HStack(spacing: R.spacingSpace8) {
                        Image(systemName: "shuffle").font(.system(size: 13, weight: .semibold))
                        Text("Shuffle")
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(height: 44)
                    .liquidGlass(in: Capsule(), interactive: true, clear: true)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows a random pairing")

                Spacer(minLength: 0)

                Button { opened = product(for: pairing) } label: {
                    HStack(spacing: R.spacingSpace4) {
                        Text("View piece")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.buttonPrimaryLabel)
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(height: 44)
                    .background(M.buttonPrimaryBackground, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("View \(pairing.name)")
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    // MARK: Styled looks

    private var styledRail: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(spacing: R.spacingSpace12) {
                Text("Styled \(staple.looks.count) ways")
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            }
            .padding(.horizontal, R.spacingSpace16)

            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace8) {
                    ForEach(Array(staple.looks.enumerated()), id: \.offset) { i, art in
                        Button {
                            withAnimation(.smooth(duration: 0.3)) { viewing = i }
                        } label: {
                            ArtView(art: art, parallax: 0.06)
                                .frame(width: 150, height: 210)
                                .clipShape(EditorialCard.shape)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(staple.title), look \(i + 1) of \(staple.looks.count)")
                        .accessibilityHint("Opens full screen")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
        .id("styled-\(staple.id)")
    }

    // MARK: Actions

    private func shuffle() {
        let count = staple.pairs.count
        guard count > 1 else { return }
        var next = Int.random(in: 0..<count)
        while next == index { next = Int.random(in: 0..<count) }
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) { pair = next }
    }

    /// The catalogue product when the pairing is one, otherwise a product built from the pairing.
    private func product(for p: Pairing) -> Product {
        EditorialData.products.first { $0.name == p.name }
            ?? Product(name: p.name, brand: p.brand, mark: p.brand.uppercased(), category: "Pairing", isNew: false, art: p.art)
    }
}
