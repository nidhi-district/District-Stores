import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Product page opened from "Hot off the rack": gallery, details, size, store availability,
/// pairings, and a floating glass bar to reserve a try-on.
struct ProductDetailView: View {
    @State var product: Product
    @State private var size: String?
    @State private var reserved = false
    @State private var shot: Int? = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var detail: EditorialData.ProductDetail? { EditorialData.productDetails[product.name] }
    private var store: String { EditorialData.storeAreas[product.brand] ?? "Gurugram" }
    private var sizes: [String] { product.category == "Denim" ? ["26", "28", "30", "32", "34"] : ["XS", "S", "M", "L", "XL"] }

    /// Pieces from other categories that complete the look.
    private var pairings: [Product] {
        EditorialData.products.filter { $0.category != product.category && $0.id != product.id }.prefix(4).map { $0 }
    }

    var body: some View {
        GeometryReader { screen in
            ZStack(alignment: .top) {
                backdrop

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: R.spacingSpace24) {
                            Color.clear.frame(height: 0).id("productTop")
                            gallery
                            info
                            sizePicker
                            details
                            storeCard
                            completeTheLook(proxy)
                        }
                        .padding(.top, screen.safeAreaInsets.top + 60)
                        .padding(.bottom, 140)
                    }
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(edges: .top)
                }

