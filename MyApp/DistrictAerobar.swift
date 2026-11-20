import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// The aerobar: what the person has going on right now, as a glass bar that sits on top of the tab bar on Home and stays put
// while they scroll. One bar shows at a time; with more than one live thing they swipe sideways between them, and a pair of
// dots under the bar says how many there are. Meant to follow Figma District-X 5201:17780, which couldn't be opened while
// building this, so it follows the District aerobar pattern instead. The movie and the table are sample data.

/// A booking that's coming up soon.
struct AerobarMovie {
    let title: String
    let cinema: String
    let screen: String
    let starts: Date

    /// Starts 42 minutes after the app first asks, so the countdown always reads as "soon".
    static let tonight = AerobarMovie(title: "The Last Monsoon", cinema: "PVR Select Citywalk", screen: "Audi 4",
                                      starts: Date().addingTimeInterval(42 * 60))
}

/// A table they've booked.
struct AerobarTable {
    let restaurant: String
    let place: String
    let image: String
    let guests: Int
    let time: Date

    /// Dinner at 9 tonight.
    static let tonight = AerobarTable(restaurant: "Unico", place: "Global Foyer Mall", image: "home_cont_unico", guests: 2,
                                      time: Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now)
}

struct DistrictAerobar: View {
    enum Item: Hashable, Identifiable {
        case movie, hub, table
        var id: Self { self }
    }

    let items: [Item]
    let arrival: HubArrival
    var movie: AerobarMovie = .tonight
    var table: AerobarTable = .tonight
    /// While they read down the page: the bar in the middle draws in to a small pill, "Explore" and the hub's name, centred
    /// over the tab bar, and the ones either side and the dots fade away. It opens back out when they scroll up.
    var collapsed = false
    let openHub: () -> Void

    /// Position along the strip. With more than one bar the strip carries two copies of the bars at each end, so there's
    /// always a neighbour peeking in on both sides and it can keep going round either way: landing on a copy swaps, unseen,
    /// to the real bar it copies.
    @State private var slot = DistrictAerobar.launchPage + DistrictAerobar.lead
    @State private var dragX: CGFloat = 0
    @State private var dragging = false
    /// Only a swipe ticks; the bars turning on their own stay quiet.
    @State private var swipes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    static let height: CGFloat = 60
    static let pillHeight: CGFloat = AerobarHubPill.height
    /// Critically damped, so the glass draws in and opens out without wobbling at either end.
    private static let morph = Animation.spring(response: 0.42, dampingFraction: 1)
    /// Each bar is this much narrower than the screen on either side, so the ones before and after show at its edges.
    private static let inset: CGFloat = 34
    private static let gap: CGFloat = 6
    /// Copies of the bars before the first real one.
    private static let lead = 2
    /// A capsule, like the tab bar under it; the photo and the button sit in from its round ends, so they follow its curve.
    private static let shape = Capsule()
    private static let settle = Animation.spring(response: 0.45, dampingFraction: 0.88)
    /// How long each bar holds before the next comes round.
    private static let dwell: Duration = .seconds(4)

    /// The bar's own height plus its page dots, for whatever needs to clear it.
    static func blockHeight(count: Int) -> CGFloat { height + (count > 1 ? 14 : 0) }

    private var barHeight: CGFloat { collapsed ? Self.pillHeight : Self.height }

    private var loops: Bool { items.count > 1 }
    private var strip: [Item] {
        guard loops else { return items }
        let n = items.count
        return (-Self.lead..<(n + Self.lead)).map { items[($0 % n + n) % n] }
    }
    private var shownSlot: Int { loops ? slot : 0 }
    /// Which real bar is showing, for the dots.
    private var page: Int { loops ? ((slot - Self.lead) % items.count + items.count) % items.count : 0 }

