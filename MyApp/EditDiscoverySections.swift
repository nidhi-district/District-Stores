import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// Discovery sections for the Edit tab: vibe-first input, swaps for the season, brands like the
// ones you shop, and creators' posts. Every one follows the page's Women / Men filter (the switch
// in the header, stored at "edit.gender") and shows the shared skeleton for a beat when it flips.
// Photos come from the shoot library; names, prices and handles are placeholders until catalogue
// and creator data land.

/// A piece built from a library photo, so cards here can open the PDP.
private func piece(_ name: String, _ brand: String, _ category: String, _ image: String, _ hexes: [UInt32],
                   _ price: String, seed: Int) -> Product {
    Product(name: name, brand: brand, mark: brand.uppercased(), category: category, isNew: false,
            art: Art(image, hexes, seed: seed), price: price)
}

/// Pills that wrap onto a new line as they run out of width.
struct EditFlowLayout: Layout {
    var spacing: CGFloat = 8
    /// Rows sit closer than pills, since each pill already carries a 44pt tap height.
    var rowSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.items.isEmpty, row.width + spacing + size.width > width {
                rows.append(Row(y: row.y + row.height + rowSpacing))
                row = rows[rows.count - 1]
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

// MARK: - What's the vibe? (vibe-first input)

/// A feeling you can pick, and the kinds of clothes that deliver it.
struct EditVibe: Identifiable, Hashable {
    let id: String
    let label: String
    let symbol: String
    let tint: UInt32
    /// `EditFabric` ids, strongest match first.
    let fabrics: [String]

    static let all: [EditVibe] = [
        EditVibe(id: "light", label: "Light", symbol: "feather", tint: 0xE9DCC0, fabrics: ["linen", "cotton"]),
        EditVibe(id: "breathable", label: "Breathable", symbol: "wind", tint: 0x8EC5D6, fabrics: ["linen", "cotton", "resort"]),
        EditVibe(id: "relaxed", label: "Relaxed", symbol: "sun.max", tint: 0xF2C94C, fabrics: ["resort", "denim"]),
        EditVibe(id: "cosy", label: "Cosy", symbol: "cup.and.saucer", tint: 0xC08A70, fabrics: ["knit", "denim"]),
        EditVibe(id: "sharp", label: "Sharp", symbol: "scissors", tint: 0x9AA6BF, fabrics: ["tailoring"]),
        EditVibe(id: "polished", label: "Polished", symbol: "sparkles", tint: 0xBCAEFE, fabrics: ["tailoring", "knit"]),
        EditVibe(id: "bold", label: "Bold", symbol: "bolt", tint: 0xF0643A, fabrics: ["statement"]),
        EditVibe(id: "sporty", label: "Sporty", symbol: "figure.run", tint: 0x7FB77E, fabrics: ["athleisure", "cotton"]),
    ]
}

/// A kind of clothing the vibes point to, with a pick for each side of the filter.
struct EditFabric: Identifiable {
    let id: String
    let name: String
    let line: String
    let women: Product
    let men: Product

    func pick(_ gender: String) -> Product { gender == "men" ? men : women }

    static let all: [EditFabric] = [
        EditFabric(id: "linen", name: "Linens", line: "Loose weaves that let the air through",
                   women: piece("Linen blazer & trouser set", "Zara", "Co-ords", "vogue_fit_brunch", [0xE9E2D4, 0xB8AE9C], "₹5,990", seed: 1301),
                   men: piece("Printed linen camp shirt", "Snitch", "Shirts", "palette_midnight-olive_5", [0x2A1E16, 0x6A4A30], "₹1,799", seed: 1302)),
        EditFabric(id: "cotton", name: "Cotton staples", line: "Tees and tanks you'll live in",
                   women: piece("Ribbed cotton tank", "H&M", "Basics", "staple_white_tee_6", [0xEDEDED, 0x6A8CC8], "₹699", seed: 1303),
                   men: piece("Boxy cotton tee", "The Souled Store", "Basics", "staple_white_tee_3", [0xEDEDED, 0x9A9A9A], "₹899", seed: 1304)),
        EditFabric(id: "resort", name: "Relaxed resort wear", line: "Easy prints for long lunches",
                   women: piece("Floral wrap midi", "Nicobar", "Dresses", "plan_brunch_1", [0xF2E7D3, 0x6A8C6A], "₹4,450", seed: 1305),
                   men: piece("Embroidered resort shirt", "Dhaga", "Shirts", "vogue_brand_dhaga", [0xE8B4A8, 0x8A3A2A], "₹3,450", seed: 1306)),
        EditFabric(id: "denim", name: "Easy denim", line: "Wide, washed and worn-in",
                   women: piece("Wide-leg jeans", "Blu", "Denim", "vogue_look_olive", [0x8FA6C2, 0x6A7A3A], "₹2,999", seed: 1307),
                   men: piece("Sherpa-lined denim jacket", "Blu", "Denim", "staple_denim_1", [0x3E5C7E, 0xA08850], "₹3,499", seed: 1308)),
        EditFabric(id: "knit", name: "Soft knits", line: "Fine-gauge, never itchy",
                   women: piece("Chenille crew jumper", "H&M", "Knitwear", "photo_rose_1", [0xC98E8A, 0xEDE0DA], "₹1,999", seed: 1309),
                   men: piece("Graphic crew sweatshirt", "The Souled Store", "Knitwear", "palette_slate-noir_2", [0x1A1A1A, 0xC9A27A], "₹1,699", seed: 1310)),
        EditFabric(id: "tailoring", name: "Sharp tailoring", line: "Clean lines that do the work",
                   women: piece("Ivory single-breasted blazer", "Zara", "Tailoring", "rack_zara_blazer", [0xEDE6DA, 0xC8402F], "₹5,490", seed: 1311),
                   men: piece("Navy two-piece suit", "H&M", "Tailoring", "staple_blazer_1", [0x1E2A45, 0xE9E9E9], "₹8,999", seed: 1312)),
        EditFabric(id: "statement", name: "Statement pieces", line: "The one everyone asks about",
                   women: piece("Patchwork denim co-ord", "Bonkers Corner", "Denim", "rack_bonkers_patchwork", [0x3E6A9E, 0xE0407A], "₹3,499", seed: 1313),
                   men: piece("Silver jacket & shorts", "Snitch", "Co-ords", "palette_midnight-olive_4", [0xC8402F, 0x9A9A9A], "₹4,299", seed: 1314)),
        EditFabric(id: "athleisure", name: "Athleisure", line: "Gym to coffee, no change",
                   women: piece("Zip track top & joggers", "adidas", "Activewear", "vogue_fit_active", [0x1A1A1A, 0x9A9A9A], "₹5,499", seed: 1315),
                   men: piece("Cap & oversized tee", "adidas", "Activewear", "staple_white_tee_2", [0xEDEDED, 0x4A5A3A], "₹2,299", seed: 1316)),
    ]

    /// The fabrics the picked vibes agree on most, each with the vibes that led to it.
    static func matches(for vibes: [EditVibe]) -> [(fabric: EditFabric, because: [EditVibe])] {
        var order: [String] = []
        var reasons: [String: [EditVibe]] = [:]
        for vibe in vibes {
            for id in vibe.fabrics {
                if reasons[id] == nil { order.append(id) }
                reasons[id, default: []].append(vibe)
            }
        }
        let ranked = order.enumerated().sorted { a, b in
            let ca = reasons[a.element]?.count ?? 0, cb = reasons[b.element]?.count ?? 0
            return ca != cb ? ca > cb : a.offset < b.offset
        }
        return ranked.prefix(4).compactMap { _, id in
            all.first { $0.id == id }.map { ($0, reasons[id] ?? []) }
        }
    }
}

/// Ask for a feeling, not a garment. One glowing panel holds the whole exchange, so the answer
/// sits right under the question: "I want to feel light, breathable & relaxed" builds as you tap
/// the chips, then "So we'd reach for linens, cotton staples & relaxed resort wear" and a pick for
/// each. Each vibe's colour runs from its chip into the glow and the dots on the cards it led to.
struct VogueVibeSection: View {
    let number: Int
    @AppStorage("edit.gender") private var gender = "women"
    @State private var picked: [String] = ["light", "breathable", "relaxed"]
    @State private var opened: Product?
    /// Bumps to ripple a shine across the pills, hinting they can be tapped.
    @State private var hint = 0
    /// Set on the first tap; the hint stops once you've found the pills.
    @State private var touched = false
    @State private var onScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let maxPicks = 3

    var body: some View {
        let vibes = EditVibe.all.filter { picked.contains($0.id) }
        let matches = EditFabric.matches(for: vibes)
        // No folio or title: the section opens on the question itself, over the vibes' glow.
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            question(vibes)
            chips
            answer(matches)
        }
        .padding(.vertical, R.spacingSpace8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Reaches into the page's own top and bottom margins and fades at both edges, so
            // the glow never starts on a hard line.
            if !reduceTransparency {
                VibeGlow(vibes: vibes)
                    .padding(.top, -EditLayout.pageTop)
                    .padding(.bottom, -EditLayout.sectionBottom)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15),
                                                 .init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: picked)
        .sensoryFeedback(.selection, trigger: picked)
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .modifier(OnScreen(visible: $onScreen))
        // While the section is on screen and untouched, ripple the hint every few seconds.
        .task(id: onScreen) {
            guard onScreen, !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(0.8))
            while !Task.isCancelled && !touched {
                hint += 1
                try? await Task.sleep(for: .seconds(4.5))
            }
        }
    }

