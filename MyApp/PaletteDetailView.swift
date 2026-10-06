import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Full-screen view for "Pick your palette". Switch palettes with the chips or by swiping
/// sideways; each palette shows its shades and a captioned feed of looks.
struct PaletteDetailView: View {
    private let palettes = EditorialData.palettes
    @State private var current: String?
    @State private var viewing: Viewing?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Viewing: Equatable {
        let paletteID: String
        let index: Int
    }

    init(palette: Palette) {
        _current = State(initialValue: palette.id)
    }

    private var currentPalette: Palette { palettes.first { $0.id == current } ?? palettes[0] }

    var body: some View {
        GeometryReader { screen in
            let headerHeight = screen.safeAreaInsets.top + 132
            ZStack(alignment: .top) {
                bloom

                ScrollViewReader { pager in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: R.spacingSpace0) {
                            ForEach(palettes) { palette in
                                PaletteDetailPage(palette: palette, topInset: headerHeight) { index in
                                    withAnimation(.smooth(duration: 0.3)) {
                                        viewing = Viewing(paletteID: palette.id, index: index)
                                    }
                                }
                                .containerRelativeFrame([.horizontal, .vertical])
                                .id(palette.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $current)
                    .scrollIndicators(.hidden)
                    .onAppear { pager.scrollTo(current) }
                }
                .ignoresSafeArea()

                header
            }
            .overlay {
                if let viewing, let palette = palettes.first(where: { $0.id == viewing.paletteID }) {
                    Lightbox(looks: palette.feed, start: viewing.index) {
                        withAnimation(.smooth(duration: 0.25)) { self.viewing = nil }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: current)
    }

    /// The current palette's colours, washed faintly across the top of the screen.
    private var bloom: some View {
        let hexes = currentPalette.hexes
        let mid = CGFloat(hexes.count - 1) / 2
        return ZStack {
            ForEach(hexes.indices, id: \.self) { i in
                Circle()
                    .fill(Color(hex: hexes[i]))
                    .frame(width: 220, height: 220)
                    .offset(x: (CGFloat(i) - mid) * 90, y: (i.isMultiple(of: 2) ? -1 : 1) * 30)
            }
        }
        .blur(radius: 100)
        .opacity(0.14)
        .frame(maxWidth: .infinity)
        .offset(y: 40)
        .id(currentPalette.id)
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: currentPalette.id)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Close button and the palette switcher.
    private var header: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(.horizontal, R.spacingSpace16)

            ScrollViewReader { chips in
                ScrollView(.horizontal) {
                    GlassGroup(spacing: R.spacingSpace8) {
                        HStack(spacing: R.spacingSpace8) {
                            ForEach(palettes) { palette in
                                paletteChip(palette)
                                    .id(palette.id)
                            }
                        }
                    }
                }
                .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
                .scrollIndicators(.hidden)
                .onAppear { chips.scrollTo(current, anchor: .center) }
                .onChange(of: current) { _, id in
                    withAnimation(.snappy) { chips.scrollTo(id, anchor: .center) }
                }
            }
        }
        .padding(.top, R.spacingSpace4)
        .padding(.bottom, R.spacingSpace12)
        .background {
            LinearGradient(
                colors: [M.backgroundPrimary, M.backgroundPrimary.opacity(0.85), M.backgroundPrimary.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    private func paletteChip(_ palette: Palette) -> some View {
        let active = palette.id == current
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { current = palette.id }
        } label: {
            HStack(spacing: R.spacingSpace8) {
                PaletteWheel(hexes: palette.hexes, lineWidth: 6)
                    .frame(width: 24, height: 24)
                Text(palette.name)
                    .backstageText(.label2)
                    .lineLimit(1)
            }
            .foregroundStyle(active ? M.buttonPrimaryLabel : M.textPrimary)
            .padding(.leading, R.spacingSpace8)
            .padding(.trailing, R.spacingSpace16)
            .frame(height: 44)
            .background {
                if active { Capsule().fill(M.buttonPrimaryBackground) }
            }
            .liquidGlass(in: Capsule(), interactive: true, clear: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.name), \(palette.looks.count) looks")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - One palette

struct PaletteDetailPage: View {
    let palette: Palette
    let topInset: CGFloat
    let onSelect: (Int) -> Void

    var body: some View {
        let feed = palette.feed
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    EditorialHeadline(lines: [palette.name.lowercased()], size: DisplaySize.title)
                        .foregroundStyle(M.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(feed.count) looks in \(palette.hexes.count) shades")
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                }

                ShadeBar(palette: palette)

                LookFeed(looks: feed, onSelect: onSelect)
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, topInset + R.spacingSpace8)
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Shades

/// The palette laid out as one bar of colour, with each shade's name and hex underneath.
/// Tap a shade to widen it.
struct ShadeBar: View {
    let palette: Palette
    @State private var selected: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace4 / 2) {
            ForEach(palette.hexes.indices, id: \.self) { i in
                let isSelected = selected == i
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
                        selected = isSelected ? nil : i
                    }
                } label: {
                    VStack(alignment: .leading, spacing: R.spacingSpace8) {
                        segment(i)
                            .fill(Color(hex: palette.hexes[i]))
                            .frame(height: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name(i))
                                .backstageText(.label3)
                                .foregroundStyle(M.textPrimary)
                            Text(String(format: "#%06X", palette.hexes[i]))
                                .backstageText(.finePrint2)
                                .foregroundStyle(M.textSecondary)
                                .monospacedDigit()
                        }
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .containerRelativeFrame(.horizontal) { width, _ in
                    shareOfWidth(width, isSelected: isSelected)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(name(i))
                .accessibilityValue(String(format: "Hex %06X", palette.hexes[i]))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .onChange(of: palette.id) { selected = nil }
    }

    /// Only the bar's outer ends are rounded, matching the card radius.
    private func segment(_ i: Int) -> UnevenRoundedRectangle {
        let r: CGFloat = 12
        let first = i == 0, last = i == palette.hexes.count - 1
        return UnevenRoundedRectangle(
            topLeadingRadius: first ? r : 0, bottomLeadingRadius: first ? r : 0,
            bottomTrailingRadius: last ? r : 0, topTrailingRadius: last ? r : 0
        )
    }

    private func name(_ i: Int) -> String {
        i < palette.shades.count ? palette.shades[i] : "Shade \(i + 1)"
    }

    /// Splits the row evenly, or gives the tapped shade twice the room of the others.
    private func shareOfWidth(_ width: CGFloat, isSelected: Bool) -> CGFloat {
        let n = CGFloat(palette.hexes.count)
        let available = width - R.spacingSpace16 * 2 - (n - 1) * (R.spacingSpace4 / 2)
        guard selected != nil else { return available / n }
        let unit = available / (n + 1)
        return isSelected ? unit * 2 : unit
    }
}

#Preview {
    PaletteDetailView(palette: EditorialData.palettes[0]).preferredColorScheme(.dark)
}
