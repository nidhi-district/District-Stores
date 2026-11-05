import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// One piece to wear with a staple from "Style Your Staples": cropped out of a street-style look,
/// so the card shows just the piece and the full photo opens behind it.
struct StaplePiece: Identifiable {
    var id: String { name }
    let name: String
    let brand: String
    let price: String
    /// The full look the piece was spotted in.
    let art: Art
    /// Where the piece sits in the photo, and how far to zoom in on it.
    let focus: UnitPoint
    let zoom: CGFloat
    /// One line on how it's worn in the photo.
    let note: String
    /// Product category for the PDP ("Denim" gets waist sizes).
    var category: String = "Tops"

    var product: Product {
        Product(name: name, brand: brand, mark: brand.uppercased(), category: category, isNew: false, art: art, price: price)
    }

    /// Hand-picked pieces per staple. Staples without an entry fall back to a crop of each look's top half.
    static let byStaple: [String: [StaplePiece]] = [
        "leathers": [
            StaplePiece(name: "Crisp white poplin shirt", brand: "Cord", price: "₹2,490",
                        art: Art("vogue_pair_leathers_look_1", [0x2B211C, 0x151515], seed: 1200),
                        focus: UnitPoint(x: 0.5, y: 0.3), zoom: 2.3,
                        note: "Buttoned to the collar, under a pinstripe bustier, over high-waist leather trousers."),
            StaplePiece(name: "Sky blue oxford shirt", brand: "Zara", price: "₹2,990",
                        art: Art("vogue_pair_leathers_look_2", [0x2B211C, 0x151515], seed: 1201),
                        focus: UnitPoint(x: 0.52, y: 0.24), zoom: 2.7,
                        note: "Collar open and sleeves loose under a brown leather mini, finished with blue boots."),
            StaplePiece(name: "Oversized blue shirt", brand: "Doodlage", price: "₹2,790",
                        art: Art("vogue_pair_leathers_look_3", [0x2B211C, 0x151515], seed: 1202),
                        focus: UnitPoint(x: 0.44, y: 0.28), zoom: 2.3,
                        note: "Front tucked into chocolate leather wide-legs, a second shirt knotted over the shoulders."),
            StaplePiece(name: "Striped camp-collar shirt", brand: "Snitch", price: "₹1,999",
                        art: Art("vogue_pair_leathers_look_4", [0x2B211C, 0x151515], seed: 1203),
                        focus: UnitPoint(x: 0.47, y: 0.27), zoom: 2.3,
                        note: "Worn open over a white tank with the sleeves pushed up, above wide leather trousers."),
        ],
        "graphic-tee": [
            StaplePiece(name: "High-rise black skinny jeans", brand: "Levi's", price: "₹2,999",
                        art: Art("staple_white_tee_1", [0xF4F4F4, 0xBDBDBD], seed: 1210),
                        focus: UnitPoint(x: 0.5, y: 0.86), zoom: 2.2,
                        note: "The band tee goes half-tucked into high-rise black skinnies.", category: "Denim"),
            StaplePiece(name: "Grey pleated trousers", brand: "Snitch", price: "₹2,299",
                        art: Art("staple_white_tee_3", [0xF4F4F4, 0xBDBDBD], seed: 1211),
                        focus: UnitPoint(x: 0.5, y: 0.92), zoom: 2.4,
                        note: "A boxy logo tee left loose over soft grey trousers."),
            StaplePiece(name: "White baseball cap", brand: "Bewakoof", price: "₹699",
                        art: Art("staple_white_tee_2", [0xF4F4F4, 0xBDBDBD], seed: 1212),
                        focus: UnitPoint(x: 0.6, y: 0.12), zoom: 2.6,
                        note: "A clean white cap with a plain tee, untucked over black jeans."),
            StaplePiece(name: "Striped track pants", brand: "Adidas", price: "₹3,999",
                        art: Art("plan_active_hero", [0xF4F4F4, 0xBDBDBD], seed: 1213),
                        focus: UnitPoint(x: 0.5, y: 0.68), zoom: 2.0,
                        note: "A fitted tee over navy three-stripe track pants and white sneakers."),
        ],
        "kurti": [
            StaplePiece(name: "Burnt orange organza dupatta", brand: "Label Earthen", price: "₹3,490",
                        art: Art("plan_diwali_hero", [0x1A1A1A, 0xE9E2D4], seed: 1220),
                        focus: UnitPoint(x: 0.3, y: 0.55), zoom: 1.9,
                        note: "Thrown over one shoulder of a rust kurta set, falling to the floor."),
            StaplePiece(name: "Embroidered mustard kaftan", brand: "Nicobar", price: "₹6,500",
                        art: Art("rack_nicobar_kaftan", [0x1A1A1A, 0xE9E2D4], seed: 1221),
                        focus: UnitPoint(x: 0.5, y: 0.45), zoom: 1.7,
                        note: "A floor-length kaftan with floral yokes, belted at the waist."),
            StaplePiece(name: "Kanjeevaram silk saree", brand: "Taneira", price: "₹14,900",
                        art: Art("plan_diwali_2", [0x1A1A1A, 0xE9E2D4], seed: 1222),
                        focus: UnitPoint(x: 0.5, y: 0.6), zoom: 1.6,
                        note: "Red and gold silk with a magenta blouse and temple jewellery."),
            StaplePiece(name: "Chandelier drop earrings", brand: "Amrapali", price: "₹2,190",
                        art: Art("plan_diwali_3", [0x1A1A1A, 0xE9E2D4], seed: 1223),
                        focus: UnitPoint(x: 0.62, y: 0.4), zoom: 2.6,
                        note: "Long silver drops, the only jewellery with an off-shoulder neckline."),
        ],
        "black-tee": [
            StaplePiece(name: "Light-wash mom jeans", brand: "Levi's", price: "₹3,299",
                        art: Art("photo_rose_6", [0x151515, 0x3E5C7E], seed: 1230),
                        focus: UnitPoint(x: 0.5, y: 0.9), zoom: 2.4,
                        note: "A black graphic tee tucked into light, high-waist mom jeans.", category: "Denim"),
            StaplePiece(name: "Black cropped biker jacket", brand: "Bershka", price: "₹4,490",
                        art: Art("plan_concert_hero", [0x151515, 0x3E5C7E], seed: 1231),
                        focus: UnitPoint(x: 0.5, y: 0.5), zoom: 1.8,
                        note: "Open over a band tee for a stadium night, chains at the hip."),
            StaplePiece(name: "Tan bucket hat", brand: "Kangol", price: "₹2,990",
                        art: Art("palette_slate-noir_2", [0x151515, 0x3E5C7E], seed: 1232),
                        focus: UnitPoint(x: 0.45, y: 0.15), zoom: 2.2,
                        note: "Pulled low over an all-black sweat, the one warm colour in the fit."),
        ],
        "white-top": [
            StaplePiece(name: "Straight-leg blue jeans", brand: "Levi's", price: "₹3,599",
                        art: Art("staple_white_tee_6", [0xF4F4F4, 0xBDBDBD], seed: 1240),
                        focus: UnitPoint(x: 0.5, y: 0.7), zoom: 1.9,
                        note: "A sleeveless white top tucked into long straight jeans and strappy heels.", category: "Denim"),
            StaplePiece(name: "Mid-wash mom jeans", brand: "Only", price: "₹2,799",
                        art: Art("look_quiet_luxury", [0xF4F4F4, 0xBDBDBD], seed: 1241),
                        focus: UnitPoint(x: 0.5, y: 0.86), zoom: 2.2,
                        note: "A soft V-neck top, loosely tucked, over relaxed mid-wash denim.", category: "Denim"),
            StaplePiece(name: "Navy wide-leg track pants", brand: "Puma", price: "₹3,299",
                        art: Art("plan_active_hero", [0xF4F4F4, 0xBDBDBD], seed: 1242),
                        focus: UnitPoint(x: 0.5, y: 0.68), zoom: 2.0,
                        note: "A cropped white tee over striped wide-leg track pants."),
        ],
        "skort": [
            StaplePiece(name: "Ivory pussy-bow blouse", brand: "Zara", price: "₹2,990",
                        art: Art("plan_first_date_2", [0x1E2B45, 0x2A2826], seed: 1250),
                        focus: UnitPoint(x: 0.5, y: 0.45), zoom: 2.0,
                        note: "Tucked into a black button-front skort, with retro sunglasses."),
            StaplePiece(name: "Black ribbed turtleneck", brand: "Marks & Spencer", price: "₹1,999",
                        art: Art("plan_office_1", [0x1E2B45, 0x2A2826], seed: 1251),
                        focus: UnitPoint(x: 0.5, y: 0.35), zoom: 2.0,
                        note: "Black on black with a quilted skort and a statement necklace."),
        ],
    ]