    /// The section's heading: "I want to feel light, breathable & relaxed", each pick set in
    /// italic in its chip's colour as it's chosen.
    private func question(_ vibes: [EditVibe]) -> some View {
        VStack(alignment: .leading, spacing: -18) {
            // The folio, as on every section, fading out behind the heading.
            Text(String(format: "%02d", number))
                .font(EditType.display(48, bold: true))
                .tracking(0.37)
                .foregroundStyle(LinearGradient(stops: [.init(color: M.textWhite.opacity(0.9), location: 0), .init(color: M.textWhite.opacity(0), location: 0.85)],
                                                startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace8) {
            (Text("I want to feel ").foregroundStyle(M.textWhite)
             + Self.tinted(vibes).font(EditType.display(28, italic: true, relativeTo: .title)))
                .font(EditType.display(28, relativeTo: .title))
                .tracking(-0.84)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Text("\(picked.count)/\(Self.maxPicks)")
                .font(EditType.text(11, .medium, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(M.textTertiary)
                .contentTransition(.numericText())
                .accessibilityLabel("\(picked.count) of \(Self.maxPicks) picked")
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    /// Every vibe in view at once, wrapping onto a second line.
    private var chips: some View {
        EditFlowLayout(spacing: 6) {
            ForEach(Array(EditVibe.all.enumerated()), id: \.element.id) { i, vibe in
                chip(vibe)
                    // Picked pills already show they're tappable; only the rest shine.
                    .modifier(ChipHint(tick: hint, delay: Double(i) * 0.12, tint: Color(hex: vibe.tint), active: !picked.contains(vibe.id)))
            }
        }
        .padding(.horizontal, EditLayout.gutter)
    }

    private func chip(_ vibe: EditVibe) -> some View {
        let on = picked.contains(vibe.id)
        let tint = Color(hex: vibe.tint)
        return Button { toggle(vibe.id) } label: {
            HStack(spacing: 4) {
                // Each vibe's icon turns into a tick when picked, so the state never rests on
                // colour alone.
                Image(systemName: on ? "checkmark" : vibe.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 13)
                    .contentTransition(.symbolEffect(.replace))
                Text(vibe.label)
                    .font(EditType.text(13, on ? .semibold : .regular, relativeTo: .subheadline))
            }
            .foregroundStyle(on ? M.textWhite : M.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Capsule().fill(on ? tint.opacity(0.32) : M.surfaceTransparent))
            .overlay(Capsule().strokeBorder(on ? tint : M.borderModerate, lineWidth: on ? 1.5 : R.stroke1Px))
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(vibe.label)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    /// The answer, joined to the question by a hairline: what we'd reach for, then a pick for each.
    @ViewBuilder
    private func answer(_ matches: [(fabric: EditFabric, because: [EditVibe])]) -> some View {
        Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            .padding(.horizontal, R.spacingSpace16)
            .accessibilityHidden(true)
        if matches.isEmpty {
            Text("Pick a vibe or two and we'll take it from there.")
                .font(EditType.text(13, relativeTo: .subheadline))
                .foregroundStyle(M.textTertiary)
                .padding(.horizontal, R.spacingSpace16)
        } else {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("So we'd reach for")
                        .font(EditType.text(12, .medium, relativeTo: .caption))
                        .foregroundStyle(M.textTertiary)
                    Self.answerSentence(matches.prefix(3))
                        .font(EditType.display(18, relativeTo: .headline))
                        .tracking(-0.4)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityElement(children: .combine)

                ScrollView(.horizontal) {
                    HStack(spacing: R.spacingSpace8) {
                            ForEach(matches, id: \.fabric.id) { match in
                                let product = match.fabric.pick(gender)
                                Button { opened = product } label: {
                                    VibeMatchCard(fabric: match.fabric, product: product, because: match.because)
                                }
                                .buttonStyle(PressableStyle())
                                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                                .accessibilityLabel("\(match.fabric.name), because you picked \(Self.sentence(match.because.map { $0.label.lowercased() })): \(product.name), \(product.price)")
                                .accessibilityHint("Opens the product")
                            }
                    }
                }
                .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
                .scrollIndicators(.hidden)
                .genderReload(.row(VibeMatchCard.size))
            }
        }
    }

    /// "Linens, cotton staples & relaxed resort wear", each underlined in the colour of the vibe
    /// that led to it most.
    private static func answerSentence(_ matches: ArraySlice<(fabric: EditFabric, because: [EditVibe])>) -> Text {
        matches.enumerated().reduce(Text("")) { text, item in
            let (i, match) = item
            let separator = i == 0 ? "" : i == matches.count - 1 ? " & " : ", "
            let name = i == 0 ? match.fabric.name : match.fabric.name.lowercased()
            let tint = match.because.first.map { Color(hex: $0.tint) } ?? M.textWhite
            return text + Text(separator).foregroundStyle(M.textWhite)
                + Text(name).foregroundStyle(M.textWhite).underline(true, color: tint)
        }
    }

    /// Up to three picks; a fourth replaces the oldest.
    private func toggle(_ id: String) {
        touched = true
        if let i = picked.firstIndex(of: id) {
            picked.remove(at: i)
        } else {
            if picked.count >= Self.maxPicks { picked.removeFirst() }
            picked.append(id)
        }
    }

    /// "light, breathable & relaxed" with each word in its vibe's colour, so the heading reads
    /// back the chips.
    static func tinted(_ vibes: [EditVibe]) -> Text {
        let joint = M.textWhite.opacity(0.85)
        guard !vibes.isEmpty else { return Text("…").foregroundStyle(joint) }
        return vibes.enumerated().reduce(Text("")) { text, item in
            let (i, vibe) = item
            let separator = i == 0 ? "" : i == vibes.count - 1 ? " & " : ", "
            return text + Text(separator).foregroundStyle(joint) + Text(vibe.label.lowercased()).foregroundStyle(Color(hex: vibe.tint))
        }
    }

    /// "Linens, cotton staples & relaxed resort wear".
    static func sentence(_ names: [String]) -> String {
        let parts = names.enumerated().map { i, name in i == 0 ? name : name.lowercased() }
        guard parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " & " + parts[parts.count - 1]
    }
}

/// A pill's "tap me" hint: one after another, each unpicked pill's outline firms up into its
/// vibe's colour, as if being selected, holds for a beat and lets go.
private struct ChipHint: ViewModifier {
    let tick: Int
    let delay: Double
    let tint: Color
    let active: Bool
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(Capsule().strokeBorder(tint, lineWidth: 1.5))
                    .padding(.vertical, 6)
                    .opacity(lit ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onChange(of: tick) {
                guard active else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(.easeOut(duration: 0.3)) { lit = true }
                    try? await Task.sleep(for: .seconds(0.55))
                    withAnimation(.easeInOut(duration: 0.5)) { lit = false }
                }
            }
    }
}

/// Tracks whether at least half the view is on screen in its scroll view.
private struct OnScreen: ViewModifier {
    @Binding var visible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.5) { visible = $0 }
        } else {
            content.onAppear { visible = true }.onDisappear { visible = false }
        }
    }
}

/// One blurred blob per picked vibe, slowly orbiting its own spot across the panel.
private struct VibeGlow: View {
    let vibes: [EditVibe]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                let spots: [CGPoint] = [CGPoint(x: 0.15, y: 0.12), CGPoint(x: 0.85, y: 0.2), CGPoint(x: 0.5, y: 0.55)]
                ForEach(Array(vibes.enumerated()), id: \.element.id) { i, vibe in
                    let spot = spots[i % spots.count]
                    let phase = t / 4 + Double(i) * 2.1
                    Circle()
                        .fill(Color(hex: vibe.tint))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .opacity(0.3)
                        .position(x: spot.x * g.size.width + 28 * cos(phase), y: spot.y * g.size.height + 22 * sin(phase * 1.3))
                        .transition(.opacity)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One answer to the vibe: the pick's photo, sharp, with its name at the foot.
private struct VibeMatchCard: View {
    let fabric: EditFabric
    let product: Product
    let because: [EditVibe]

    static let size = CGSize(width: 140, height: 180)

    var body: some View {
        // A short, clear foot: no frost, so the photo stays sharp.
        VoguePhotoCard(art: product.art, width: Self.size.width, height: Self.size.height, scrimReach: 0.32, shade: 0.7, tint: 0.35, frosted: false) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(fabric.name)
                    .font(EditType.text(14, .semibold, relativeTo: .subheadline))
                    .tracking(-0.14)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
        }
    }
}


// MARK: - Swap this for that

/// Trade a piece for one that suits the weather now.
struct EditSwap: Identifiable {
    var id: String { into }
    let out: String
    let outImage: String
    let into: String
    let why: String
    let product: Product

    static func list(for gender: String) -> [EditSwap] { gender == "men" ? men : women }

    static let women: [EditSwap] = [
        EditSwap(out: "Chunky knits", outImage: "palette_sage-linen_2", into: "Sweater vests",
                 why: "All the knit, none of the noon sweat.",
                 product: EditorialData.rackEdit[0]),
        EditSwap(out: "Sweatshirts", outImage: "photo_rose_1", into: "Full-sleeve shirts",
                 why: "Sleeves down at 9, rolled up by lunch.",
                 product: piece("Crisp white poplin shirt", "Zara", "Shirts", "plan_office_2", [0xEDEDED, 0x3A5A7A], "₹2,990", seed: 1401)),
        EditSwap(out: "Skinny jeans", outImage: "rack_bonkers_jeans", into: "Wide-leg denim",
                 why: "Room to breathe, and it's what the street's wearing.",
                 product: piece("High-rise wide-leg jeans", "Blu", "Denim", "vogue_pair_jeans", [0x6A8CB8, 0xEDEDED], "₹2,999", seed: 1402)),
        EditSwap(out: "Heavy coats", outImage: "look_camel_coat", into: "Shackets",
                 why: "Wear it open over a tee till December.",
                 product: piece("Olive cotton shacket", "Zara", "Outerwear", "vogue_look_olive", [0x6A7A3A, 0x8FA6C2], "₹3,990", seed: 1403)),
    ]

    static let men: [EditSwap] = [
        EditSwap(out: "Hoodies", outImage: "palette_slate-noir_2", into: "Denim jackets",
                 why: "Throw it over a tee. It breathes, a hoodie doesn't.",
                 product: piece("Sherpa-lined denim jacket", "Blu", "Denim", "staple_denim_1", [0x3E5C7E, 0xA08850], "₹3,499", seed: 1411)),
        EditSwap(out: "Full suits", outImage: "staple_blazer_1", into: "A blazer over a tee",
                 why: "Half the layers, just as sharp.",
                 product: piece("Camel wool overcoat", "Zara", "Outerwear", "staple_blazer_3", [0xB07A4A, 0xE9E2D4], "₹6,490", seed: 1412)),
        EditSwap(out: "Plain tees", outImage: "staple_white_tee", into: "Printed shirts",
                 why: "Same ease, a lot more to say.",
                 product: piece("Printed camp-collar shirt", "Snitch", "Shirts", "palette_midnight-olive_5", [0x2A1E16, 0x6A4A30], "₹1,799", seed: 1413)),
    ]
}

/// "Swap this for that": each card sets the piece to retire (greyed, struck through) beside the
/// one to wear instead, with a swap mark on the seam and the reason underneath.
struct VogueSwapSection: View {
    let number: Int
    @AppStorage("edit.gender") private var gender = "women"
    @State private var opened: Product?
    @State private var visible: String?

    var body: some View {
        let swaps = EditSwap.list(for: gender)
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: number, title: Text("Swap this for that"),
                              dek: "It's still 30° at noon. Trade the heavy stuff for pieces that work right now.", rule: false)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: EditLayout.cardGap) {
                    ForEach(Array(swaps.enumerated()), id: \.element.id) { i, swap in
                        Button { opened = swap.product } label: { SwapCard(swap: swap) }
                            .buttonStyle(PressableStyle())
                            .slideIn(i)
                            .id(swap.id)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Swap \(swap.out.lowercased()) for \(swap.into.lowercased()). \(swap.why)")
                            .accessibilityHint("Opens \(swap.product.name)")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .id(gender)
            .genderReload(.row(CGSize(width: SwapCard.width, height: SwapCard.photoHeight)))
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: swaps.firstIndex { $0.id == visible } ?? 0, count: swaps.count)
        }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }
}

private struct SwapCard: View {
    let swap: EditSwap

    static let width: CGFloat = 300
    static let photoHeight: CGFloat = 300
    private static let outWidth: CGFloat = 112
    /// How far the seam leans either side of `outWidth`.
    private static let slant: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            // The old piece is cut away on a slant, so the two read as one move from out to in
            // without a button-like mark on the seam.
            ZStack(alignment: .leading) {
                half(Image(swap.product.art.image ?? swap.outImage), width: Self.width - Self.outWidth + Self.slant, label: swap.into, retired: false)
                    .padding(.leading, Self.outWidth - Self.slant)
                half(Image(swap.outImage), width: Self.outWidth + Self.slant, label: swap.out, retired: true)
                    .clipShape(SlantCut(slant: Self.slant * 2))
                    .overlay { SlantSeam(slant: Self.slant * 2).stroke(M.backgroundPrimary, lineWidth: 3) }
            }
            .frame(width: Self.width, height: Self.photoHeight, alignment: .leading)
            .clipped()
            .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }

            // Just the reason: the card itself opens the piece.
            Text(swap.why)
                .font(EditType.text(14, relativeTo: .subheadline))
                .lineSpacing(3)
                .foregroundStyle(M.textSecondary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .frame(width: Self.width, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// One side of the swap: the retired piece greyed with its name struck through, the new one
    /// in full colour.
    private func half(_ image: Image, width: CGFloat, label: String, retired: Bool) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: width, height: Self.photoHeight)
            .clipped()
            .grayscale(retired ? 1 : 0)
            .brightness(retired ? -0.12 : 0)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 110)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(retired ? "Out" : "In")
                        .font(EditType.text(11, .medium, relativeTo: .caption2))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(M.textWhite.opacity(0.7))
                    Text(label)
                        .font(EditType.text(retired ? 13 : 16, .semibold, relativeTo: .headline))
                        .strikethrough(retired, color: M.textWhite.opacity(0.8))
                        .foregroundStyle(retired ? M.textWhite.opacity(0.8) : M.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, retired ? R.spacingSpace12 : Self.slant + R.spacingSpace12)
                .padding(.trailing, retired ? Self.slant * 2 + R.spacingSpace4 : R.spacingSpace8)
                .padding(.bottom, R.spacingSpace12)
            }
    }
}

