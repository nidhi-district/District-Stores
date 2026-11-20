import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// Shop a mall: Stores home's moving brand wall → the mall's canvas of edits and store spotlights (pan in any
// direction; switch mall from the header) → an edit opens as its own canvas of pieces (save with ♡, tap for the
// product page).

/// One trip into a mall from Stores home.
struct MallVisit: Identifiable {
    let id = UUID()
    let mall: MallShop
    /// An edit id (a brand's "brand-<Name>", or "picks") to open on arrival.
    var startEdit: String? = nil
    /// Debug: start with three pieces saved.
    var presaved = false
    /// Debug: start with the mall switcher open.
    var showSwitcher = false
}

/// What a canvas card opens: an edit, or the saved picks when `edit` is nil. `id` is the card it zooms from.
struct MallOpening: Identifiable {
    let id: String
    let edit: MallEdit?
}

// MARK: - Experience

struct MallDiscoveryView: View {
    let visit: MallVisit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mall: MallShop
    @State private var filter = MallFilter()
    @State private var shown = false
    @State private var switcherOpen = false
    @State private var picks = MallPicks()
    @State private var opening: MallOpening?
    @State private var hint: String?
    @Namespace private var zoom

    init(visit: MallVisit) {
        self.visit = visit
        _mall = State(initialValue: visit.mall)
    }

    private var subtitle: String {
        if filter.isEmpty { return mall.summary }
        let count = mall.edits.filter { $0.fits(filter) }.count
        return "\(filter.title) · \(count) edits"
    }

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            MallCanvasView(mall: mall, filter: $filter, zoom: zoom) { opening = $0 }
                .opacity(shown ? 1 : 0)

            if switcherOpen {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { setSwitcher(false) }
                    .transition(.opacity)
                    .accessibilityLabel("Close mall list")
                    .accessibilityAddTraits(.isButton)
            }

            VStack(spacing: 0) {
                header
                if switcherOpen {
                    MallSwitcherPanel(current: mall, choose: choose)
                        .padding(.horizontal, R.spacingSpace12)
                        .padding(.top, R.spacingSpace4)
                        .transition(.asymmetric(insertion: .scale(scale: 0.94, anchor: .top).combined(with: .opacity),
                                                removal: .scale(scale: 0.97, anchor: .top).combined(with: .opacity)))
                }
                if let hint {
                    MallHint(text: hint)
                        .padding(.top, R.spacingSpace8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .opacity(shown ? 1 : 0)
        }
        .environment(picks)
        .presentationBackground(.clear)
        .readerCover(item: $opening) { o in
            MallEditView(edit: o.edit, mall: mall)
                .environment(picks)
                .zoomTransition(id: o.id, in: zoom)
        }
        .onAppear(perform: arrive)
        .task(id: mall) { await MallImages.shared.preload(mall.edits.flatMap(\.covers)) }
        .task(id: hint) {
            guard hint != nil else { return }
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.smooth) { hint = nil }
        }
        .sensoryFeedback(.selection, trigger: mall)
        .sensoryFeedback(.impact(weight: .light), trigger: switcherOpen)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            M.backgroundPrimary
            RadialGradient(colors: [mall.glow.opacity(0.22), mall.glow.opacity(0.05), .clear],
                           center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 460)
        }
        .animation(.smooth(duration: 0.7), value: mall)
        .ignoresSafeArea()
        .opacity(shown ? 1 : 0)
    }

    // MARK: Header

    /// Back, the mall switcher (the mall's name over its line, with a chevron, like the Stores tab's location), and picks.
    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "chevron.left", label: "Back to Stores", action: close)
            Spacer(minLength: 0)
            Button { setSwitcher(!switcherOpen) } label: {
                VStack(spacing: 2) {
                    HStack(spacing: R.spacingSpace4) {
                        Text(mall.name)
                            .backstageText(.label1)
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(M.textSecondary)
                            .rotationEffect(.degrees(switcherOpen ? 180 : 0))
                    }
                    .id(mall.name)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)).combined(with: .opacity))
                    Text(subtitle)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                .clipped()
                .padding(.horizontal, R.spacingSpace12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mall.name), \(subtitle)")
            .accessibilityHint("Switches mall")
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            MallPicksButton(count: picks.saved.count, action: openPicks)
                .zoomSource(id: "picks", in: zoom)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace8)
        .background(alignment: .top) {
            MallHeaderVeil()
                .padding(.bottom, -R.spacingSpace40)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    // MARK: Actions

    private func arrive() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.32)) { shown = true }
        if visit.presaved {
            for p in mall.pieces.prefix(3) { picks.toggle(p) }
        }
        if let id = visit.startEdit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if id == "picks" { opening = MallOpening(id: "picks", edit: nil); return }
                if let edit = mall.edits.first(where: { $0.id == id }) { opening = MallOpening(id: "start-\(id)", edit: edit) }
            }
        }
        if visit.showSwitcher {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { setSwitcher(true) }
        }
    }

    private func setSwitcher(_ open: Bool) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { switcherOpen = open }
    }

    private func choose(_ m: MallShop) {
        setSwitcher(false)
        guard m != mall else { return }
        withAnimation(.smooth(duration: 0.35)) { mall = m }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.2)) {
            shown = false
            switcherOpen = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { dismiss() }
        }
    }

    private func openPicks() {
        if picks.saved.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { hint = "Tap ♡ on any piece to save it here" }
        } else {
            opening = MallOpening(id: "picks", edit: nil)
        }
    }
}

