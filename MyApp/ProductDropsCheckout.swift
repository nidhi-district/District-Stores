import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive
private typealias P = DropPalette

// MARK: - Pick-up sheet

/// The bottom sheet after "Add to Cart": "Select store for pick-up" (Figma 7663:12543), then
/// "Pick-up time" (Figma 7663:12820) in the same sheet.
struct DropsPickupSheet: View {
    @Environment(DropFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    var onProceed: () -> Void
    @State private var step = 0
    init(onProceed: @escaping () -> Void) { self.onProceed = onProceed }

    @State private var query = ""
    @State private var brand = "All"
    @State private var selectedStore: DropStore?

    var body: some View {
        ZStack {
            if step == 0 { storeStep.transition(.move(edge: .leading).combined(with: .opacity)) }
            else { slotStep.transition(.move(edge: .trailing).combined(with: .opacity)) }
        }
        .animation(.snappy, value: step)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) {
            // Figma ellipse glow above the sheet.
            RadialGradient(colors: [Color.white.opacity(0.07), .clear], center: .top, startRadius: 0, endRadius: 240)
                .frame(height: 240)
                .allowsHitTesting(false)
        }
        .presentationDetents([.height(616), .large])
        .presentationCornerRadius(16)
        .presentationBackground(M.backgroundPrimary)
        .presentationDragIndicator(.hidden)
        .onAppear { selectedStore = flow.store }
    }

    // MARK: Store

    private var stores: [DropStore] {
        DropsData.stores.filter { s in
            (brand == "All" || s.name.localizedCaseInsensitiveContains(brand) || brand.localizedCaseInsensitiveContains(s.name))
                && (query.isEmpty || s.name.localizedCaseInsensitiveContains(query) || s.area.localizedCaseInsensitiveContains(query))
        }
    }

