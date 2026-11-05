import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive
private typealias P = DropPalette
private typealias V = VoucherPalette

// MARK: - Voucher sheet

/// Shared ids for the details ↔ outlets morph.
private enum Morph {
    static let logo = "logo"
    static let card = "card"
    static let panel = "panel"
    static let title = "title"
    static func row(_ outlet: VoucherOutlet) -> String { "row-" + outlet.id }
}

/// One spring for every part of the morph, so the sheet, cards and rows land together.
private let morphSpring = Animation.spring(response: 0.52, dampingFraction: 0.86)

/// The voucher sheet (Figma 3713:9087). "View all" doesn't push a new screen: the sheet grows to full
/// height while the same pieces move into place. The voucher card folds into a ticket, the logo goes
/// to the top bar, and the outlets card opens into the full list (Figma 3713:9396), with each preview
/// row turning into its outlet card. Back reverses it. Nothing stacks and the sheet never closes.
struct VoucherSheet: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    let voucher: GiftVoucher

    @Namespace private var ns
    @State private var expanded = false
    @State private var fitHeight: CGFloat = 600
    @State private var detent: PresentationDetent = .height(600)

    private var fitted: PresentationDetent { .height(fitHeight) }

    var body: some View {
        ZStack(alignment: .top) {
            if expanded {
                VoucherOutletsPane(voucher: voucher, ns: ns, back: { setExpanded(false) })
                    .transition(.asymmetric(insertion: .opacity.animation(morphSpring.delay(0.04)), removal: .opacity))
            } else {
                VoucherDetailsPane(voucher: voucher, ns: ns, viewOutlets: { setExpanded(true) }) { height in
                    let h = min(height, 760)
                    guard abs(h - fitHeight) > 1 else { return }
                    let wasFitted = detent == fitted
                    fitHeight = h
                    if !expanded && wasFitted { detent = fitted }
                }
                .transition(.opacity)
            }
        }
        .presentationDetents([fitted, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(R.cornerRadiusCorner32)
        .presentationBackground(P.ink)
        .sensoryFeedback(.impact(weight: .light), trigger: expanded)
        .onAppear {
            if wallet.sheetOpensOutlets {
                expanded = true
                detent = .large
            }
        }
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(morphSpring) {
            expanded = value
            detent = value ? .large : fitted
        }
    }
}

// MARK: - Details

/// The sheet's first screen: brand header, voucher card (code once bought), outlets card, terms.
struct VoucherDetailsPane: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    let voucher: GiftVoucher
    let ns: Namespace.ID
    var viewOutlets: () -> Void
    var onHeight: (CGFloat) -> Void

    @State private var termsExpanded = false
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    private var owned: Bool { wallet.owns(voucher) }

    var body: some View {
        ScrollView {
            VStack(spacing: R.spacingSpace20) {
                VoucherSheetHeader(voucher: voucher, ns: ns)
                VStack(spacing: R.spacingSpace12) {
                    card
                    if owned { VoucherCodeBlock(voucher: voucher).transition(.scale(scale: 0.96).combined(with: .opacity)) }
                    VoucherRedeemCard(voucher: voucher, ns: ns, viewAll: viewOutlets)
                    VoucherSheetSteps(voucher: voucher, owned: owned)
                }
                .padding(.horizontal, R.spacingSpace16)
                terms.padding(.horizontal, R.spacingSpace16)
            }
            .padding(.bottom, R.spacingSpace8)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                contentHeight = $0
                onHeight(contentHeight + footerHeight)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(P.ink)
        .animation(.snappy, value: owned)
    }

    // MARK: Card (Figma card 27; the logo moved up into the header)

    private var card: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gift voucher")
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                    Text("Worth \(rupees(voucher.worth)) on your bill")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    VoucherTicker(voucher: voucher, owned: owned)
                    VoucherPriceRow(voucher: voucher)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VoucherBurst(percent: voucher.percentOff, scale: 1.1)
                .padding(.top, R.spacingSpace4)
        }
        .padding(R.spacingSpace12)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(M.backgroundSecondary)
                .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.95))
                .matchedGeometryEffect(id: Morph.card, in: ns)
        }
    }

    // MARK: Terms

    private var terms: some View {
        VStack(spacing: R.spacingSpace12) {
            VoucherSectionLabel(title: "Terms & conditions")
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                ForEach(VoucherData.terms.prefix(termsExpanded ? VoucherData.terms.count : 3), id: \.self) { term in
                    HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace8) {
                        Text("•")
                        Text(term).fixedSize(horizontal: false, vertical: true)
                    }
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.snappy) { termsExpanded.toggle() }
            } label: {
                HStack(spacing: R.spacingSpace4) {
                    Text(termsExpanded ? "View less" : "View more")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(termsExpanded ? 180 : 0))
                }
            }
            .buttonStyle(BackstageTextButtonStyle())
        }
    }

    // MARK: Footer (Figma "Bottom Sheet -> Footer")

    private var footer: some View {
        Group {
            if owned {
                Button { wallet.sheet = nil } label: { Text("Done").frame(maxWidth: .infinity) }
                    .buttonStyle(BackstagePrimaryButtonStyle())
            } else {
                Button { wallet.buy(voucher) } label: {
                    HStack(spacing: R.spacingSpace4) {
                        Text("Proceed · \(rupees(voucher.price))")
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BackstagePrimaryButtonStyle())
            }
        }
        .sensoryFeedback(.success, trigger: owned)
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace12)
        .padding(.bottom, R.spacingSpace8)
        .background(P.ink)
        .overlay(alignment: .top) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
            footerHeight = $0
            onHeight(contentHeight + footerHeight)
        }
    }
}