    var body: some View {
        VStack(spacing: R.spacingSpace8) {
            GeometryReader { geo in
                let barWidth = geo.size.width - (loops ? 2 * Self.inset : 2 * R.spacingSpace16)
                let step = barWidth + Self.gap
                HStack(spacing: Self.gap) {
                    ForEach(Array(strip.enumerated()), id: \.offset) { index, item in
                        let shown = index == shownSlot
                        // How far this bar is from the middle, in bars: the neighbours sit back a little.
                        let distance = min(abs(CGFloat(index - shownSlot) + dragX / step), 1)
                        bar(item, folded: collapsed && shown, width: barWidth)
                            // Every bar keeps its full slot, so the strip doesn't shift as the middle one draws in.
                            .frame(width: barWidth, height: barHeight)
                            .allowsHitTesting(shown)
                            .overlay {
                                // A tap on a neighbour brings it into the middle rather than opening it.
                                if !shown, !collapsed {
                                    Capsule().fill(.clear).contentShape(Capsule())
                                        .onTapGesture { turn(by: index - shownSlot) }
                                }
                            }
                            .scaleEffect(1 - 0.04 * distance)
                            .opacity(collapsed && !shown ? 0 : 1 - 0.35 * distance)
                            .accessibilityHidden(!shown)
                    }
                }
                .offset(x: (geo.size.width - barWidth) / 2 - CGFloat(shownSlot) * step + dragX)
                .contentShape(Rectangle())
                // High priority, so a swipe that starts on a bar never ends up as a tap on it; a plain tap still goes through.
                .highPriorityGesture(swipe(width: barWidth), including: loops && !collapsed ? .all : .subviews)
            }
            .frame(height: barHeight)

            if loops, !collapsed {
                AerobarDots(count: items.count, page: page)
                    .transition(.opacity)
            }
        }
        .animation(Self.morph, value: collapsed)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: swipes)
        .onChange(of: items) { slot = Self.lead }
        // Restarts whenever the bar changes or a finger comes down or lifts, so each bar gets its full turn.
        .task(id: RotationKey(slot: slot, dragging: dragging, collapsed: collapsed)) { await rotate() }
        .accessibilityElement(children: .contain)
        .accessibilityScrollAction { edge in
            switch edge {
            case .leading: turn(by: -1)
            case .trailing: turn(by: 1)
            default: break
            }
        }
    }

    private struct RotationKey: Equatable {
        let slot: Int
        let dragging: Bool
        let collapsed: Bool
    }

    /// One bar on its glass. Folded, the glass draws in round the pill: the bar's own content keeps its full size and fades
    /// as the edges close over it, and the pill's line fades in once there's little left of it, so it reads as one shape.
    private func bar(_ item: Item, folded: Bool, width: CGFloat) -> some View {
        ZStack {
            content(item)
                .frame(width: width, height: Self.height)
                .opacity(folded ? 0 : 1)
                .allowsHitTesting(!folded)
                .animation(folded ? .easeOut(duration: 0.14) : .easeOut(duration: 0.24).delay(0.12), value: folded)
            AerobarHubPill(arrival: arrival, active: folded, openHub: openHub)
                .opacity(folded ? 1 : 0)
                .allowsHitTesting(folded)
                .accessibilityHidden(!folded)
                .animation(folded ? .easeOut(duration: 0.22).delay(0.16) : .easeOut(duration: 0.1), value: folded)
        }
        .frame(width: folded ? AerobarHubPill.width : width, height: folded ? Self.pillHeight : Self.height)
        .clipShape(Self.shape)
        .frostedBar(in: Self.shape)
    }

    @ViewBuilder
    private func content(_ item: Item) -> some View {
        switch item {
        case .hub: AerobarHubBar(arrival: arrival, openHub: openHub)
        case .movie: AerobarMovieBar(movie: movie)
        case .table: AerobarTableBar(table: table)
        }
    }

    // MARK: Paging

    private func swipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragging = true
                dragX = value.translation.width
            }
            .onEnded { value in
                // A flick counts as much as a long drag.
                let travel = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
                    ? value.predictedEndTranslation.width : value.translation.width
                let step = travel < -width * 0.3 ? 1 : (travel > width * 0.3 ? -1 : 0)
                withAnimation(Self.settle) {
                    slot = min(max(slot + step, 0), items.count + 2 * Self.lead - 1)
                    dragX = 0
                }
                if step != 0 { swipes += 1 }
                dragging = false
            }
    }

    private func turn(by step: Int) {
        guard loops else { return }
        withAnimation(reduceMotion ? .smooth(duration: 0.25) : Self.settle) { slot += step }
    }

    /// On a copy at either end, swap to the real bar once the slide has settled. Otherwise hold, then move on, unless a finger
    /// is on the bar or VoiceOver is reading it.
    private func rotate() async {
        // Drawn in to the pill, it stays put on the hub.
        guard loops, !collapsed else { return }
        let n = items.count
        if slot < Self.lead || slot >= n + Self.lead {
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled, !dragging else { return }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { slot = slot < Self.lead ? slot + n : slot - n }
            return
        }
        guard !dragging, !voiceOver else { return }
        try? await Task.sleep(for: Self.dwell)
        guard !Task.isCancelled, !dragging else { return }
        turn(by: 1)
    }

    /// Debug builds accept `-aerobarPage <n>`, which opens on that bar.
    private static var launchPage: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-aerobarPage"), i + 1 < args.count, let n = Int(args[i + 1]) { return max(n, 0) }
        #endif
        return 0
    }
}