// MARK: - Mall switcher

/// The mall dropdown (header inside, and the home pill's popover): malls nearest first, each with its photo,
/// where it is, its brands and how many.
struct MallSwitcherPanel: View {
    let current: MallShop
    /// Its own glass, border and shadow; off inside a popover, which brings its own.
    var chrome = true
    let choose: (MallShop) -> Void

    private var malls: [MallShop] {
        MallCatalog.malls.sorted { ($0.hub?.distanceKm ?? .greatestFiniteMagnitude) < ($1.hub?.distanceKm ?? .greatestFiniteMagnitude) }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous)
        let list = VStack(alignment: .leading, spacing: 0) {
            Text("Malls near you")
                .backstageText(.label2)
                .foregroundStyle(M.textTertiary)
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace16)
                .padding(.bottom, R.spacingSpace4)
                .accessibilityAddTraits(.isHeader)
            ForEach(malls) { m in
                Button { choose(m) } label: { row(m) }
                    .buttonStyle(PressableStyle())
            }
        }
        .padding(.bottom, R.spacingSpace8)

        if chrome {
            list
                .liquidGlass(in: shape)
                .overlay(shape.strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
        } else {
            list
        }
    }

    private func row(_ m: MallShop) -> some View {
        let selected = m == current
        let brands = m.wallBrands
        return HStack(spacing: R.spacingSpace12) {
            Image(m.hub?.image ?? "")
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(m.name)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text([m.area, m.distance].filter { !$0.isEmpty }.joined(separator: " · "))
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                HStack(spacing: R.spacingSpace4) {
                    ForEach(brands.prefix(4), id: \.name) { MallBrandLogo(brand: $0, size: 22) }
                    Text("\(m.brands.count) brands")
                        .backstageText(.label2)
                        .foregroundStyle(M.textOffer)
                        .padding(.leading, R.spacingSpace4)
                }
            }
            Spacer(minLength: 0)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(M.textPrimary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, 10)
        .background(selected ? M.surfaceTransparent : .clear, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .padding(.horizontal, R.spacingSpace4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(m.name), \(m.distance), \(m.brands.count) brands")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Mall canvas

/// Every edit in the mall on a canvas you can pan in any direction. Cards shrink a little towards the edges of
/// the screen, like a lens. A new mall or filter folds the cards away and ripples the new set out from the middle.
struct MallCanvasView: View {
    /// What the header asked for; the canvas catches up once the old cards have folded away.
    let mall: MallShop
    @Binding var filter: MallFilter
    let zoom: Namespace.ID
    let onOpen: (MallOpening) -> Void

    @State private var shownMall: MallShop
    @State private var shownFilter: MallFilter
    @State private var revealed = false
    @State private var spotlit: Int?

    init(mall: MallShop, filter: Binding<MallFilter>, zoom: Namespace.ID, onOpen: @escaping (MallOpening) -> Void) {
        self.mall = mall
        _filter = filter
        self.zoom = zoom
        self.onOpen = onOpen
        _shownMall = State(initialValue: mall)
        _shownFilter = State(initialValue: filter.wrappedValue)
    }

    private var edits: [MallEdit] { shownMall.edits.filter { $0.fits(shownFilter) }.map { $0.narrowed(to: shownFilter) } }

    var body: some View {
        let edits = edits
        let grid = MallCanvasGrid(edits: edits)
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                MallCanvasField(layout: grid.layout, cells: grid.cells) { cell in
                    let edit = edits[grid.edit(at: cell)]
                    let id = "\(shownMall.short)-\(shownFilter.key)-\(cell)"
                    Button { onOpen(MallOpening(id: id, edit: edit)) } label: {
                        MallEditCard(edit: edit)
                    }
                    .buttonStyle(PressableStyle())
                    .zoomSource(id: id, in: zoom)
                    .overlay {
                        if spotlit == cell {
                            RoundedRectangle(cornerRadius: MallEditCard.radius, style: .continuous)
                                .strokeBorder(.white, lineWidth: 2.5)
                                .shadow(color: M.brandPurple, radius: 16)
                                .transition(.opacity)
                        }
                    }
                    .scaleEffect(spotlit == cell ? 1.06 : 1)
                    .id(cell)
                    .modifier(MallReveal(revealed: revealed, delay: min(0.5, grid.layout.ring(cell) * 0.07)))
                    .canvasLens()
                    .accessibilityLabel("\(edit.title), \(edit.kicker), \(edit.pieces.count) pieces")
                }
            }
            .defaultScrollAnchor(.center)
            .scrollIndicators(.hidden)
            .overlay {
                if edits.isEmpty {
                    Text("Nothing matches these filters in \(shownMall.name) yet")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                }
            }
            .overlay(alignment: .bottom) { pills(proxy) }
            .onChange(of: mall) { _, _ in refill(proxy) }
            .onChange(of: filter) { _, _ in refill(proxy) }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { revealed = true }
        }
    }

    // MARK: Pills

    private func pills(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Menu {
                    Picker("Category", selection: $filter.category) {
                        Text("All categories").tag(MallFilter.Category?.none)
                        ForEach(MallFilter.Category.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                } label: {
                    HStack(spacing: R.spacingSpace4) {
                        Text(filter.category?.title ?? "Category")
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                }
                .menuStyle(.button)
                .buttonStyle(MallPillStyle(active: filter.category != nil))
                .accessibilityLabel("Category, \(filter.category?.title ?? "all")")

                genderPill(.women, "Women")
                genderPill(.men, "Men")

                Button { filter.payOnDistrict.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "indianrupeesign.circle.fill").font(.system(size: 15, weight: .semibold))
                        Text("Pay via District")
                    }
                }
                .buttonStyle(MallPillStyle(active: filter.payOnDistrict, leading: 14))
                .accessibilityHint("Shows only stores where you can pay your bill on District")
                .accessibilityAddTraits(filter.payOnDistrict ? .isSelected : [])
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace8)
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(colors: [M.backgroundPrimary.opacity(0), M.backgroundPrimary.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                .padding(.top, -48)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    /// Women / Men: tapping the active one clears it.
    private func genderPill(_ g: MallFilter.Gender, _ title: String) -> some View {
        Button { filter.gender = filter.gender == g ? nil : g } label: { Text(title) }
            .buttonStyle(MallPillStyle(active: filter.gender == g))
            .accessibilityAddTraits(filter.gender == g ? .isSelected : [])
    }

    /// Cards fold away, the canvas refills for the new mall or filter and ripples back out from the middle.
    private func refill(_ proxy: ScrollViewProxy) {
        revealed = false
        spotlit = nil
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            shownMall = mall
            shownFilter = filter
            try? await Task.sleep(for: .seconds(0.02))
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { proxy.scrollTo(MallCanvasGrid(edits: edits).centreCell, anchor: .center) }
            revealed = true
        }
    }
}

// MARK: - Canvas layout

/// Cards in columns, every other column dropped half a card, so the field reads as a loose mosaic.
struct MallCanvasLayout {
    let columns: Int
    let rows: Int
    let card: CGSize
    let gap: CGFloat
    let insets: EdgeInsets

    private var pitch: CGSize { CGSize(width: card.width + gap, height: card.height + gap) }

    func center(_ index: Int) -> CGPoint {
        let c = index % columns, r = index / columns
        let drop = c.isMultiple(of: 2) ? 0 : pitch.height / 2
        return CGPoint(x: insets.leading + CGFloat(c) * pitch.width + card.width / 2,
                       y: insets.top + CGFloat(r) * pitch.height + drop + card.height / 2)
    }

    var size: CGSize {
        CGSize(width: insets.leading + CGFloat(columns) * pitch.width - gap + insets.trailing,
               height: insets.top + CGFloat(rows) * pitch.height - gap + (columns > 1 ? pitch.height / 2 : 0) + insets.bottom)
    }

    /// Distance from the middle of the field, in cards: the reveal ripples out by it.
    func ring(_ index: Int) -> Double {
        let p = center(index), s = size
        let dx = (p.x - s.width / 2) / pitch.width, dy = (p.y - s.height / 2) / pitch.height
        return Double((dx * dx + dy * dy).squareRoot())
    }

    /// An edit's pieces: three columns, four when there are many.
    static func pieces(count: Int) -> MallCanvasLayout {
        let columns = count > 12 ? 4 : 3
        return MallCanvasLayout(columns: columns, rows: max(1, Int((Double(count) / Double(columns)).rounded(.up))),
                                card: CGSize(width: 152, height: 186), gap: 18,
                                insets: EdgeInsets(top: 112, leading: 20, bottom: 150, trailing: 20))
    }
}

/// The mall canvas. Brands come first: cards are dealt out from the middle in rings, two store spotlights to
/// every billboard. With enough edits the field is large and repeats them (repeats land rings apart); when a
/// filter leaves only a few, each appears once.
struct MallCanvasGrid {
    let layout: MallCanvasLayout
    let cells: Int
    private let assignment: [Int]

    init(edits: [MallEdit]) {
        let count = edits.count
        let repeats = count >= 12
        let columns = repeats ? 7 : 3
        let rows = repeats ? 6 : max(1, Int((Double(count) / 3).rounded(.up)))
        let layout = MallCanvasLayout(columns: columns, rows: rows, card: CGSize(width: 158, height: 240), gap: 20,
                                      insets: EdgeInsets(top: 116, leading: 24, bottom: 130, trailing: 24))
        let cells = repeats ? columns * rows : count
        self.layout = layout
        self.cells = cells

        let brands = edits.indices.filter { edits[$0].style == .spotlight }
        let boards = edits.indices.filter { edits[$0].style == .billboard }
        var sequence: [Int] = []
        if repeats {
            var b = 0, s = 0
            for i in 0..<cells {
                if (i % 3 == 2 && !boards.isEmpty) || brands.isEmpty {
                    sequence.append(boards[s % boards.count]); s += 1
                } else {
                    sequence.append(brands[b % brands.count]); b += 1
                }
            }
        } else {
            var brandsLeft = brands[...], boardsLeft = boards[...]
            var i = 0
            while sequence.count < cells {
                if i % 3 == 2 || brandsLeft.isEmpty, let x = boardsLeft.first {
                    sequence.append(x); boardsLeft = boardsLeft.dropFirst()
                } else if let x = brandsLeft.first {
                    sequence.append(x); brandsLeft = brandsLeft.dropFirst()
                } else if let x = boardsLeft.first {
                    sequence.append(x); boardsLeft = boardsLeft.dropFirst()
                }
                i += 1
            }
        }
        let rings = (0..<cells).sorted { layout.ring($0) < layout.ring($1) }
        var map = Array(repeating: 0, count: cells)
        for (i, cell) in rings.enumerated() { map[cell] = sequence[i] }
        assignment = map
    }

    func edit(at cell: Int) -> Int { assignment[cell] }

    var centreCell: Int {
        (0..<max(1, cells)).min { layout.ring($0) < layout.ring($1) } ?? 0
    }
}

struct MallCanvasField<Cell: View>: View {
    let layout: MallCanvasLayout
    let cells: Int
    @ViewBuilder let cell: (Int) -> Cell

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(0..<cells, id: \.self) { i in
                cell(i)
                    .frame(width: layout.card.width, height: layout.card.height)
                    .position(layout.center(i))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}

extension View {
    /// Shrinks and dims a canvas card as it nears the screen's edge.
    func canvasLens(_ amount: CGFloat = 0.13) -> some View {
        visualEffect { content, proxy in
            let frame = proxy.frame(in: .scrollView)
            let page = proxy.bounds(of: .scrollView)?.size ?? proxy.size
            let dx = (frame.midX - page.width / 2) / max(page.width, 1)
            let dy = (frame.midY - page.height / 2) / max(page.height, 1)
            let d = min(1, (dx * dx + dy * dy).squareRoot() * 1.3)
            return content
                .scaleEffect(1 - amount * d * d)
                .opacity(1 - 0.3 * d * d)
        }
    }
}

/// Pops a card in, delayed by its distance from the middle.
struct MallReveal: ViewModifier {
    let revealed: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(revealed || reduceMotion ? 1 : 0.5)
            .opacity(revealed ? 1 : 0)
            .animation(revealed ? .spring(response: 0.6, dampingFraction: 0.8).delay(reduceMotion ? 0 : delay) : .easeIn(duration: 0.14),
                       value: revealed)
    }
}

// MARK: - Cards

/// A canvas card: a store spotlight (two pieces fanned behind the brand's logo), or a billboard edit.
struct MallEditCard: View {
    static let radius: CGFloat = 24
    let edit: MallEdit

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Self.radius, style: .continuous) }

    var body: some View {
        switch edit.style {
        case .billboard: billboard
        case .spotlight: spotlight
        }
    }

    /// A cross-brand edit as a billboard (like Home's spotlight cards): a solid ground, a small-caps line, a serif
    /// title with an italic second line, and a lifted-out piece in the corner.
    private var billboard: some View {
        let cream = Color(hex: 0xF3E8D6)
        return ZStack(alignment: .topLeading) {
            edit.ground
            RadialGradient(colors: [.white.opacity(0.1), .clear], center: .topLeading, startRadius: 0, endRadius: 240)
            if let art = edit.art {
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 150, alignment: .bottomTrailing)
                    .shadow(color: .black.opacity(0.4), radius: 10, x: -2, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 6)
                    .padding(.bottom, 8)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(edit.kicker.uppercased())
                    .font(.custom("BeVietnamPro-SemiBold", fixedSize: 10))
                    .tracking(1.1)
                    .foregroundStyle(cream.opacity(0.8))
                    .lineLimit(1)
                    .padding(.bottom, R.spacingSpace8)
                Text(edit.lead)
                    .font(.custom("PlayfairDisplay-Regular", fixedSize: 25))
                    .foregroundStyle(cream)
                    .lineLimit(2)
                Text(edit.italic)
                    .font(.custom("PlayfairDisplay-Italic", fixedSize: 25))
                    .foregroundStyle(cream)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("\(edit.pieces.count) pieces")
                    .font(.custom("PlayfairDisplay-Regular", fixedSize: 14))
                    .foregroundStyle(cream.opacity(0.9))
            }
            .padding(14)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: R.stroke1Px))
    }

    /// A brand's card: a mosaic of its pieces, then its logo on the left, floor and category, and its name.
    private var spotlight: some View {
        let covers = Array(edit.covers.prefix(3))
        let tile = RoundedRectangle(cornerRadius: 12, style: .continuous)
        func piece(_ name: String) -> some View {
            MallPhoto(name: name, packshot: MallCatalog.piece(name)?.packshot ?? false, inset: 6)
                .clipShape(tile)
        }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if let first = covers.first { piece(first) }
                if covers.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(covers.dropFirst(), id: \.self) { piece($0) }
                    }
                    .frame(width: 52)
                }
            }
            .frame(height: 140)
            .padding([.horizontal, .top], 6)

            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                if let brand = edit.brand {
                    MallBrandLogo(brand: brand, size: 52)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        .padding(.top, -26)
                        .padding(.bottom, R.spacingSpace4)
                }
                Text(edit.kicker)
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                Text(edit.brand?.name ?? edit.title)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .background(M.surfacePrimary)
        .clipShape(shape)
        .overlay(shape.strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }
}

