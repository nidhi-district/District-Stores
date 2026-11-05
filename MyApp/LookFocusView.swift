import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Full-screen looks from "Cop these looks", paged vertically like Reels: swipe up for the next
/// look, down for the one before. Each page shows the photo edge to edge with its dots, and a row
/// of piece cards underneath; the centred card drives a spotlight on its piece. Tap a dot to jump
/// to its card; tap a card to open the product.
struct LookFocusView: View {
    let looks: [Look]
    private let startLook: Int
    private let startSpot: Int
    @State private var page: Int?
    @State private var opened: LookSku?
    @State private var similar: Similar?
    @State private var tryingOn: Look?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Similar: Identifiable {
        let look: Look
        let spot: Int
        var id: String { "\(look.id)-\(spot)" }
    }

    init(looks: [Look], look: Int, start: Int) {
        self.looks = looks
        startLook = min(max(look, 0), looks.count - 1)
        startSpot = start
        _page = State(initialValue: startLook)
    }

    private var current: Int { min(max(page ?? startLook, 0), looks.count - 1) }

    var body: some View {
        GeometryReader { geo in
            let full = CGSize(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    LazyVStack(spacing: R.spacingSpace0) {
                        ForEach(Array(looks.enumerated()), id: \.element.id) { i, look in
                            LookReel(look: look, start: i == startLook ? startSpot : 0, size: full,
                                     insets: geo.safeAreaInsets, isLast: i == looks.count - 1,
                                     open: { opened = $0 }, similar: { similar = Similar(look: look, spot: $0) })
                                .frame(width: full.width, height: full.height)
                                .clipped()
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $page)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
                .onAppear { reader.scrollTo(startLook) }
            }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: .trailing) { pageMarks.padding(.trailing, 6) }
        }
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: page)
        .readerCover(item: $opened) { ProductDetailView(product: $0.product) }
        .sheet(item: $similar) { ShopTheLookView(look: $0.look, start: $0.spot) }
        .fullScreenCover(item: $tryingOn) { VirtualTryOnView(title: $0.title, art: $0.art) }
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityScrollAction { edge in
            // VoiceOver three-finger swipes move between looks.
            let next = edge == .bottom ? current - 1 : current + 1
            if looks.indices.contains(next) { withAnimation(reduceMotion ? nil : .snappy) { page = next } }
        }
    }

    // MARK: Chrome

    /// Close, which look you're on, and try-on for it. Sits over a soft shade, not a blur.
    private var topBar: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            Text("Look \(current + 1) of \(looks.count)")
                .font(EditType.text(13, .medium, relativeTo: .caption))
                .foregroundStyle(M.textWhite)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: current)
                .shadow(color: .black.opacity(0.4), radius: 4)
            Spacer(minLength: 0)
            TryOnButton { tryingOn = looks[current] }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace4)
        .background(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    /// A slim vertical stack of marks on the right edge, one per look, so the pager reads as one.
    private var pageMarks: some View {
        VStack(spacing: 5) {
            ForEach(looks.indices, id: \.self) { i in
                Capsule()
                    .fill(M.textWhite.opacity(i == current ? 1 : 0.35))
                    .frame(width: 3, height: i == current ? 22 : 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }
}

/// One page of the pager: the look edge to edge from the top of the screen, then its title and
/// piece cards on black underneath.
private struct LookReel: View {
    let look: Look
    let size: CGSize
    let insets: EdgeInsets
    let isLast: Bool
    let open: (LookSku) -> Void
    let similar: (Int) -> Void
    @State private var active: Int?
    @State private var nudge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Same frame as the card in the Edit, so the dots land where they do there.
    private static let aspect: CGFloat = 270.0 / 400.0
    private static let cardHeight: CGFloat = 120

    init(look: Look, start: Int, size: CGSize, insets: EdgeInsets, isLast: Bool,
         open: @escaping (LookSku) -> Void, similar: @escaping (Int) -> Void) {
        self.look = look
        self.size = size
        self.insets = insets
        self.isLast = isLast
        self.open = open
        self.similar = similar
        _active = State(initialValue: min(max(start, 0), look.spots.count - 1))
    }

    private var index: Int { min(max(active ?? 0, 0), look.spots.count - 1) }
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86) }

    var body: some View {
        ZStack(alignment: .top) {
            photo
            VStack(spacing: R.spacingSpace0) {
                Spacer(minLength: 0)
                footer
            }
            .padding(.bottom, insets.bottom + R.spacingSpace8)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Color.black)
    }

    // MARK: Photo

    /// Full width at the card's aspect, with a dimmed spotlight on the active piece. Its foot
    /// fades into the black below, so there's no hard edge and no blurred fill.
    private var photo: some View {
        let width = size.width
        let height = width / Self.aspect
        let spot = look.spots[index]

        return ArtView(art: look.art)
            .frame(width: width, height: height)
            .overlay { spotlight(at: CGPoint(x: spot.x * width, y: spot.y * height)) }
            .overlay {
                ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                    FocusPin(spot: spot, isActive: i == index) {
                        withAnimation(motion) { active = i }
                    }
                    .position(x: spot.x * width, y: spot.y * height)
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: height * 0.22)
                    .allowsHitTesting(false)
            }
            .animation(motion, value: index)
    }

    /// Dims everything but a soft circle around the active piece.
    private func spotlight(at point: CGPoint) -> some View {
        // A big radial fade, clear at its centre, moved onto the piece so the move animates.
        Color.black.opacity(0.4)
            .mask {
                RadialGradient(colors: [.clear, .black], center: .center, startRadius: 44, endRadius: 170)
                    .frame(width: 2400, height: 2400)
                    .position(point)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(look.title)
                    .font(EditType.text(20, .semibold, relativeTo: .title3))
                    .tracking(-0.2)
                    .foregroundStyle(M.textWhite)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text("\(index + 1) of \(look.spots.count) pieces")
                    .font(EditType.text(12, .regular, relativeTo: .caption))
                    .foregroundStyle(M.textWhite.opacity(0.7))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: index)
            }
            .padding(.horizontal, R.spacingSpace20)

            cards

            if !isLast { nextHint }
        }
        .background(alignment: .bottom) {
            // Keeps the text legible where a short screen lets the photo run under it.
            LinearGradient(colors: [.clear, .black.opacity(0.85), .black], startPoint: .top, endPoint: .bottom)
                .padding(.top, -40)
                .padding(.bottom, -(insets.bottom + R.spacingSpace8))
                .allowsHitTesting(false)
        }
    }

    /// "Swipe up" cue for the next look, with a small bob.
    private var nextHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .semibold))
                .offset(y: nudge ? -3 : 1)
            Text("Swipe up for the next look")
                .font(EditType.text(12, .medium, relativeTo: .caption))
        }
        .foregroundStyle(M.textWhite.opacity(0.6))
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { nudge = true }
        }
        .accessibilityHidden(true)
    }

    /// One card per tagged piece; the card that settles in the middle drives the spotlight.
    private var cards: some View {
        ScrollViewReader { reader in
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace12) {
                ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                    let sku = look.options(for: spot)[0]
                    FocusPieceCard(sku: sku, open: { open(sku) }, similar: { similar(i) })
                        .containerRelativeFrame(.horizontal) { width, _ in width - 64 }
                        .frame(height: Self.cardHeight)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card.scaleEffect(phase.isIdentity ? 1 : 0.94).opacity(phase.isIdentity ? 1 : 0.7)
                        }
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 32, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $active, anchor: .center)
        .scrollIndicators(.hidden)
        // A horizontal scroll view takes all the height it's offered; pin it to the cards.
        .frame(height: Self.cardHeight)
        // Open on the card for the dot that was tapped.
        .onAppear { reader.scrollTo(index, anchor: .center) }
        }
    }
}

