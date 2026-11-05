import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive
private typealias P = DropPalette

/// The cart's explainer sheets.
enum DropCartSheet: String, Identifiable {
    case reserve, nonRefundable, itemTotal, savings
    var id: String { rawValue }
}

// MARK: - Sheet container

/// Bottom sheet that hugs its content: optional symbol badge, title, subtitle and close control,
/// scrolling body, and a pinned action area. Grows to the large detent only when the content needs it.
struct DropInfoSheet<Content: View, Actions: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String?
    var symbol: String?
    var tint: Color
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions
    @State private var contentHeight: CGFloat = 360
    @State private var actionsHeight: CGFloat = 88

    init(title: String, subtitle: String? = nil, symbol: String? = nil, tint: Color = M.textOffer,
         @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                header
                content
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace24)
            .padding(.bottom, R.spacingSpace8)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: R.spacingSpace4) { actions }
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace12)
                .padding(.bottom, R.spacingSpace8)
                .background(M.backgroundPrimary)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionsHeight = $0 }
        }
        .presentationDetents([.height(contentHeight + actionsHeight + R.spacingSpace16), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(R.cornerRadiusCorner24)
        .presentationBackground(M.backgroundPrimary)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.16), in: Circle())
                        .overlay(Circle().strokeBorder(tint.opacity(0.24), lineWidth: R.stroke1Px))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(title)
                        .dropFont("SemiBold", 18, relativeTo: .title3)
                        .foregroundStyle(M.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .backstageText(.body3)
                            .foregroundStyle(M.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SheetCircleButton(systemName: "xmark", label: "Close") { dismiss() }
        }
    }
}

/// Full-width primary action for a sheet.
private struct SheetPrimary: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity) }
            .buttonStyle(BackstagePrimaryButtonStyle())
    }
}

/// Grouped surface used inside sheets.
private struct SheetCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) { content }
            .padding(R.spacingSpace16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(P.card, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }
}

// MARK: - Split bar

/// "Now / at pick-up" split: a 25% green segment against the offer-tinted remainder, with amounts.
struct DropPaymentSplit: View {
    let now: Int
    let later: Int
    var large = false

    private var share: CGFloat { now + later > 0 ? CGFloat(now) / CGFloat(now + later) : 0.25 }

