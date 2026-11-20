import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Brand wall

/// A mall's brands as a flat moving wall: three rows of square logo tiles drifting in opposite directions at
/// different speeds. A new mall flips the tiles over in a wave from left to right, like a departures board.
/// Tiles stay tappable while they move: every position is recomputed each frame and hit-testing follows it.
struct MallBrandWall: View {
    let mall: MallShop
    var paused = false
    var tile: CGFloat = 68
    var rows = 3
    let onBrand: (MallBrand) -> Void

    @State private var swap = WallSwap()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let gap: CGFloat = 10
    /// Points a second; negative rows drift right.
    private static let speeds: [Double] = [20, -14, 26]

    /// The last mall, for the flip wave; outside SwiftUI state so frames don't re-render the tree.
    private final class WallSwap {
        var previous: MallShop?
        var start = -100.0
    }

    var body: some View {
        let height = tile * CGFloat(rows) + Self.gap * CGFloat(rows - 1)
        GeometryReader { geo in
            let width = geo.size.width
            TimelineView(.animation(paused: paused || reduceMotion)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<rows, id: \.self) { r in
                        row(r, t: t, width: width, centreY: tile / 2 + CGFloat(r) * (tile + Self.gap))
                    }
                }
                .frame(width: width, height: height)
            }
        }
        .frame(height: height)
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.07),
                                   .init(color: .black, location: 0.93), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .onChange(of: mall) { old, _ in
            swap.previous = old
            swap.start = Date().timeIntervalSinceReferenceDate
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Brands in \(mall.name)")
    }

    private static func brands(_ mall: MallShop, row: Int) -> [MallBrand] {
        MallCatalog.shuffled(mall.wallBrands, seed: mall.name + ["a", "b", "c"][row])
    }

    private static func wrap(_ k: Int, _ n: Int) -> Int { ((k % n) + n) % n }

    /// Tile k sits at k·pitch − s from the left edge; only the slots on screen are built. Travel never wraps, so a
    /// mall with a different number of brands swaps in without a jump.
    private func row(_ r: Int, t: Double, width: CGFloat, centreY: CGFloat) -> some View {
        let current = Self.brands(mall, row: r)
        let swapAge = t - swap.start
        let old = swapAge < 1.6 ? swap.previous.map { Self.brands($0, row: r) } : nil
        let pitch = Double(tile + Self.gap)
        let s = t * Self.speeds[r] + Double(r) * 97
        let first = Int((s / pitch).rounded(.down)) - 1
        let last = Int(((s + Double(width)) / pitch).rounded(.up)) + 1
        let slots = Array(first...last)

        return ForEach(slots, id: \.self) { k in
            if !current.isEmpty {
                let x = Double(k) * pitch - s + Double(tile) / 2
                let flip: Double = {
                    guard old != nil else { return 1 }
                    let delay = 0.5 * max(0, min(1, x / Double(width))) + Double(r) * 0.08
                    return max(0, min(1, (swapAge - delay) / 0.4))
                }()
                let brand = flip < 0.5 ? (old.map { $0[Self.wrap(k, $0.count)] } ?? current[Self.wrap(k, current.count)])
                                       : current[Self.wrap(k, current.count)]
                let flipAngle = flip < 1 ? (flip < 0.5 ? flip * .pi : (flip - 1) * .pi) : 0

                Button { onBrand(brand) } label: {
                    MallBrandLogo(brand: brand, size: tile)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle())
                .rotation3DEffect(.radians(flipAngle), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .position(x: x, y: Double(centreY))
                .accessibilityLabel(brand.name)
                .accessibilityHint("Opens \(brand.name)'s catalogue")
                .accessibilityHidden(x < 0 || x > Double(width))
            }
        }
    }
}

// MARK: - Stores home entry

