import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// The "District Vogue" app's Explore tab: the page read as a printed issue. A Vogue-style cover
// with a Didone masthead, then a CRED Periscope-style reading run: editor's letter, numbered
// contents, features, the edit, street style, a colour report and an occasion index, closing on a
// back page. Each part is a "page" with its own paper colour, and the whole screen cross-fades to
// it as the page scrolls in. Content and detail screens are shared with the main app.

// MARK: - Type

/// Bodoni Moda (a true Didone, as on fashion mastheads) for display and italics; Inter for running
/// text and small caps. Both are variable: weight, plus optical size so Bodoni's hairlines stay
/// fine at headline sizes and sturdy in small text.
enum VogueType {
    static func serif(_ size: CGFloat, weight: CGFloat = 400, italic: Bool = false) -> Font {
        variable(italic ? "BodoniModa-Italic" : "BodoniModa-Regular", size: size, weight: weight,
                 opticalSize: min(96, max(6, size)))
    }

    static func sans(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        variable("Inter-Regular", size: size, weight: weight, opticalSize: min(32, max(14, size)))
    }

    private static func variable(_ name: String, size: CGFloat, weight: CGFloat, opticalSize: CGFloat) -> Font {
        #if canImport(UIKit)
        let wght = 0x7767_6874, opsz = 0x6F70_737A // 'wght', 'opsz'
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: name,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: weight, opsz: opticalSize],
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
        #else
        return .custom(name, fixedSize: size)
        #endif
    }
}

private extension View {
    /// Tracked small capitals for kickers, issue lines and credits.
    func vogueCaps(_ size: CGFloat = 10.5, tracking: CGFloat = 2.2) -> some View {
        font(VogueType.sans(size, weight: 600)).tracking(tracking).textCase(.uppercase)
    }
}

// MARK: - Paper

/// A page's paper and ink. Editorial colours, picked like a magazine's stock, so they sit outside
/// the app's UI tokens.
struct VogueTone: Equatable {
    let paper: Color
    let ink: Color

    var soft: Color { ink.opacity(0.72) }
    var faint: Color { ink.opacity(0.46) }
    var rule: Color { ink.opacity(0.2) }
    var hairline: Color { ink.opacity(0.1) }

    static let noir = VogueTone(paper: Color(hex: 0x0E0D0C), ink: Color(hex: 0xF3EFE7))
    static let ivory = VogueTone(paper: Color(hex: 0xF1EBDF), ink: Color(hex: 0x17130F))
    static let oxblood = VogueTone(paper: Color(hex: 0x4A0F19), ink: Color(hex: 0xF7E9E3))
    static let forest = VogueTone(paper: Color(hex: 0x14211A), ink: Color(hex: 0xEDE8DA))

    /// Paper dyed a deep shade of a palette colour, with light ink.
    static func dyed(_ hex: UInt32) -> VogueTone {
        let scale = 0.32
        let r = Double((hex >> 16) & 0xFF) * scale, g = Double((hex >> 8) & 0xFF) * scale, b = Double(hex & 0xFF) * scale
        return VogueTone(paper: Color(red: r / 255, green: g / 255, blue: b / 255), ink: Color(hex: 0xF3EFE7))
    }
}

private struct VogueToneKey: EnvironmentKey {
    static let defaultValue = VogueTone.noir
}

private struct VoguePressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The paper and ink of the page a view sits on.
    var vogueTone: VogueTone {
        get { self[VogueToneKey.self] }
        set { self[VogueToneKey.self] = newValue }
    }

    /// Whether the enclosing `VoguePressStyle` button is held down.
    var voguePressed: Bool {
        get { self[VoguePressedKey.self] }
        set { self[VoguePressedKey.self] = newValue }
    }
}

/// Lets a row restyle itself while pressed (it reads `voguePressed`), rather than just dimming.
struct VoguePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.voguePressed, configuration.isPressed)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}

// MARK: - Page

/// The parts of the issue the contents page can jump to.
enum VogueSection: Int, CaseIterable, Hashable {
    case features, edit, street, colour, occasions

    var title: String {
        switch self {
        case .features: "The features"
        case .edit: "The edit"
        case .street: "Street style"
        case .colour: "The colour report"
        case .occasions: "Where to wear it"
        }
    }