// MARK: - Redeem card

/// Where the voucher works, at a glance: count and open-now summary, the nearest outlets as a short
/// route, and one way into the full list. Each row is the seed of its outlet card in the list.
struct VoucherRedeemCard: View {
    let voucher: GiftVoucher
    let ns: Namespace.ID
    var viewAll: () -> Void

    private var nearest: [VoucherOutlet] { voucher.outlets.sorted { $0.km < $1.km } }
    private var preview: [VoucherOutlet] { Array(nearest.prefix(2)) }
    private var openCount: Int { voucher.outlets.filter(\.isOpen).count }

    var body: some View {
        Button(action: viewAll) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                header
                VStack(spacing: R.spacingSpace8) {
                    ForEach(Array(preview.enumerated()), id: \.element.id) { i, outlet in
                        row(outlet, index: i)
                    }
                }
                viewAllRow
            }
            .padding(R.spacingSpace12)
            .background {
                RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous)
                    .fill(M.backgroundSecondary)
                    .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                    .matchedGeometryEffect(id: Morph.panel, in: ns)
            }
            .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Redeem at \(voucher.outlets.count) outlets, \(openCount) open now, nearest \(nearest.first?.distance ?? "")")
        .accessibilityHint("Shows all outlets with search and directions")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Redeem at \(voucher.outlets.count) outlets")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .matchedGeometryEffect(id: Morph.title, in: ns)
                HStack(spacing: 6) {
                    Circle().fill(V.accent).frame(width: 6, height: 6)
                    Text("\(openCount) open now")
                    Circle().fill(M.iconTertiary).frame(width: 3, height: 3)
                    Text("nearest \(nearest.first?.distance ?? "")")
                }
                .backstageText(.label3)
                .foregroundStyle(M.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "map.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(V.accent)
                .frame(width: 40, height: 40)
                .background(V.accentStrong.opacity(0.16), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    /// A numbered stop: pin, name, open state (and any extra offer), distance.
    private func row(_ outlet: VoucherOutlet, index: Int) -> some View {
        HStack(spacing: R.spacingSpace12) {
            Text("\(index + 1)")
                .dropFont("Bold", 12, relativeTo: .caption)
                .foregroundStyle(outlet.isOpen ? P.ink : M.textSecondary)
                .frame(width: 24, height: 24)
                .background(outlet.isOpen ? V.accentFill : M.surfaceSecondary, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(outlet.name)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(outlet.status)
                        .foregroundStyle(outlet.isOpen ? M.textSecondary : M.textTertiary)
                    if let offer = outlet.offer {
                        HStack(spacing: 3) {
                            Image(systemName: "tag.fill").font(.system(size: 9))
                            Text(offer)
                        }
                        .foregroundStyle(M.textOffer)
                    }
                }
                .backstageText(.label3)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(outlet.distance)
                .backstageText(.label2)
                .foregroundStyle(M.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                .fill(M.surfacePrimary)
                .matchedGeometryEffect(id: Morph.row(outlet), in: ns)
        }
    }

    private var viewAllRow: some View {
        HStack(spacing: R.spacingSpace4) {
            Text(voucher.outlets.count > preview.count
                 ? "View all \(voucher.outlets.count) outlets"
                 : "Search, filter & get directions")
            Spacer(minLength: 0)
            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
        }
        .backstageText(.button3)
        .foregroundStyle(V.accent)
        .padding(.horizontal, R.spacingSpace4)
        .frame(minHeight: 32)
    }
}

// MARK: - How it works

/// "How it works" for this voucher: a lit blue panel with three steps on a rail, written with the
/// voucher's own price, outlets and worth. Step one ticks off once the voucher is bought.
struct VoucherSheetSteps: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    let voucher: GiftVoucher
    let owned: Bool

    private struct Step: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var done = false
        var id: String { title }
    }

    private var steps: [Step] {
        let nearest = voucher.outlets.min { $0.km < $1.km }
        return [
            Step(icon: "creditcard.fill",
                 title: owned ? "Voucher bought" : "Buy it here for \(rupees(voucher.price))",
                 detail: owned ? "It's saved in your vouchers" : "It's yours instantly, no waiting",
                 done: owned),
            Step(icon: "figure.walk",
                 title: "Visit any of the \(voucher.outlets.count) outlets",
                 detail: nearest.map { "Nearest is \($0.name.components(separatedBy: ",").first ?? $0.name), \($0.distance)" } ?? ""),
            Step(icon: "ticket.fill",
                 title: owned ? "Show \(wallet.code(for: voucher)) at billing" : "Show your code at billing",
                 detail: "\(rupees(voucher.worth)) comes straight off your bill"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            kicker
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                    row(step, index: i, last: i == steps.count - 1)
                }
            }
        }
        .padding(R.spacingSpace16)
        .background {
            let shape = RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous)
            ZStack(alignment: .topTrailing) {
                shape.fill(LinearGradient(colors: [V.deep, Color(rgba: 0x0B2F6BFF)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RadialGradient(colors: [V.accentStrong.opacity(0.45), .clear], center: .topTrailing, startRadius: 0, endRadius: 220)
                    .clipShape(shape)
                shape.strokeBorder(LinearGradient(colors: [V.accent.opacity(0.55), V.accentStrong.opacity(0.15)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
        }
        .animation(.snappy, value: owned)
    }

    private var kicker: some View {
        HStack(spacing: 10) {
            bolt("gv_bolt_left")
            Text("How it works")
                .dropFont("SemiBold", 12, relativeTo: .subheadline)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(LinearGradient(colors: [V.accent, V.accentPale], startPoint: .leading, endPoint: .trailing))
                .accessibilityAddTraits(.isHeader)
            bolt("gv_bolt_right")
            Spacer(minLength: 0)
            Text("3 easy steps")
                .backstageText(.label3)
                .foregroundStyle(V.accentFill.opacity(0.8))
        }
    }

    private func row(_ step: Step, index: Int, last: Bool) -> some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(step.done ? V.accent : V.accentFill)
                        .shadow(color: V.accentStrong.opacity(0.6), radius: 8)
                    Image(systemName: step.done ? "checkmark" : step.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(P.ink)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 36, height: 36)
                if !last {
                    Rectangle()
                        .fill(LinearGradient(colors: [V.accentFill.opacity(0.7), V.accentStrong.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2)
                        .frame(minHeight: 18, maxHeight: .infinity)
                        .padding(.vertical, R.spacingSpace4)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP \(index + 1)")
                    .dropFont("SemiBold", 10, relativeTo: .caption2)
                    .tracking(1)
                    .foregroundStyle(V.accent)
                Text(step.title)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.detail)
                    .backstageText(.body3)
                    .foregroundStyle(V.accentPale.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, last ? 0 : R.spacingSpace16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func bolt(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .frame(width: 47.8, height: 51.6)
            .frame(width: 7.8, height: 11.6)
            .dealTint()
            .accessibilityHidden(true)
    }
}

extension VoucherOutlet {
    /// "Open · till 10:30 PM" or "Closed · opens 11:00 AM".
    var status: String {
        let parts = hours.components(separatedBy: " to ")
        return isOpen ? "Open · till \(parts.last ?? hours)" : "Closed · opens \(parts.first ?? hours)"
    }
}

// MARK: - Header

/// Brand-led sheet header, driven entirely by the voucher: the brand's colour lights a glow over the
/// deals wash and cloud, behind a large logo tile with a tinted ring, then the name and a meta line.
struct VoucherSheetHeader: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    let voucher: GiftVoucher
    let ns: Namespace.ID

    var body: some View {
        VStack(spacing: R.spacingSpace12) {
            kicker
            VoucherMorphLogo(voucher: voucher, ns: ns, side: 84, radius: 24, ring: 3)
                .shadow(color: voucher.tint.opacity(0.55), radius: 22, y: 6)
                .padding(.top, R.spacingSpace4)
            VStack(spacing: R.spacingSpace4) {
                Text(voucher.brand)
                    .dropFont("SemiBold", 22, relativeTo: .title2)
                    .tracking(-0.22)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: R.spacingSpace8) {
                    Text(voucher.category.replacingOccurrences(of: " | ", with: " · "))
                    Circle().fill(M.iconTertiary).frame(width: 3, height: 3)
                    Text("\(voucher.outlets.count) outlets near you")
                }
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .padding(.bottom, R.spacingSpace4)
        .background(alignment: .top) { glow }
        .overlay(alignment: .topTrailing) {
            SheetCircleButton(systemName: "xmark", label: "Close") { wallet.sheet = nil }
                .padding(.top, R.spacingSpace20)
                .padding(.trailing, R.spacingSpace20)
        }
    }

    /// "GIFT VOUCHER DEAL" between the deals' lightning marks.
    private var kicker: some View {
        HStack(spacing: 10) {
            bolt("gv_bolt_left")
            Text("Gift voucher deal")
                .dropFont("SemiBold", 11, relativeTo: .caption)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(V.accentFill)
            bolt("gv_bolt_right")
        }
    }

    private func bolt(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .frame(width: 47.8, height: 51.6)
            .frame(width: 7.8, height: 11.6)
            .dealTint()
            .accessibilityHidden(true)
    }

    private var glow: some View {
        ZStack(alignment: .top) {
            V.heroWash
                .opacity(0.45)
                .frame(height: 300)
            Image("gv_sheet_cloud")
                .resizable()
                .frame(width: 387, height: 119)
                .dealTint()
                .opacity(0.7)
                .padding(.top, 70)
            RadialGradient(colors: [voucher.tint.opacity(0.55), voucher.tint.opacity(0.12), .clear],
                           center: .init(x: 0.5, y: 0.42), startRadius: 0, endRadius: 190)
                .frame(height: 300)
            LinearGradient(colors: [.clear, P.ink], startPoint: .center, endPoint: .bottom)
                .frame(height: 300)
        }
        .frame(height: 300)
        .clipped()
        .padding(.top, -60)
        .accessibilityHidden(true)
    }
}

/// The brand logo on its tinted ring, sized by its frame so it can fly between the header and the
/// outlets bar.
private struct VoucherMorphLogo: View {
    let voucher: GiftVoucher
    let ns: Namespace.ID
    var side: CGFloat
    var radius: CGFloat
    var ring: CGFloat

    var body: some View {
        ZStack {
            Color.white
            Image(voucher.logo.asset)
                .resizable()
                .aspectRatio(contentMode: voucher.logo.fills ? .fill : .fit)
                .padding(voucher.logo.fills ? 0 : side * 0.06)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .padding(ring)
        .background(voucher.tint.opacity(0.9), in: RoundedRectangle(cornerRadius: radius + ring, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius + ring, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .matchedGeometryEffect(id: Morph.logo, in: ns)
        .frame(width: side + ring * 2, height: side + ring * 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Code block

/// A purchased voucher's counter code, shown in place (text only, no QR).
struct VoucherCodeBlock: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    let voucher: GiftVoucher
    @State private var copied = false

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show this code at the counter")
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
                Text(wallet.code(for: voucher))
                    .dropFont("Bold", 22, relativeTo: .title2)
                    .tracking(1.5)
                    .foregroundStyle(M.textPrimary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIPasteboard.general.string = wallet.code(for: voucher)
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(BackstageTextButtonStyle())
            .sensoryFeedback(.success, trigger: copied)
        }
        .padding(R.spacingSpace16)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous)
            .strokeBorder(V.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}

// MARK: - Eligible outlets (Figma 3713:9396, morphed from the details)

/// Every outlet that takes the voucher. It keeps the voucher in view: the brand sits in the top bar
/// and the voucher card has folded into a ticket. Below, the outlets card has opened into the list
/// with search, filters, a nearest marker and directions, and the price and Proceed stay in reach.
struct VoucherOutletsPane: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    let voucher: GiftVoucher
    let ns: Namespace.ID
    var back: () -> Void

    @State private var query = ""
    @State private var filter: OutletFilter?

    private var owned: Bool { wallet.owns(voucher) }

    enum OutletFilter: String, CaseIterable, Identifiable {
        case open = "Open now", near = "Within 5 km", offers = "Extra offers"
        var id: String { rawValue }

        func keeps(_ outlet: VoucherOutlet) -> Bool {
            switch self {
            case .open: outlet.isOpen
            case .near: outlet.km <= 5
            case .offers: outlet.offer != nil
            }
        }
    }

    private var sorted: [VoucherOutlet] { voucher.outlets.sorted { $0.km < $1.km } }
    private var outlets: [VoucherOutlet] {
        sorted
            .filter { filter?.keeps($0) ?? true }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                ticket
                panel
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace4)
            .padding(.bottom, R.spacingSpace24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { dock }
        .background(brandGlow.ignoresSafeArea())
        // Swipe from the left edge to go back, like a pushed page.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { g in
                    if g.startLocation.x < 32, g.translation.width > 80, abs(g.translation.height) < 80 { back() }
                }
        )
    }

    // MARK: Top bar: back, the brand (the header's logo lands here), close

    private var topBar: some View {
        HStack(spacing: R.spacingSpace12) {
            SheetCircleButton(systemName: "chevron.left", label: "Back to voucher", action: back)
            VoucherMorphLogo(voucher: voucher, ns: ns, side: 34, radius: 10, ring: 2)
            VStack(alignment: .leading, spacing: 0) {
                Text(voucher.brand)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text("Eligible outlets")
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SheetCircleButton(systemName: "xmark", label: "Close") { wallet.sheet = nil }
        }
        .padding(.horizontal, R.spacingSpace20)
        .padding(.top, R.spacingSpace24)
        .padding(.bottom, R.spacingSpace12)
        // The same glow as the page behind, cut to the bar, so it reads as one wash at rest and
        // still covers the list when it scrolls under.
        .background { brandGlow.ignoresSafeArea(edges: .top).clipped() }
    }

    private var brandGlow: some View {
        // An overlay, so the gradient's height never sizes the bar it sits behind.
        P.ink.overlay(alignment: .top) {
            RadialGradient(colors: [voucher.tint.opacity(0.26), voucher.tint.opacity(0.06), .clear],
                           center: .init(x: 0.18, y: 0), startRadius: 0, endRadius: 320)
                .frame(height: 360)
        }
    }

    // MARK: Ticket: the voucher card, folded

    private var ticket: some View {
        HStack(spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: 2) {
                if owned {
                    Text("Voucher ready · \(wallet.code(for: voucher))")
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                    Text("Worth \(rupees(voucher.worth)) at any outlet below")
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                } else {
                    Text("Gift voucher worth \(rupees(voucher.worth))")
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                    HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace4) {
                        Text("Pay \(rupees(voucher.price))").foregroundStyle(V.accent)
                        Text(rupees(voucher.worth)).strikethrough().foregroundStyle(V.strike)
                            .accessibilityLabel("instead of \(rupees(voucher.worth))")
                    }
                    .backstageText(.label2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            perforation
            Text("\(voucher.percentOff)%\nOFF")
                .dropFont("Bold", 15, relativeTo: .headline)
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .foregroundStyle(V.accentFill)
                .frame(width: 52)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace12)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(M.backgroundSecondary)
                .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.95))
                .matchedGeometryEffect(id: Morph.card, in: ns)
        }
        .accessibilityElement(children: .combine)
    }

    /// Dashed tear line between the voucher and its discount.
    private var perforation: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(M.borderModerate)
            .frame(width: 1, height: 36)
            .accessibilityHidden(true)
    }

    // MARK: Panel: the outlets card, opened

    private var panel: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Redeem at \(voucher.outlets.count) outlets")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .matchedGeometryEffect(id: Morph.title, in: ns)
                Text("\(voucher.outlets.filter(\.isOpen).count) open now · sorted by distance")
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
            }
            search
            chips
            VStack(spacing: R.spacingSpace8) {
                if outlets.isEmpty {
                    Text("No outlets match. Try another area or clear the filter.")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ForEach(outlets) { outlet in
                        VoucherOutletCard(outlet: outlet, nearest: outlet.id == sorted.first?.id, ns: ns)
                    }
                }
            }
            .animation(.snappy, value: outlets)
        }
        .padding(R.spacingSpace12)
        .background {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous)
                .fill(M.backgroundSecondary)
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                .matchedGeometryEffect(id: Morph.panel, in: ns)
        }
    }

    private var search: some View {
        HStack(spacing: R.spacingSpace8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(M.iconSecondary)
            TextField("", text: $query, prompt: Text("Search for address").foregroundStyle(M.textTertiary))
                .backstageText(.label1)
                .foregroundStyle(M.textPrimary)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(M.iconTertiary).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, R.spacingSpace8)
        .frame(height: 44)
        .background(M.surfacePrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                ForEach(OutletFilter.allCases) { f in
                    DropChip(title: f.rawValue, selected: filter == f, removable: true) {
                        withAnimation(.snappy) { filter = filter == f ? nil : f }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .padding(.vertical, -R.spacingSpace8)
    }

    private var dock: some View {
        DropCTADock(radius: 28) {
            HStack(spacing: R.spacingSpace12) {
                VStack(alignment: .leading, spacing: 2) {
                    if owned {
                        Text("Voucher ready").backstageText(.title4).foregroundStyle(M.textPrimary)
                        Text("Show it at any outlet above").backstageText(.label3).foregroundStyle(M.textSecondary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace4) {
                            Text(rupees(voucher.price)).backstageText(.title3).foregroundStyle(M.textPrimary)
                            Text(rupees(voucher.worth)).dropFont("Medium", 12).strikethrough().foregroundStyle(V.strike)
                                .accessibilityLabel("worth \(rupees(voucher.worth))")
                        }
                        Text("You save \(rupees(voucher.worth - voucher.price))")
                            .backstageText(.label3)
                            .foregroundStyle(V.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    // Buying here folds back to the details, where the new code appears.
                    if !owned { wallet.buy(voucher) }
                    back()
                } label: {
                    HStack(spacing: R.spacingSpace4) {
                        Text(owned ? "Show voucher" : "Proceed")
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .lineLimit(1)
                    .fixedSize()
                }
                .buttonStyle(BackstagePrimaryButtonStyle())
                .sensoryFeedback(.success, trigger: owned)
            }
        }
    }
}

// MARK: - Outlet card

/// Figma outlet row: name, distance and an "Open • hours" pill, or an extra offer line, plus directions.
struct VoucherOutletCard: View {
    let outlet: VoucherOutlet
    var nearest = false
    /// When set, the card grows out of its preview row on the details screen.
    var ns: Namespace.ID?

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                if nearest {
                    Text("Nearest")
                        .dropFont("SemiBold", 10, relativeTo: .caption2)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(P.ink)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(V.accentFill, in: Capsule())
                }
                Text(outlet.name)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(outlet.distance)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                HStack(spacing: R.spacingSpace8) {
                    Text(outlet.status)
                        .lineLimit(1)
                        .dropFont("SemiBold", 11, relativeTo: .caption)
                        .tracking(-0.11)
                        .foregroundStyle(outlet.isOpen ? M.textPrimary : M.textSecondary)
                        .padding(.horizontal, 6)
                        .frame(height: 23)
                        .background(V.outletPill, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                    if let offer = outlet.offer {
                        HStack(spacing: R.spacingSpace4) {
                            Image(systemName: "tag.fill").font(.system(size: 11))
                            Text(offer).backstageText(.label2)
                        }
                        .foregroundStyle(M.textOffer)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Link(destination: URL(string: "maps://?q=\(outlet.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 44, height: 44)
                    .background(M.surfaceSecondary, in: Circle())
            }
            .accessibilityLabel("Directions to \(outlet.name)")
        }
        .padding(R.spacingSpace16)
        .background { background }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var background: some View {
        let shape = RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous)
        let card = shape.fill(M.surfacePrimary).overlay(shape.strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        if let ns {
            card.matchedGeometryEffect(id: Morph.row(outlet), in: ns)
        } else {
            card
        }
    }
}