/// The retired half: full width at the top, `slant` narrower at the foot.
private struct SlantCut: Shape {
    let slant: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: rect.origin)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Just the slanted edge of `SlantCut`, drawn as a gap in the page colour.
private struct SlantSeam: Shape {
    let slant: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
        }
    }
}

// MARK: - Your next favourite label (brand discovery)

/// A homegrown label to try instead of one you already shop.
struct EditBrandPick: Identifiable {
    var id: String { brand }
    let brand: String
    let pitch: String
    /// Where the label is from, for the "Homegrown" badge.
    let origin: String
    let art: Art
    /// The brand's story, when the edit has one.
    var story: String? = nil
    let product: Product
}

/// "If you like X Y, you'll love …": a label you know and every homegrown one we'd send you to instead.
struct EditBrandSwap: Identifiable {
    var id: String { "\(familiar) \(category)" }
    let familiar: String
    let category: String
    let picks: [EditBrandPick]

    static func list(for gender: String) -> [EditBrandSwap] { gender == "men" ? men : women }

    private static let bombayShirts = "Made to your measurements, in a week"
    private static let gullyLabs = "Handmade in India, with a street twist"
    private static let neemans = "Everyday sneakers knit from merino"
    private static let nappaDori = "Leather that gets better every year"
    private static let souledStore = "Pop-culture prints, cut in India"
    private static let bewakoof = "Easy graphic tees that don't cost much"
    private static let andamen = "Long-staple cotton shirts, cut clean"