    var dek: String {
        switch self {
        case .features: "Homegrown labels, in their own words"
        case .edit: "New on the rails this week"
        case .street: "Looks you can shop, piece by piece"
        case .colour: "Palettes worth dressing in"
        case .occasions: "Fits for every plan"
        }
    }
}

struct VogueExploreView: View {
    @State private var scrollY: CGFloat = 0
    @State private var reading: Story?
    /// Top edge of each page on screen, by page number.
    @State private var pageTops: [Int: CGFloat] = [:]
    /// The palette centred in the colour report; it dyes that page's paper.
    @State private var palette = EditorialData.palettes[0]
    @Environment(\.tabBarCompactHandler) private var setTabBarCompact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The cover story: Cord, shot in warm light with room above for the masthead.
    private var coverStory: Story { EditorialData.stories.first { $0.brand == "Cord" } ?? EditorialData.stories[0] }

    /// Paper for each page, in reading order.
    private func tone(_ page: Int) -> VogueTone {
        switch page {
        case 1, 3: .ivory
        case 4: .oxblood
        case 6: .dyed(palette.hexes[0])
        case 7: .forest
        default: .noir
        }
    }

    var body: some View {
        GeometryReader { screen in
            let viewport = screen.size.height
            // The page whose top has come two-thirds of the way up the screen owns the background.
            let current = pageTops.filter { $0.value < viewport * 0.66 }.keys.max() ?? 0

            ScrollViewReader { proxy in
                ZStack(alignment: .top) {
                    tone(current).paper
                        .ignoresSafeArea()
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: tone(current))

                    ScrollView(.vertical) {
                        VStack(spacing: R.spacingSpace0) {
                            VogueCover(story: coverStory, height: viewport + screen.safeAreaInsets.top,
                                       topInset: screen.safeAreaInsets.top, scrollY: scrollY) {
                                reading = coverStory
                            }
                            .page(0, tone: tone(0), report: report)

                            VStack(spacing: 96) {
                                EditorsLetter()
                                VogueContents { section in
                                    withAnimation(.smooth) { proxy.scrollTo(section, anchor: .top) }
                                }
                            }
                            .page(1, tone: tone(1), report: report)

                            VogueFeatures(skipping: coverStory) { reading = $0 }
                                .id(VogueSection.features)
                                .page(2, tone: tone(2), report: report)
                            VogueEdit()
                                .id(VogueSection.edit)
                                .page(3, tone: tone(3), report: report)
                            VoguePullQuote(viewport: viewport)
                                .page(4, tone: tone(4), report: report)
                            VogueStreetStyle()
                                .id(VogueSection.street)
                                .page(5, tone: tone(5), report: report)
                            VogueColourReport(focused: $palette)
                                .id(VogueSection.colour)
                                .page(6, tone: tone(6), report: report)
                            VogueOccasions()
                                .id(VogueSection.occasions)
                                .page(7, tone: tone(7), report: report)
                            VogueBackPage()
                                .page(8, tone: tone(8), report: report)
                                .padding(.bottom, R.spacingSpace48)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(edges: .top)
                    .modifier(ExploreScrollTracker { y in
                        let delta = y - scrollY
                        if y > -40 { setTabBarCompact(false) }
                        else if delta < -6 { setTabBarCompact(true) }
                        else if delta > 6 { setTabBarCompact(false) }
                        scrollY = y
                    })

                    TopBar(scrolled: scrollY < -8)
                }
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: current)
        }
        .readerCover(item: $reading) { StoryReaderView(story: $0) }
    }

    private func report(_ page: Int, _ top: CGFloat) {
        if pageTops[page] != top { pageTops[page] = top }
    }
}

private extension View {
    /// Marks a page of the issue: sets its ink for everything inside and reports where its top is.
    func page(_ number: Int, tone: VogueTone, report: @escaping (Int, CGFloat) -> Void) -> some View {
        self
            .padding(.vertical, number == 0 ? 0 : 72)
            .environment(\.vogueTone, tone)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { report(number, $0) }
    }
}

// MARK: - Cover

/// Full-bleed cover: a Didone masthead rising from behind its rule, the issue line, cover lines
/// stepping in down the left, and the cover credit at the foot. The photo drifts in slowly; on
/// scroll the masthead lags behind and fades. Tapping the cover opens the cover story.
struct VogueCover: View {
    let story: Story
    let height: CGFloat
    /// Status bar height; the masthead starts below it and the tab header.
    let topInset: CGFloat
    let scrollY: CGFloat
    let open: () -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var depth: CGFloat { max(0, -scrollY) }

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .topLeading) {
                ArtView(art: story.art, parallax: 0.12)
                    .scaleEffect(shown || reduceMotion ? 1 : 1.12)
                    .animation(.easeOut(duration: 6), value: shown)
                LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.55), location: 0),
                    .init(color: Color.black.opacity(0), location: 0.32),
                    .init(color: Color.black.opacity(0), location: 0.48),
                    .init(color: Color.black.opacity(0.85), location: 1),
                ], startPoint: .top, endPoint: .bottom)

                VStack(alignment: .leading, spacing: R.spacingSpace0) {
                    masthead
                        .offset(y: depth * 0.45)
                        .opacity(1 - min(1, depth / 420))
                    Spacer(minLength: 0)
                    coverLines
                    credit
                        .opacity(shown ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(1.2), value: shown)
                }
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, topInset + 72)
                .padding(.bottom, 104)
            }
            .frame(height: height)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("District, issue 07. Cover story: \(story.brand), \(story.title)")
        .accessibilityHint("Opens the cover story")
        .accessibilityAddTraits(.isButton)
    }

    private var masthead: some View {
        VStack(spacing: R.spacingSpace8) {
            Text("DISTRICT")
                .font(VogueType.serif(132, weight: 900))
                .tracking(-4)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.white)
                // Rises up from behind the rule.
                .offset(y: shown || reduceMotion ? 0 : 140)
                .animation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.15), value: shown)
                .clipped()
            HStack(spacing: R.spacingSpace8) {
                Rectangle().fill(Color.white.opacity(0.6)).frame(height: R.stroke1Px)
                    .scaleEffect(x: shown || reduceMotion ? 1 : 0, anchor: .trailing)
                Text("Nº 07  ·  October 2026  ·  Gurugram")
                    .vogueCaps(tracking: 2.6)
                    .foregroundStyle(Color.white)
                    .fixedSize()
                Rectangle().fill(Color.white.opacity(0.6)).frame(height: R.stroke1Px)
                    .scaleEffect(x: shown || reduceMotion ? 1 : 0, anchor: .leading)
            }
            .animation(.easeInOut(duration: 0.8).delay(0.5), value: shown)
        }
    }

    private var coverLines: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: -10) {
                Text("The")
                    .font(VogueType.serif(32, italic: true))
                    .modifier(StepIn(shown: shown, delay: 0.7))
                Text("Homegrown")
                    .font(VogueType.serif(60, weight: 800))
                    .tracking(-1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .modifier(StepIn(shown: shown, delay: 0.8))
                Text("issue")
                    .font(VogueType.serif(32, italic: true))
                    .modifier(StepIn(shown: shown, delay: 0.9))
            }
            .foregroundStyle(Color.white)

            Text("The labels rewriting\nhow the city dresses")
                .vogueCaps(11, tracking: 2.4)
                .lineSpacing(5)
                .foregroundStyle(Color.white)
                .modifier(StepIn(shown: shown, delay: 1.0))

            HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace8) {
                Text("Plus")
                    .font(VogueType.serif(19, italic: true))
                Text("The white tee, six ways")
                    .font(VogueType.serif(19, weight: 600))
            }
            .foregroundStyle(Color.white)
            .modifier(StepIn(shown: shown, delay: 1.1))
        }
        .padding(.bottom, R.spacingSpace24)
    }

    private var credit: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("On the cover")
                    .vogueCaps()
                    .foregroundStyle(Color.white.opacity(0.7))
                Text("\(story.brand) — \u{201C}\(story.title)\u{201D}")
                    .font(VogueType.serif(16, italic: true))
                    .foregroundStyle(Color.white)
            }
            Spacer(minLength: R.spacingSpace12)
            Text("Read")
                .vogueCaps()
                .foregroundStyle(Color.white)
                .padding(.bottom, 3)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white).frame(height: R.stroke1Px) }
        }
    }
}