                controls
            }
            .overlay(alignment: .bottom) { reserveBar }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: reserved) { _, new in new }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        let colour = DominantColor.of(product.art)
        return RadialGradient(
            colors: [colour.opacity(0.3), colour.opacity(0.08), colour.opacity(0)],
            center: UnitPoint(x: 0.5, y: 0.25), startRadius: 0, endRadius: 520
        )
        .ignoresSafeArea()
        .id(product.id)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: product.id)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Gallery

    /// The full shot plus two close-up crops of the same photo.
    private var gallery: some View {
        let crops: [(scale: CGFloat, anchor: UnitPoint)] = [(1, .center), (1.9, .top), (1.9, .bottom)]
        return VStack(spacing: R.spacingSpace12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace8) {
                    ForEach(crops.indices, id: \.self) { i in
                        ArtView(art: product.art)
                            .scaleEffect(crops[i].scale, anchor: crops[i].anchor)
                            .clipped()
                            .frame(height: 460)
                            .clipShape(EditorialCard.shape)
                            .overlay(alignment: .topLeading) {
                                if i == 0, product.isNew { NewBadge().padding(R.spacingSpace12) }
                            }
                            .containerRelativeFrame(.horizontal) { width, _ in width - R.spacingSpace32 }
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $shot)
            .scrollIndicators(.hidden)
            .id(product.id)

            HStack(spacing: R.spacingSpace4 + 2) {
                ForEach(crops.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == (shot ?? 0) ? M.iconPrimary : M.iconTertiary)
                        .frame(width: i == (shot ?? 0) ? 18 : 6, height: 6)
                }
            }
            .animation(.snappy, value: shot)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photos of \(product.name)")
        .accessibilityValue("Photo \((shot ?? 0) + 1) of 3")
        .accessibilityAdjustableAction { direction in
            let now = shot ?? 0
            switch direction {
            case .increment: shot = min(2, now + 1)
            case .decrement: shot = max(0, now - 1)
            @unknown default: break
            }
        }
    }

    // MARK: Info

    private var info: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace12) {
                BrandMark(brand: product.brand, mark: product.mark, size: 40)
                VStack(alignment: .leading, spacing: R.spacingSpace0) {
                    Text(product.brand)
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                    Text(product.category)
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                }
            }
            Text(product.name)
                .editorialDisplay(DisplaySize.title)
                .foregroundStyle(M.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail.description)
                    .backstageText(.body1)
                    .foregroundStyle(M.textSecondary)
            }
        }
        .padding(.horizontal, R.spacingSpace20)
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            HStack {
                Text("Size")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                Spacer()
                Button("Size guide") {}
                    .buttonStyle(BackstageTextButtonStyle())
            }
            HStack(spacing: R.spacingSpace8) {
                ForEach(sizes, id: \.self) { s in
                    let active = s == size
                    Button {
                        withAnimation(.snappy) { size = s; reserved = false }
                    } label: {
                        Text(s).frame(minWidth: 28)
                    }
                    .buttonStyle(BackstageFilterButtonStyle(isActive: active))
                    .accessibilityLabel("Size \(s)")
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, R.spacingSpace20)
        .sensoryFeedback(.selection, trigger: size)
    }

    private var details: some View {
        VStack(spacing: R.spacingSpace0) {
            if let detail {
                row("Material", detail.material)
                row("Fit", detail.fit)
                row("Care", detail.care)
            }
        }
        .padding(.horizontal, R.spacingSpace20)
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(spacing: R.spacingSpace0) {
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .backstageText(.label3)
                    .foregroundStyle(M.textTertiary)
                Spacer(minLength: R.spacingSpace16)
                Text(value)
                    .backstageText(.body3)
                    .foregroundStyle(M.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, R.spacingSpace12)
        }
        .accessibilityElement(children: .combine)
    }

    private var storeCard: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            Image(systemName: "storefront")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 44, height: 44)
                .background(M.surfaceTransparent, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                Text("Try it at \(product.brand)")
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                Text(store)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                Label("In stock in most sizes", systemImage: "checkmark")
                    .backstageText(.body3)
                    .foregroundStyle(M.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(R.spacingSpace16)
        .background(M.surfaceTransparent, in: EditorialCard.shape)
        .overlay(EditorialCard.shape.strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .padding(.horizontal, R.spacingSpace20)
        .accessibilityElement(children: .combine)
    }

    private func completeTheLook(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Text("Complete the look")
                .backstageText(.label1)
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace20)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                    ForEach(pairings) { item in
                        Button {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                                product = item
                                size = nil
                                reserved = false
                                shot = 0
                            }
                            proxy.scrollTo("productTop", anchor: .top)
                        } label: {
                            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                                ArtView(art: item.art)
                                    .frame(width: 150, height: 190)
                                    .clipShape(EditorialCard.shape)
                                VStack(alignment: .leading, spacing: R.spacingSpace0) {
                                    Text(item.name)
                                        .backstageText(.label2)
                                        .foregroundStyle(M.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(item.brand)
                                        .backstageText(.label2)
                                        .foregroundStyle(M.textSecondary)
                                }
                            }
                            .frame(width: 150, alignment: .leading)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(item.name) by \(item.brand)")
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Chrome

    private var controls: some View {
        GlassGroup(spacing: R.spacingSpace8) {
            HStack {
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                Spacer()
                ShareLink(item: "\(product.name) by \(product.brand), on District") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 44, height: 44)
                        .liquidGlass(in: Circle(), interactive: true, clear: true)
                }
                .accessibilityLabel("Share \(product.name)")
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace4)
    }

    /// Floating glass action bar: chosen size and the reserve action.
    private var reserveBar: some View {
        HStack(spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                Text(size.map { "Size \($0)" } ?? "Select a size")
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                Text(reserved ? "Held for 24 hours at \(product.brand)" : "Try it on in store, no payment")
                    .backstageText(.finePrint1)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: R.spacingSpace8)
            if reserved {
                Button { withAnimation(.snappy) { reserved = false } } label: {
                    Label("Reserved", systemImage: "checkmark")
                }
                .buttonStyle(BackstageSecondaryButtonStyle())
                .accessibilityHint("Cancels the reservation")
            } else {
                Button("Reserve to try") { withAnimation(.snappy) { reserved = true } }
                    .buttonStyle(BackstagePrimaryButtonStyle())
                    .disabled(size == nil)
                    .accessibilityHint(size == nil ? "Select a size first" : "")
            }
        }
        .padding(.leading, R.spacingSpace20)
        .padding(.trailing, R.spacingSpace8)
        .padding(.vertical, R.spacingSpace8)
        .liquidGlass(in: Capsule())
        .padding(.horizontal, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

#Preview {
    ProductDetailView(product: EditorialData.products[1]).preferredColorScheme(.dark)
}
