import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Swift mirror of the Backstage DS Figma variables (Foundations 1.0 draft, registry 2026-08-12).
///
/// Product UI consumes `Mapped` (colour) and `Responsive` (dimensions) only. `Core` exists solely
/// to define Mapped aliases and must not be referenced from product views.
/// Only the tokens this feature uses are mirrored; add others from the registry as needed,
/// keeping Figma names and order.
enum BackstageTokens {

    // MARK: - Core (alias definition only)

    enum Core {
        static let colorGrey50 = Color(rgba: 0xF6F6F9FF)
        static let colorGrey100 = Color(rgba: 0xF0F0F5FF)
        static let colorGrey200 = Color(rgba: 0xE7E7EEFF)
        static let colorGrey300 = Color(rgba: 0xC6C5D3FF)
        static let colorGrey400 = Color(rgba: 0x787792FF)
        static let colorGrey500 = Color(rgba: 0x4F4E5FFF)
        static let colorGrey600 = Color(rgba: 0x373744FF)
        static let colorGrey700 = Color(rgba: 0x25252DFF)
        static let colorGrey800 = Color(rgba: 0x1C1C22FF)
        static let colorGrey900 = Color(rgba: 0x0E0E11FF)
        static let colorPurple100 = Color(rgba: 0xEDE7FDFF)
        static let colorPurple300 = Color(rgba: 0xC3ACF6FF)
        static let colorPurple500 = Color(rgba: 0x7B49EEFF)
        static let colorGreen400 = Color(rgba: 0x67E494FF)
        static let colorGreen500 = Color(rgba: 0x37DC73FF)
        static let colorTransparaentGreyGrey0Pct = Color(rgba: 0x0E0E1100)
        static let colorTransparaentGreyGrey8Pct = Color(rgba: 0x0E0E1114)
        static let colorTransparaentGreyGrey16Pct = Color(rgba: 0x0E0E1129)
        static let colorTransparaentGreyGrey24Pct = Color(rgba: 0x0E0E113D)
        static let colorTransparaentGreyGrey32Pct = Color(rgba: 0x0E0E1152)
        static let colorTransparaentGreyGrey48Pct = Color(rgba: 0x0E0E117A)
        static let colorTransparaentGreyGrey72Pct = Color(rgba: 0x0E0E11B8)
        static let colorTransparaentWhiteWhite0Pct = Color(rgba: 0xF6F6F900)
        static let colorTransparaentWhiteWhite8Pct = Color(rgba: 0xF6F6F914)
        static let colorTransparaentWhiteWhite16Pct = Color(rgba: 0xF6F6F929)
        static let colorTransparaentWhiteWhite24Pct = Color(rgba: 0xF6F6F93D)
        static let colorTransparaentWhiteWhite32Pct = Color(rgba: 0xF6F6F952)
        static let colorTransparaentWhiteWhite48Pct = Color(rgba: 0xF6F6F97A)
        static let colorTransparaentWhiteWhite72Pct = Color(rgba: 0xF6F6F9B8)
        static let colorTransparaentPurplePurple8Pct = Color(rgba: 0x2E214F14)
        static let colorTransparaentPurplePurple24Pct = Color(rgba: 0x2E214F3D)
        static let colorTransparaentBlackBlack8Pct = Color(rgba: 0x00000014)
        static let colorTransparaentBlackBlack16Pct = Color(rgba: 0x00000029)
        static let colorPureBlack = Color(rgba: 0x000000FF)
        static let colorPurePurple = Color(rgba: 0x8870FFFF)
        static let colorPureWhite = Color(rgba: 0xFFFFFFFF)
    }

    // MARK: - Mapped (Dark mode default, Light mode)

    enum Mapped {
        // background/*
        static let backgroundPrimary = Color(dark: Color(rgba: 0x131316FF), light: Core.colorGrey50)  // Figma color/background/primary
        static let backgroundSecondary = Color(dark: Color(rgba: 0x1E1E20FF), light: Core.colorPureWhite)  // Figma color/background/secondary

        // surface/*
        static let surfacePrimary = Color(dark: Core.colorGrey800, light: Core.colorPureWhite)
        static let surfaceSecondary = Color(dark: Color(rgba: 0x2C2C2EFF), light: Core.colorGrey100)  // Figma color/surface/secondary
        static let surfaceTertiary = Color(dark: Core.colorGrey600, light: Core.colorGrey200)
        static let surfaceInverse = Color(dark: Core.colorGrey50, light: Core.colorGrey900)
        static let surfaceTransparent = Color(dark: Core.colorTransparaentWhiteWhite8Pct, light: Core.colorTransparaentPurplePurple8Pct)
        static let surfaceSelectionPurple = Color(dark: Core.colorTransparaentPurplePurple24Pct, light: Core.colorPurple100)

