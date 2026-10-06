import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// "What goes well with?" lookbook: every look built on one staple, full screen, swiped through
/// vertically. Each look shows how it is built — the staple plus the piece it is styled with — and
/// either piece opens its product page.
struct StapleLookbookView: View {
    let staple: Staple
    @State private var page: Int?
    @State private var opened: Product?
    /// Shows the swipe hint until the first swipe (or a few seconds pass).
    @State private var showsHint = true
    @State private var bob = false
    private let startPage: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(staple: Staple, start: Int) {
        self.staple = staple
        self.startPage = start
        _page = State(initialValue: start)
    }

    private var index: Int { page ?? 0 }
    private var count: Int { staple.looks.count }

    /// The piece each look is styled with (pairings repeat when there are more looks than pieces).
    private func pairing(_ i: Int) -> Pairing { staple.pairs[i % staple.pairs.count] }

    var body: some View {
        GeometryReader { screen in
            ZStack(alignment: .top) {
                ScrollViewReader { reader in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(staple.looks.indices, id: \.self) { i in
                                lookPage(i, bottomInset: screen.safeAreaInsets.bottom)
                                    .containerRelativeFrame([.horizontal, .vertical])
                                    .id(i)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $page)
                    .scrollIndicators(.hidden)
                    .onAppear { reader.scrollTo(page) }
                }
                .ignoresSafeArea()

                header(topInset: screen.safeAreaInsets.top)
            }
            .overlay(alignment: .trailing) { pageIndicator }
            .overlay {
                if showsHint && count > 1 { swipeHint.transition(.opacity) }
            }
        }
        .onChange(of: page) { _, new in
            if new != startPage { withAnimation(.easeOut(duration: 0.25)) { showsHint = false } }
        }
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.4)) { showsHint = false }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.selection, trigger: page)
    }

    // MARK: Header

    private func header(topInset: CGFloat) -> some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count) ways to wear the \(staple.title.lowercased())")
                    .backstageText(.label1)
                    .foregroundStyle(M.textWhite)
                    .lineLimit(1)
                Text("\(String(format: "%02d", index + 1)) / \(String(format: "%02d", count))")
                    .backstageText(.label2)
                    .foregroundStyle(M.textWhite.opacity(0.7))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: index)
            }
            .shadow(color: .black.opacity(0.4), radius: 8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace4)
        .padding(.bottom, R.spacingSpace24)
        .background {
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    /// A glass pill nudging the reader to swipe for the next look.
    private var swipeHint: some View {
        let up = startPage < count - 1
        return HStack(spacing: R.spacingSpace8) {
            Image(systemName: up ? "chevron.up" : "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .offset(y: reduceMotion ? 0 : (bob ? (up ? -4 : 4) : 0))
            Text(up ? "Swipe up for more looks" : "Swipe down for more looks")
                .backstageText(.label2)
        }
        .foregroundStyle(M.textWhite)
        .padding(.horizontal, R.spacingSpace16)
        .frame(height: 36)
        .liquidGlass(in: Capsule(), clear: true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { bob = true }
        }
        .allowsHitTesting(false)
        .accessibilityLabel(up ? "Swipe up for more looks" : "Swipe down for more looks")
    }

    /// Segments down the right edge: one per look, the current one long and bright.
    private var pageIndicator: some View {
        VStack(spacing: R.spacingSpace4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? M.iconWhite : M.iconWhite.opacity(0.35))
                    .frame(width: 3, height: i == index ? 22 : 8)
            }
        }
        .animation(.snappy, value: index)
        .padding(.trailing, R.spacingSpace8)
        .accessibilityHidden(true)
    }

    // MARK: A look

    private func lookPage(_ i: Int, bottomInset: CGFloat) -> some View {
        let piece = pairing(i)
        return ZStack(alignment: .bottom) {
            let zoom: Double = reduceMotion ? 0 : 0.08
            ArtView(art: staple.looks[i])
                .scrollTransition(.interactive, axis: .vertical) { content, phase in
                    content.scaleEffect(1 + abs(phase.value) * zoom)
                }
            LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)

            formula(i, piece: piece)
                .padding(.horizontal, R.spacingSpace16)
                .padding(.bottom, bottomInset + R.spacingSpace24)
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Look \(i + 1) of \(count): \(staple.title) with \(piece.name)")
    }

    /// How the look is built: the two pieces, each opening its product.
    private func formula(_ i: Int, piece: Pairing) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Look \(String(format: "%02d", i + 1))")
                    .backstageText(.label2)
                    .foregroundStyle(M.textWhite.opacity(0.7))
                Text("\(staple.title) + \(piece.name)")
                    .backstageText(.title3)
                    .foregroundStyle(M.textWhite)
                    .lineLimit(2)
            }

            VStack(spacing: R.spacingSpace8) {
                pieceRow(art: staple.thumb, name: staple.title, detail: staple.subtitle,
                         product: Product(name: staple.title, brand: "District edit", mark: "D",
                                          category: "Staple", isNew: false, art: staple.thumb))
                pieceRow(art: piece.art, name: piece.name, detail: piece.brand, product: product(for: piece))
            }
        }
        .padding(R.spacingSpace16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner20), clear: true)
    }

    private func pieceRow(art: Art, name: String, detail: String, product: Product) -> some View {
        Button { opened = product } label: {
            HStack(spacing: R.spacingSpace12) {
                ArtView(art: art)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .backstageText(.label1)
                        .foregroundStyle(M.textWhite)
                        .lineLimit(1)
                    Text(detail)
                        .backstageText(.body3)
                        .foregroundStyle(M.textWhite.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(M.iconWhite.opacity(0.8))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(name), \(detail)")
        .accessibilityHint("Opens product")
    }

    /// The catalogue product when the pairing is one, otherwise a product built from the pairing.
    private func product(for p: Pairing) -> Product {
        EditorialData.products.first { $0.name == p.name }
            ?? Product(name: p.name, brand: p.brand, mark: p.brand.uppercased(), category: "Pairing", isNew: false, art: p.art)
    }
}