    static func pieces(for staple: String, name: String, looks: [Art]) -> [StaplePiece] {
        if let picked = byStaple[staple] { return picked }
        return looks.enumerated().map { i, art in
            StaplePiece(name: "Look \(i + 1) with the \(name.lowercased())", brand: "District edit", price: "",
                        art: art, focus: UnitPoint(x: 0.5, y: 0.3), zoom: 1.8,
                        note: "Spotted with the \(name.lowercased()).")
        }
    }
}

/// One staple and the pieces to wear with it, for the "View all" page.
struct StapleGroup: Identifiable {
    let id: String
    let name: String
    let pieces: [StaplePiece]
}

/// The last card on a staple's rail: opens every look for every staple.
struct StapleViewAllTile: View {
    let count: Int

    var body: some View {
        VStack(spacing: R.spacingSpace12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 52, height: 52)
                .background(M.surfaceSecondary, in: Circle())
            VStack(spacing: 2) {
                Text("View all")
                    .font(EditType.text(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(M.textPrimary)
                Text("\(count) looks")
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
            }
        }
        .frame(width: 120, height: StaplePieceCard.size.height)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
    }
}

/// A piece on the shelf: the crop of it, then its name and brand · price underneath.
struct StaplePieceCard: View {
    let piece: StaplePiece
    static let size = CGSize(width: 168, height: 210)

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            CroppedArt(art: piece.art, focus: piece.focus, zoom: piece.zoom)
                .frame(width: Self.size.width, height: Self.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(piece.name)
                    .font(EditType.text(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(piece.price.isEmpty ? piece.brand : "\(piece.brand) · \(piece.price)")
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: Self.size.width, alignment: .leading)
    }
}

/// Full-screen carousel behind a piece: each page is the whole photo with the piece's details
/// written over the foot, like a product page. Swipe sideways through the staple's pieces.
struct StaplePieceViewer: View {
    let staple: String
    let pieces: [StaplePiece]
    /// Every staple's pieces, for "View all". Starts on `stapleID`.
    let groups: [StapleGroup]
    let stapleID: String
    @State private var index: Int?
    @State private var opened: StaplePiece?
    @State private var viewingAll = false
    @Environment(\.dismiss) private var dismiss