    var body: some View {
        VStack(spacing: large ? R.spacingSpace12 : R.spacingSpace8) {
            GeometryReader { g in
                HStack(spacing: 3) {
                    Capsule().fill(P.success).frame(width: max(g.size.width * share - 1.5, 8))
                    Capsule().fill(M.textOffer.opacity(0.32))
                }
            }
            .frame(height: large ? 8 : 6)
            .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                amount("Pay now", now, P.success, alignment: .leading)
                Spacer()
                amount("At pick-up", later, M.textOffer, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func amount(_ label: String, _ value: Int, _ color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .backstageText(.label3)
                .foregroundStyle(M.textTertiary)
            Text(rupees(value))
                .backstageText(large ? .title2 : .title4)
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Reserve

/// Cart banner for reserve-only drops: today's 25% against the balance at pick-up, and a way into the explainer.
struct DropReserveBanner: View {
    @Environment(DropFlow.self) private var flow
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                HStack(spacing: R.spacingSpace12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(M.textOffer)
                        .frame(width: 32, height: 32)
                        .background(M.surfaceOfferSecondary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pay 25% now to reserve")
                            .backstageText(.title4)
                            .foregroundStyle(P.reserveText)
                        Text("Pay the rest when you collect")
                            .backstageText(.body3)
                            .foregroundStyle(P.white70)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 2) {
                        Text("How it works")
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .backstageText(.button3)
                    .foregroundStyle(M.textPrimary)
                }
                DropPaymentSplit(now: flow.reserveNow, later: flow.reserveLater)
            }
            .padding(R.spacingSpace16)
            .background(alignment: .topTrailing) {
                Image("pd_reserve_glow")
                    .resizable()
                    .frame(width: 160, height: 160)
                    .blendMode(.plusLighter)
                    .offset(x: 70, y: -50)
                    .accessibilityHidden(true)
            }
            .background(LinearGradient(colors: [M.brandPurple900, P.ink], startPoint: .topTrailing, endPoint: .bottomLeading))
            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(P.reserveEdge, lineWidth: R.stroke1Px))
            .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Explains how reserving works")
    }
}

/// "How reserving works": the split, a three-step timeline and the non-refundable note.
struct DropReserveSheet: View {
    @Environment(DropFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    /// From the PDP, before a store or slot is chosen: quote this product's price instead of the cart.
    var preview: DropProduct?
    var learnMore: () -> Void

    private var total: Int { preview?.price ?? flow.total }
    private var now: Int { preview.map { (Double($0.price) * 0.25).rounded() }.map { Int($0) } ?? flow.reserveNow }
    private var later: Int { total - now }
    private var storeText: String {
        guard preview == nil, let store = flow.store else { return "Your pick is held for you at the store you choose." }
        return "Your pick is held for you at \(store.name), \(store.area.components(separatedBy: ", ").last?.capitalized ?? "")."
    }
    private var slotText: String { preview == nil ? "On \(flow.slotLabel), share" : "In your pick-up slot, share" }

    var body: some View {
        DropInfoSheet(title: "Reserve now, pay at pick-up",
                      subtitle: "Lock in your pick with 25% today. Pay the rest at the store when you collect.",
                      symbol: "lock.fill") {
            SheetCard {
                DropPaymentSplit(now: now, later: later, large: true)
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                HStack {
                    Text(preview == nil ? "Order total" : "Price").backstageText(.label2).foregroundStyle(M.textSecondary)
                    Spacer()
                    Text(rupees(total)).backstageText(.title4).foregroundStyle(M.textPrimary)
                }
            }
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                Text("How it works")
                    .dropSectionLabel()
                    .foregroundStyle(M.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 0) {
                    TimelineStep(index: 1, title: "Pay \(rupees(now)) today", detail: storeText)
                    TimelineStep(index: 2, title: "Pay \(rupees(later)) at the store",
                                 detail: "\(slotText) your reservation ID at the counter and check the fit. Pay by UPI, card or cash.")
                    TimelineStep(index: 3, title: "Get your pickup code and collect",
                                 detail: "Your pickup code unlocks once the balance is paid. You can also pay it early in the app.", last: true)
                }
            }
            Button(action: learnMore) {
                HStack(alignment: .top, spacing: R.spacingSpace12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(P.warning)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The 25% is non-refundable")
                            .backstageText(.title4)
                            .foregroundStyle(M.textPrimary)
                        Text("If you cancel or miss your slot, it isn't refunded.")
                            .backstageText(.body3)
                            .foregroundStyle(M.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Learn more")
                        .backstageText(.button3)
                        .underline()
                        .foregroundStyle(M.textPrimary)
                        .padding(.top, 2)
                }
                .padding(R.spacingSpace12)
                .background(P.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous).strokeBorder(P.warning.opacity(0.24), lineWidth: R.stroke1Px))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the refund policy")
        } actions: {
            SheetPrimary(title: "Got it") { dismiss() }
        }
    }
}

private struct TimelineStep: View {
    let index: Int
    let title: String
    let detail: String
    var last = false

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(spacing: 0) {
                Text("\(index)")
                    .backstageText(.button3)
                    .foregroundStyle(M.textInverse)
                    .frame(width: 24, height: 24)
                    .background(M.surfaceInverse, in: Circle())
                if !last {
                    Rectangle().fill(M.borderIntense).frame(width: R.stroke1Px).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(title)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                Text(detail)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
            .padding(.bottom, last ? 0 : R.spacingSpace20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index). \(title). \(detail)")
    }
}

// MARK: - Non-refundable

/// Why the reservation can't be refunded, and what is still protected.
struct DropNonRefundableSheet: View {
    @Environment(DropFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    /// The reservation amount when opened from the PDP; otherwise the cart's.
    var reserveAmount: Int?

    var body: some View {
        DropInfoSheet(title: "This purchase is non-refundable",
                      subtitle: "Drop pieces are limited, so your pick is taken off the shelf just for you.",
                      symbol: "exclamationmark.shield.fill", tint: P.warning) {
            SheetCard {
                PolicyRow(symbol: "xmark.circle.fill", tint: P.warning, title: "No refund if you cancel",
                          detail: reserveAmount == nil && flow.plan == .full
                            ? "The \(rupees(flow.payNow)) you pay isn't refunded if you cancel or miss your pick-up slot."
                            : "The \(rupees(reserveAmount ?? flow.reserveNow)) reservation amount isn't refunded if you cancel or miss your pick-up slot.")
                PolicyRow(symbol: "calendar.badge.clock", tint: M.textOffer, title: "Plans changed?",
                          detail: "Reschedule your pick-up slot once, up to 24 hours before it starts.")
                PolicyRow(symbol: "checkmark.seal.fill", tint: P.success, title: "You're still covered",
                          detail: "If the store can't hand over your pick or it's faulty, you get a full refund.")
                PolicyRow(symbol: "shoeprints.fill", tint: M.iconSecondary, title: "Check the fit in store",
                          detail: "Size exchanges at pick-up depend on what the store has in stock.")
            }
        } actions: {
            SheetPrimary(title: "I understand") { dismiss() }
            Button {} label: { Text("Read terms and conditions").frame(maxWidth: .infinity) }
                .buttonStyle(BackstageTextButtonStyle())
        }
    }
}

private struct PolicyRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).backstageText(.title4).foregroundStyle(M.textPrimary)
                Text(detail)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Item total

/// "Item total" as a centred pop-up: MRP of each item before discounts, a hop to the savings
/// breakdown and an OK button, with the close control floating outside the card, below it.
struct DropItemTotalPopup: View {
    @Environment(DropFlow.self) private var flow
    var close: () -> Void
    var showSavings: () -> Void

    private var count: Int { flow.cart.reduce(0) { $0 + $1.quantity } }

    var body: some View {
        ZStack {
            M.proposedOverlayScrim.opacity(0.64)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityHidden(true)
            VStack(spacing: R.spacingSpace20) {
                card
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 48, height: 48)
                        .background(M.surfaceSecondary, in: Circle())
                        .overlay(Circle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, R.spacingSpace24)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("Item total")
                    .dropFont("SemiBold", 18, relativeTo: .title3)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("\(count) \(count == 1 ? "item" : "items") at MRP, before discounts")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
            }
            ScrollView {
                VStack(spacing: R.spacingSpace12) {
                    ForEach(flow.cart) { item in
                        HStack(spacing: R.spacingSpace12) {
                            Image(item.image)
                                .resizable()
                                .scaledToFit()
                                .padding(5)
                                .frame(width: 44, height: 44)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.product.name).backstageText(.label2).foregroundStyle(M.textPrimary)
                                Text("\(item.colour) • UK \(item.size)")
                                    .backstageText(.label3)
                                    .foregroundStyle(M.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(rupees(item.product.mrp * item.quantity)).backstageText(.title4).foregroundStyle(M.textPrimary)
                                Text("\(rupees(item.product.mrp)) × \(item.quantity)")
                                    .backstageText(.label3)
                                    .foregroundStyle(M.textTertiary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 220)
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            HStack {
                Text("Item total").backstageText(.title4).foregroundStyle(M.textPrimary)
                Spacer()
                Text(rupees(flow.itemTotal)).backstageText(.title3).foregroundStyle(M.textPrimary)
            }
            Button(action: showSavings) {
                HStack(spacing: R.spacingSpace8) {
                    Image(systemName: "tag.fill").font(.system(size: 11)).foregroundStyle(M.textOffer)
                    Text("You save \(rupees(flow.savings)), so you pay \(rupees(flow.total))")
                        .backstageText(.label2)
                        .foregroundStyle(M.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(M.iconTertiary)
                }
                .padding(R.spacingSpace12)
                .background(M.surfaceOfferSecondary.opacity(0.5), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your savings")
            Button(action: close) { Text("OK").frame(maxWidth: .infinity) }
                .buttonStyle(BackstageSecondaryButtonStyle())
                .padding(.top, R.spacingSpace4)
        }
        .padding(R.spacingSpace20)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .elevation(.floating)
    }
}

/// Every discount on the order; the coupon can be applied right here.
struct DropSavingsSheet: View {
    @Environment(DropFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DropInfoSheet(title: "Your savings", subtitle: "Discounts applied to this order", symbol: "tag.fill") {
            SheetCard {
                ForEach(flow.cart) { item in
                    row("Drop price • \(item.product.name)", detail: "\(item.colour), size \(item.size)",
                        value: rupees(-(item.product.mrp - item.product.price) * item.quantity))
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flat ₹500 OFF").backstageText(.label2).foregroundStyle(M.textPrimary)
                        Text("Coupon on full payment").backstageText(.label3).foregroundStyle(M.textTertiary)
                    }
                    Spacer()
                    Button(flow.couponApplied ? "Remove" : "Apply") {
                        withAnimation(.snappy) { flow.couponApplied.toggle() }
                    }
                    .buttonStyle(BackstageFilterButtonStyle(isActive: !flow.couponApplied))
                    .padding(.vertical, -R.spacingSpace8)
                }
                if flow.couponApplied {
                    row("Coupon discount", detail: nil, value: rupees(-flow.coupon))
                        .transition(.opacity)
                }
                row("Convenience fee", detail: "Waived on drops", value: "Free")
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                HStack {
                    Text("Total savings").backstageText(.title4).foregroundStyle(P.success)
                    Spacer()
                    Text(rupees(flow.savings))
                        .backstageText(.title3)
                        .foregroundStyle(P.success)
                        .contentTransition(.numericText())
                }
            }
            HStack {
                Text("You pay for this order").backstageText(.label2).foregroundStyle(M.textSecondary)
                Spacer()
                Text(rupees(flow.total))
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, R.spacingSpace4)
        } actions: {
            SheetPrimary(title: "Done") { dismiss() }
        }
    }

    private func row(_ title: String, detail: String?, value: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).backstageText(.label2).foregroundStyle(M.textPrimary)
                if let detail { Text(detail).backstageText(.label3).foregroundStyle(M.textTertiary) }
            }
            Spacer()
            Text(value).backstageText(.title4).foregroundStyle(M.textOffer)
        }
        .accessibilityElement(children: .combine)
    }
}