        // border/*
        static let borderSubtle = Color(dark: Core.colorTransparaentWhiteWhite8Pct, light: Core.colorTransparaentGreyGrey8Pct)
        static let borderModerate = Color(dark: Color(rgba: 0x2F2F37FF), light: Core.colorTransparaentGreyGrey16Pct)  // Figma color/border/moderate
        static let borderIntense = Color(dark: Core.colorTransparaentWhiteWhite24Pct, light: Core.colorTransparaentGreyGrey24Pct)
        static let borderSelection = Color(dark: Core.colorGrey50, light: Core.colorGrey900)
        static let borderSelectionPurple = Color(dark: Core.colorPurple300, light: Core.colorPurple500)
        static let borderCardBorderSurfacePrimary = Color(dark: Color(rgba: 0x1E1E20FF), light: Core.colorGrey100)  // Figma color/border/Card

        // text/*
        static let textPrimary = Color(dark: Color(rgba: 0xF7F7F7FF), light: Core.colorGrey900)  // Figma color/text/primary
        static let textSecondary = Color(dark: Color(rgba: 0xA5A5ACFF), light: Core.colorTransparaentGreyGrey72Pct)  // Figma color/text/secondary
        static let textTertiary = Color(dark: Color(rgba: 0x77777EFF), light: Core.colorTransparaentGreyGrey48Pct)  // Figma color/text/tertiary
        static let textInverse = Color(dark: Core.colorGrey900, light: Core.colorGrey50)
        static let textPurple = Color(dark: Core.colorPurePurple, light: Core.colorPurePurple)
        static let textWhite = Color(dark: Core.colorGrey50, light: Core.colorGrey50)

        // Offers (Figma "Homepage and Search")
        static let textOffer = Color(dark: Color(rgba: 0xBCAEFEFF), light: Color(rgba: 0x5631EDFF))  // Figma color/text/offer
        static let surfaceOfferPrimary = Color(dark: Color(rgba: 0x5631EDFF), light: Color(rgba: 0x5631EDFF))  // Figma color/surface/offer - Primary
        static let surfaceOfferSecondary = Color(dark: Color(rgba: 0x6D49FD33), light: Color(rgba: 0x6D49FD1F))  // Figma color/surface/offer - Secondary

        // Brand washes (Figma colors/*/900)
        static let brandGreen900 = Color(dark: Color(rgba: 0x042F12FF), light: Color(rgba: 0x042F12FF))
        static let brandPurple900 = Color(dark: Color(rgba: 0x160D3BFF), light: Color(rgba: 0x160D3BFF))
        static let textBlack = Color(dark: Core.colorGrey900, light: Core.colorGrey900)

        // icon/*
        static let iconPrimary = Color(dark: Color(rgba: 0xF7F7F7FF), light: Core.colorGrey900)  // Figma color/icon/primary
        static let iconSecondary = Color(dark: Core.colorTransparaentWhiteWhite72Pct, light: Core.colorTransparaentGreyGrey72Pct)
        static let iconTertiary = Color(dark: Color(rgba: 0x8B8B93FF), light: Core.colorTransparaentGreyGrey48Pct)  // Figma color/icon/tertiary
        static let iconQuaternary = Color(dark: Color(rgba: 0x77777EFF), light: Core.colorTransparaentGreyGrey48Pct)  // Figma color/icon/quaternary
        static let iconAccentGreen = Color(dark: Color(rgba: 0x58E487FF), light: Color(rgba: 0x1E9E4AFF))  // Figma color/icon/accent/green
        static let iconInverse = Color(dark: Core.colorGrey900, light: Core.colorGrey50)
        static let iconBrand = Color(dark: Core.colorPurePurple, light: Core.colorPurePurple)
        static let iconWhite = Color(dark: Core.colorGrey50, light: Core.colorGrey50)

        // verticals/*
        static let verticalsStores = Color(dark: Core.colorGreen400, light: Core.colorGreen500)

        // button/primary/*
        static let buttonPrimaryBackground = Color(dark: Core.colorGrey50, light: Core.colorGrey900)
        static let buttonPrimaryBackgroundPressed = Color(dark: Core.colorGrey100, light: Core.colorGrey800)
        static let buttonPrimaryBackgroundDisabled = Color(dark: Core.colorTransparaentWhiteWhite8Pct, light: Core.colorTransparaentGreyGrey8Pct)
        static let buttonPrimaryIcon = iconInverse
        static let buttonPrimaryLabel = textInverse
        static let buttonPrimaryLabelPressed = textInverse
        static let buttonPrimaryLabelDisabled = Color(dark: Core.colorTransparaentWhiteWhite24Pct, light: Core.colorTransparaentGreyGrey24Pct)

        // button/secondary/*
        static let buttonSecondaryBackground = Color(dark: Core.colorTransparaentWhiteWhite8Pct, light: Core.colorTransparaentWhiteWhite0Pct)
        static let buttonSecondaryBackgroundPressed = Color(dark: Core.colorTransparaentWhiteWhite16Pct, light: Core.colorTransparaentGreyGrey8Pct)
        static let buttonSecondaryBorder = Color(dark: Core.colorGrey50, light: Core.colorGrey800)
        static let buttonSecondaryBorderPressed = Color(dark: Core.colorGrey100, light: Core.colorGrey500)
        static let buttonSecondaryIcon = Color(dark: Core.colorGrey50, light: Core.colorGrey700)
        static let buttonSecondaryLabel = Color(dark: Core.colorGrey50, light: Core.colorGrey900)
        static let buttonSecondaryLabelPressed = Color(dark: Core.colorGrey100, light: Core.colorGrey700)