/// Fades a cover line in from the left, after a delay.
private struct StepIn: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(x: shown || reduceMotion ? 0 : -24)
            .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(delay), value: shown)
    }
}

// MARK: - Shared chrome

/// Section opener: the section number on a rule that draws itself in, a serif title with an
/// italic turn sliding up line by line, and a one-line standfirst.
struct VogueOpener: View {
    let number: Int
    let title: String
    let italic: String
    let dek: String
    @Environment(\.vogueTone) private var tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace12) {
                Text("Nº \(String(format: "%02d", number))")
                    .vogueCaps()
                    .foregroundStyle(tone.faint)
                Rectangle().fill(tone.rule).frame(height: R.stroke1Px)
                    .scrollTransition(.interactive, axis: .vertical) { rule, phase in
                        rule.scaleEffect(x: reduceMotion ? 1 : 1 - max(0, phase.value), anchor: .leading)
                    }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: -6) {
                Text(title)
                    .font(VogueType.serif(46, weight: 700))
                    .modifier(KineticLine(index: 0))
                Text(italic)
                    .font(VogueType.serif(46, italic: true))
                    .modifier(KineticLine(index: 1))
            }
            .tracking(-1)
            .foregroundStyle(tone.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) \(italic)")
            .accessibilityAddTraits(.isHeader)

            Text(dek)
                .font(VogueType.serif(18, italic: true))
                .foregroundStyle(tone.soft)
                .modifier(KineticLine(index: 2))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.spacingSpace16)
    }
}