/// A brand's logo on a rounded square tile, or its name as a word mark when no logo is bundled.
struct MallBrandLogo: View {
    let brand: MallBrand
    var size: CGFloat = 54

    /// Long wordmarks get less padding so they stay legible in a square.
    private static let long: Set<String> = ["Zara", "Doodlage", "Peter England"]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        Group {
            if let logo = brand.logo {
                if brand.fullBleed {
                    Image(logo).resizable().scaledToFill()
                } else if let caption = brand.caption, size >= 60 {
                    VStack(spacing: size * 0.08) {
                        Image(logo).resizable().scaledToFit().frame(height: size * 0.42)
                        Text(caption)
                            .font(.custom("BeVietnamPro-Medium", fixedSize: 10))
                            .tracking(0.3)
                            .foregroundStyle(Color(hex: brand.captionColor))
                            .lineLimit(1)
                            .fixedSize()
                    }
                } else {
                    Image(logo).resizable().scaledToFit()
                        .padding(size * (Self.long.contains(brand.name) ? 0.1 : (brand.caption != nil ? 0.2 : 0.15)))
                }
            } else {
                // Small tiles show the initial: a whole word would have to drop below 10pt.
                let fontSize = max(10, size * 0.22)
                Text(size < 34 ? String(brand.name.prefix(1)) : brand.name.uppercased())
                    .font(.custom("BeVietnamPro-ExtraBold", fixedSize: fontSize))
                    .tracking(-0.3)
                    .foregroundStyle(M.textBlack)
                    .multilineTextAlignment(.center)
                    .lineLimit(size < 34 ? 1 : 2)
                    .minimumScaleFactor(10 / fontSize)
                    .padding(.horizontal, size < 34 ? 0 : 6)
            }
        }
        .frame(width: size, height: size)
        .background(brand.onDark ? Color.black : Color.white)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: R.stroke1Px))
        .accessibilityHidden(true)
    }
}