        // button/filter/*
        static let buttonFilterBackground = Color(dark: Core.colorTransparaentBlackBlack8Pct, light: Core.colorTransparaentWhiteWhite0Pct)
        static let buttonFilterBackgroundPressed = Color(dark: Core.colorTransparaentBlackBlack16Pct, light: Core.colorGrey50)
        static let buttonFilterBackgroundActive = Color(dark: Core.colorTransparaentPurplePurple24Pct, light: Core.colorPurple100)
        static let buttonFilterBorder = Color(dark: Core.colorGrey300, light: Core.colorGrey800)
        static let buttonFilterBorderPressed = Color(dark: Core.colorGrey500, light: Core.colorGrey300)
        static let buttonFilterBorderActive = Color(dark: Core.colorPurple300, light: Core.colorPurple500)
        static let buttonFilterLabel = Color(dark: Core.colorGrey50, light: Core.colorGrey700)
        static let buttonFilterLabelPressed = Color(dark: Core.colorGrey200, light: Core.colorGrey600)
        static let buttonFilterLabelActive = Color(dark: Core.colorPurple300, light: Core.colorPurple500)

        // button/text/*
        static let buttonTextIcon = Color(dark: Core.colorGrey50, light: Core.colorGrey700)
        static let buttonTextLabel = Color(dark: Core.colorGrey50, light: Core.colorGrey900)
        static let buttonTextLabelPressed = Color(dark: Core.colorGrey200, light: Core.colorGrey600)

        // Effects/*  (shadow colours for elevation styles only)
        static let effectsBlackShadow8 = Color(dark: Core.colorTransparaentGreyGrey8Pct, light: Core.colorTransparaentGreyGrey8Pct)
        static let effectsBlackShadow16 = Color(dark: Core.colorTransparaentGreyGrey16Pct, light: Core.colorTransparaentGreyGrey16Pct)
        static let effectsShadowM = Color(dark: Color(rgba: 0x00000040), light: Color(rgba: 0x00000040))  // Figma shadow-m
        static let effectsShadowL = Color(dark: Color(rgba: 0x00000080), light: Color(rgba: 0x00000080))  // Figma shadow-l

        // PROPOSED — not yet in Figma. The registry has no scrim role for legibility over photography.
        // Pending DS-owner approval as `overlay/scrim`; keep usage limited to ImageScrim.
        static let proposedOverlayScrim = Color(dark: Core.colorPureBlack, light: Core.colorPureBlack)
    }

    // MARK: - Responsive

    enum Responsive {
        static let fontFamilyPrimary = "Be Vietnam Pro"

        static let spacingSpace0: CGFloat = 0
        static let spacingSpace4: CGFloat = 4
        static let spacingSpace8: CGFloat = 8
        static let spacingSpace12: CGFloat = 12
        static let spacingSpace16: CGFloat = 16
        static let spacingSpace20: CGFloat = 20
        static let spacingSpace24: CGFloat = 24
        static let spacingSpace32: CGFloat = 32
        static let spacingSpace40: CGFloat = 40
        static let spacingSpace42: CGFloat = 42
        static let spacingSpace48: CGFloat = 48
        static let spacingSpace56: CGFloat = 56
        static let spacingSpace64: CGFloat = 64
        static let spacingSpace72: CGFloat = 72
        static let spacingSpace80: CGFloat = 80

        static let cornerRadiusCorner0: CGFloat = 0
        static let cornerRadiusCorner4: CGFloat = 4
        static let cornerRadiusCorner8: CGFloat = 8
        static let cornerRadiusCorner12: CGFloat = 12
        static let cornerRadiusCorner16: CGFloat = 16
        static let cornerRadiusCorner20: CGFloat = 20
        static let cornerRadiusCorner24: CGFloat = 24
        static let cornerRadiusCorner32: CGFloat = 32
        static let cornerRadiusFullRounded: CGFloat = 1000

        static let strokeHalfPx: CGFloat = 0.5
        static let stroke1Px: CGFloat = 1
        static let stroke1PlusHalfPx: CGFloat = 1.5
        static let stroke2Px: CGFloat = 2
    }
}

// MARK: - Colour construction

extension Color {
    /// 0xRRGGBBAA, matching the registry's 8-digit hex notation.
    init(rgba: UInt32) {
        self.init(
            .sRGB,
            red: Double((rgba >> 24) & 0xFF) / 255,
            green: Double((rgba >> 16) & 0xFF) / 255,
            blue: Double((rgba >> 8) & 0xFF) / 255,
            opacity: Double(rgba & 0xFF) / 255
        )
    }

    /// Resolves per appearance, mirroring a Mapped variable's Dark/Light modes.
    init(dark: Color, light: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}