/// A text link: small caps over an underline that thickens when pressed.
private struct VogueLink: View {
    let title: String
    var color: Color
    @Environment(\.voguePressed) private var pressed

    var body: some View {
        Text(title)
            .vogueCaps()
            .foregroundStyle(color)
            .padding(.bottom, 3)
            .overlay(alignment: .bottomLeading) {
                Rectangle().fill(color).frame(height: pressed ? 2 : R.stroke1Px)
            }
    }
}

// MARK: - Editor's letter

/// A short letter from the desk, set like a printed page: a raised initial, running text and a
/// sign-off.
struct EditorsLetter: View {
    @Environment(\.vogueTone) private var tone
    private let lead = "ressing well in this city has never been about a label on the inside of a collar. It is the tailor down the lane, the studio that still cuts by hand, the stall that knows your size before you do."
    private let close = "This issue is about the people who make that possible: homegrown labels working at their own pace, the stores that stock them, and the ways you can wear them from Monday to the weekend."

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            Text("From the editor")
                .vogueCaps()
                .foregroundStyle(tone.faint)

            Text("Dressed for\nthe city")
                .font(VogueType.serif(40, weight: 500, italic: true))
                .tracking(-0.8)
                .foregroundStyle(tone.ink)
                .modifier(KineticLine(index: 0))
                .accessibilityAddTraits(.isHeader)

            (Text("D").font(VogueType.serif(72, weight: 800)).foregroundColor(tone.ink)
             + Text(lead).font(VogueType.sans(16)).foregroundColor(tone.soft))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)

            Text(close)
                .font(VogueType.sans(16))
                .foregroundStyle(tone.soft)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: R.spacingSpace12) {
                Rectangle().fill(tone.rule).frame(width: 32, height: R.stroke1Px)
                Text("The District Style Desk")
                    .font(VogueType.serif(18, italic: true))
                    .foregroundStyle(tone.ink)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }
}

// MARK: - Contents