/// "Shop a mall" on Stores home, edge to edge with no card around it: the mall's photo as a backdrop under
/// "Shop in <mall> ⌄", then its brand wall (a tile opens that brand) and "Step inside". It moves on to the next
/// mall by itself (photo crossfades, name rolls, dots follow) so it's clear the mall can change; tapping the
/// heading opens a plain list of malls and stops the cycling.
struct MallEntry: View {
    var paused = false
    /// The mall, and the edit to open on (a brand's spotlight), if any.
    let open: (MallShop, String?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mall = MallCatalog.malls[0]
    @State private var visible = true
    @State private var cycling = true
    @State private var picking = false

    private static let dwell: Double = 4

    private var running: Bool { cycling && visible && !paused && !picking && !reduceMotion }

    private static let photoHeight: CGFloat = 170
    private static let tile: CGFloat = 56
    private static let wallGap: CGFloat = 12
    private static let radius: CGFloat = 24
    /// From the top of the photo to the middle of the logo rows: where the glow and the outline fade out.
    private static var glowHeight: CGFloat { photoHeight + wallGap + tile + 5 }

    var body: some View {
        VStack(spacing: R.spacingSpace16) {
            VStack(spacing: Self.wallGap) {
                ZStack(alignment: .bottomLeading) {
                    backdrop
                    heading
                        .padding(.horizontal, R.spacingSpace16)
                        .padding(.bottom, R.spacingSpace16)
                }
                .frame(height: Self.photoHeight)

                MallBrandWall(mall: mall, paused: paused || !visible, tile: Self.tile, rows: 2) { brand in
                    open(mall, "brand-\(brand.name)")
                }
                // The lower row blurs and fades away under "Step inside".
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: Self.tile * 0.95)
                        .mask {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        }
                        .allowsHitTesting(false)
                }
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5),
                                           .init(color: .black.opacity(0.35), location: 0.8), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .background(alignment: .top) { glow }
            .overlay(alignment: .top) { outline }

            Button { open(mall, nil) } label: {
                HStack(spacing: R.spacingSpace8) {
                    Text("Step inside \(mall.short)")
                        .contentTransition(.opacity)
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                }
                .backstageText(.label1)
                .foregroundStyle(M.textInverse)
                .padding(.horizontal, R.spacingSpace24)
                .frame(height: 44)
                .background(M.surfaceInverse, in: Capsule())
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            // Sits over the faded lower row of logos.
            .padding(.top, -R.spacingSpace16)
            .accessibilityHint("Opens every brand in \(mall.name)")
        }
        .modifier(ScrollVisibility(visible: $visible))
        .task(id: running) { await cycle() }
        .task(id: mall) {
            // Warm the canvas's photos so it opens full.
            await MallImages.shared.preload(mall.edits.flatMap(\.covers))
        }
        .sensoryFeedback(.selection, trigger: mall)
    }