    init(staple: String, pieces: [StaplePiece], start: Int, groups: [StapleGroup] = [], stapleID: String = "") {
        self.staple = staple
        self.pieces = pieces
        self.groups = groups
        self.stapleID = stapleID
        _index = State(initialValue: start)
    }

    private var current: Int { index ?? 0 }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: R.spacingSpace0) {
                        ForEach(Array(pieces.enumerated()), id: \.offset) { i, piece in
                            page(piece)
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
            .ignoresSafeArea()

            topBar
        }
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: index)
        .readerCover(item: $opened) { ProductDetailView(product: $0.product) }
        .fullScreenCover(isPresented: $viewingAll) { StapleAllView(groups: groups, start: stapleID) }
        .accessibilityAction(.escape) { dismiss() }
    }

    /// Story-style segments, then the close button and "View all".
    private var topBar: some View {
        VStack(spacing: R.spacingSpace12) {
            HStack(spacing: 4) {
                ForEach(pieces.indices, id: \.self) { i in
                    Capsule()
                        .fill(M.textWhite.opacity(i == current ? 1 : 0.3))
                        .frame(height: 3)
                }
            }
            .animation(.snappy, value: current)
            .accessibilityHidden(true)
            HStack {
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                Text("\(current + 1) / \(pieces.count)")
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textWhite)
                    .monospacedDigit()
                    .padding(.leading, R.spacingSpace4)
                Spacer()
                if !groups.isEmpty {
                    Button { viewingAll = true } label: {
                        HStack(spacing: 6) {
                            Text("View all")
                                .font(EditType.text(14, .semibold, relativeTo: .subheadline))
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(M.textPrimary)
                        .padding(.horizontal, R.spacingSpace16)
                        .frame(height: 44)
                        .contentShape(Capsule())
                        .liquidGlass(in: Capsule(), interactive: true, clear: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows every look for every staple")
                }
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace8)
        .background {
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .padding(.bottom, -60)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    private func page(_ piece: StaplePiece) -> some View {
        ArtView(art: piece.art)
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .black.opacity(0.6), location: 0.45),
                                       .init(color: .black.opacity(0.9), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 380)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) { details(piece) }
    }

    private func details(_ piece: StaplePiece) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Text("Style it with \(staple.lowercased())")
                .font(EditType.text(12, .medium, relativeTo: .caption))
                .foregroundStyle(M.textWhite.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.8)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(piece.name)
                    .font(EditType.text(26, .semibold, relativeTo: .title))
                    .tracking(-0.4)
                    .foregroundStyle(M.textWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(piece.price.isEmpty ? piece.brand : "\(piece.brand) · \(piece.price)")
                    .font(EditType.text(15, .medium, relativeTo: .subheadline))
                    .foregroundStyle(M.textWhite.opacity(0.85))
            }
            Text(piece.note)
                .font(EditType.text(14, .regular, relativeTo: .body))
                .foregroundStyle(M.textWhite.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button { opened = piece } label: {
                Text("View product")
                    .font(EditType.text(15, .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(M.surfaceInverse, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, R.spacingSpace4)
        }
        .padding(.horizontal, R.spacingSpace20)
        .padding(.bottom, R.spacingSpace48)
    }
}

/// Every look for every staple on one page: a sticky row of staple pills that jump to each staple's
/// grid. Tapping a look opens its product page.
struct StapleAllView: View {
    let groups: [StapleGroup]
    let start: String
    @State private var current: String
    @State private var opened: StaplePiece?
    /// Off until the page has jumped to `start`, so the sections passing by don't move the pills.
    @State private var settled = false
    @Environment(\.dismiss) private var dismiss

    init(groups: [StapleGroup], start: String) {
        self.groups = groups
        self.start = start
        _current = State(initialValue: start)
    }

    /// Distinct from the pills' ids, which share the outer scroll reader.
    private static func sectionID(_ id: String) -> String { "section-\(id)" }

    private let columns = [GridItem(.flexible(), spacing: R.spacingSpace12, alignment: .top),
                           GridItem(.flexible(), spacing: R.spacingSpace12, alignment: .top)]

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: R.spacingSpace0) {
                header
                pills(proxy)
                ScrollView {
                    // Not lazy (it's ~20 tiles), so the jump to `start` can land on any section.
                    VStack(alignment: .leading, spacing: R.spacingSpace32) {
                        ForEach(groups) { group in
                            section(group)
                                .id(Self.sectionID(group.id))
                                .modifier(SectionSeen { if settled, current != group.id { current = group.id } })
                        }
                    }
                    .padding(.horizontal, R.spacingSpace16)
                    .padding(.top, R.spacingSpace16)
                    .padding(.bottom, R.spacingSpace48)
                }
                .scrollIndicators(.hidden)
                .task {
                    // Land on the staple you came from.
                    try? await Task.sleep(for: .milliseconds(250))
                    proxy.scrollTo(Self.sectionID(start), anchor: .top)
                    try? await Task.sleep(for: .milliseconds(300))
                    current = start
                    settled = true
                }
            }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: current)
        .readerCover(item: $opened) { ProductDetailView(product: $0.product) }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text("Style Your Staples")
                    .font(EditType.text(18, .semibold, relativeTo: .headline))
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("\(groups.reduce(0) { $0 + $1.pieces.count }) looks across \(groups.count) staples")
                    .font(EditType.text(12, .regular, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace8)
    }

    /// One pill per staple; the one you're looking at is inverse.
    private func pills(_ proxy: ScrollViewProxy) -> some View {
        ScrollViewReader { row in
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(groups) { group in
                        let on = group.id == current
                        Button {
                            current = group.id
                            withAnimation(.snappy) { proxy.scrollTo(Self.sectionID(group.id), anchor: .top) }
                        } label: {
                            Text(group.name)
                                .font(EditType.text(14, .medium, relativeTo: .subheadline))
                                .foregroundStyle(on ? M.borderCardBorderSurfacePrimary : M.textWhite)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, R.spacingSpace16)
                                .frame(height: 36)
                                .background(on ? M.surfaceInverse : M.surfaceSecondary, in: Capsule())
                                .frame(minHeight: 44)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(group.id)
                        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, R.spacingSpace16)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, R.spacingSpace8)
            .onChange(of: current) { _, id in withAnimation(.snappy) { row.scrollTo(id, anchor: .center) } }
            .onAppear { row.scrollTo(current, anchor: .center) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
    }

    private func section(_ group: StapleGroup) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(alignment: .firstTextBaseline) {
                Text("With \(group.name)")
                    .font(EditType.text(16, .semibold, relativeTo: .headline))
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(group.pieces.count) looks")
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
            }
            LazyVGrid(columns: columns, spacing: R.spacingSpace20) {
                ForEach(group.pieces) { piece in
                    Button { opened = piece } label: { tile(piece) }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(piece.name), \(piece.brand)")
                        .accessibilityValue(piece.price)
                        .accessibilityHint("Opens the product")
                }
            }
        }
    }

    /// The whole look, with the piece's crop pinned in the corner, then name and brand · price.
    private func tile(_ piece: StaplePiece) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            Color.clear
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay { ArtView(art: piece.art) }
                .overlay(alignment: .bottomTrailing) {
                    CroppedArt(art: piece.art, focus: piece.focus, zoom: piece.zoom)
                        .frame(width: 52, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(M.textWhite, lineWidth: 1.5) }
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .padding(R.spacingSpace8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(piece.name)
                    .font(EditType.text(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(piece.price.isEmpty ? piece.brand : "\(piece.brand) · \(piece.price)")
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
    }
}

/// Calls `seen` when a section scrolls into view (iOS 18+; earlier, the pills only follow taps).
private struct SectionSeen: ViewModifier {
    let seen: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollVisibilityChange(threshold: 0.35) { visible in if visible { seen() } }
        } else {
            content
        }
    }
}

#Preview("View all") {
    StapleAllView(groups: StaplePiece.byStaple.map { StapleGroup(id: $0.key, name: $0.key, pieces: $0.value) }, start: "leathers")
        .preferredColorScheme(.dark)
}

#Preview {
    StaplePieceViewer(staple: "Leathers", pieces: StaplePiece.byStaple["leathers"]!, start: 0)
        .preferredColorScheme(.dark)
}