/// "In this issue": big italic numerals, serif titles and page numbers. A held row slides along
/// and its title turns italic; letting go jumps to the section.
struct VogueContents: View {
    let jump: (VogueSection) -> Void
    @Environment(\.vogueTone) private var tone

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            VStack(alignment: .leading, spacing: -4) {
                Text("In this")
                    .font(VogueType.serif(30, italic: true))
                    .modifier(KineticLine(index: 0))
                Text("Issue")
                    .font(VogueType.serif(76, weight: 800))
                    .tracking(-2.5)
                    .modifier(KineticLine(index: 1))
            }
            .foregroundStyle(tone.ink)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: R.spacingSpace0) {
                ForEach(VogueSection.allCases, id: \.self) { section in
                    Button { jump(section) } label: { ContentsRow(section: section) }
                        .buttonStyle(VoguePressStyle())
                        .modifier(KineticLine(index: section.rawValue))
                        .accessibilityLabel("\(section.title). \(section.dek)")
                        .accessibilityHint("Jumps to this section")
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(tone.rule).frame(height: R.stroke1Px) }
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private struct ContentsRow: View {
        let section: VogueSection
        @Environment(\.vogueTone) private var tone
        @Environment(\.voguePressed) private var pressed

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace16) {
                Text(String(format: "%02d", section.rawValue + 1))
                    .font(VogueType.serif(38, italic: true))
                    .foregroundStyle(pressed ? tone.ink : tone.faint)
                    .frame(width: 52, alignment: .leading)
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(section.title)
                        .font(VogueType.serif(24, weight: pressed ? 500 : 600, italic: pressed))
                        .foregroundStyle(tone.ink)
                    Text(section.dek)
                        .font(VogueType.sans(13))
                        .foregroundStyle(tone.soft)
                }
                Spacer(minLength: 0)
                Text("p. \(String(format: "%02d", 6 + section.rawValue * 8))")
                    .vogueCaps(tracking: 1.2)
                    .foregroundStyle(tone.faint)
            }
            .offset(x: pressed ? 8 : 0)
            .padding(.vertical, R.spacingSpace16)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(tone.hairline).frame(height: R.stroke1Px) }
        }
    }
}

// MARK: - Features

/// The lead feature as a full article opener, then the rest as a numbered list whose pictures
/// ease in as they arrive.
struct VogueFeatures: View {
    let skipping: Story
    let open: (Story) -> Void
    @Environment(\.vogueTone) private var tone

    private var stories: [Story] { EditorialData.stories.filter { $0.id != skipping.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace32) {
            VogueOpener(number: 1, title: "The", italic: "features", dek: VogueSection.features.dek)
            if let lead = stories.first {
                leadFeature(lead)
            }
            VStack(spacing: R.spacingSpace0) {
                ForEach(Array(stories.dropFirst().enumerated()), id: \.element.id) { i, story in
                    Button { open(story) } label: { FeatureRow(story: story, number: i + 2) }
                        .buttonStyle(VoguePressStyle())
                        .accessibilityLabel("\(story.brand): \(story.title)")
                        .accessibilityHint("Opens the story")
                }
            }
            .padding(.horizontal, R.spacingSpace16)
        }
    }