    static let women: [EditBrandSwap] = [
        EditBrandSwap(familiar: "Uniqlo", category: "shirts", picks: [
            EditBrandPick(brand: "Bombay Shirt Company", pitch: bombayShirts, origin: "Mumbai",
                          art: Art("plan_office_2", [0xEDEDED, 0x3A5A7A, 0xC9A27A], seed: 1501),
                          product: piece("Made-to-measure white oxford", "Bombay Shirt Company", "Shirts", "plan_office_2", [0xEDEDED, 0x3A5A7A], "₹2,690", seed: 1502)),
            EditBrandPick(brand: "Doodlage", pitch: "Made from factory offcuts, so no two match", origin: "Delhi",
                          art: Art("article_doodlage_3", [0xEDEDED, 0xD8B060, 0x6A8A5A], seed: 1521), story: "Doodlage",
                          product: piece("Embroidered upcycled shirt", "Doodlage", "Shirts", "article_doodlage_3", [0xEDEDED, 0xD8B060], "₹3,200", seed: 1522)),
            EditBrandPick(brand: "Andamen", pitch: andamen, origin: "Bengaluru",
                          art: Art("article_doodlage_2", [0xB8CCE0, 0x8A6A4A, 0xC8C0B0], seed: 1523),
                          product: piece("Chambray utility shirt", "Andamen", "Shirts", "article_doodlage_2", [0xB8CCE0, 0x8A6A4A], "₹3,490", seed: 1524)),
        ]),
        EditBrandSwap(familiar: "Nike", category: "sneakers", picks: [
            EditBrandPick(brand: "Gully Labs", pitch: gullyLabs, origin: "Delhi",
                          art: Art("article_gully_2", [0xF2B400, 0x7A1A22, 0xEDEDED], seed: 1503), story: "Gully Labs",
                          product: piece("Maroon suede low-tops", "Gully Labs", "Footwear", "article_gully_2", [0xF2B400, 0x7A1A22], "₹4,999", seed: 1504)),
            EditBrandPick(brand: "Neeman's", pitch: neemans, origin: "Hyderabad",
                          art: Art("palette_slate-noir_3", [0x2A2A2E, 0xEDEDED, 0x5A6A80], seed: 1525),
                          product: piece("White merino knit sneakers", "Neeman's", "Footwear", "palette_slate-noir_3", [0x2A2A2E, 0xEDEDED], "₹3,299", seed: 1526)),
        ]),
        EditBrandSwap(familiar: "Charles & Keith", category: "bags", picks: [
            EditBrandPick(brand: "Nappa Dori", pitch: nappaDori, origin: "Delhi",
                          art: Art("article_nappa_1", [0xEDE6E6, 0x8A4A30, 0x3A2A1A], seed: 1505), story: "Nappa Dori",
                          product: piece("Tan leather backpack", "Nappa Dori", "Bags", "article_nappa_1", [0xEDE6E6, 0x8A4A30], "₹9,500", seed: 1506)),
            EditBrandPick(brand: "Zouk", pitch: "Vegan bags in prints from Indian crafts", origin: "Mumbai",
                          art: Art("palette_rose-clay_2", [0x5A3A2A, 0xE8A0B8, 0xC8B8A8], seed: 1527),
                          product: piece("Pink crochet shoulder bag", "Zouk", "Bags", "palette_rose-clay_2", [0x5A3A2A, 0xE8A0B8], "₹1,890", seed: 1528)),
        ]),
        EditBrandSwap(familiar: "H&M", category: "graphic tees", picks: [
            EditBrandPick(brand: "The Souled Store", pitch: souledStore, origin: "Mumbai",
                          art: Art("rack_tss_tee", [0xE9E2D4, 0x2D4FA8, 0xEDEDED], seed: 1507),
                          product: EditorialData.products[7]),
            EditBrandPick(brand: "Bewakoof", pitch: bewakoof, origin: "Mumbai",
                          art: Art("staple_white_tee_1", [0xEDEDED, 0x1A1A1A, 0xD8D8D8], seed: 1529),
                          product: piece("Trail graphic tee", "Bewakoof", "Streetwear", "staple_white_tee_1", [0xEDEDED, 0x1A1A1A], "₹599", seed: 1530)),
        ]),
    ]

    static let men: [EditBrandSwap] = [
        EditBrandSwap(familiar: "Uniqlo", category: "shirts", picks: [
            EditBrandPick(brand: "Bombay Shirt Company", pitch: bombayShirts, origin: "Mumbai",
                          art: Art("palette_midnight-olive_5", [0x2A1E16, 0x6A4A30, 0x151515], seed: 1511),
                          product: piece("Made-to-measure printed shirt", "Bombay Shirt Company", "Shirts", "palette_midnight-olive_5", [0x2A1E16, 0x6A4A30], "₹2,890", seed: 1512)),
            EditBrandPick(brand: "Andamen", pitch: andamen, origin: "Bengaluru",
                          art: Art("article_doodlage_2", [0xB8CCE0, 0x8A6A4A, 0xC8C0B0], seed: 1531),
                          product: piece("Chambray utility shirt", "Andamen", "Shirts", "article_doodlage_2", [0xB8CCE0, 0x8A6A4A], "₹3,490", seed: 1532)),
            EditBrandPick(brand: "Snitch", pitch: "New drops every week, priced to try", origin: "Bengaluru",
                          art: Art("palette_midnight-olive_3", [0x8A5A40, 0x9AB0C8, 0xE0D0D8], seed: 1533),
                          product: piece("Sky-blue oxford shirt", "Snitch", "Shirts", "palette_midnight-olive_3", [0x8A5A40, 0x9AB0C8], "₹1,299", seed: 1534)),
        ]),
        EditBrandSwap(familiar: "Nike", category: "sneakers", picks: [
            EditBrandPick(brand: "Gully Labs", pitch: gullyLabs, origin: "Delhi",
                          art: Art("article_gully_1", [0xE0A23A, 0x8A5A3B, 0xEDEDED], seed: 1513), story: "Gully Labs",
                          product: piece("Tan leather court sneakers", "Gully Labs", "Footwear", "article_gully_1", [0xE0A23A, 0x8A5A3B], "₹5,499", seed: 1514)),
            EditBrandPick(brand: "Neeman's", pitch: neemans, origin: "Hyderabad",
                          art: Art("palette_slate-noir_3", [0x2A2A2E, 0xEDEDED, 0x5A6A80], seed: 1535),
                          product: piece("White merino knit sneakers", "Neeman's", "Footwear", "palette_slate-noir_3", [0x2A2A2E, 0xEDEDED], "₹3,299", seed: 1536)),
        ]),
        EditBrandSwap(familiar: "Clarks", category: "shoes", picks: [
            EditBrandPick(brand: "Nappa Dori", pitch: nappaDori, origin: "Delhi",
                          art: Art("article_nappa_2", [0xEDEDED, 0x8A4A20, 0x3A2A1A], seed: 1515), story: "Nappa Dori",
                          product: piece("Tan leather derbies", "Nappa Dori", "Footwear", "article_nappa_2", [0xEDEDED, 0x8A4A20], "₹7,900", seed: 1516)),
        ]),
        EditBrandSwap(familiar: "H&M", category: "tees", picks: [
            EditBrandPick(brand: "The Souled Store", pitch: souledStore, origin: "Mumbai",
                          art: Art("staple_white_tee_3", [0xEDEDED, 0xC8402F, 0x9A9A9A], seed: 1517),
                          product: piece("Boxy logo tee", "The Souled Store", "Streetwear", "staple_white_tee_3", [0xEDEDED, 0xC8402F], "₹899", seed: 1518)),
            EditBrandPick(brand: "Bewakoof", pitch: bewakoof, origin: "Mumbai",
                          art: Art("staple_white_tee_2", [0xEDEDED, 0x2A3A2A, 0x5A7A4A], seed: 1537),
                          product: piece("Heavyweight white tee", "Bewakoof", "Streetwear", "staple_white_tee_2", [0xEDEDED, 0x2A3A2A], "₹549", seed: 1538)),
        ]),
    ]
}