    private var storeStep: some View {
        VStack(spacing: R.spacingSpace16) {
            HStack(spacing: R.spacingSpace12) {
                Text("Select store for pick-up")
                    .dropFont("SemiBold", 18, relativeTo: .title3)
                    .foregroundStyle(M.textWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                SheetCircleButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            HStack(spacing: R.spacingSpace8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(M.textTertiary)
                TextField("", text: $query, prompt: Text("Search for store or brand").foregroundStyle(M.textTertiary))
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, R.spacingSpace12)
            .frame(height: 44)
            .background(M.surfaceTransparent, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: R.stroke1Px))
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(DropsData.storeBrands, id: \.self) { b in
                        Button(b) { brand = b }
                            .buttonStyle(BackstageFilterButtonStyle(isActive: brand == b))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            ScrollView {
                VStack(spacing: R.spacingSpace16) {
                    ForEach(stores) { s in
                        Button { selectedStore = s } label: { DropStoreRow(store: s, selected: selectedStore == s) }
                            .buttonStyle(PressableStyle())
                    }
                    if stores.isEmpty {
                        Text("No stores match “\(query)”")
                            .backstageText(.body3)
                            .foregroundStyle(M.textSecondary)
                            .padding(.top, R.spacingSpace24)
                    }
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace16)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DropCTADock {
                Button {
                    flow.store = selectedStore
                    step = 1
                } label: { Text("Choose pick-up slot") }
                .buttonStyle(PickupButtonStyle())
                .disabled(selectedStore == nil)
            }
        }
    }

    // MARK: Slot

    private var slotStep: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                SheetCircleButton(systemName: "chevron.left", label: "Back to stores") { step = 0 }
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text("Pick-up time")
                        .dropFont("SemiBold", 18, relativeTo: .title3)
                        .foregroundStyle(M.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Choose a slot for your order")
                        .backstageText(.label2)
                        .foregroundStyle(P.white70)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SheetCircleButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text("Select date")
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                HStack(spacing: R.spacingSpace12) {
                    ForEach(Array(DropFlow.dates.enumerated()), id: \.offset) { i, d in
                        let on = flow.date == i
                        Button { flow.date = i } label: {
                            VStack(spacing: 0) {
                                Text(d.0).backstageText(.title3)
                                Text(d.1).backstageText(.body3)
                            }
                            .foregroundStyle(on ? M.textPrimary : P.white70)
                            .padding(.horizontal, R.spacingSpace12)
                            .frame(height: 58)
                            .background(on ? M.surfaceTransparent : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(on ? M.borderSelection : Color.white.opacity(0.16), lineWidth: R.stroke1Px))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(d.1) \(d.0)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text("Select time")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: R.spacingSpace16), count: 3), spacing: R.spacingSpace16) {
                    ForEach(DropFlow.times, id: \.self) { t in
                        let off = DropFlow.unavailable.contains(t)
                        let on = flow.time == t
                        Button { flow.time = t } label: {
                            Text(t)
                                .backstageText(.title4)
                                .fontWeight(.medium)
                                .foregroundStyle(off ? Color(rgba: 0xF7F7F745) : (on ? M.textPrimary : P.white70))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(on || off ? M.surfaceTransparent : P.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(off ? .clear : (on ? M.borderSelection : Color.white.opacity(0.16)), lineWidth: R.stroke1Px))
                        }
                        .buttonStyle(.plain)
                        .disabled(off)
                        .accessibilityLabel(off ? "\(t), unavailable" : t)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace12)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DropCTADock(radius: 32) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(M.textPrimary, M.surfaceOfferPrimary)
                    (Text("Selected: ").foregroundStyle(P.white70) + Text(flow.slotLabel).foregroundStyle(P.softWhite).fontWeight(.semibold))
                        .dropFont("Medium", 13)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Button(action: onProceed) { Text("Proceed").frame(maxWidth: .infinity) }
                    .buttonStyle(BackstagePrimaryButtonStyle())
            }
        }
    }
}

/// 32pt round sheet control on white 8%.
struct SheetCircleButton: View {
    let systemName: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 32, height: 32)
                .background(M.surfaceTransparent, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(-6)
        .accessibilityLabel(label)
    }
}

/// Primary button that greys to the Figma #77777E fill with a black label until a store is chosen.
private struct PickupButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .backstageText(.label1)
            .foregroundStyle(isEnabled ? M.buttonPrimaryLabel : M.textBlack)
            .frame(maxWidth: .infinity)
            .frame(minHeight: R.spacingSpace48)
            .background(isEnabled ? (configuration.isPressed ? M.buttonPrimaryBackgroundPressed : M.buttonPrimaryBackground) : M.textTertiary,
                        in: Capsule())
    }
}

private struct DropStoreRow: View {
    let store: DropStore
    let selected: Bool

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            Image(store.logo)
                .resizable()
                .scaledToFit()
                .padding(store.logoInset ? 13 : 0)
                .frame(width: 54, height: 54)
                .background(store.logo == "pd_store_ivenus" ? Color(rgba: 0x111214FF) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(store.name)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                HStack(spacing: 6) {
                    Text(store.distance)
                    Rectangle().fill(P.meta.opacity(0.5)).frame(width: 1, height: 12)
                    Text(store.area).lineLimit(1)
                }
                .backstageText(.label3)
                .foregroundStyle(P.meta)
                HStack(spacing: R.spacingSpace4) {
                    Image(systemName: "tag.fill").font(.system(size: 9))
                    Text(store.offer).dropFont("Regular", 10)
                }
                .foregroundStyle(M.textOffer)
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        }
        .padding(10)
        .background(P.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? M.borderSelection : M.borderSubtle, lineWidth: R.stroke1Px))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Cart