    private func leadFeature(_ story: Story) -> some View {
        Button { open(story) } label: {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                ArtView(art: story.art, parallax: 0.1)
                    .frame(height: 480)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        Text("Photograph courtesy \(story.brand)")
                            .font(VogueType.sans(9, weight: 500))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .rotationEffect(.degrees(-90), anchor: .bottomTrailing)
                            .offset(x: -4, y: -8)
                            .fixedSize()
                    }
                    .revealOnScroll()

                VStack(alignment: .leading, spacing: R.spacingSpace12) {
                    Text("Feature  ·  \(story.brand)")
                        .vogueCaps()
                        .foregroundStyle(tone.faint)
                    Text(story.title)
                        .font(VogueType.serif(40, weight: 700))
                        .tracking(-0.8)
                        .foregroundStyle(tone.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(KineticLine(index: 0))
                    if !story.article.dek.isEmpty {
                        Text(story.article.dek)
                            .font(VogueType.serif(19, italic: true))
                            .foregroundStyle(tone.soft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .modifier(KineticLine(index: 1))
                    }
                    HStack {
                        Text("By the District Style Desk  ·  \(story.article.readTime)")
                            .font(VogueType.sans(12, weight: 500))
                            .foregroundStyle(tone.faint)
                        Spacer()
                        VogueLink(title: "Read", color: tone.ink)
                    }
                    .padding(.top, R.spacingSpace4)
                }
                .padding(.horizontal, R.spacingSpace16)
            }
        }
        .buttonStyle(VoguePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feature: \(story.brand). \(story.title)")
        .accessibilityHint("Opens the story")
        .accessibilityAddTraits(.isButton)
    }

    private struct FeatureRow: View {
        let story: Story
        let number: Int
        @Environment(\.vogueTone) private var tone
        @Environment(\.voguePressed) private var pressed

        var body: some View {
            HStack(alignment: .top, spacing: R.spacingSpace16) {
                Text(String(format: "%02d", number))
                    .font(VogueType.serif(24, italic: true))
                    .foregroundStyle(pressed ? tone.ink : tone.faint)
                    .frame(width: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    Text(story.brand)
                        .vogueCaps()
                        .foregroundStyle(tone.faint)
                    Text(story.title)
                        .font(VogueType.serif(22, weight: pressed ? 500 : 600, italic: pressed))
                        .foregroundStyle(tone.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(story.article.readTime)
                        .font(VogueType.sans(12))
                        .foregroundStyle(tone.soft)
                }
                Spacer(minLength: 0)
                ArtView(art: story.art)
                    .scaleEffect(pressed ? 1.08 : 1)
                    .frame(width: 88, height: 112)
                    .clipped()
                    .scrollTransition(.interactive, axis: .vertical) { photo, phase in
                        photo.opacity(1 - max(0, phase.value) * 0.7)
                            .offset(x: max(0, phase.value) * 30)
                    }
            }
            .padding(.vertical, R.spacingSpace20)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Rectangle().fill(tone.hairline).frame(height: R.stroke1Px) }
        }
    }
}

// MARK: - The edit

/// New arrivals as a shopping page: a two-column grid that reveals card by card, each photo
/// captioned with a number, the piece in serif, the label in caps and the price.
struct VogueEdit: View {
    @State private var opened: Product?

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace32) {
            VogueOpener(number: 2, title: "The", italic: "edit", dek: VogueSection.edit.dek)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: R.spacingSpace12), GridItem(.flexible())],
                      alignment: .leading, spacing: R.spacingSpace32) {
                ForEach(Array(EditorialData.products.enumerated()), id: \.element.id) { i, product in
                    Button { opened = product } label: { EditCell(product: product, number: i + 1) }
                        .buttonStyle(VoguePressStyle())
                        .modifier(KineticLine(index: i % 2))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(product.name) by \(product.brand), \(product.price)")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, R.spacingSpace16)
        }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
    }

    private struct EditCell: View {
        let product: Product
        let number: Int
        @Environment(\.vogueTone) private var tone
        @Environment(\.voguePressed) private var pressed

        var body: some View {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                ArtView(art: product.art)
                    .scaleEffect(pressed ? 1.06 : 1)
                    .aspectRatio(0.75, contentMode: .fit)
                    .clipped()
                HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace8) {
                    Text(String(format: "%02d", number))
                        .font(VogueType.serif(15, italic: true))
                        .foregroundStyle(tone.faint)
                    Text(product.name)
                        .font(VogueType.serif(17, weight: 600, italic: pressed))
                        .foregroundStyle(tone.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Text(product.brand)
                        .vogueCaps(tracking: 1.4)
                        .foregroundStyle(tone.soft)
                        .lineLimit(1)
                    Spacer(minLength: R.spacingSpace4)
                    Text(product.price)
                        .font(VogueType.sans(12, weight: 500))
                        .foregroundStyle(tone.soft)
                }
            }
        }
    }
}

// MARK: - Pull quote

/// The quote on oxblood paper, its words lighting up as it rises through the screen.
struct VoguePullQuote: View {
    let viewport: CGFloat
    @State private var progress: CGFloat = 0
    @Environment(\.vogueTone) private var tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let words = "Dress like the city is watching. It usually is.".split(separator: " ").map(String.init)

    var body: some View {
        let lit = reduceMotion ? words.count : Int((progress * CGFloat(words.count)).rounded(.up))
        VStack(spacing: R.spacingSpace20) {
            Text("\u{201C}")
                .font(VogueType.serif(120, weight: 800))
                .foregroundStyle(tone.faint)
                .frame(height: 64)
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(1 - progress) * -20))
                .accessibilityHidden(true)
            words.enumerated().reduce(Text("")) { line, item in
                let (i, word) = item
                let piece = Text(word + (i < words.count - 1 ? " " : ""))
                    .font(word == "watching." ? VogueType.serif(36, italic: true) : VogueType.serif(36, weight: 500))
                    .foregroundColor(i < lit ? tone.ink : tone.ink.opacity(0.22))
                return line + piece
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeOut(duration: 0.2), value: lit)
            .accessibilityLabel(words.joined(separator: " "))
            Text("The District Style Desk")
                .vogueCaps()
                .foregroundStyle(tone.faint)
        }
        .padding(.horizontal, R.spacingSpace24)
        .padding(.vertical, R.spacingSpace40)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
            progress = min(1, max(0, (viewport * 0.85 - top) / (viewport * 0.45)))
        }
    }
}

