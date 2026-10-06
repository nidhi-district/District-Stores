import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Sheet behind the "+" pins in "Cop these looks": every tagged piece in the look, the exact item
/// featured first and similar options after. Switch pieces with the numbered tabs or by swiping
/// sideways; tap any piece to open its product page.
struct ShopTheLookView: View {
    let look: Look
    @State private var current: Int?
    @State private var opened: LookSku?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(look: Look, start: Int) {
        self.look = look
        _current = State(initialValue: start)
    }

    private var index: Int { current ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace0) {
            header
                .padding(.horizontal, R.spacingSpace20)
                .padding(.top, R.spacingSpace24)
                .padding(.bottom, R.spacingSpace16)
            pills
            pager
        }
        .background(alignment: .top) { wash }
        .readerCover(item: $opened) { sku in
            ProductDetailView(product: sku.product)
        }
        .sensoryFeedback(.selection, trigger: current)
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(M.backgroundPrimary)
    }

    /// A faint wash of the look's own colour behind the header.
    private var wash: some View {
        LinearGradient(
            colors: [DominantColor.of(look.art).opacity(0.16), DominantColor.of(look.art).opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 240)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: R.spacingSpace12) {
            Text(look.title.lowercased())
                .editorialDisplay(DisplaySize.title)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
        }
    }

    /// One pill per tagged piece.
    private var pills: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                        let active = i == index
                        Button {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { current = i }
                        } label: {
                            Text(spot.item)
                        }
                        .buttonStyle(BackstageFilterButtonStyle(isActive: active))
                        .accessibilityValue(spot.price)
                        .accessibilityAddTraits(active ? .isSelected : [])
                        .id(i)
                    }
                }
            }
            .contentMargins(.horizontal, R.spacingSpace20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: index) { _, i in
                withAnimation(.snappy) { reader.scrollTo(i, anchor: .center) }
            }
        }
    }

    /// One page per tagged piece.
    private var pager: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace0) {
                    ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                        ShopPiecePage(options: look.options(for: spot)) { opened = $0 }
                            .containerRelativeFrame(.horizontal)
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .onAppear { reader.scrollTo(current) }
        }
    }
}

// MARK: - One piece

struct ShopPiecePage: View {
    let options: [LookSku]
    let open: (LookSku) -> Void

    private let columns = [GridItem(.flexible(), spacing: R.spacingSpace12, alignment: .top),
                           GridItem(.flexible(), spacing: R.spacingSpace12, alignment: .top)]

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                if let exact = options.first(where: \.isExact) {
                    FeaturedSkuCard(sku: exact) { open(exact) }
                }

                let similar = options.filter { !$0.isExact }
                if !similar.isEmpty {
                    VStack(alignment: .leading, spacing: R.spacingSpace16) {
                        HStack(spacing: R.spacingSpace12) {
                            Text("Similar pieces")
                                .backstageText(.label2)
                                .foregroundStyle(M.textTertiary)
                                .fixedSize()
                            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                        }
                        .accessibilityAddTraits(.isHeader)

                        LazyVGrid(columns: columns, spacing: R.spacingSpace24) {
                            ForEach(similar) { sku in
                                SkuCard(sku: sku) { open(sku) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, R.spacingSpace20)
            .padding(.top, R.spacingSpace20)
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
    }
}

/// The exact piece from the look: a crop of the piece (with a tiny inset of the whole look, a dot
/// marking where it sits) beside its brand, name and price.
struct FeaturedSkuCard: View {
    let sku: LookSku
    let open: () -> Void

    private let shape = RoundedRectangle(cornerRadius: R.cornerRadiusCorner16)

    var body: some View {
        let tint = DominantColor.of(sku.art)
        Button(action: open) {
            HStack(alignment: .top, spacing: R.spacingSpace16) {
                CroppedArt(art: sku.art, focus: sku.focus, zoom: sku.zoom)
                    .frame(width: 116, height: 148)
                    .overlay(alignment: .bottomLeading) { source.padding(R.spacingSpace8) }
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))

                VStack(alignment: .leading, spacing: R.spacingSpace0) {
                    HStack(spacing: R.spacingSpace4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .semibold))
                        Text("As styled")
                            .backstageText(.label2)
                    }
                    .foregroundStyle(M.textTertiary)
                    .padding(.bottom, R.spacingSpace8)

                    Text(sku.brand)
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                    Text(sku.name)
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(2)
                        .padding(.top, 2)
                    Text(sku.price)
                        .backstageText(.body2)
                        .foregroundStyle(M.textSecondary)
                        .padding(.top, R.spacingSpace4)

                    Spacer(minLength: R.spacingSpace8)

                    HStack(spacing: 2) {
                        Text("View piece")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.textInverse)
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(height: 28)
                    .background(M.surfaceInverse, in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.vertical, R.spacingSpace4)
            }
            .padding(R.spacingSpace8)
            .background(M.surfacePrimary, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [tint.opacity(0.5), M.borderSubtle, M.borderSubtle],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: R.stroke1Px
                )
            )
            .shadow(color: tint.opacity(0.12), radius: 18, y: 8)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("As styled in this look: \(sku.name), \(sku.brand), \(sku.price)")
        .accessibilityHint("Opens product")
        .accessibilityAddTraits(.isButton)
    }

    /// The whole look in miniature, with a dot on the piece.
    private var source: some View {
        ArtView(art: sku.art)
            .frame(width: 28, height: 38)
            .overlay {
                GeometryReader { geo in
                    Circle()
                        .fill(M.iconWhite)
                        .frame(width: 4, height: 4)
                        .shadow(color: M.textBlack.opacity(0.4), radius: 2)
                        .position(x: sku.focus.x * geo.size.width, y: sku.focus.y * geo.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(M.iconWhite.opacity(0.9), lineWidth: R.stroke1Px))
            .shadow(color: M.textBlack.opacity(0.3), radius: 6, y: 2)
            .accessibilityHidden(true)
    }
}

/// A similar option: photo, brand in small caps, name and price.
struct SkuCard: View {
    let sku: LookSku
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                CroppedArt(art: sku.art, focus: sku.focus, zoom: sku.zoom)
                    .aspectRatio(0.78, contentMode: .fit)
                    .background(M.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))

                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(sku.brand)
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                    Text(sku.name)
                        .backstageText(.body2)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(2)
                    Text(sku.price)
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                }
                .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sku.name), \(sku.brand), \(sku.price)")
        .accessibilityHint("Opens product")
        .accessibilityAddTraits(.isButton)
    }
}

/// A photo zoomed in on one point (kept inside the frame), used to crop a piece out of a look.
struct CroppedArt: View {
    let art: Art
    let focus: UnitPoint
    let zoom: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxX = (zoom - 1) / 2 * w, maxY = (zoom - 1) / 2 * h
            let dx = min(max((0.5 - focus.x) * w * zoom, -maxX), maxX)
            let dy = min(max((0.5 - focus.y) * h * zoom, -maxY), maxY)
            ArtView(art: art)
                .frame(width: w, height: h)
                .scaleEffect(zoom)
                .offset(x: dx, y: dy)
        }
        .clipped()
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        ShopTheLookView(look: EditorialData.looks[0], start: 0)
    }
    .preferredColorScheme(.dark)
}