/// "with EMI available" (Figma 7647:8266): review the cart before paying the 25% reservation.
struct DropsCartView: View {
    @Environment(DropFlow.self) private var flow
    @State private var sheet: DropCartSheet? = {
        #if DEBUG
        // `-dropsCartSheet reserve|nonRefundable|itemTotal|savings` opens an explainer in Debug builds.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-dropsCartSheet"), i + 1 < args.count { return DropCartSheet(rawValue: args[i + 1]) }
        #endif
        return nil
    }()
    @State private var itemTotal = ProcessInfo.processInfo.arguments.contains("-dropsItemTotal")

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                if flow.plan == .reserve { DropReserveBanner { sheet = .reserve } }
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    items
                    Button { flow.path.removeLast() } label: {
                        HStack(spacing: R.spacingSpace4) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                            Text("Add more items").backstageText(.label3)
                        }
                        .foregroundStyle(M.textOffer)
                        .padding(.horizontal, R.spacingSpace4)
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.9)
                }
                offers
                crossSell
                collection
                DropBillSummary(rows: billRows, total: ("Total value", flow.total),
                                paid: (flow.plan == .full ? "Pay now" : "Pay now (25%)", flow.payNow),
                                due: flow.plan == .full ? nil : ("Remaining at pick-up", flow.reserveLater),
                                footer: "You save \(rupees(flow.savings)) on this order",
                                actions: ["Item total": { withAnimation(.snappy(duration: 0.3)) { itemTotal = true } }, "Item discount": { sheet = .savings },
                                          "Coupon discount": { sheet = .savings }, "Pay now (25%)": { sheet = .reserve },
                                          "Remaining at pick-up": { sheet = .reserve }])
                DropLinkList(rows: [("doc.text", "Terms and conditions"), ("bubble.left.and.text.bubble.right", "Chat with support")], bordered: false)
                    .background(P.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            }
            .padding(R.spacingSpace16)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            DropPageHeader(title: "Review your cart",
                           subtitle: flow.store.map { "\($0.name) • \($0.area)" })
                .background(LinearGradient(colors: [M.backgroundPrimary, M.backgroundPrimary.opacity(0)], startPoint: .top, endPoint: .bottom))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DropCTADock {
                Button { flow.balancePaid = false; flow.path.append(.success) } label: {
                    Text(flow.plan == .full ? "Pay \(rupees(flow.payNow))" : "Pay \(rupees(flow.payNow)) to reserve")
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                }
                    .buttonStyle(BackstagePrimaryButtonStyle())
                    .disabled(flow.cart.isEmpty)
            }
        }
        .overlay {
            if itemTotal {
                DropItemTotalPopup {
                    withAnimation(.snappy(duration: 0.25)) { itemTotal = false }
                } showSavings: {
                    withAnimation(.snappy(duration: 0.25)) { itemTotal = false }
                    sheet = .savings
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .reserve: DropReserveSheet { sheet = .nonRefundable }
            case .nonRefundable: DropNonRefundableSheet()
            case .itemTotal: EmptyView()
            case .savings: DropSavingsSheet()
            }
        }
    }

    private var billRows: [(String, String, Bool)] {
        [("Item total", rupees(flow.itemTotal), false),
         ("Item discount", rupees(-flow.itemDiscount), true),
         ("Coupon discount", rupees(-flow.coupon), true),
         ("Convenience", "Free", true)]
    }

    private var items: some View {
        @Bindable var flow = flow
        return VStack(spacing: 0) {
            VStack(spacing: R.spacingSpace16) {
                ForEach($flow.cart) { $item in
                    if item.id != flow.cart.first?.id { Rectangle().fill(M.borderSubtle).frame(height: 1).padding(.horizontal, 25) }
                    CartItemRow(item: $item) {
                        withAnimation(.snappy) { flow.cart.removeAll { $0.id == item.id } }
                    }
                    .padding(.horizontal, R.spacingSpace12)
                }
                if flow.cart.isEmpty {
                    Text("Your cart is empty")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .padding(.vertical, R.spacingSpace24)
                }
            }
            .padding(.top, R.spacingSpace12)
            .padding(.bottom, R.spacingSpace16)
            Button { sheet = .nonRefundable } label: {
                HStack(spacing: R.spacingSpace4) {
                    Image(systemName: "info.circle").font(.system(size: 10))
                    Text("This purchase is non-refundable").backstageText(.label3)
                    Spacer()
                    Text("Why?").backstageText(.label3).underline(pattern: .dash)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(M.textSecondary)
                .padding(.horizontal, 17.5)
                .frame(height: 36)
                .background(Color.white.opacity(0.04))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Explains the refund policy")
        }
        .background(P.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }

    private var offers: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            DropSectionHeader(title: "Add-on offers") { flow.path.append(.offers) }
                .opacity(0.7)
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace12) {
                    CartOfferCard(title: "Flat ₹500 OFF", detail: "on full payment", icon: .gift,
                                  applied: flow.couponApplied) { flow.couponApplied.toggle() }
                    CartOfferCard(title: "No cost EMI + Flat ₹500 OFF", detail: "on Pay in 3 options", icon: .gift, applied: false) {}
                    CartOfferCard(title: "10% OFF", detail: "up to ₹1,000", icon: .logo("pd_bank_offer"), note: "valid above ₹5000")
                    CartOfferCard(title: "₹500 off", detail: "on MasterCard", icon: .logo("pd_bank_amazonpay"), note: "Add ₹150 more to unlock", locked: true)
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var crossSell: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            DropSectionHeader(title: "Other products at this store") { flow.path.append(.listing) }
                .opacity(0.7)
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace12) {
                    ForEach(DropsData.crossSell) { p in
                        Button { flow.path.append(.product(p)) } label: {
                            DropProductCard(product: p, scale: 0.651, nameStyle: .label3, width: 145)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Collection details")
                .dropSectionLabel()
                .foregroundStyle(P.white70)
                .opacity(0.7)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) {
                if let store = flow.store {
                    DetailRow(icon: "mappin.and.ellipse") {
                        VStack(alignment: .leading, spacing: R.spacingSpace4) {
                            Text("\(store.name), \(store.area.capitalized)")
                                .backstageText(.title4)
                                .foregroundStyle(P.softWhite)
                            Text(store.address)
                                .backstageText(.body3)
                                .foregroundStyle(M.textTertiary)
                            Text(store.km)
                                .backstageText(.label3)
                                .foregroundStyle(M.textOffer)
                                .padding(.horizontal, R.spacingSpace8)
                                .padding(.vertical, 2)
                                .background(M.surfaceTransparent, in: Capsule())
                                .padding(.top, 2)
                        }
                    }
                    Rectangle().fill(M.borderSubtle).frame(height: 1)
                }
                DetailRow(icon: "clock") {
                    Text("\(flow.slotLabel) - \(endTime)")
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                }
            }
            .padding(.horizontal, R.spacingSpace12)
            .padding(.vertical, R.spacingSpace16)
            .background(P.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
    }

    /// Two-hour collection window from the chosen slot.
    private var endTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let start = f.date(from: flow.time) else { return "" }
        return f.string(from: start.addingTimeInterval(2 * 3600))
    }
}

private struct DetailRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 24, height: 24)
                .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CartItemRow: View {
    @Binding var item: DropCartItem
    var remove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            Image(item.image)
                .resizable()
                .scaledToFit()
                .padding(7)
                .frame(width: 64, height: 64)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8.4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8.4, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.7))
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(item.product.name)
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                HStack(spacing: 6) {
                    chip(item.colour)
                    chip("Size - \(item.size)")
                }
                Button {} label: {
                    HStack(spacing: 2) {
                        Text("Edit")
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .backstageText(.button3)
                    .foregroundStyle(P.editLink)
                    .frame(minHeight: 28)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                stepper
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rupees(item.product.price * item.quantity))
                        .backstageText(.button3)
                        .foregroundStyle(M.textPrimary)
                    Text(rupees(item.product.mrp * item.quantity))
                        .backstageText(.label3)
                        .strikethrough()
                        .foregroundStyle(P.strike)
                }
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .backstageText(.label3)
            .foregroundStyle(M.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var stepper: some View {
        HStack(spacing: 2) {
            Button { if item.quantity > 1 { item.quantity -= 1 } else { remove() } } label: {
                Image(systemName: "minus").frame(width: 20, height: 26)
            }
            .accessibilityLabel(item.quantity > 1 ? "Decrease quantity" : "Remove item")
            Text("\(item.quantity)")
                .backstageText(.button3)
                .frame(width: 18)
                .contentTransition(.numericText())
            Button { if item.quantity < 4 { item.quantity += 1 } } label: {
                Image(systemName: "plus").frame(width: 20, height: 26)
            }
            .accessibilityLabel("Increase quantity")
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(P.ink)
        .buttonStyle(.plain)
        .frame(width: 70, height: 26)
        .background(M.textPrimary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(.snappy, value: item.quantity)
    }
}

private struct CartOfferCard: View {
    enum Icon { case gift, logo(String) }
    let title: String
    let detail: String
    let icon: Icon
    var applied: Bool? = nil
    var note: String?
    var locked = false
    var apply: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .backstageText(.title4)
                    .fontWeight(.medium)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2)
                Text(detail)
                    .dropFont("Regular", 10)
                    .foregroundStyle(M.textPrimary.opacity(0.5))
            }
            Spacer(minLength: 0)
            if let applied {
                Button(applied ? "Applied ✓" : "Apply", action: apply)
                    .buttonStyle(BackstageTextButtonStyle())
                    .underline(!applied)
                    .foregroundStyle(applied ? P.success : M.textPrimary)
                    .frame(height: 20)
            } else if let note {
                Text(note)
                    .dropFont("Regular", 10)
                    .foregroundStyle(P.warning)
            }
        }
        .padding(R.spacingSpace12)
        .frame(width: 135, height: 143, alignment: .topLeading)
        .background(locked ? M.surfaceTransparent : M.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(applied == true ? P.success.opacity(0.6) : Color.white.opacity(locked ? 0.08 : 0.16), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var iconView: some View {
        switch icon {
        case .gift:
            Image("pd_gift")
                .resizable()
                .frame(width: 15, height: 15)
                .frame(width: 24, height: 24)
                .background(P.ink, in: RoundedRectangle(cornerRadius: 5.4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5.4, style: .continuous).strokeBorder(P.giftEdge, lineWidth: 0.5))
        case .logo(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4.8, style: .continuous))
        }
    }
}