// MARK: - Hub

/// Where they are: the hub's photo, its name with "You're here", and a solid white Explore button. The bar and the button both
/// open the hub.
private struct AerobarHubBar: View {
    let arrival: HubArrival
    let openHub: () -> Void

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Button(action: openHub) {
                HStack(spacing: R.spacingSpace12) {
                    Image(arrival.hub.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(M.hubPureWhite.opacity(0.16), lineWidth: R.stroke1Px))
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(M.hubTextSuccess)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().strokeBorder(Color.black.opacity(0.7), lineWidth: 1.5))
                                .offset(x: -1, y: -1)
                        }
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(arrival.hub.name)
                            .backstageText(.label1)
                            .foregroundStyle(M.hubPureWhite)
                        Text("\(Text("You're here").foregroundStyle(M.hubTextSuccess)) · \(arrival.nudge)")
                            .backstageText(.label2)
                            .foregroundStyle(M.hubPureWhite.opacity(0.64))
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens \(arrival.hub.name)")

            Button(action: openHub) {
                Text("Explore")
                    .backstageText(.title4)
                    .foregroundStyle(Color.black)
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color(hex: 0xFFFFFF), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Explore \(arrival.hub.name)")
            .padding(.trailing, 14)
        }
    }
}

// MARK: - Hub pill

/// The bar drawn in while they read down the page: the same glass as the tab bar under it, always the same length, with the
/// hub's photo, "Explore" and its name on one line, and an arrow. All white; the only colour is the photo's own, spilling
/// softly into the glass from behind it and fading out before the words, so each hub's pill is lit by its place.
private struct AerobarHubPill: View {
    static let width: CGFloat = 232
    /// Slim; the photo keeps its size and sits just inside the round end.
    static let height: CGFloat = 38

    let arrival: HubArrival
    var active = true
    let openHub: () -> Void

    var body: some View {
        Button(action: openHub) {
            HStack(spacing: 10) {
                Image(arrival.hub.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(M.hubPureWhite.opacity(0.18), lineWidth: R.stroke1Px))
                    .accessibilityHidden(true)
                Text("Explore \(arrival.hub.name)")
                    .backstageText(.title4)
                    .foregroundStyle(M.hubPureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(M.hubPureWhite.opacity(0.7))
                    .accessibilityHidden(true)
            }
            .padding(.leading, 4)
            .padding(.trailing, 15)
            .frame(width: Self.width, height: Self.height)
            .background { spill }
            .overlay { AerobarPillShine(active: active) }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Explore \(arrival.hub.name)")
        .accessibilityHint("You’re here. Opens the hub")
    }

    /// The photo, blurred right out and dimmed to a low glow, strongest behind it and gone before the words end.
    private var spill: some View {
        Image(arrival.hub.image)
            .resizable()
            .scaledToFill()
            .frame(width: Self.width, height: Self.height)
            .blur(radius: 14)
            .saturation(1.05)
            .brightness(-0.22)
            .opacity(0.7)
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.55), location: 0.25),
                                       .init(color: .black.opacity(0.18), location: 0.5), .init(color: .clear, location: 0.72)],
                               startPoint: .leading, endPoint: .trailing)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A thin line of light running round the pill's edge, as if it catches the light: a bright head with a tail that fades out