/// A catalogue photo from the downsampled cache, fading in when it arrives. Packshots sit whole on white.
struct MallPhoto: View {
    let name: String
    var packshot = false
    var inset: CGFloat = 14
    @State private var loaded: UIImage?
    @State private var loadedName: String?

    var body: some View {
        let image = MallImages.shared.cached(name) ?? (loadedName == name ? loaded : nil)
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: packshot ? .fit : .fill)
                        .padding(packshot ? inset : 0)
                        .transition(.opacity)
                }
            }
            .background(packshot ? Color.white : M.surfaceSecondary)
            .clipped()
            .task(id: name) {
                // Always hand the image to state: a preload may have filled the cache after this view first drew
                // empty, and the cache alone doesn't redraw it.
                guard loadedName != name else { return }
                let image = await MallImages.shared.load(name)
                withAnimation(.easeOut(duration: 0.2)) {
                    loaded = image
                    loadedName = name
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Edit (collection) canvas

/// An edit's pieces, or the saved picks, on their own canvas. ♡ saves with a toast; a tile opens the product page.
struct MallEditView: View {
    let mall: MallShop
    /// What's on show: the edit opened, or the next brand after a pull past the end.
    @State private var edit: MallEdit?
    /// How far the canvas is pulled past its bottom edge.
    @State private var pull: CGFloat = 0
    @State private var switches = 0

    /// Pulling this far past the end, then letting go, moves on to the next brand.
    private static let pullToSwitch: CGFloat = 90

    init(edit: MallEdit?, mall: MallShop) {
        self.mall = mall
        _edit = State(initialValue: edit)
    }

    @Environment(MallPicks.self) private var picks
    @Environment(\.dismiss) private var dismiss
    @State private var product: StoreProduct?
    @State private var toast: MallPiece?
    @State private var revealed = false
    @State private var routeTapped = 0
    @State private var routeNote = false
    @Namespace private var zoom

    private var pieces: [MallPiece] { edit?.pieces ?? picks.saved }
    private var title: String { edit?.brand?.name ?? edit?.title ?? "\(MallCatalog.shopperName)'s picks" }
    private var subtitle: String {
        if let edit, edit.brand != nil { return "\(edit.kicker) · \(edit.pieces.count) pieces" }
        if let edit { return "\(edit.sellers) · \(edit.pieces.count) pieces" }
        return "\(picks.saved.count) saved while browsing"
    }

    var body: some View {
        let pieces = pieces
        let layout = MallCanvasLayout.pieces(count: pieces.count)
        ScrollViewReader { proxy in
        ScrollView([.horizontal, .vertical]) {
            MallCanvasField(layout: layout, cells: pieces.count) { i in
                let piece = pieces[i]
                MallPieceTile(piece: piece, saved: picks.contains(piece),
                              toggle: { toggle(piece) },
                              open: { product = piece.product })
                    .zoomSource(id: piece.id, in: zoom)
                    .modifier(MallReveal(revealed: revealed, delay: min(0.4, layout.ring(i) * 0.06)))
                    .canvasLens(0.1)
                    .id(i)
            }
        }
        .modifier(EdgePullReader(pull: $pull) {
            if pull >= Self.pullToSwitch, nextBrand != nil { switchBrand(proxy) }
        })
        }
        .defaultScrollAnchor(.top)
        .scrollIndicators(.hidden)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) {
            VStack(spacing: R.spacingSpace8) {
                toastView
                if let next = nextBrand, let nextLogo = next.brand, pull > 8 {
                    nextBrandHint(nextLogo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let brand = edit?.brand { routeCTA(brand) }
            }
        }
        .overlay { if pieces.isEmpty { empty } }
        .readerCover(item: $product) { p in
            StoreProductView(product: p).zoomTransition(id: p.image, in: zoom)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { revealed = true }
        }
        .task(id: toast?.id) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { toast = nil }
        }
        .sensoryFeedback(.success, trigger: picks.saveCount)
        .sensoryFeedback(.success, trigger: switches)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pull > 8)
    }

    private func toggle(_ piece: MallPiece) {
        let saving = !picks.contains(piece)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) { picks.toggle(piece) }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) { toast = saving ? piece : nil }
    }

    private var header: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
            VStack(spacing: 2) {
                Text(title)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace8)
        .padding(.bottom, R.spacingSpace40)
        .background {
            MallHeaderVeil()
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private var toastView: some View {
        if let piece = toast {
            HStack(spacing: R.spacingSpace12) {
                MallPhoto(name: piece.image, packshot: piece.packshot, inset: 4)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved to \(MallCatalog.shopperName)'s picks")
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                    Text("\(piece.brand) · \(piece.name)")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(M.brandPurple)
            }
            .padding(R.spacingSpace12)
            .background(M.surfaceSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
            .padding(.horizontal, R.spacingSpace16)
            .padding(.bottom, R.spacingSpace12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture { withAnimation(.smooth) { toast = nil } }
            .accessibilityElement(children: .combine)
        }
    }

    /// The brand after this one in the mall, for the pull-to-switch at the end of the canvas.
    private var nextBrand: MallEdit? {
        guard let current = edit, current.brand != nil else { return nil }
        let brands = mall.edits.filter { $0.style == .spotlight }
        guard brands.count > 1, let i = brands.firstIndex(of: current) else { return nil }
        return brands[(i + 1) % brands.count]
    }

    /// Rises as the canvas is pulled past its end: the next brand's logo in a ring that fills with the pull.
    private func nextBrandHint(_ brand: MallBrand) -> some View {
        let progress = min(1, pull / Self.pullToSwitch)
        let armed = progress >= 1
        return HStack(spacing: R.spacingSpace8) {
            ZStack {
                Circle().stroke(M.borderModerate, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(M.textOffer, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                MallBrandLogo(brand: brand, size: 24)
            }
            .frame(width: 32, height: 32)
            Text(armed ? "Release for \(brand.name)" : "Keep pulling for \(brand.name)")
                .backstageText(.label2)
                .foregroundStyle(M.textPrimary)
                .contentTransition(.opacity)
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(armed ? M.textOffer : M.textSecondary)
                .rotationEffect(.degrees(armed ? 180 : 0))
        }
        .padding(.leading, 6)
        .padding(.trailing, R.spacingSpace16)
        .frame(height: 44)
        .liquidGlass(in: Capsule())
        .scaleEffect(armed ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: armed)
        .sensoryFeedback(.impact(weight: .light), trigger: pull > 8) { _, now in now }
        .sensoryFeedback(.impact(weight: .heavy), trigger: armed) { _, now in now }
        .accessibilityElement(children: .combine)
    }

    /// Folds this brand's pieces away and deals the next brand's in from the top.
    private func switchBrand(_ proxy: ScrollViewProxy) {
        guard let next = nextBrand else { return }
        switches += 1
        revealed = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                edit = next
                pull = 0
                proxy.scrollTo(0, anchor: .topLeading)
            }
            try? await Task.sleep(for: .seconds(0.03))
            revealed = true
        }
    }

    /// In-mall navigation's entry point on a brand's page: "Take me to <brand>", its floor and the walk.
    private func routeCTA(_ brand: MallBrand) -> some View {
        let floor = mall.floor(of: brand.name)
        let minutes = (mall.name + brand.name).unicodeScalars.reduce(0) { $0 + Int($1.value) } % 5 + 2
        return Button {
            routeTapped += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { routeNote = true }
        } label: {
            HStack(spacing: R.spacingSpace12) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(M.textWhite)
                    .rotationEffect(.degrees(35))
                    .frame(width: 40, height: 40)
                    .background(LinearGradient(colors: [M.brandPurple, M.districtWash], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take me to \(brand.name)")
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text(routeNote ? "In-mall directions are coming soon" : "Floor \(floor) · about a \(minutes) min walk")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(M.textPrimary)
            }
            .padding(.leading, R.spacingSpace8)
            .padding(.trailing, R.spacingSpace20)
            .frame(height: 56)
            .liquidGlass(in: Capsule(), interactive: true)
            .overlay(Capsule().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace8)
        .sensoryFeedback(.impact(weight: .medium), trigger: routeTapped)
        .task(id: routeTapped) {
            guard routeNote else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.smooth) { routeNote = false }
        }
        .accessibilityLabel("Take me to \(brand.name), floor \(floor), about a \(minutes) minute walk")
        .accessibilityHint("Directions inside \(mall.name)")
    }

    private var empty: some View {
        VStack(spacing: R.spacingSpace8) {
            Image(systemName: "heart")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(M.iconTertiary)
            Text("Nothing saved yet")
                .backstageText(.label1)
                .foregroundStyle(M.textPrimary)
            Text("Tap ♡ on any piece to keep it here while you browse \(mall.name).")
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, R.spacingSpace40)
    }
}

/// A piece on an edit's canvas: price, brand, ♡. Saved pieces get a purple outline.
struct MallPieceTile: View {
    let piece: MallPiece
    let saved: Bool
    let toggle: () -> Void
    let open: () -> Void

    private static let radius: CGFloat = 26

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        Button(action: open) {
            MallPhoto(name: piece.image, packshot: piece.packshot)
                .overlay {
                    if !piece.packshot {
                        LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(piece.brand)
                        .backstageText(.label3)
                        .foregroundStyle(piece.packshot ? M.textBlack.opacity(0.7) : .white)
                        .lineLimit(1)
                        .padding(.leading, 14)
                        .padding(.trailing, 52)
                        .padding(.bottom, 16)
                }
                .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .overlay(alignment: .topLeading) {
            Text(piece.priceText)
                .backstageText(.label3)
                .foregroundStyle(M.textWhite)
                .padding(.horizontal, R.spacingSpace8)
                .frame(height: 24)
                .background(Color.black.opacity(0.34), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: toggle) {
                Image(systemName: saved ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(M.textWhite)
                    .symbolEffect(.bounce, value: saved)
                    .frame(width: 36, height: 36)
                    .background {
                        if saved {
                            Circle().fill(M.brandPurple)
                        } else {
                            Circle().fill(Color.black.opacity(0.3)).background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel(saved ? "Saved" : "Save")
            .accessibilityAddTraits(saved ? .isSelected : [])
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(saved ? M.brandPurple : .white.opacity(0.08), lineWidth: saved ? 2.5 : R.stroke1Px))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(piece.brand), \(piece.name), \(piece.priceText)")
    }
}

// MARK: - Small parts

/// The ♡ in the header with a count of saved pieces.
struct MallPicksButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: count > 0 ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(count > 0 ? M.brandPurple : M.iconPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .liquidGlass(in: Circle(), interactive: true, clear: true)
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(count)")
                            .backstageText(.label3)
                            .foregroundStyle(M.textWhite)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(M.surfaceOfferPrimary, in: Capsule())
                            .offset(x: 4, y: -4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: count)
        .accessibilityLabel(count > 0 ? "Your picks, \(count) saved" : "Your picks")
    }
}

/// A floating pill: glass when idle, solid white when chosen.
struct MallPillStyle: ButtonStyle {
    let active: Bool
    var leading: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .backstageText(.label1)
            .foregroundStyle(active ? M.textInverse : M.textPrimary)
            .padding(.leading, leading)
            .padding(.trailing, 18)
            .frame(height: 46)
            .background {
                if active {
                    Capsule().fill(M.surfaceInverse)
                } else {
                    Color.clear.liquidGlass(in: Capsule(), interactive: true)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
            .animation(.snappy(duration: 0.25), value: active)
    }
}

/// Behind a canvas header: stacked materials that blur more towards the top, over a dark base, so the title
/// stays readable over bright photos while the cards still read through lower down. (As the hubs listing header.)
private struct MallHeaderVeil: View {
    var body: some View {
        ZStack {
            layer(.ultraThinMaterial, until: 1)
            layer(.ultraThinMaterial, until: 0.82)
            layer(.thinMaterial, until: 0.64)
            LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0.88), location: 0),
                                   .init(color: M.backgroundPrimary.opacity(0.7), location: 0.6),
                                   .init(color: M.backgroundPrimary.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }

    private func layer(_ material: Material, until end: CGFloat) -> some View {
        Rectangle()
            .fill(material)
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: end * 0.6),
                                       .init(color: .clear, location: end)],
                               startPoint: .top, endPoint: .bottom)
            }
    }
}

/// A one-line nudge that drops in under the header.
private struct MallHint: View {
    let text: String

    var body: some View {
        Text(text)
            .backstageText(.label2)
            .foregroundStyle(M.textPrimary)
            .padding(.horizontal, R.spacingSpace16)
            .frame(height: 36)
            .liquidGlass(in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}

/// Reports how far a scroll view is pulled past its bottom edge, and calls `onRelease` when the finger lifts.
/// Needs iOS 18's scroll geometry; earlier systems simply never show the pull hint.
private struct EdgePullReader: ViewModifier {
    @Binding var pull: CGFloat
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    // The furthest the content can rest; short content rests at the top.
                    let end = max(g.contentSize.height + g.contentInsets.bottom - g.containerSize.height, -g.contentInsets.top)
                    return g.contentOffset.y - end
                } action: { _, over in
                    pull = max(0, over)
                }
                .onScrollPhaseChange { old, new in
                    if old == .interacting && new != .interacting { onRelease() }
                }
        } else {
            content
        }
    }
}
