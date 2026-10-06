import SwiftUI
import CoreText

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Fonts

enum BackstageFonts {
    static let faces = [
        "BeVietnamPro-Regular", "BeVietnamPro-Medium", "BeVietnamPro-SemiBold", "BeVietnamPro-Bold", "BeVietnamPro-ExtraBold",
        // Magazine accent faces: the cover-style section opener and the pull quote.
        "Anton-Regular", "DMSerifDisplay-Italic", "PlayfairDisplay", "PlayfairDisplay-Italic",
    ]

    /// Registers the bundled faces for this process. Call once at launch.
    static func register() {
        for face in faces {
            guard let url = Bundle.main.url(forResource: face, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Typography (the 15 named Figma text styles)

enum BackstageTextStyle {
    case heading3      // Section heading/Heading 3
    case title1        // Title/Title 1
    case title2        // Title/Title 2
    case title3        // Title/Title 3
    case title4        // Title/Title 4
    case specialTitle  // Title/Special title
    case caption       // Caption/Caption
    case body1         // Body/Body 1
    case body2         // Body/Body 2
    case body3         // Body/Body 3
    case label1        // Label/Label 1
    case label2        // Label/Label 2
    case label3        // Label/Label 3
    case finePrint1    // Fine print/Fine Print 1
    case finePrint2    // Fine print/Fine Print 2
    case button3       // Buttons & Links/Button 3

    // Title 3, Title 4, Label 2, Label 3, Body 3 and Button 3 follow the Figma "Homepage and
    // Search" file's text variables; the rest keep the Backstage reference values.

    var fontName: String {
        switch self {
        case .heading3, .title1: "BeVietnamPro-ExtraBold"
        case .title2, .specialTitle: "BeVietnamPro-Bold"
        case .title3, .title4, .label1, .button3: "BeVietnamPro-SemiBold"
        case .caption, .finePrint1, .finePrint2, .label2, .label3: "BeVietnamPro-Medium"
        case .body1, .body2, .body3: "BeVietnamPro-Regular"
        }
    }

    var size: CGFloat {
        switch self {
        case .heading3: 26
        case .title1: 22
        case .title2: 20
        case .caption, .body1: 18
        case .title3, .body2, .label1: 16
        case .title4: 14
        case .finePrint1, .body3, .label2, .button3: 12
        case .label3: 11
        case .specialTitle, .finePrint2: 10
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .heading3: 28
        case .title1, .title2, .body1: 24
        case .caption, .body2, .title3: 22
        case .label1: 20
        case .title4, .finePrint1, .body3, .button3: 18
        case .label2, .specialTitle, .finePrint2: 16
        case .label3: 14
        }
    }

    /// Tracking as a fraction of font size (Figma percent).
    var tracking: CGFloat {
        switch self {
        case .title2: -0.02
        case .title3: -0.01
        case .title4: -0.24 / 14
        case .button3: -0.24 / 12
        case .specialTitle: 0.2
        default: 0
        }
    }

    /// Dynamic Type curve each style scales along.
    var relativeTo: Font.TextStyle {
        switch self {
        case .heading3: .title
        case .title1: .title2
        case .title2: .title3
        case .title3, .title4: .headline
        case .caption, .body1: .body
        case .body2, .label1: .callout
        case .body3, .label2: .subheadline
        case .label3, .finePrint1, .button3: .caption
        case .specialTitle, .finePrint2: .caption2
        }
    }
}

private struct BackstageTextModifier: ViewModifier {
    let style: BackstageTextStyle
    @ScaledMetric private var scale: CGFloat

    /// Be Vietnam Pro's natural line height (ascent + descent) in ems.
    private static let naturalLineHeight: CGFloat = 1.265

    init(style: BackstageTextStyle) {
        self.style = style
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        let size = style.size * scale
        content
            .font(.custom(style.fontName, fixedSize: size))
            .tracking(size * style.tracking)
            .lineSpacing(max(0, (style.lineHeight - style.size * Self.naturalLineHeight) * scale))
            .textCase(style == .specialTitle ? .uppercase : nil)
    }
}

extension View {
    /// Applies a named Backstage text style, scaled with Dynamic Type.
    func backstageText(_ style: BackstageTextStyle) -> some View {
        modifier(BackstageTextModifier(style: style))
    }
}

// MARK: - Editorial display

/// Large, tight, lowercase display headlines in Be Vietnam Pro (magazine style).
/// Same family as the DS; sizes above Heading 3 are not yet a named Figma style — propose
/// `Display/Display 1` to the DS owner. Use only for section headlines and display moments.
private struct EditorialDisplayModifier: ViewModifier {
    let size: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        let s = size * scale
        content
            .font(.custom("BeVietnamPro-SemiBold", fixedSize: s))
            .tracking(-0.045 * s)
            .textCase(.lowercase)
    }
}

/// The editorial heading scale. Every display heading uses one of these sizes.
enum DisplaySize {
    /// Cover title of a long read (the story reader hero).
    static let hero: CGFloat = 24
    /// Section openers on the Explore page.
    static let section: CGFloat = 26
    /// The Explore pull quote.
    static let quote: CGFloat = 30
    /// The main title of every full-screen view.
    static let title: CGFloat = 20
    /// Headings inside cards, sub-headings inside screens, pull quotes and the ticker.
    static let card: CGFloat = 16
}

extension View {
    func editorialDisplay(_ size: CGFloat) -> some View {
        modifier(EditorialDisplayModifier(size: size))
    }
}

/// Multi-line display headline with tight leading (lines stacked closer than the font's natural height).
struct EditorialHeadline: View {
    let lines: [String]
    var size: CGFloat = DisplaySize.title
    /// Lines slide up, staggered, as the headline scrolls into view.
    var kinetic = false
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: -size * scale * 0.26) {
            ForEach(lines.indices, id: \.self) { i in
                Text(lines[i])
                    .editorialDisplay(size)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .modifier(KineticLine(index: i, enabled: kinetic))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lines.joined(separator: " "))
    }
}

// MARK: - Elevation

enum BackstageElevation {
    case none, shadow50, shadow100, shadow200, floating
}

extension View {
    /// Elevation styles. Blur/offset values approximate the Figma effect styles until they are exported.
    @ViewBuilder
    func elevation(_ level: BackstageElevation) -> some View {
        switch level {
        case .none: self
        case .shadow50: shadow(color: M.effectsBlackShadow8, radius: 4, y: 2)
        // Figma shadow-m (y 4, blur 16) and shadow-l (y 8, blur 32); SwiftUI radius ≈ blur / 2.
        case .shadow100: shadow(color: M.effectsShadowM, radius: 8, y: 4)
        case .shadow200: shadow(color: M.effectsShadowL, radius: 16, y: 8)
        case .floating: shadow(color: M.effectsShadowL, radius: 16, y: 8)
        }
    }
}

// MARK: - Liquid Glass (navigation, floating controls and transient layers only)

private struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let clear: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content
                    .background(M.surfacePrimary, in: shape)
                    .overlay(shape.stroke(M.borderModerate, lineWidth: R.stroke1Px))
            } else {
                if #available(iOS 26.0, macOS 26.0, *) {
                    let base: Glass = clear ? .clear : .regular
                    content.glassEffect(interactive ? base.interactive() : base, in: shape)
                } else {
                    content.background(clear ? .ultraThinMaterial : .regularMaterial, in: shape)
                }
            }
        }
        .overlay {
            if contrast == .increased {
                shape.stroke(M.borderIntense, lineWidth: R.stroke1Px)
            }
        }
    }
}