    /// The mall's photo inside the outline, rounded at the top and dissolving at the bottom into the glow.
    /// Crossfades when the mall changes; tapping it steps inside.
    private var backdrop: some View {
        Color.clear
            .overlay {
                Image(mall.hub?.image ?? "")
                    .resizable()
                    .scaledToFill()
                    .id(mall.name)
                    .transition(.opacity)
            }
            .overlay {
                // Keeps the white heading readable.
                ZStack {
                    LinearGradient(stops: [.init(color: .black.opacity(0.05), location: 0), .init(color: .black.opacity(0.35), location: 0.4),
                                           .init(color: .black.opacity(0.8), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    // Extra shade on the left, under the heading.
                    LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .leading, endPoint: UnitPoint(x: 0.75, y: 0.5))
                }
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: Self.radius, topTrailingRadius: Self.radius, style: .continuous))
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.8),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) { dots.padding(R.spacingSpace12) }
            .contentShape(Rectangle())
            .onTapGesture { open(mall, nil) }
            .accessibilityHidden(true)
    }

    /// The photo's own colours, heavily blurred, washing down behind the logos to the middle of the rows.
    private var glow: some View {
        Color.clear
            .frame(height: Self.glowHeight + 40)
            .overlay {
                Image(mall.hub?.image ?? "")
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 48, opaque: true)
                    .saturation(1.2)
                    .id(mall.name)
                    .transition(.opacity)
            }
            .clipped()
            .opacity(0.32)
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                       .init(color: .black, location: 0.62), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// A hairline container that starts with the photo and fades away by the middle of the logos.
    private var outline: some View {
        RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
            .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.22), location: 0),
                                                 .init(color: .white.opacity(0.1), location: 0.6),
                                                 .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom),
                          lineWidth: R.stroke1Px)
            .frame(height: Self.glowHeight + 24)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Which mall is on show; the current one stretches.
    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(MallCatalog.malls) { m in
                Capsule()
                    .fill(.white.opacity(m == mall ? 0.95 : 0.4))
                    .frame(width: m == mall ? 14 : 5, height: 5)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 15)
        .background(.black.opacity(0.3), in: Capsule())
        .animation(.snappy, value: mall)
    }

    /// "Shop in" over "<mall> ⌄" (18pt) and its area and distance; tapping it switches mall.
    private var heading: some View {
        Button {
            cycling = false
            picking = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Shop in")
                    .backstageText(.body2)
                    .foregroundStyle(M.textWhite.opacity(0.92))
                HStack(spacing: R.spacingSpace8) {
                    // Only the name changes: it rolls up inside its own line; the rest of the heading stays put.
                    Text(mall.name)
                        .backstageText(.hubTitle1)
                        .foregroundStyle(M.textWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .id(mall.name)
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)))
                        .frame(height: 30)
                        .clipped()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(M.textWhite.opacity(0.85))
                }
                Text([mall.area, mall.distance].filter { !$0.isEmpty }.joined(separator: " · "))
                    .backstageText(.hubBody2)
                    .foregroundStyle(M.textWhite.opacity(0.9))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .padding(.top, 2)
            }
            .shadow(color: .black.opacity(0.7), radius: 6, y: 1)
            .frame(minHeight: 44, alignment: .bottomLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Shop in \(mall.name)")
        .accessibilityHint("Choose another mall")
        .accessibilityAddTraits(.isHeader)
        .popover(isPresented: $picking, arrowEdge: .top) {
            MallPickerList(current: mall) { m in
                picking = false
                withAnimation(.smooth(duration: 0.4)) { mall = m }
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Holds each mall for a few seconds, then rolls on to the next.
    private func cycle() async {
        guard running else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.dwell))
            guard !Task.isCancelled else { return }
            let malls = MallCatalog.malls
            let next = malls[((malls.firstIndex(of: mall) ?? 0) + 1) % malls.count]
            withAnimation(.smooth(duration: 0.45)) { mall = next }
            try? await Task.sleep(for: .seconds(0.9))
        }
    }
}

/// Stores home's mall dropdown: just the malls, nearest first, with how far each is.
private struct MallPickerList: View {
    let current: MallShop
    let choose: (MallShop) -> Void

    private var malls: [MallShop] {
        MallCatalog.malls.sorted { ($0.hub?.distanceKm ?? .greatestFiniteMagnitude) < ($1.hub?.distanceKm ?? .greatestFiniteMagnitude) }
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(malls) { m in
                let selected = m == current
                Button { choose(m) } label: {
                    HStack(spacing: R.spacingSpace12) {
                        Text(m.name)
                            .backstageText(.label1)
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: R.spacingSpace12)
                        Text(m.distance)
                            .backstageText(.body3)
                            .foregroundStyle(selected ? M.textPrimary.opacity(0.8) : M.textSecondary)
                    }
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(height: 50)
                    .background {
                        // The current mall sits on a filled pill instead of a tick.
                        if selected {
                            RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                                .fill(M.surfaceSelectionPurple)
                                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                                    .strokeBorder(M.borderSelectionPurple.opacity(0.5), lineWidth: R.stroke1Px))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(R.spacingSpace8)
        .frame(width: 340)
    }
}

/// Pauses offscreen animation where the OS can tell us (iOS 18+).
private struct ScrollVisibility: ViewModifier {
    @Binding var visible: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.02) { visible = $0 }
        } else {
            content
        }
    }
}