/// Homegrown labels for the brands you already shop, as one sentence: the heading asks "If you
/// like…", a chip names the brand you know ("Uniqlo shirts"), and the cards answer with every
/// label we'd send you to instead ("you'll love Bombay Shirt Company", "you'll love Doodlage"…).
/// Labels with a story open it; the rest open a piece.
struct VogueBrandSwapSection: View {
    let number: Int
    @AppStorage("edit.gender") private var gender = "women"
    @State private var chosen: String?
    @State private var opened: Product?
    @State private var reading: Story?
    @State private var visible: String?
    @Namespace private var rail
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let swaps = EditBrandSwap.list(for: gender)
        let swap = swaps.first { $0.id == chosen } ?? swaps[0]
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: number, title: Text("If you like…"), rule: false)
            VStack(alignment: .leading, spacing: R.spacingSpace20) {
                chips(swaps, current: swap)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: EditLayout.cardGap) {
                        ForEach(Array(swap.picks.enumerated()), id: \.element.id) { i, pick in
                            Button { open(pick) } label: { LoveTryCard(pick: pick) }
                                .buttonStyle(PressableStyle())
                                .slideIn(i)
                                .id(pick.id)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("If you like \(swap.familiar) \(swap.category), you'll love \(pick.brand). \(pick.pitch)")
                                .accessibilityHint(pick.story == nil ? "Opens a piece" : "Opens the story")
                        }
                    }
                    .scrollTargetLayout()
                }
                .carousel()
                // A fresh row per brand you know, so the cards slide in again and start at the first.
                .id("\(gender) \(swap.id)")
                .transition(.opacity)
                .genderReload(.row(LoveTryCard.size))
                .defaultScrollAnchor(.leading)
                .scrollPosition(id: $visible, anchor: .leading)
            }

            EditProgress(index: swap.picks.firstIndex { $0.id == visible } ?? 0, count: swap.picks.count)
        }
        .onChange(of: gender) { chosen = nil; visible = nil }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .readerCover(item: $reading) { StoryReaderView(story: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id ?? reading?.id)
        .sensoryFeedback(.selection, trigger: chosen)
    }

    /// The brands you already know, carrying on from the heading as a rail of big wordmarks: the
    /// picked one lit with its category in italic underneath, the rest ghosted, and an underline
    /// that slides to whichever you tap. One is always picked.
    private func chips(_ swaps: [EditBrandSwap], current: EditBrandSwap) -> some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: R.spacingSpace24) {
                    ForEach(swaps) { swap in
                        wordmark(swap, on: swap.id == current.id)
                            .id(swap.id)
                    }
                }
            }
            .contentMargins(.horizontal, EditLayout.gutter, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: current.id) { _, id in
                withAnimation(reduceMotion ? nil : .snappy) { reader.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func wordmark(_ swap: EditBrandSwap, on: Bool) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.2)) { chosen = swap.id; visible = nil }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 3) {
                    Text(swap.familiar)
                        .font(EditType.display(30, relativeTo: .title))
                        .tracking(-0.8)
                        .lineLimit(1)
                        .fixedSize()
                    // How many labels answer this one, as a superscript.
                    Text("\(swap.picks.count)")
                        .font(EditType.text(11, .semibold, relativeTo: .caption2))
                        .monospacedDigit()
                        .padding(.top, 5)
                }
                .foregroundStyle(on ? M.textPrimary : M.textWhite.opacity(0.22))

                Text("\(swap.category),")
                    .font(EditType.display(15, italic: true, relativeTo: .subheadline))
                    .foregroundStyle(on ? M.textSecondary : M.textWhite.opacity(0.22))

                // The underline slides between wordmarks.
                ZStack(alignment: .leading) {
                    Color.clear.frame(height: 2)
                    if on {
                        Capsule().fill(M.textPrimary)
                            .frame(width: 28, height: 2)
                            .matchedGeometryEffect(id: "brand.underline", in: rail)
                    }
                }
            }
            .scaleEffect(on ? 1 : 0.94, anchor: .bottomLeading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(swap.familiar) \(swap.category), \(swap.picks.count) \(swap.picks.count == 1 ? "label" : "labels")")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func open(_ pick: EditBrandPick) {
        if let brand = pick.story, let story = EditorialData.stories.first(where: { $0.brand == brand }) {
            reading = story
        } else {
            opened = pick.product
        }
    }
}

/// The answer on a photo of what the label makes: "you'll love", the label, its pitch, and where
/// it's from.
private struct LoveTryCard: View {
    let pick: EditBrandPick

    static let size = CGSize(width: 264, height: 340)

    var body: some View {
        ArtView(art: pick.art)
            .frame(width: Self.size.width, height: Self.size.height)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [.init(color: .black.opacity(0), location: 0), .init(color: .black.opacity(0.6), location: 0.45),
                                       .init(color: .black.opacity(0.85), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) { homegrown }
            .overlay(alignment: .bottomLeading) { answer }
            .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
            .contentShape(Rectangle())
    }

    /// "Homegrown · Mumbai", in glass on the photo's corner.
    private var homegrown: some View {
        HStack(spacing: R.spacingSpace4) {
            Image(systemName: "leaf.fill").font(.system(size: 10, weight: .semibold))
            Text("Homegrown · \(pick.origin)")
                .font(EditType.text(11, .medium, relativeTo: .caption2))
        }
        .foregroundStyle(M.textWhite)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .liquidGlass(in: Capsule(), clear: true)
        .padding(R.spacingSpace12)
        .accessibilityHidden(true)
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) {
            Text("you'll love")
                .font(EditType.text(13, relativeTo: .subheadline))
                .foregroundStyle(M.textWhite.opacity(0.75))
            Text(pick.brand)
                .font(EditType.display(24, relativeTo: .title3))
                .tracking(-0.5)
                .foregroundStyle(M.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(pick.pitch)
                .font(EditType.text(12, relativeTo: .caption))
                .foregroundStyle(M.textWhite.opacity(0.75))
                .lineLimit(1)
        }
        .padding(R.spacingSpace16)
    }
}


// MARK: - Same look, your price (find similar, with caveats)

/// How much you want to spend on a look.
enum EditTier: String, CaseIterable, Identifiable {
    case steal, smart, splurge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steal: "Steal"
        case .smart: "Smart buy"
        case .splurge: "Splurge"
        }
    }

    /// How many of the three ₹ marks light up.
    var level: Int {
        switch self {
        case .steal: 1
        case .smart: 2
        case .splurge: 3
        }
    }
}

/// A look you'd save (from street style or a creator) and its hero piece at three prices, each
/// with an honest note on how it differs from the original.
struct EditDupe: Identifiable {
    var id: String { title }
    let title: String
    /// Where the look was spotted.
    let source: String
    let art: Art
    /// The piece the tiers stand in for.
    let hero: String
    let picks: [Pick]

    struct Pick: Identifiable {
        var id: EditTier { tier }
        let tier: EditTier
        let product: Product
        /// What's different from the original, said plainly.
        let caveat: String
    }

    static func list(for gender: String) -> [EditDupe] { gender == "men" ? men : women }

    /// Cheapest first.
    var byPrice: [Pick] { picks.sorted { $0.tier.level < $1.tier.level } }
    var cheapest: Pick { byPrice[0] }

    private static func pick(_ tier: EditTier, _ name: String, _ brand: String, _ category: String, _ image: String,
                             _ hexes: [UInt32], _ price: String, _ caveat: String, seed: Int) -> Pick {
        Pick(tier: tier, product: piece(name, brand, category, image, hexes, price, seed: seed), caveat: caveat)
    }

    static let women: [EditDupe] = [
        EditDupe(title: "Copenhagen cool, Gurgaon price", source: "Street style · Copenhagen",
                 art: Art("vogue_look_navy", [0x1E2A45, 0xBDBDC2, 0x3A3A3A], seed: 1701), hero: "Navy wool overcoat", picks: [
                     pick(.splurge, "Double-faced wool coat", "Zara", "Outerwear", "vogue_look_navy", [0x1E2A45, 0xBDBDC2], "₹9,990",
                          "Closest match. 70% wool, not 100%.", seed: 1702),
                     pick(.smart, "Navy tailored coat", "H&M", "Outerwear", "vogue_look_navy", [0x1E2A45, 0xBDBDC2], "₹5,499",
                          "Same cut. Poly blend, so it drapes lighter.", seed: 1703),
                     pick(.steal, "Longline navy shacket", "Bonkers Corner", "Outerwear", "vogue_look_navy", [0x1E2A45, 0xBDBDC2], "₹1,899",
                          "A shacket, not a coat. Gets the shape, not the warmth.", seed: 1704),
                 ]),
        EditDupe(title: "Looks old money. Isn't.", source: "Saved from @mira.wears",
                 art: Art("vogue_look_ivory", [0xEDE6DA, 0x6A6A6A, 0x3A3A3A], seed: 1711), hero: "Ivory trouser suit", picks: [
                     pick(.splurge, "Linen-blend ivory suit", "Zara", "Tailoring", "vogue_look_ivory", [0xEDE6DA, 0x6A6A6A], "₹8,980",
                          "Closest cut. Linen blend, so it creases more.", seed: 1712),
                     pick(.smart, "Relaxed cream blazer & trousers", "H&M", "Tailoring", "vogue_look_ivory", [0xEDE6DA, 0x6A6A6A], "₹4,598",
                          "Boxier blazer; trousers sit a little higher.", seed: 1713),
                     pick(.steal, "Cream co-ord set", "Bonkers Corner", "Co-ords", "vogue_look_ivory", [0xEDE6DA, 0x6A6A6A], "₹2,199",
                          "A co-ord, not suiting. Softer shoulders.", seed: 1714),
                 ]),
        EditDupe(title: "Airport look, no paparazzi", source: "Street style · Paris",
                 art: Art("vogue_fit_active", [0x1A1A1A, 0x9A9A9A, 0xE9E9E9], seed: 1721), hero: "Zip top & wide joggers", picks: [
                     pick(.splurge, "Zip track top & wide pants", "adidas", "Activewear", "vogue_fit_active", [0x1A1A1A, 0x9A9A9A], "₹7,499",
                          "Closest fit. Small logo on the hip.", seed: 1722),
                     pick(.smart, "Fleece zip-up & wide joggers", "The Souled Store", "Activewear", "vogue_fit_active", [0x1A1A1A, 0x9A9A9A], "₹2,999",
                          "Cotton fleece, not scuba. A little heavier.", seed: 1723),
                     pick(.steal, "Half-zip & straight joggers", "H&M", "Activewear", "vogue_fit_active", [0x1A1A1A, 0x9A9A9A], "₹1,799",
                          "Half-zip, not full. Joggers taper at the ankle.", seed: 1724),
                 ]),
    ]