/// A dot on the photo. The active one grows a ring and a name tag; the rest stay small.
private struct FocusPin: View {
    let spot: Hotspot
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(M.iconWhite, lineWidth: 1.5)
                    .frame(width: isActive ? 34 : 0, height: isActive ? 34 : 0)
                    .opacity(isActive ? 1 : 0)
                Circle()
                    .fill(M.iconWhite)
                    .frame(width: isActive ? 14 : 8, height: isActive ? 14 : 8)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                    .padding(5)
                    .background(Circle().fill(M.iconWhite.opacity(isActive ? 0 : 0.25)))
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if isActive {
                Text(spot.item)
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(M.surfaceInverse, in: Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    .offset(y: -40)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(spot.item)
        .accessibilityValue(spot.price)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

/// The floating card for one piece: a crop of it from the photo, its name, brand and price.
private struct FocusPieceCard: View {
    let sku: LookSku
    let open: () -> Void
    let similar: () -> Void

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            CroppedArt(art: sku.art, focus: sku.focus, zoom: sku.zoom)
                .frame(width: 92)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(sku.brand)
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                Text(sku.name)
                    .font(EditType.text(15, .semibold, relativeTo: .headline))
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sku.price)
                    .font(EditType.text(13, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textPrimary)
                Spacer(minLength: 0)
                Button(action: similar) {
                    Text("See similar")
                        .font(EditType.text(12, .medium, relativeTo: .caption))
                        .foregroundStyle(M.textSecondary)
                        .underline()
                        .frame(minHeight: 28, alignment: .bottomLeading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(M.iconTertiary)
        }
        .padding(R.spacingSpace8)
        .padding(.trailing, R.spacingSpace8)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: open)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sku.name), \(sku.brand), \(sku.price)")
        .accessibilityHint("Opens the product")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "See similar", similar)
    }
}

#Preview {
    LookFocusView(looks: EditorialData.looks, look: 0, start: 0).preferredColorScheme(.dark)
}