extension View {
    /// Native Liquid Glass on iOS 26+, native material before that, opaque Mapped surface under
    /// Reduce Transparency. Never apply to ordinary content cards.
    /// `clear` uses the more transparent glass variant, for controls floating over rich content.
    func liquidGlass<S: Shape>(in shape: S, interactive: Bool = false, clear: Bool = false) -> some View {
        modifier(LiquidGlassModifier(shape: shape, interactive: interactive, clear: clear))
    }
}

/// Lets adjacent glass controls blend and morph together on iOS 26+.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = R.spacingSpace12
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

// MARK: - Buttons (bound to button/* component tokens)

struct BackstagePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .backstageText(.label1)
            .foregroundStyle(isEnabled ? M.buttonPrimaryLabel : M.buttonPrimaryLabelDisabled)
            .padding(.horizontal, R.spacingSpace24)
            .frame(minHeight: R.spacingSpace48)
            .background(
                isEnabled ? (configuration.isPressed ? M.buttonPrimaryBackgroundPressed : M.buttonPrimaryBackground) : M.buttonPrimaryBackgroundDisabled,
                in: Capsule()
            )
            .contentShape(Capsule())
    }
}

struct BackstageSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .backstageText(.label1)
            .foregroundStyle(configuration.isPressed ? M.buttonSecondaryLabelPressed : M.buttonSecondaryLabel)
            .padding(.horizontal, R.spacingSpace24)
            .frame(minHeight: R.spacingSpace48)
            .background(configuration.isPressed ? M.buttonSecondaryBackgroundPressed : M.buttonSecondaryBackground, in: Capsule())
            .overlay(
                Capsule().strokeBorder(configuration.isPressed ? M.buttonSecondaryBorderPressed : M.buttonSecondaryBorder, lineWidth: R.stroke1Px)
            )
            .contentShape(Capsule())
    }
}

struct BackstageTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .backstageText(.label2)
            .foregroundStyle(configuration.isPressed ? M.buttonTextLabelPressed : M.buttonTextLabel)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct BackstageFilterButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .backstageText(.label2)
            .foregroundStyle(isActive ? M.buttonFilterLabelActive : (pressed ? M.buttonFilterLabelPressed : M.buttonFilterLabel))
            .padding(.horizontal, R.spacingSpace16)
            .frame(minHeight: 36)
            .background(isActive ? M.buttonFilterBackgroundActive : (pressed ? M.buttonFilterBackgroundPressed : M.buttonFilterBackground), in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isActive ? M.buttonFilterBorderActive : (pressed ? M.buttonFilterBorderPressed : M.buttonFilterBorder),
                    lineWidth: R.stroke1Px
                )
            )
            .padding(.vertical, R.spacingSpace4)
            .contentShape(Rectangle())
    }
}

/// Subtle press feedback for tappable content cards.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    /// Paging horizontal carousel with the standard page gutter.
    func carousel() -> some View {
        contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
    }
}