// MARK: - Street style

/// Full-bleed looks paged sideways; neighbours shrink and turn away as you swipe. Each is credited
/// like a street-style page and opens shop-the-look.
struct VogueStreetStyle: View {
    @State private var page: Int? = 0
    @State private var opened: Look?
    @Environment(\.vogueTone) private var tone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let looks = EditorialData.looks

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            VogueOpener(number: 3, title: "Street", italic: "style", dek: VogueSection.street.dek)

            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace0) {
                    ForEach(Array(looks.enumerated()), id: \.offset) { i, look in
                        Button { opened = look } label: { spread(look) }
                            .buttonStyle(VoguePressStyle())
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                                card
                                    .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * 0.12)
                                    .rotation3DEffect(.degrees(reduceMotion ? 0 : phase.value * -14), axis: (x: 0, y: 1, z: 0))
                                    .opacity(1 - abs(phase.value) * 0.5)
                            }
                            .id(i)
                            .accessibilityLabel("\(look.title). \(look.spots.map(\.item).joined(separator: ", "))")
                            .accessibilityHint("Opens shop the look")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: page)

            HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace4) {
                Text(String(format: "%02d", (page ?? 0) + 1))
                    .font(VogueType.serif(26, italic: true))
                    .foregroundStyle(tone.ink)
                    .contentTransition(.numericText())
                Text("/ \(String(format: "%02d", looks.count))")
                    .font(VogueType.serif(15, italic: true))
                    .foregroundStyle(tone.faint)
                Spacer()
                // Progress hairline across the looks.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(tone.hairline)
                        Rectangle().fill(tone.ink)
                            .frame(width: g.size.width * CGFloat((page ?? 0) + 1) / CGFloat(max(1, looks.count)))
                    }
                }
                .frame(width: 120, height: R.stroke1Px)
            }
            .animation(.snappy, value: page)
            .padding(.horizontal, R.spacingSpace16)
            .accessibilityHidden(true)
        }
        .readerCover(item: $opened) { ShopTheLookView(look: $0, start: 0) }
    }

    private func spread(_ look: Look) -> some View {
        ZStack(alignment: .bottomLeading) {
            ArtView(art: look.art)
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                Text(look.title)
                    .font(VogueType.serif(34, weight: 600, italic: true))
                    .foregroundStyle(Color.white)
                // Credits, as printed beside a street-style shot.
                Text(look.spots.map { "\($0.item), \($0.price)" }.joined(separator: "  ·  "))
                    .font(VogueType.sans(12))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                VogueLink(title: "Shop the look", color: .white)
                    .padding(.top, R.spacingSpace4)
            }
            .padding(R.spacingSpace16)
        }
        .frame(height: 540)
        .clipped()
        .padding(.horizontal, R.spacingSpace16)
    }
}

// MARK: - Colour report