/// behind it, a slow lap every seven seconds. It travels at an even pace along the edge, round the ends and along the sides alike.
/// Only while the pill is showing; Reduce Motion leaves it off.
private struct AerobarPillShine: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let lap: Double = 7
    /// How much of the way round the light reaches, head to the end of its tail.
    private static let length: CGFloat = 0.18
    /// The tail is drawn in this many pieces, each fainter than the one before.
    private static let pieces = 30

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !active || reduceMotion)) { context in
            let head = CGFloat(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.lap) / Self.lap)
            ZStack {
                ForEach(0..<Self.pieces, id: \.self) { piece in
                    let step = Self.length / CGFloat(Self.pieces)
                    ShineArc(from: head - step * CGFloat(piece + 1), to: head - step * CGFloat(piece))
                        .stroke(Color.white.opacity(0.55 * pow(1 - Double(piece) / Double(Self.pieces), 1.8)),
                                style: StrokeStyle(lineWidth: 1, lineCap: .butt))
                }
            }
        }
        .blendMode(.plusLighter)
        .opacity(active && !reduceMotion ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A stretch of the pill's edge, from one fraction of the way round to another, carrying on past the start if it has to.
    private struct ShineArc: Shape {
        let from: CGFloat
        let to: CGFloat

        func path(in rect: CGRect) -> Path {
            // Half the line's width in, so it isn't cut by the glass's edge.
            let edge = Capsule().inset(by: 0.5).path(in: rect)
            let start = from - floor(from)
            let end = to - floor(to)
            guard start > end else { return edge.trimmedPath(from: start, to: end) }
            var path = edge.trimmedPath(from: start, to: 1)
            path.addPath(edge.trimmedPath(from: 0, to: end))
            return path
        }
    }
}

// MARK: - Movie

/// What's next: the poster, the film and where, and a ring counting down the minutes to the show.
private struct AerobarMovieBar: View {
    let movie: AerobarMovie

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            AerobarPoster()
                // The hub bar's photo is 40 across; the poster takes the same slot, so the words line up between bars.
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .backstageText(.label1)
                    .foregroundStyle(M.hubPureWhite)
                Text("\(movie.starts.formatted(date: .omitted, time: .shortened))  ·  \(movie.cinema)")
                    .backstageText(.label2)
                    .foregroundStyle(M.hubPureWhite.opacity(0.64))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            AerobarCountdown(starts: movie.starts)
                .padding(.trailing, 12)
        }
        .padding(.leading, 10)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Dining

/// A table they've booked: the restaurant's photo, who and where, and the time on the right where the movie keeps its countdown.
private struct AerobarTableBar: View {
    let table: AerobarTable

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            Image(table.image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(M.hubPureWhite.opacity(0.16), lineWidth: R.stroke1Px))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Table for \(table.guests) at \(table.restaurant)")
                    .backstageText(.label1)
                    .foregroundStyle(M.hubPureWhite)
                Text("Tonight  ·  \(table.place)")
                    .backstageText(.label2)
                    .foregroundStyle(M.hubPureWhite.opacity(0.64))
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            AerobarTime(time: table.time)
                .padding(.trailing, 12)
        }
        .padding(.leading, 10)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A booking's time in the same 40pt circle the movie's countdown uses, without the ring.
private struct AerobarTime: View {
    let time: Date

