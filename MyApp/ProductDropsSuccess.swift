import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive
private typealias P = DropPalette

// MARK: - Order confirmation

/// Order confirmation for both payment plans (Figma "full payment crystal" in the Full payment and
/// Partial Payment sections).
///
/// The two plans hand out different credentials so a code never means two things:
/// - **Reservation ID** (reserve plan only, before the balance is paid): the counter looks up the order
///   with it to collect the balance. It can't be used to collect the pick.
/// - **Pickup code** (only once fully paid): the code the counter hands the pick over against.
///   Under the reserve plan it shows as locked until the balance is paid, at the counter or in the app.
struct DropsPaymentSuccessView: View {
    @Environment(DropFlow.self) private var flow
    var close: () -> Void
    @State private var paying = false
    @State private var pop: CGFloat = 0
    @State private var copied = false
    /// Checklist items the user has ticked off.
    @State private var ticked: Set<String> = []

    init(close: @escaping () -> Void) { self.close = close }

    /// Reserve plan with the balance still due.
    private var awaitingBalance: Bool { flow.plan == .reserve && !flow.balancePaid }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                hero
                steps.padding(.top, R.spacingSpace24)
                VStack(alignment: .leading, spacing: R.spacingSpace32) {
                    VStack(alignment: .leading, spacing: R.spacingSpace16) {
                        sectionLabel(awaitingBalance ? "At the store" : "Collection details")
                        if awaitingBalance {
                            reservationPass.transition(.opacity)
                            lockedPickup.transition(.opacity)
                        } else {
                            pickupPass.transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                        notice
                    }
                    beforeYouGo.id("before-you-go")
                    reservedItem
                    venue
                    summary
                    details
                    VStack(alignment: .leading, spacing: R.spacingSpace16) {
                        sectionLabel("Need help")
                        DropLinkList(rows: [("bubble.left.and.text.bubble.right", "Chat with support"), ("doc.text", "Terms and conditions")])
                    }
                }
                .padding(R.spacingSpace16)
                .padding(.top, R.spacingSpace16)
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        #if DEBUG
        // `-dropsChecklist` opens on "Before you go" with the first item ticked.
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("-dropsChecklist") else { return }
            ticked = [checklist[0].id]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { proxy.scrollTo("before-you-go", anchor: .top) }
        }
        #endif
        }
        .background(alignment: .top) {
            (awaitingBalance ? M.surfaceOfferPrimary : P.paidGreen)
                .frame(height: 492)
                .blur(radius: 112)
                .opacity(0.16)
                .offset(y: -250)
                .ignoresSafeArea()
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                GlassIconButton(systemName: "arrow.left", label: "Done", action: close)
                Spacer()
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace4)
            .background(LinearGradient(colors: [M.backgroundPrimary, M.backgroundPrimary.opacity(0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea())
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DropCTADock {
                if awaitingBalance {
                    Button(action: payBalance) {
                        Group {
                            if paying { ProgressView().tint(M.textInverse) }
                            else { Text("Pay remaining \(rupees(flow.reserveLater))") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BackstagePrimaryButtonStyle())
                    .disabled(paying)
                } else {
                    Button(action: close) { Text("Done").frame(maxWidth: .infinity) }
                        .buttonStyle(BackstagePrimaryButtonStyle())
                }
            }
        }
        .animation(.snappy(duration: 0.45), value: flow.balancePaid)
    }

    private func payBalance() {
        paying = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            paying = false
            pop = 0.6
            flow.balancePaid = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { pop = 1 }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .dropSectionLabel()
            .foregroundStyle(P.white70)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: R.spacingSpace16) {
            Group {
                if awaitingBalance {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(M.textOffer)
                        .frame(width: 48, height: 48)
                        .background(M.surfaceOfferSecondary, in: Circle())
                        .overlay(Circle().strokeBorder(M.borderSelectionPurple, lineWidth: R.stroke1Px))
                } else {
                    Image("pd_success_check").resizable().frame(width: 48, height: 48)
                }
            }
            .scaleEffect(pop)
            .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { pop = 1 } }
            .accessibilityHidden(true)
            VStack(spacing: R.spacingSpace4) {
                Text(awaitingBalance ? "Your pick is reserved" : "Payment Successful")
                    .dropFont("SemiBold", 22, relativeTo: .title2)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Group {
                    if awaitingBalance {
                        Text("You paid ").foregroundStyle(M.textSecondary)
                        + Text(rupees(flow.reserveNow)).foregroundStyle(P.paidGreen).fontWeight(.semibold)
                        + Text(" • \(rupees(flow.reserveLater)) due at pick-up").foregroundStyle(M.textSecondary)
                    } else {
                        Text(flow.plan == .reserve ? "Balance paid. You've paid " : "You paid ").foregroundStyle(M.textSecondary)
                        + Text(rupees(flow.total)).foregroundStyle(P.paidGreen).fontWeight(.semibold)
                        + Text(flow.plan == .reserve ? " in total" : "").foregroundStyle(M.textSecondary)
                    }
                }
                .backstageText(.body3)
                .contentTransition(.numericText())
            }
        }
        .padding(.top, R.spacingSpace24)
    }

    // MARK: Steps

    private enum StepState { case done, current, upcoming }

    private var steps: some View {
        let items: [(String, StepState)] = switch (flow.plan, flow.balancePaid) {
        case (.full, _): [("Pay in full", .done), ("Show code at the store", .current), ("Collect your pick", .upcoming)]
        case (.reserve, false): [("Reserve your pick", .done), ("Pay remaining at the store", .current), ("Show code to collect", .upcoming)]
        case (.reserve, true): [("Reserve your pick", .done), ("Pay remaining amount", .done), ("Show code at the store to collect", .current)]
        }
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 { rail(lit: item.1 != .upcoming) }
                step(item.0, item.1)
            }
        }
        .padding(.horizontal, R.spacingSpace24)
        .accessibilityElement(children: .combine)
    }

    private func step(_ title: String, _ state: StepState) -> some View {
        VStack(spacing: R.spacingSpace8) {
            switch state {
            case .done:
                Image("pd_step_done").resizable().frame(width: 24, height: 24)
            case .current:
                ZStack {
                    Image("pd_step_ring").resizable().frame(width: 24, height: 24)
                    Image("pd_step_clock").resizable().frame(width: 17, height: 17)
                }
            case .upcoming:
                Circle().strokeBorder(M.borderIntense, lineWidth: 1.5).frame(width: 24, height: 24)
            }
            Text(title)
                .backstageText(.label3)
                .foregroundStyle(state == .current ? M.textPrimary : (state == .done ? M.textTertiary : P.white70))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 84)
    }

    private func rail(lit: Bool) -> some View {
        LinearGradient(colors: [M.backgroundSecondary, lit ? P.railGreen : P.railEnd], startPoint: .leading, endPoint: .trailing)
            .frame(height: 2)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, 11)
    }

    // MARK: Credentials

    /// Reserve plan: what the counter uses to collect the balance.
    private var reservationPass: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack {
                Text("Reservation")
                    .backstageText(.title4)
                    .foregroundStyle(P.reserveText)
                Spacer()
                Text("Balance due \(rupees(flow.reserveLater))")
                    .backstageText(.label3)
                    .foregroundStyle(M.textOffer)
                    .padding(.horizontal, R.spacingSpace8)
                    .padding(.vertical, R.spacingSpace4)
                    .background(M.surfaceOfferSecondary, in: Capsule())
            }
            HStack(spacing: R.spacingSpace8) {
                Text("\(DropFlow.dates[flow.date].1), \(DropFlow.dates[flow.date].0)")
                Rectangle().fill(M.borderIntense).frame(width: R.stroke1Px, height: 12)
                Text(flow.time)
            }
            .backstageText(.title4)
            .foregroundStyle(M.textPrimary)
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            HStack(spacing: R.spacingSpace4) {
                Text("Reservation ID:").backstageText(.body3).foregroundStyle(M.textTertiary)
                Text(flow.reservationID).backstageText(.title4).tracking(0.5).foregroundStyle(M.textPrimary)
                Button {
                    UIPasteboard.general.string = flow.reservationID
                    copied = true
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(copied ? P.success : M.iconSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Copied" : "Copy reservation ID")
            }
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Image(systemName: "creditcard")
                    .font(.system(size: 13))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 32, height: 32)
                    .background(M.surfaceTransparent, in: Circle())
                Text("Share this ID at the counter to pay the balance. It's not a pickup code: your pick is handed over only after full payment.")
                    .backstageText(.body3)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(R.spacingSpace16)
        .background(LinearGradient(colors: [M.brandPurple900, P.ink], startPoint: .topTrailing, endPoint: .bottomLeading),
                    in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(P.reserveEdge, lineWidth: R.stroke1Px))
    }

    /// Reserve plan: the pickup code's place, locked until the balance is paid.
    private var lockedPickup: some View {
        HStack(spacing: R.spacingSpace12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 32, height: 32)
                .background(M.surfaceSecondary, in: Circle())
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                HStack(spacing: R.spacingSpace8) {
                    Text("Pickup code").backstageText(.title4).foregroundStyle(M.textPrimary)
                    Text("• • • • • •").backstageText(.title4).foregroundStyle(M.textTertiary)
                        .accessibilityHidden(true)
                }
                Text("Unlocks once you pay \(rupees(flow.reserveLater)), at the counter or here in the app.")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(R.spacingSpace16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous)
            .strokeBorder(M.borderIntense, style: StrokeStyle(lineWidth: R.stroke1Px, dash: [4, 4])))
        .accessibilityElement(children: .combine)
    }

    /// Fully paid: the code the counter hands the pick over against (Figma "Confirmation code").
    private var pickupPass: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(spacing: R.spacingSpace8) {
                Text("\(DropFlow.dates[flow.date].1), \(DropFlow.dates[flow.date].0)")
                Rectangle().fill(M.borderIntense).frame(width: R.stroke1Px, height: 12)
                Text(flow.time)
            }
            .backstageText(.title4)
            .foregroundStyle(M.textPrimary)
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            HStack(spacing: R.spacingSpace4) {
                Text("Pickup code:").backstageText(.body3).foregroundStyle(M.textTertiary)
                Text(flow.pickupCode).backstageText(.title4).tracking(0.5).foregroundStyle(M.textPrimary)
                Spacer()
                Label("Fully paid", systemImage: "checkmark.seal.fill")
                    .backstageText(.label3)
                    .foregroundStyle(P.success)
            }
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Image(systemName: "bag")
                    .font(.system(size: 13))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 32, height: 32)
                    .background(M.surfaceTransparent, in: Circle())
                Text("Verify the product(s), share the pickup code with the cashier, & collect your purchase.")
                    .backstageText(.body3)
                    .foregroundStyle(M.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(R.spacingSpace16)
        .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSelection, lineWidth: R.stroke1Px))
    }

    private var notice: some View {
        HStack(spacing: R.spacingSpace12) {
            Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(M.textSecondary)
            Text("You can find this order in Profile → Store Transactions")
                .backstageText(.label3)
                .foregroundStyle(M.textSecondary)
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, R.spacingSpace16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }

    // MARK: Before you go

    private struct ChecklistItem: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    /// What to sort out before heading to the store, by payment state.
    private var checklist: [ChecklistItem] {
        let slotEnd: String = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.date(from: flow.time).map { f.string(from: $0.addingTimeInterval(2 * 3600)) } ?? ""
        }()
        let slot = "\(DropFlow.dates[flow.date].1), \(DropFlow.dates[flow.date].0) • \(flow.time) – \(slotEnd)"
        let id = ChecklistItem(id: "id", symbol: "person.text.rectangle", title: "Carry a valid photo ID",
                               detail: "The name on it should match the order: Aarav Mehta.")
        let inspect = ChecklistItem(id: "inspect", symbol: "shoeprints.fill", title: "Check your pick at the counter",
                                    detail: "Try them on and check size and condition before you leave the store.")
        if awaitingBalance {
            return [
                ChecklistItem(id: "pass", symbol: "number", title: "Keep your reservation ID handy",
                              detail: "Share \(flow.reservationID) at the counter to pay the balance. It isn't your pickup code."),
                ChecklistItem(id: "balance", symbol: "indianrupeesign.circle", title: "Keep \(rupees(flow.reserveLater)) ready",
                              detail: "Pay by UPI, card or cash at the store, or pay early in the app to skip this step."),
                ChecklistItem(id: "slot", symbol: "clock", title: "Reach within your slot",
                              detail: "\(slot). Unclaimed reservations lapse and the 25% isn't refunded."),
                id,
                ChecklistItem(id: "code", symbol: "lock.open", title: "Collect with your pickup code",
                              detail: "It unlocks here as soon as the balance is paid."),
            ]
        }
        return [
            ChecklistItem(id: "code", symbol: "number", title: "Keep your pickup code handy",
                          detail: "Share \(flow.pickupCode) at the counter. A screenshot works if you're offline."),
            ChecklistItem(id: "slot", symbol: "clock", title: "Reach within your slot",
                          detail: "\(slot). Your pick is held until the slot ends."),
            id,
            inspect,
        ]
    }

    private var beforeYouGo: some View {
        let items = checklist
        let done = items.filter { ticked.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack {
                sectionLabel("Before you go")
                Spacer()
                Text(done == items.count ? "All set" : "\(done) of \(items.count) done")
                    .backstageText(.label3)
                    .foregroundStyle(done == items.count ? P.success : M.textTertiary)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px).padding(.leading, 52) }
                    checklistRow(item)
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace4)
            .background(P.card, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
        .animation(.snappy, value: ticked)
    }

    private func checklistRow(_ item: ChecklistItem) -> some View {
        let on = ticked.contains(item.id)
        return Button {
            if on { ticked.remove(item.id) } else { ticked.insert(item.id) }
        } label: {
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                ZStack {
                    Circle()
                        .strokeBorder(on ? P.success : M.borderIntense, lineWidth: 1.5)
                        .background(Circle().fill(on ? P.success : .clear))
                    Image(systemName: on ? "checkmark" : item.symbol)
                        .font(.system(size: on ? 11 : 12, weight: on ? .bold : .regular))
                        .foregroundStyle(on ? M.textInverse : M.iconSecondary)
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .backstageText(.title4)
                        .foregroundStyle(on ? M.textTertiary : M.textPrimary)
                    Text(item.detail)
                        .backstageText(.body3)
                        .foregroundStyle(on ? M.textTertiary : M.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, R.spacingSpace12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(on ? "Marks as not done" : "Marks as done")
    }

    // MARK: Order

    private var reservedItem: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Text(awaitingBalance ? "Reserved items" : "Your items")
                .backstageText(.label2)
                .foregroundStyle(M.textTertiary)
            ForEach(flow.cart) { item in
                HStack(spacing: R.spacingSpace12) {
                    Image(item.image)
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                        .frame(width: 64, height: 64)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8.4, style: .continuous))
                    VStack(alignment: .leading, spacing: R.spacingSpace4) {
                        Text(item.product.name + (item.quantity > 1 ? " × \(item.quantity)" : ""))
                            .backstageText(.label2)
                            .foregroundStyle(M.textPrimary)
                        Text("\(item.colour) • Size \(item.size)")
                            .backstageText(.label3)
                            .foregroundStyle(M.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner4, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(rupees(item.product.price * item.quantity)).backstageText(.button3).foregroundStyle(M.textPrimary)
                        Text(rupees(item.product.mrp * item.quantity)).backstageText(.label3).strikethrough().foregroundStyle(P.strike)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace8)
        .padding(.bottom, R.spacingSpace16)
        .background(P.card, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .elevation(.shadow100)
    }

    @ViewBuilder private var venue: some View {
        if let store = flow.store {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                sectionLabel("Venue")
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("\(store.name), \(store.area.components(separatedBy: ", ").last?.capitalized ?? "")")
                            .backstageText(.title4)
                            .foregroundStyle(M.textPrimary)
                        Spacer()
                        Text(store.km)
                            .backstageText(.label3)
                            .foregroundStyle(M.textOffer)
                            .padding(.horizontal, R.spacingSpace8)
                            .padding(.vertical, R.spacingSpace4)
                            .background(M.surfaceTransparent, in: Capsule())
                    }
                    Text(store.address)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                    HStack(spacing: R.spacingSpace8) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text("Mon-Sat, 10:00 AM - 8:00 PM").backstageText(.label3)
                    }
                    .foregroundStyle(M.textSecondary)
                    Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                    Link(destination: Self.mapsURL(store)) {
                        HStack(spacing: R.spacingSpace4) {
                            Text("Get Directions")
                            Image(systemName: "location.north.circle").font(.system(size: 14))
                        }
                        .backstageText(.title4)
                        .foregroundStyle(M.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(M.surfaceInverse, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
                    }
                }
                .padding(.horizontal, R.spacingSpace12)
                .padding(.vertical, R.spacingSpace16)
                .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            }
        }
    }

    private static func mapsURL(_ store: DropStore) -> URL {
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [URLQueryItem(name: "q", value: "\(store.name) \(store.area)")]
        return c.url!
    }

    private var summary: some View {
        let base: [(String, String, Bool)] = [("Item total", rupees(flow.itemTotal), false),
                                              ("Item discount", rupees(-flow.itemDiscount), true),
                                              ("Coupon discount", rupees(-flow.coupon), true)]
        let footer = "You saved \(rupees(flow.savings)) on this order"
        return Group {
            switch (flow.plan, flow.balancePaid) {
            case (.full, _):
                DropBillSummary(rows: base, total: ("Total paid", flow.total), footer: footer)
            case (.reserve, false):
                DropBillSummary(rows: base + [("Paid to reserve (25%)", rupees(-flow.reserveNow), true)],
                                total: ("Remaining amount", flow.reserveLater), footer: footer)
            case (.reserve, true):
                DropBillSummary(rows: base + [("Paid to reserve (25%)", rupees(flow.reserveNow), false),
                                              ("Balance paid", rupees(flow.reserveLater), false)],
                                total: ("Total paid", flow.total), footer: footer)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            sectionLabel("Your details")
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Image(systemName: "person")
                    .font(.system(size: 17))
                    .foregroundStyle(M.iconTertiary)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text("Aarav Mehta").backstageText(.title4).fontWeight(.medium).foregroundStyle(P.softWhite)
                    Text("+91 XXXXXXXXXX").backstageText(.body3).foregroundStyle(M.iconTertiary)
                    Text("aarav.mehta@example.com").backstageText(.body3).foregroundStyle(M.iconTertiary)
                }
                Spacer()
            }
            .padding(R.spacingSpace16)
            .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
        }
    }
}