    static let men: [EditDupe] = [
        EditDupe(title: "Copenhagen cool, Gurgaon price", source: "Street style · Copenhagen",
                 art: Art("staple_denim_1", [0x3E5C7E, 0xA08850, 0xE9E9E9], seed: 1731), hero: "Tapered khaki chinos", picks: [
                     pick(.splurge, "Slim stretch chinos", "Zara", "Trousers", "staple_denim_1", [0xA08850, 0x3E5C7E], "₹3,990",
                          "Closest match. Stretch cotton, holds a crease.", seed: 1732),
                     pick(.smart, "Tapered cotton chinos", "H&M", "Trousers", "staple_denim_1", [0xA08850, 0x3E5C7E], "₹1,999",
                          "Same taper. Thinner twill.", seed: 1733),
                     pick(.steal, "Khaki everyday trousers", "Snitch", "Trousers", "staple_denim_1", [0xA08850, 0x3E5C7E], "₹1,199",
                          "Slightly looser leg, no cuff.", seed: 1734),
                 ]),
        EditDupe(title: "Looks old money. Isn't.", source: "Saved from @kabir.fits",
                 art: Art("staple_blazer_3", [0xB07A4A, 0xE9E2D4, 0xC9CCC4], seed: 1741), hero: "Camel overcoat", picks: [
                     pick(.splurge, "Camel wool overcoat", "Zara", "Outerwear", "staple_blazer_3", [0xB07A4A, 0xE9E2D4], "₹6,490",
                          "Closest match. Wool blend, not cashmere.", seed: 1742),
                     pick(.smart, "Single-breasted camel coat", "H&M", "Outerwear", "staple_blazer_3", [0xB07A4A, 0xE9E2D4], "₹3,999",
                          "Shorter, ends mid-thigh.", seed: 1743),
                     pick(.steal, "Camel unstructured blazer", "Snitch", "Tailoring", "staple_blazer_3", [0xB07A4A, 0xE9E2D4], "₹1,999",
                          "A blazer, not a coat. Same colour, same ease.", seed: 1744),
                 ]),
        EditDupe(title: "Airport look, no paparazzi", source: "Street style · Seoul",
                 art: Art("palette_slate-noir_2", [0x1A1A1A, 0xC9A27A, 0x6A6A6A], seed: 1751), hero: "Black sweatshirt & bucket hat", picks: [
                     pick(.splurge, "Heavyweight crew & cotton bucket hat", "adidas", "Streetwear", "palette_slate-noir_2", [0x1A1A1A, 0xC9A27A], "₹5,298",
                          "Closest match. Logo on the chest.", seed: 1752),
                     pick(.smart, "Graphic crew sweatshirt", "The Souled Store", "Streetwear", "palette_slate-noir_2", [0x1A1A1A, 0xC9A27A], "₹1,699",
                          "Different print. Hat sold separately.", seed: 1753),
                     pick(.steal, "Black crew sweatshirt", "H&M", "Streetwear", "palette_slate-noir_2", [0x1A1A1A, 0xC9A27A], "₹999",
                          "Plain, no print. Thinner fleece.", seed: 1754),
                 ]),
    ]
}

/// Find similar: looks people save from street style and creators, each with its hero piece at
/// three prices, cheapest first. Kept light: no budget switch and no tier names, just a ₹ scale,
/// the price and the label. Each card is one tap: it opens `DupeCompareSheet`, which has room for
/// the honest note on each pick and opens the piece you choose.
struct VogueBudgetSection: View {
    let number: Int
    @AppStorage("edit.gender") private var gender = "women"
    @State private var opened: Product?
    @State private var comparing: EditDupe?
    /// Chosen in the sheet; opened once the sheet has gone.
    @State private var chosen: Product?
    @State private var visible: String?

    var body: some View {
        let looks = EditDupe.list(for: gender)
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: number, title: Text("Same look, your price"),
                              dek: "The look you saved, at three prices.", rule: false)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: EditLayout.cardGap) {
                    ForEach(Array(looks.enumerated()), id: \.element.id) { i, look in
                        Button { comparing = look } label: { DupeCard(look: look) }
                            .buttonStyle(PressableStyle())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(look.title). \(look.hero), from \(look.cheapest.product.price)")
                            .accessibilityHint("Compares three ways to get it")
                            .slideIn(i)
                            .id(look.id)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .id(gender)
            .genderReload(.row(CGSize(width: DupeCard.width, height: DupeCard.photoHeight)))
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: looks.firstIndex { $0.id == visible } ?? 0, count: looks.count)
        }
        .sheet(item: $comparing, onDismiss: {
            opened = chosen
            chosen = nil
        }) { look in
            DupeCompareSheet(look: look) { product in
                chosen = product
                comparing = nil
            }
        }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: comparing?.id)
        #if DEBUG
        // `-openDupe` opens the first look's compare sheet.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-openDupe") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            comparing = EditDupe.list(for: gender).first
        }
        #endif
    }
}

/// One saved look: the photo with its line and where it was spotted, then a strip of three price
/// tiles, cheapest to dearest. The whole card is one button (see `VogueBudgetSection`).
private struct DupeCard: View {
    let look: EditDupe

    static let width: CGFloat = 318
    static let photoHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VoguePhotoCard(art: look.art, width: Self.width, height: Self.photoHeight, scrimReach: 0.45, shade: 0.8, tint: 0.5, frosted: false) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(look.title)
                        .font(EditType.display(22, relativeTo: .title3))
                        .tracking(-0.5)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(look.hero)
                        .font(EditType.text(12, relativeTo: .caption))
                        .foregroundStyle(M.textWhite.opacity(0.75))
                }
                .padding(R.spacingSpace16)
            }
            .overlay(alignment: .topLeading) {
                Text(look.source)
                    .font(EditType.text(11, .medium, relativeTo: .caption2))
                    .foregroundStyle(M.textWhite)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .background(Capsule().fill(.black.opacity(0.3)))
                    .padding(R.spacingSpace12)
            }

            HStack(spacing: 0) {
                ForEach(Array(look.byPrice.enumerated()), id: \.element.id) { i, pick in
                    if i > 0 {
                        Rectangle().fill(M.borderSubtle).frame(width: R.stroke1Px).padding(.vertical, R.spacingSpace12)
                    }
                    tile(pick)
                }
            }
            .background(M.surfaceTransparent)
        }
        .frame(width: Self.width)
        .overlay { Rectangle().strokeBorder(M.borderModerate, lineWidth: R.stroke1Px) }
        .contentShape(Rectangle())
    }

    /// ₹ scale, price, label.
    private func tile(_ pick: EditDupe.Pick) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) {
            RupeeScale(level: pick.tier.level)
            Text(pick.product.price)
                .font(EditType.text(15, .semibold, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(M.textWhite)
            Text(pick.product.brand)
                .font(EditType.text(11, relativeTo: .caption2))
                .foregroundStyle(M.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, R.spacingSpace12)
    }
}

/// Three rupee marks with the tier's share lit, the rest faded: ₹ ₹ ₹ reads as a scale at a glance.
private struct RupeeScale: View {
    let level: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...3, id: \.self) { i in
                Text("₹").foregroundStyle(i <= level ? M.textWhite : M.textWhite.opacity(0.2))
            }
        }
        .font(EditType.text(12, .semibold, relativeTo: .caption))
        .accessibilityHidden(true)
    }
}


/// "3 ways to get it": the look's three picks, cheapest first, each with its ₹ scale, price,
/// piece and the honest note on how it differs from the original. Tapping one opens that piece.
private struct DupeCompareSheet: View {
    let look: EditDupe
    let choose: (Product) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("3 ways to get it")
                    .font(EditType.text(12, .medium, relativeTo: .caption))
                    .foregroundStyle(M.textTertiary)
                Text(look.hero)
                    .font(EditType.display(24, relativeTo: .title2))
                    .tracking(-0.5)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                ForEach(Array(look.byPrice.enumerated()), id: \.element.id) { i, pick in
                    if i > 0 { EditRule() }
                    Button { choose(pick.product) } label: { row(pick) }
                        .buttonStyle(PressableStyle())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(pick.product.name) by \(pick.product.brand), \(pick.product.price). \(pick.caveat)")
                        .accessibilityHint("Opens the product")
                }
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(440), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(M.surfacePrimary)
        .environment(\.colorScheme, .dark)
    }

    private func row(_ pick: EditDupe.Pick) -> some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            ArtView(art: pick.product.art)
                .frame(width: 56, height: 72)
                .clipped()
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: R.spacingSpace8) {
                    Text(pick.product.price)
                        .font(EditType.text(15, .semibold, relativeTo: .subheadline))
                        .monospacedDigit()
                        .foregroundStyle(M.textWhite)
                    RupeeScale(level: pick.tier.level)
                }
                Text("\(pick.product.brand) · \(pick.product.name)")
                    .font(EditType.text(12, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                Text(pick.caveat)
                    .font(EditType.text(12, relativeTo: .caption))
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(M.textTertiary)
                .frame(height: 72)
        }
        .padding(.vertical, R.spacingSpace12)
        .contentShape(Rectangle())
    }
}