    private static let clock: DateFormatter = { let f = DateFormatter(); f.dateFormat = "h:mm"; return f }()
    private static let meridiem: DateFormatter = { let f = DateFormatter(); f.dateFormat = "a"; return f }()

    var body: some View {
        VStack(spacing: -3) {
            Text(Self.clock.string(from: time))
                .font(.custom("BeVietnamPro-SemiBold", fixedSize: 11))
                .monospacedDigit()
                .fixedSize()
            Text(Self.meridiem.string(from: time))
                .font(.custom("BeVietnamPro-Medium", fixedSize: 9))
                .opacity(0.64)
        }
        .foregroundStyle(M.hubPureWhite)
        .frame(width: 36, height: 36)
        .overlay(Circle().strokeBorder(M.hubPureWhite.opacity(0.14), lineWidth: 2.5))
        .accessibilityElement()
        .accessibilityLabel("At \(time.formatted(date: .omitted, time: .shortened))")
    }
}

/// Minutes to the show inside a ring that closes over its last hour.
private struct AerobarCountdown: View {
    let starts: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let left = max(0, Int((starts.timeIntervalSince(context.date) / 60).rounded(.up)))
            let closed = 1 - min(Double(left), 60) / 60
            ZStack {
                Circle().stroke(M.hubPureWhite.opacity(0.14), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: closed)
                    .stroke(M.hubPureWhite, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -3) {
                    Text("\(left)")
                        .font(.custom("BeVietnamPro-SemiBold", fixedSize: 13))
                        .monospacedDigit()
                    Text("min")
                        .font(.custom("BeVietnamPro-Medium", fixedSize: 9))
                        .opacity(0.64)
                }
                .foregroundStyle(M.hubPureWhite)
            }
            .frame(width: 36, height: 36)
            .accessibilityElement()
            .accessibilityLabel("Starts in \(left) minutes")
        }
    }
}

/// A small made-up poster: a monsoon dusk, rain across it, hills and the title along the bottom.
private struct AerobarPoster: View {
    private static let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1E2E), Color(hex: 0x24456A), Color(hex: 0xB65A3C), Color(hex: 0xE9955A)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFE2B8), Color(hex: 0xF4A261).opacity(0)],
                                     center: .center, startRadius: 1, endRadius: 13))
                .frame(width: 26, height: 26)
                .offset(y: 4)
            Canvas { context, size in
                var rain = Path()
                for i in 0..<16 {
                    let x = CGFloat((i * 37) % 41) - 4
                    let y = CGFloat((i * 23) % 34) - 6
                    rain.move(to: CGPoint(x: x, y: y))
                    rain.addLine(to: CGPoint(x: x - 2.5, y: y + 7))
                }
                context.stroke(rain, with: .color(.white.opacity(0.28)), lineWidth: 0.5)

                var hills = Path()
                hills.move(to: CGPoint(x: 0, y: size.height * 0.7))
                hills.addQuadCurve(to: CGPoint(x: size.width * 0.55, y: size.height * 0.72),
                                   control: CGPoint(x: size.width * 0.25, y: size.height * 0.56))
                hills.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.66),
                                   control: CGPoint(x: size.width * 0.8, y: size.height * 0.6))
                hills.addLine(to: CGPoint(x: size.width, y: size.height))
                hills.addLine(to: CGPoint(x: 0, y: size.height))
                context.fill(hills, with: .color(Color(hex: 0x120B12)))
            }
            Text("THE LAST\nMONSOON")
                .font(.system(size: 4.4, weight: .heavy))
                .tracking(0.3)
                .fixedSize()
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 4)
        }
        .frame(width: 30, height: 42)
        .clipShape(Self.shape)
        .overlay(Self.shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

// MARK: - Dots

/// Which bar is showing, out of how many: the current one is a short bar, the rest dots.
private struct AerobarDots: View {
    let count: Int
    let page: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(M.hubPureWhite.opacity(i == page ? 0.9 : 0.3))
                    .frame(width: i == page ? 14 : 5, height: 5)
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
        .accessibilityHidden(true)
    }
}