/// Payment summary: the purple band holding the bill card and the savings footer.
struct DropBillSummary: View {
    let rows: [(String, String, Bool)]
    let total: (String, Int)
    var paid: (String, Int)?
    var due: (String, Int)?
    let footer: String
    /// Rows that open an explainer; their labels get a dashed underline.
    var actions: [String: () -> Void] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Payment summary")
                .dropSectionLabel()
                .foregroundStyle(P.white70)
                .opacity(0.7)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: R.spacingSpace4) {
                VStack(spacing: 14) {
                    ForEach(rows, id: \.0) { r in
                        tappable(r.0) {
                            HStack {
                                Text(r.0).foregroundStyle(P.white70).underline(actions[r.0] != nil, pattern: .dash)
                                Spacer()
                                Text(r.1).foregroundStyle(r.2 ? M.textOffer : P.softWhite)
                            }
                            .backstageText(.label2)
                        }
                    }
                    Rectangle().fill(M.borderSubtle).frame(height: 1)
                    HStack {
                        Text(total.0).backstageText(.title4).fontWeight(.medium)
                        Spacer()
                        Text(rupees(total.1)).backstageText(.title4)
                    }
                    .foregroundStyle(P.softWhite)
                    if let paid {
                        Rectangle().fill(M.borderSubtle).frame(height: 1)
                        tappable(paid.0) {
                            HStack {
                                Text(paid.0).backstageText(.label2).underline(actions[paid.0] != nil, pattern: .dash)
                                Spacer()
                                Text(rupees(paid.1)).backstageText(.title4)
                            }
                            .foregroundStyle(P.success)
                        }
                    }
                    if let due {
                        tappable(due.0) {
                            HStack(spacing: R.spacingSpace4) {
                                Text(due.0).backstageText(.title4).foregroundStyle(M.textPrimary)
                                if actions[due.0] != nil {
                                    Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(M.iconTertiary)
                                }
                                Spacer()
                                Text(rupees(due.1)).backstageText(.title3).foregroundStyle(M.textOffer)
                            }
                            .padding(R.spacingSpace8)
                            .background(P.dueRow, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(R.spacingSpace12)
                .background(P.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                Text(footer)
                    .backstageText(.label3)
                    .foregroundStyle(P.softWhite)
                    .frame(height: 18)
                    .padding(.bottom, 2)
            }
            .background(P.summaryBand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
    }

    @ViewBuilder
    private func tappable<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        if let action = actions[label] {
            Button(action: action) { content().contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the breakdown")
        } else {
            content()
        }
    }
}

// MARK: - All offers

/// "All add-on offers" (Figma 7647:7543).
struct DropsOffersView: View {
    @State private var query = ""
    @State private var filter = "All"
    @State private var keyword = 0
    @State private var info: DropOffer?
    private let keywords = ["Promocode", "Bank", "Credit card", "Debit card", "Wallet"]
    private let filters = ["All", "Credit card", "Debit card", "No cost EMI"]

    init() {}

    private var shown: [DropOffer] {
        DropsData.offers.filter { o in
            switch filter {
            case "Credit card": o.kind == .credit
            case "Debit card": o.kind == .debit
            case "No cost EMI": o.kind == .emi
            default: true
            }
        }
        .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: R.spacingSpace20) {
                search
                ScrollView(.horizontal) {
                    HStack(spacing: R.spacingSpace8) {
                        ForEach(filters, id: \.self) { f in DropChip(title: f, selected: filter == f) { filter = f } }
                    }
                    .padding(.horizontal, R.spacingSpace16)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -R.spacingSpace16)
                VStack(spacing: R.spacingSpace16) {
                    ForEach(shown) { o in offerRow(o) }
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace8)
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { DropPageHeader(title: "All offers") }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.snappy) { keyword = (keyword + 1) % keywords.count }
            }
        }
        .alert(item: $info) { o in
            Alert(title: Text(o.title), message: Text("\(o.detail). One use per card per order."), dismissButton: .default(Text("Got it")))
        }
    }

    private var search: some View {
        HStack(spacing: R.spacingSpace8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(P.white50)
            ZStack(alignment: .leading) {
                if query.isEmpty {
                    HStack(spacing: 4) {
                        Text("Search for")
                        Text("“\(keywords[keyword])”")
                            .id(keyword)
                            .transition(.push(from: .bottom))
                    }
                    .backstageText(.title4)
                    .fontWeight(.medium)
                    .foregroundStyle(P.white50)
                    .clipped()
                    .accessibilityHidden(true)
                }
                TextField("", text: $query)
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityLabel("Search offers")
            }
        }
        .padding(.horizontal, R.spacingSpace8)
        .frame(height: 44)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func offerRow(_ o: DropOffer) -> some View {
        HStack(spacing: R.spacingSpace12) {
            Image(o.logo)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(o.title).backstageText(.title4).foregroundStyle(M.textPrimary)
                Text(o.detail).backstageText(.body3).foregroundStyle(M.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { info = o } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(M.iconTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Offer details")
        }
        .padding(.leading, R.spacingSpace16)
        .padding(.trailing, 4)
        .frame(height: 73)
        .background(Image("pd_offer_card_ticket").resizable())
        .accessibilityElement(children: .contain)
    }
}