// MARK: - Straight off the feed (creator posts)

/// A creator's post, a still or a reel, with the pieces they tagged.
struct EditPost: Identifiable {
    var id: String { "\(handle)-\(art.image ?? "")" }
    let handle: String
    let art: Art
    let isReel: Bool
    /// A bundled clip for reels that have one; reels without play the still with a slow push-in.
    var video: String? = nil
    let caption: String
    let likes: String
    let pieces: [Product]

    static func list(for gender: String) -> [EditPost] { gender == "men" ? men : women }

    static let women: [EditPost] = [
        EditPost(handle: "mira.wears", art: Art("vogue_look_ivory", [0xEDE6DA, 0x6A6A6A, 0x3A3A3A], seed: 1601), isReel: true,
                 caption: "All-ivory for a Monday, because why not. Blazer's on repeat all month.", likes: "12.4k",
                 pieces: [piece("Ivory relaxed blazer", "Zara", "Tailoring", "vogue_look_ivory", [0xEDE6DA, 0x6A6A6A], "₹5,490", seed: 1602),
                          piece("Wide-leg cream trousers", "H&M", "Trousers", "vogue_fit_brunch", [0xE9E2D4, 0xB8AE9C], "₹2,299", seed: 1603)]),
        EditPost(handle: "ananya.in.layers", art: Art("vogue_pair_leathers_look_2", [0x6A8CC8, 0x3A2A21, 0xEDEDED], seed: 1604), isReel: false,
                 caption: "Leather mini, chambray shirt, blue boots. Three pieces, zero thinking.", likes: "8,902",
                 pieces: [piece("Leather corset mini dress", "Snitch", "Dresses", "vogue_pair_leathers_look_2", [0x3A2A21, 0x6A8CC8], "₹3,999", seed: 1605),
                          piece("Oversized chambray shirt", "Blu", "Shirts", "palette_butter-denim_4", [0x5D7FA6, 0xD8CFC2], "₹1,899", seed: 1606)]),
        EditPost(handle: "brunchwithtara", art: Art("plan_brunch_2", [0xE5AC48, 0x8FA6C2, 0xEDE6DA], seed: 1607), isReel: true,
                 caption: "Golden hour, mustard tee, denim jacket off the shoulder. Brunch uniform.", likes: "21.7k",
                 pieces: [piece("Mustard cotton tee", "H&M", "Basics", "plan_brunch_2", [0xE5AC48, 0xEDE6DA], "₹699", seed: 1608),
                          piece("Washed denim jacket", "Blu", "Denim", "staple_denim_2", [0x8FA6C2, 0xF2C9D0], "₹2,999", seed: 1609)]),
        EditPost(handle: "kavyaonthego", art: Art("rack_blu_trucker", [0x6A8CB8, 0xF2C9D0, 0x1A1A1A], seed: 1610), isReel: false,
                 caption: "Denim on denim never left. Trucker jacket from a store two lanes down.", likes: "5,310",
                 pieces: [piece("Classic trucker jacket", "Blu", "Denim", "rack_blu_trucker", [0x6A8CB8, 0xF2C9D0], "₹2,799", seed: 1611)]),
    ]

    static let men: [EditPost] = [
        EditPost(handle: "galli.diaries", art: Art("story_galli", [0x1E1A14, 0x6B4A2A, 0xC9A46A], seed: 1621), isReel: true, video: "galli_story",
                 caption: "Tweed, a satchel and a rickshaw ride through the old lanes.", likes: "18.2k",
                 pieces: [piece("Herringbone tweed jacket", "Galli", "Outerwear", "story_galli", [0x6B4A2A, 0xC9A46A], "₹6,800", seed: 1622)]),
        EditPost(handle: "kabir.fits", art: Art("staple_blazer_3", [0xB07A4A, 0xE9E2D4, 0xC9CCC4], seed: 1623), isReel: false,
                 caption: "Camel coat, white tee, grey denim. The only formula I need this season.", likes: "9,846",
                 pieces: [piece("Camel wool overcoat", "Zara", "Outerwear", "staple_blazer_3", [0xB07A4A, 0xE9E2D4], "₹6,490", seed: 1624),
                          piece("Heavyweight white tee", "H&M", "Basics", "staple_white_tee", [0xEDEDED, 0x6A5A4A], "₹999", seed: 1625)]),
        EditPost(handle: "arjun.offduty", art: Art("palette_midnight-olive_3", [0x7A4A34, 0x8FB0D0, 0x1E2A45], seed: 1626), isReel: true,
                 caption: "A tie under a biker. Trust me on this one.", likes: "14.1k",
                 pieces: [piece("Tan leather biker jacket", "Snitch", "Outerwear", "palette_midnight-olive_3", [0x7A4A34, 0x8FB0D0], "₹5,499", seed: 1627)]),
        EditPost(handle: "neel.in.print", art: Art("palette_midnight-olive_5", [0x2A1E16, 0x6A4A30, 0x151515], seed: 1628), isReel: false,
                 caption: "Prints for the weekend. Sleeves stay short till it drops below 25.", likes: "6,477",
                 pieces: [piece("Printed camp-collar shirt", "Snitch", "Shirts", "palette_midnight-olive_5", [0x2A1E16, 0x6A4A30], "₹1,799", seed: 1629)]),
    ]
}

/// Creators' posts, stills and reels, laid out like the feed they came from. Each card shows the
/// handle, what kind of post it is, its likes and how many pieces are tagged; tapping opens a
/// full-screen, Reels-style pager on that post, and you swipe up through the rest.
struct VogueCreatorsSection: View {
    let number: Int
    @AppStorage("edit.gender") private var gender = "women"
    @State private var opened: Opened?
    @State private var visible: String?
    @Namespace private var zoom

    struct Opened: Identifiable {
        let start: Int
        let posts: [EditPost]
        var id: String { posts[start].id }
    }

    var body: some View {
        let posts = EditPost.list(for: gender)
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(number: number, title: Text("Straight off the feed"),
                              dek: "Reels and posts from creators we love, and every piece they're wearing.", rule: false)
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { i, post in
                        Button { opened = Opened(start: i, posts: posts) } label: { CreatorPostCard(post: post) }
                            .buttonStyle(PressableStyle())
                            .slideIn(i)
                            .zoomSource(id: post.id, in: zoom)
                            .id(post.id)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(post.isReel ? "Reel" : "Post") by \(post.handle), \(post.likes) likes. \(post.caption)")
                            .accessibilityHint("Opens the post and its \(post.pieces.count) tagged pieces")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .id(gender)
            .genderReload(.row(CreatorPostCard.size))
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: posts.firstIndex { $0.id == visible } ?? 0, count: posts.count)
        }
        .readerCover(item: $opened) { item in
            CreatorReelPager(posts: item.posts, start: item.start).zoomTransition(id: item.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
        #if DEBUG
        // Debug builds accept `-openReel <n>` to open the pager on that post.
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-openReel"), i + 1 < args.count, let n = Int(args[i + 1]) {
                try? await Task.sleep(for: .seconds(3))
                let posts = EditPost.list(for: gender)
                opened = Opened(start: min(max(n, 0), posts.count - 1), posts: posts)
            }
        }
        #endif
    }
}

/// The creator's round avatar (a crop of the post itself for now) in a gradient ring.
private struct CreatorAvatar: View {
    let art: Art
    var size: CGFloat = 26

    var body: some View {
        ArtView(art: art)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .padding(2)
            .background(Circle().fill(M.backgroundPrimary))
            .padding(1.5)
            .background(Circle().fill(AngularGradient(colors: [Color(hex: 0xF9CE34), Color(hex: 0xEE2A7B), Color(hex: 0x6228D7), Color(hex: 0xF9CE34)],
                                                      center: .center)))
            .accessibilityHidden(true)
    }
}

private struct CreatorPostCard: View {
    let post: EditPost

    static let size = CGSize(width: 210, height: 373)