/// Palettes as swatch cards: a photograph over a stack of named colour chips, like a printer's
/// colour guide. The palette in front dyes the page's paper and its chips open up taller.
struct VogueColourReport: View {
    @Binding var focused: Palette
    @State private var centred: String?
    @State private var opened: Palette?
    @Environment(\.vogueTone) private var tone

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace32) {
            VogueOpener(number: 4, title: "The colour", italic: "report", dek: VogueSection.colour.dek)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                    ForEach(EditorialData.palettes) { palette in
                        Button { opened = palette } label: { card(palette, active: palette.id == focused.id) }
                            .buttonStyle(VoguePressStyle())
                            .id(palette.id)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(palette.name): \(palette.shades.joined(separator: ", "))")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .scrollPosition(id: $centred, anchor: .leading)
            .onChange(of: centred) { _, id in
                guard let id, let palette = EditorialData.palettes.first(where: { $0.id == id }) else { return }
                withAnimation(.easeInOut(duration: 0.5)) { focused = palette }
            }
            .sensoryFeedback(.selection, trigger: focused.id)
        }
        .readerCover(item: $opened) { PaletteDetailView(palette: $0) }
    }

    private func card(_ palette: Palette, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            VStack(spacing: R.spacingSpace0) {
                ArtView(art: palette.looks[0])
                    .frame(width: 230, height: 250)
                    .clipped()
                ForEach(palette.hexes.indices, id: \.self) { i in
                    chip(palette, i, tall: active)
                }
            }
            .frame(width: 230)
            .shadow(color: Color.black.opacity(active ? 0.35 : 0), radius: 18, y: 10)

            Text(palette.name)
                .font(VogueType.serif(24, italic: true))
                .foregroundStyle(tone.ink)
            Text("\(palette.hexes.count) shades  ·  \(palette.looks.count) looks")
                .font(VogueType.sans(12))
                .foregroundStyle(tone.soft)
        }
        .opacity(active ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.35), value: active)
    }

    /// One colour as a printed chip, its name and hex set in whichever of black or white reads on it.
    private func chip(_ palette: Palette, _ i: Int, tall: Bool) -> some View {
        let hex = palette.hexes[i]
        let ink = Self.isLight(hex) ? Color.black.opacity(0.85) : Color.white
        return HStack {
            Text(i < palette.shades.count ? palette.shades[i] : "Shade \(i + 1)")
                .vogueCaps(tracking: 1.6)
            Spacer()
            Text(String(format: "#%06X", hex))
                .font(VogueType.sans(10, weight: 500))
                .monospacedDigit()
        }
        .foregroundStyle(ink)
        .padding(.horizontal, R.spacingSpace12)
        .frame(height: tall ? 40 : 32)
        .background(Color(hex: hex))
    }

    private static func isLight(_ hex: UInt32) -> Bool {
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 150
    }
}

// MARK: - Occasions

/// "Where to wear it": every plan as a line in an index, set large in serif. A held line turns
/// italic and its picture opens out.
struct VogueOccasions: View {
    @State private var opened: Plan?
    @Environment(\.vogueTone) private var tone

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace24) {
            VogueOpener(number: 5, title: "Where to", italic: "wear it", dek: VogueSection.occasions.dek)
            VStack(spacing: R.spacingSpace0) {
                ForEach(Array(EditorialData.plans.enumerated()), id: \.element.id) { i, plan in
                    Button { opened = plan } label: { OccasionRow(plan: plan) }
                        .buttonStyle(VoguePressStyle())
                        .modifier(KineticLine(index: i % 3))
                        .accessibilityLabel("\(plan.title), \(plan.count) looks")
                        .accessibilityHint("Opens the looks")
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .overlay(alignment: .top) {
                Rectangle().fill(tone.rule).frame(height: R.stroke1Px).padding(.horizontal, R.spacingSpace16)
            }
        }
        .readerCover(item: $opened) { PlanGalleryView(plan: $0) }
    }

    private struct OccasionRow: View {
        let plan: Plan
        @Environment(\.vogueTone) private var tone
        @Environment(\.voguePressed) private var pressed

        var body: some View {
            HStack(alignment: .center, spacing: R.spacingSpace12) {
                Text(plan.title)
                    .font(VogueType.serif(30, weight: pressed ? 500 : 600, italic: pressed))
                    .tracking(-0.5)
                    .foregroundStyle(tone.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: R.spacingSpace8)
                Text("\(plan.count) looks")
                    .font(VogueType.serif(15, italic: true))
                    .foregroundStyle(tone.faint)
                ArtView(art: plan.gallery[0])
                    .frame(width: pressed ? 64 : 44, height: pressed ? 80 : 56)
                    .clipped()
            }
            .padding(.vertical, R.spacingSpace12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(tone.hairline).frame(height: R.stroke1Px) }
        }
    }
}

// MARK: - Back page

struct VogueBackPage: View {
    @Environment(\.vogueTone) private var tone

    var body: some View {
        VStack(spacing: R.spacingSpace12) {
            Text("DISTRICT")
                .font(VogueType.serif(72, weight: 900))
                .tracking(-2.5)
                .foregroundStyle(tone.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .modifier(KineticLine(index: 0))
            Text("Curated by District Stores, Gurugram")
                .font(VogueType.serif(17, italic: true))
                .foregroundStyle(tone.soft)
            Text("Nº 07  ·  October 2026")
                .vogueCaps()
                .foregroundStyle(tone.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, R.spacingSpace16)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VogueExploreView().preferredColorScheme(.dark)
}