    var body: some View {
        VoguePhotoCard(art: post.art, width: Self.size.width, height: Self.size.height, scrimReach: 0.45, shade: 0.75, tint: 0.6,
                       frosted: false, video: post.video) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                // Likes first, as a feed shows them, then the caption.
                HStack(spacing: R.spacingSpace4) {
                    Image(systemName: "heart.fill").font(.system(size: 10))
                    Text("\(post.likes) likes")
                }
                .font(EditType.text(11, .semibold, relativeTo: .caption2))
                .foregroundStyle(M.textWhite)
                Text(post.caption)
                    .font(EditType.text(12, relativeTo: .caption))
                    .lineSpacing(2)
                    .foregroundStyle(M.textWhite.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(R.spacingSpace12)
        }
        .overlay(alignment: .top) {
            HStack(spacing: R.spacingSpace8) {
                CreatorAvatar(art: post.art)
                Text(post.handle)
                    .font(EditType.text(12, .semibold, relativeTo: .caption))
                    .foregroundStyle(M.textWhite)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                Spacer(minLength: 0)
                // Reel or still, so the two formats read apart at a glance.
                Image(systemName: post.isReel ? "play.fill" : "square.on.square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(M.textWhite)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.black.opacity(0.4)))
            }
            .padding(10)
            .background(LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom).allowsHitTesting(false))
        }
    }
}

/// Creators' posts full screen, paged vertically like Reels: each page fills exactly one screen
/// (the photo or clip edge to edge, with the handle, likes, caption and tagged pieces laid over
/// its foot), and you swipe up for the next post, down for the one before.
private struct CreatorReelPager: View {
    let posts: [EditPost]
    private let start: Int
    @State private var page: Int?
    @State private var opened: Product?
    /// True while a swipe is under way: every page shrinks to a rounded card with its neighbours
    /// peeking, then the one you land on grows back to fill the screen.
    @State private var carded = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardScale: CGFloat = 0.8
    private static let cardRadius: CGFloat = 32
    private static let cardGap: CGFloat = 14
    private var cardScale: CGFloat { carded ? Self.cardScale : 1 }

    init(posts: [EditPost], start: Int) {
        self.posts = posts
        self.start = min(max(start, 0), posts.count - 1)
        _page = State(initialValue: self.start)
    }

    private var current: Int { min(max(page ?? start, 0), posts.count - 1) }

    var body: some View {
        GeometryReader { geo in
            let full = CGSize(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            ScrollViewReader { reader in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { i, post in
                            let card = cardScale
                            CreatorReelPage(post: post, size: full, insets: geo.safeAreaInsets, active: i == current,
                                            isLast: i == posts.count - 1, carded: carded, open: { opened = $0 })
                                .frame(width: full.width, height: full.height)
                                .clipShape(RoundedRectangle(cornerRadius: carded ? Self.cardRadius : 0, style: .continuous))
                                .visualEffect { content, proxy in
                                    // How many pages this one sits from the screen: 0 on it, ±1 for the neighbours.
                                    let h = max(proxy.size.height, 1)
                                    let d = proxy.frame(in: .scrollView).minY / h
                                    return content
                                        .scaleEffect(card)
                                        // Pull the neighbours in so they peek a sliver above and below.
                                        .offset(y: -d * (h * (1 - card) - (card < 1 ? Self.cardGap : 0)))
                                        // A slight lean while moving, so the cards feel like they stretch as they pass.
                                        .rotation3DEffect(.degrees(card < 1 ? Double(max(-1, min(1, d))) * -10 : 0),
                                                          axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                                }
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $page)
                .scrollIndicators(.hidden)
                .modifier(ReelScrollPhase { moving in
                    guard !reduceMotion else { return }
                    withAnimation(moving ? .spring(duration: 0.35, bounce: 0.1) : .spring(duration: 0.5, bounce: 0.18)) { carded = moving }
                })
                .ignoresSafeArea()
                .onAppear { reader.scrollTo(start) }
            }
            .overlay(alignment: .topLeading) {
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                    .padding(.leading, R.spacingSpace16)
                    .padding(.top, R.spacingSpace12)
            }
            .overlay(alignment: .trailing) { pageMarks.padding(.trailing, 6).opacity(carded ? 0 : 1) }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: page)
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityScrollAction { edge in
            // VoiceOver three-finger swipes move between posts.
            let next = edge == .bottom ? current - 1 : current + 1
            if posts.indices.contains(next) { withAnimation(reduceMotion ? nil : .snappy) { page = next } }
        }
    }

    /// One mark per post on the right edge, so the pager reads as a stack.
    private var pageMarks: some View {
        VStack(spacing: 5) {
            ForEach(posts.indices, id: \.self) { i in
                Capsule()
                    .fill(M.textWhite.opacity(i == current ? 1 : 0.35))
                    .frame(width: 3, height: i == current ? 22 : 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }
}

/// Tells the pager when a swipe starts and when it has settled (iOS 18+; earlier systems keep the
/// plain full-screen paging).
private struct ReelScrollPhase: ViewModifier {
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in onChange(phase != .idle) }
        } else {
            content
        }
    }
}

/// One post of the pager, sized to the screen. Reels play their clip (or push slowly into the
/// still) and run a progress bar along the top while they're the page on screen.
private struct CreatorReelPage: View {
    let post: EditPost
    let size: CGSize
    let insets: EdgeInsets
    let active: Bool
    let isLast: Bool
    /// The pager is mid-swipe and showing this page as a card.
    var carded = false
    let open: (Product) -> Void
    @State private var progress: CGFloat = 0
    @State private var pushed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let reelLength: Double = 8

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
            Color.clear
                .frame(width: size.width, height: size.height)
                .overlay {
                    ArtView(art: post.art)
                        .scaleEffect(post.isReel && post.video == nil && pushed ? 1.08 : 1)
                }
                .overlay {
                    if let video = post.video, active, !reduceMotion { LoopingVideo(name: video) }
                }
                .clipped()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).frame(height: insets.top + 120)
                Spacer(minLength: 0)
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.6), location: 0.35),
                                       .init(color: .black.opacity(0.9), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.5)
            }
            .allowsHitTesting(false)

            footer
                .opacity(carded ? 0 : 1)
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .top) {
            if post.isReel {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(M.textWhite.opacity(0.3))
                        Capsule().fill(M.textWhite).frame(width: g.size.width * (reduceMotion ? 1 : progress))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, insets.top + 2)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: active, initial: true) { _, isActive in play(isActive) }
    }

    private func play(_ isActive: Bool) {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0; pushed = false }
        guard isActive, post.isReel, !reduceMotion else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.linear(duration: Self.reelLength).repeatForever(autoreverses: false)) { progress = 1 }
            withAnimation(.easeInOut(duration: Self.reelLength).repeatForever(autoreverses: true)) { pushed = true }
        }
    }

    /// Handle, likes, caption and the tagged pieces, laid over the foot of the photo.
    private var footer: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace8) {
                CreatorAvatar(art: post.art, size: 30)
                Text(post.handle)
                    .font(EditType.text(14, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(M.textWhite)
                Text(post.isReel ? "Reel" : "Post")
                    .font(EditType.text(11, .medium, relativeTo: .caption2))
                    .foregroundStyle(M.textWhite.opacity(0.7))
                    .padding(.horizontal, R.spacingSpace8)
                    .frame(height: 20)
                    .overlay(Capsule().strokeBorder(M.textWhite.opacity(0.35), lineWidth: R.stroke1Px))
            }
            .padding(.horizontal, EditLayout.gutter)

            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                HStack(spacing: R.spacingSpace4) {
                    Image(systemName: "heart.fill").font(.system(size: 11))
                    Text("\(post.likes) likes")
                }
                .font(EditType.text(12, .semibold, relativeTo: .caption))
                .foregroundStyle(M.textWhite)
                Text(post.caption)
                    .font(EditType.text(14, relativeTo: .subheadline))
                    .lineSpacing(3)
                    .foregroundStyle(M.textWhite.opacity(0.9))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, EditLayout.gutter)
            .padding(.trailing, R.spacingSpace24)

            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(post.pieces) { product in
                        Button { open(product) } label: { pieceChip(product) }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("\(product.name) by \(product.brand), \(product.price)")
                            .accessibilityHint("Opens the product")
                    }
                }
            }
            .contentMargins(.horizontal, EditLayout.gutter, for: .scrollContent)
            .scrollIndicators(.hidden)

            if !isLast {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold))
                    Text("Swipe up for the next post")
                }
                .font(EditType.text(11, .medium, relativeTo: .caption2))
                .foregroundStyle(M.textWhite.opacity(0.6))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
        .padding(.bottom, insets.bottom + R.spacingSpace12)
    }

    private func pieceChip(_ product: Product) -> some View {
        HStack(spacing: R.spacingSpace8) {
            ArtView(art: product.art)
                .frame(width: 44, height: 56)
                .clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(EditType.text(12, .semibold, relativeTo: .caption))
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text("\(product.brand) · \(product.price)")
                    .font(EditType.text(11, relativeTo: .caption2))
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 170, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(M.textTertiary)
        }
        .padding(6)
        .padding(.trailing, 4)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}


#Preview {
    ScrollView {
        VStack(spacing: 64) {
            VogueVibeSection(number: 3)
            VogueSwapSection(number: 5)
            VogueCreatorsSection(number: 7)
            VogueBrandSwapSection(number: 9)
        }
    }
    .background(BackstageTokens.Mapped.backgroundPrimary)
    .preferredColorScheme(.dark)
}
