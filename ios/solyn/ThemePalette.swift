//
//  ThemePalette.swift
//  solyn
//
//  Colour themes as data. A theme is a set of hex values for the same roles
//  `DS.Palette` has always had — paper, card, ink, the green that acts, the gold
//  that rewards, the navy that is sky — so the twenty-odd screens that read
//  `DS.Palette.sage` re-theme without each of them learning about themes.
//
//  Two things are deliberately NOT here:
//  - Mood colours. They are a record of how someone felt, so they are fixed
//    (`DS.Brand`) and never move when the theme does.
//  - Light versus dark. That is still `AppTheme` (Day · Night · Sunset). A theme
//    supplies both a day set and the night/sky set its record and Twin screens
//    use; the night set is also what Night and Sunset-after-dark show. Fully
//    designed dark variants for the newer themes come later.
//

import SwiftUI

// MARK: - Theme identity

enum ThemeGroup: String, CaseIterable, Identifiable {
    case bold = "Bold"
    case calm = "Calm & soulful"
    case seasons = "Seasons"
    case festivals = "Festivals"

    var id: String { rawValue }

    var themes: [ThemeID] { ThemeID.allCases.filter { $0.group == self } }
}

/// Stored by raw value, so the strings are part of the save format: add cases,
/// never rename them.
enum ThemeID: String, CaseIterable, Identifiable {
    case standard = "default"
    case sticker
    case highContrast
    case mist
    case lotus
    case sandalwood
    case hush
    case paperNotebook
    case spring
    case summer
    case monsoon
    case autumn
    case winter
    case christmas
    case diwali
    case holi
    case pongal
    case ramadan
    case eid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Default"
        case .sticker: return "Sticker"
        case .highContrast: return "High contrast"
        case .mist: return "Mist"
        case .lotus: return "Lotus"
        case .sandalwood: return "Sandalwood"
        case .hush: return "Hush"
        case .paperNotebook: return "Paper notebook"
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .monsoon: return "Monsoon"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        case .christmas: return "Christmas"
        case .diwali: return "Diwali"
        case .holi: return "Holi"
        case .pongal: return "Pongal / Sankranti"
        case .ramadan: return "Ramadan"
        case .eid: return "Eid"
        }
    }

    var group: ThemeGroup {
        switch self {
        case .standard, .sticker, .highContrast: return .bold
        case .mist, .lotus, .sandalwood, .hush, .paperNotebook: return .calm
        case .spring, .summer, .monsoon, .autumn, .winter: return .seasons
        case .christmas, .diwali, .holi, .pongal, .ramadan, .eid: return .festivals
        }
    }

    /// The day set. High contrast is the one theme whose night set is a
    /// separate design rather than its sky colours, see `palette(isNight:)`.
    var palette: ThemePalette { ThemePalette.table[self] ?? .standard }

    func palette(isNight: Bool) -> ThemePalette {
        if self == .highContrast && isNight { return .highContrastNight }
        return palette
    }
}

// MARK: - Palette

/// One theme's colours, by role. The role names are `DS.Palette`'s, so the
/// grammar stays the same in every theme: `sage` is whatever colour acts here,
/// `gold` whatever rewards, `navy` whatever the sky is.
///
/// Every `sage` must carry white text at 4.5:1 or better, because buttons put
/// white on it all over the app; `ThemePaletteTests` holds every theme to that.
struct ThemePalette: Equatable {
    // Paper and ink.
    var ivory: UInt32
    var ivory2: UInt32
    var ink: UInt32
    var inkSoft: UInt32
    var inkMute: UInt32
    // Acts.
    var sage: UInt32
    var sageDeep: UInt32
    var sagePositive: UInt32
    var forest: UInt32
    // Rewards.
    var gold: UInt32
    var goldDay: UInt32
    var goldNight: UInt32
    // Sky.
    var navy: UInt32
    var navySurface: UInt32
    var navyText: UInt32
    var starBlue: UInt32
    // Accents.
    var terracotta: UInt32
    var coral: UInt32
    // Card tints.
    var tintSage: UInt32
    var tintGold: UInt32
    var tintTerra: UInt32
    var tintCoral: UInt32

    /// The app as it shipped before themes. Every other theme starts from this
    /// and changes what it needs to.
    static let standard = ThemePalette(
        ivory: 0xF7F3EA, ivory2: 0xFFFFFF,
        ink: 0x1E2A26, inkSoft: 0x5C6A64, inkMute: 0x8B9690,
        sage: 0x2E5B44, sageDeep: 0x214432, sagePositive: 0x446F51, forest: 0x8FBF77,
        gold: 0xD9A441, goldDay: 0x8A6A1F, goldNight: 0xEDCB86,
        navy: 0x101B2D, navySurface: 0x1C2A42, navyText: 0xF1EDE2, starBlue: 0x9DC1E4,
        terracotta: 0xC4956A, coral: 0xD44F45,
        tintSage: 0xE4EDE4, tintGold: 0xF3E7CD, tintTerra: 0xF3E8DC, tintCoral: 0xF8E5DF
    )

    /// Built from `standard` so a theme lists only what makes it itself.
    static func theme(_ edit: (inout ThemePalette) -> Void) -> ThemePalette {
        var p = ThemePalette.standard
        edit(&p)
        return p
    }

    static let highContrastNight = ThemePalette.theme {
        $0.ivory = 0x000000; $0.ivory2 = 0x000000
        $0.ink = 0xFFFFFF; $0.inkSoft = 0xFFFFFF; $0.inkMute = 0xEDEDED
        // One blue that carries white text AND reads on black: 4.6:1 both ways.
        $0.sage = 0x2A68FF; $0.sageDeep = 0x1F4FC7; $0.sagePositive = 0x7DFFB0; $0.forest = 0x7DFFB0
        $0.gold = 0xFFD60A; $0.goldDay = 0xFFD60A; $0.goldNight = 0xFFD60A
        $0.navy = 0x000000; $0.navySurface = 0x1A1A1A; $0.navyText = 0xFFFFFF; $0.starBlue = 0xFFFFFF
        $0.terracotta = 0xFFFFFF; $0.coral = 0xFF453A
        $0.tintSage = 0x000000; $0.tintGold = 0x000000; $0.tintTerra = 0x000000; $0.tintCoral = 0x000000
    }

    /// Hex values come from the theme mockups (scratchpad themes/themes.css,
    /// 2026-11-06); `sage` is each theme's action colour, `terracotta` its
    /// streak colour, `navy`/`navySurface`/`navyText` its record and sky screens.
    static let table: [ThemeID: ThemePalette] = [
        .standard: .standard,

        .sticker: theme {
            $0.ivory = 0xF4F5F1; $0.ivory2 = 0xFFFFFF
            $0.ink = 0x1D1F24; $0.inkSoft = 0x3E424B; $0.inkMute = 0x5E626B
            $0.sage = 0x1F5A43; $0.sageDeep = 0x174634; $0.sagePositive = 0x1F5A43
            $0.gold = 0xF2C14E; $0.goldDay = 0x7A5800
            $0.navy = 0x1D1F24; $0.navySurface = 0x2E3139; $0.navyText = 0xFFFFFF
            $0.terracotta = 0xE2553A; $0.coral = 0xE2553A
            $0.tintSage = 0xE2ECE6; $0.tintGold = 0xFCEFC9
        },

        .highContrast: theme {
            $0.ivory = 0xFFFFFF; $0.ivory2 = 0xFFFFFF
            $0.ink = 0x000000; $0.inkSoft = 0x000000; $0.inkMute = 0x1A1A1A
            $0.sage = 0x0047FF; $0.sageDeep = 0x0033B8; $0.sagePositive = 0x005A2B
            $0.gold = 0x000000; $0.goldDay = 0x000000
            $0.navy = 0x000000; $0.navySurface = 0x1A1A1A; $0.navyText = 0xFFFFFF
            $0.goldNight = 0xFFD60A; $0.forest = 0x7DFFB0; $0.starBlue = 0xFFFFFF
            $0.terracotta = 0x000000; $0.coral = 0xD70015
            $0.tintSage = 0xFFFFFF; $0.tintGold = 0xFFFFFF; $0.tintTerra = 0xFFFFFF; $0.tintCoral = 0xFFFFFF
        },

        .mist: theme {
            $0.ivory = 0xEEF2F4; $0.ink = 0x2C3A45; $0.inkSoft = 0x4E5D69; $0.inkMute = 0x66737E
            $0.sage = 0x4F6F88; $0.sageDeep = 0x3E5A70; $0.sagePositive = 0x2F5D45
            $0.gold = 0xB8892B; $0.goldDay = 0x7D5E17
            $0.navy = 0x2B3946; $0.navySurface = 0x3A4A58; $0.navyText = 0xEEF2F4
            $0.terracotta = 0x4F6F88; $0.coral = 0xC8665A
            $0.tintSage = 0xE3EDE6; $0.tintGold = 0xF5EEDC
        },

        .lotus: theme {
            $0.ivory = 0xFBF1F2; $0.ink = 0x2E2A2B; $0.inkSoft = 0x5A4E52; $0.inkMute = 0x74666B
            $0.sage = 0x2F5B46; $0.sageDeep = 0x234636; $0.sagePositive = 0x2F5B46
            $0.gold = 0xB88A2E; $0.goldDay = 0x7A5A14
            $0.navy = 0x22342C; $0.navySurface = 0x2F463B; $0.navyText = 0xFBF1F2
            $0.terracotta = 0xB0476B; $0.coral = 0xC8546E
            $0.tintSage = 0xE4EEE7; $0.tintGold = 0xFAF0DA; $0.tintTerra = 0xF7DDE3
        },

        .sandalwood: theme {
            $0.ivory = 0xF6EEE2; $0.ivory2 = 0xFFFDF9
            $0.ink = 0x3B2A1E; $0.inkSoft = 0x5E4636; $0.inkMute = 0x735B49
            // The mockup's saffron (#E39B2D) cannot carry white text; its deeper
            // text shade acts instead, and saffron stays the reward colour.
            $0.sage = 0x8F520C; $0.sageDeep = 0x6E3F09; $0.sagePositive = 0x3F5F3C
            $0.gold = 0xE39B2D; $0.goldDay = 0x7A5C2A
            $0.navy = 0x2E2118; $0.navySurface = 0x3F2F23; $0.navyText = 0xF6EEE2
            $0.terracotta = 0xB86E12; $0.coral = 0xC2553A
            $0.tintSage = 0xE7EDE0; $0.tintGold = 0xF3E6CC; $0.tintTerra = 0xF1E2C8
        },

        .hush: theme {
            $0.ivory = 0xF3EFF8; $0.ink = 0x3A2A45; $0.inkSoft = 0x5A4A66; $0.inkMute = 0x6F6180
            $0.sage = 0x6B4A7E; $0.sageDeep = 0x533962; $0.sagePositive = 0x2F5D45
            $0.gold = 0xB38A3A; $0.goldDay = 0x7A5C1C
            $0.navy = 0x2A2236; $0.navySurface = 0x3A3049; $0.navyText = 0xF3EFF8
            $0.terracotta = 0x7E4F9A; $0.coral = 0xC45C78
            $0.tintSage = 0xE6EEE8; $0.tintGold = 0xF6EEDC; $0.tintTerra = 0xEAE1F3
        },

        .paperNotebook: theme {
            $0.ivory = 0xFBFAF5; $0.ink = 0x1F2A44; $0.inkSoft = 0x444C5E; $0.inkMute = 0x5F6573
            $0.sage = 0x23408E; $0.sageDeep = 0x1A316E; $0.sagePositive = 0x2F5D45
            $0.gold = 0xB8862A; $0.goldDay = 0x7A5A14
            $0.navy = 0x1F2A44; $0.navySurface = 0x2E3A57; $0.navyText = 0xFBFAF5
            $0.terracotta = 0x23408E; $0.coral = 0xC0392B
            $0.tintSage = 0xE5EEE6; $0.tintGold = 0xF7EFDB; $0.tintTerra = 0xE6EAF4
        },

        .spring: theme {
            $0.ivory = 0xF4F7F1; $0.ink = 0x233127; $0.inkSoft = 0x4A5A4E; $0.inkMute = 0x617064
            $0.sage = 0x3B7449; $0.sageDeep = 0x2D5938; $0.sagePositive = 0x2E5E3A
            $0.gold = 0xC99A2E; $0.goldDay = 0x7A5A14
            $0.navy = 0x1F3550; $0.navySurface = 0x2D4766; $0.navyText = 0xF4F7F1
            $0.terracotta = 0xC04466; $0.coral = 0xD9536E
            $0.tintSage = 0xE1EFE1; $0.tintGold = 0xF7EFD6; $0.tintTerra = 0xF8D7E0
        },

        .summer: theme {
            $0.ivory = 0xFFF9EE; $0.ink = 0x2A2418; $0.inkSoft = 0x544A36; $0.inkMute = 0x6B6150
            $0.sage = 0x0F7471; $0.sageDeep = 0x0B5856; $0.sagePositive = 0x2A5E3E
            $0.gold = 0xE0A100; $0.goldDay = 0x7A5600
            $0.navy = 0x0E3B4A; $0.navySurface = 0x19505F; $0.navyText = 0xFFF9EE
            $0.terracotta = 0xD2553C; $0.coral = 0xE5674E
            $0.tintSage = 0xE2F0E6; $0.tintGold = 0xFFF0C2; $0.tintTerra = 0xD7F0EE
        },

        .monsoon: theme {
            $0.ivory = 0xE6ECEF; $0.ink = 0x1E2A33; $0.inkSoft = 0x44535F; $0.inkMute = 0x5F6E7A
            $0.sage = 0x2E6A55; $0.sageDeep = 0x235141; $0.sagePositive = 0x23574A
            $0.gold = 0xE8A900; $0.goldDay = 0x7C5A00
            $0.navy = 0x26354A; $0.navySurface = 0x34465E; $0.navyText = 0xEEF2F4
            $0.terracotta = 0xB8693E; $0.coral = 0xC7613A
            $0.tintSage = 0xDCEBE3; $0.tintGold = 0xFFF1C7; $0.tintTerra = 0xDCE6EE
        },

        .autumn: theme {
            $0.ivory = 0xF8F1E7; $0.ink = 0x2F2220; $0.inkSoft = 0x57433C; $0.inkMute = 0x6F5950
            $0.sage = 0x7A3E5A; $0.sageDeep = 0x5E2F45; $0.sagePositive = 0x3F5A2E
            $0.gold = 0xC9971F; $0.goldDay = 0x7A5A0E
            $0.navy = 0x2C1E24; $0.navySurface = 0x3E2B33; $0.navyText = 0xF8F1E7
            $0.terracotta = 0xA6461E; $0.coral = 0xC0502A
            $0.tintSage = 0xE6ECDC; $0.tintGold = 0xF7EBCB; $0.tintTerra = 0xF3E0D2
        },

        .winter: theme {
            $0.ivory = 0xF1F6F9; $0.ink = 0x1D2B33; $0.inkSoft = 0x43535D; $0.inkMute = 0x5B6B75
            $0.sage = 0x1F5A48; $0.sageDeep = 0x174537; $0.sagePositive = 0x1F5A48
            $0.gold = 0xC29A3A; $0.goldDay = 0x7A5C14
            $0.navy = 0x142634; $0.navySurface = 0x213A4C; $0.navyText = 0xF1F6F9
            $0.terracotta = 0xA3243F; $0.coral = 0xC23B55
            $0.tintSage = 0xDFEEE7; $0.tintGold = 0xF6EEDA; $0.tintTerra = 0xDCEBF4
        },

        .christmas: theme {
            $0.ivory = 0xF7F4EE; $0.ink = 0x23201C; $0.inkSoft = 0x4C463E; $0.inkMute = 0x665E54
            $0.sage = 0x1E5A3C; $0.sageDeep = 0x16452E; $0.sagePositive = 0x1E5A3C
            $0.gold = 0xC8A13A; $0.goldDay = 0x7A5E14
            $0.navy = 0x14271E; $0.navySurface = 0x213A2E; $0.navyText = 0xF7F4EE
            $0.terracotta = 0x9B1F2E; $0.coral = 0xC0392B
            $0.tintSage = 0xE0EDE4; $0.tintGold = 0xF6EDD3; $0.tintTerra = 0xF6DCDC
        },

        .diwali: theme {
            $0.ivory = 0xFBF6EE; $0.ink = 0x2A1F1A; $0.inkSoft = 0x56463C; $0.inkMute = 0x6E5D52
            $0.sage = 0xB5297A; $0.sageDeep = 0x8C1F5E; $0.sagePositive = 0x2F5D45
            $0.gold = 0xE8930C; $0.goldDay = 0x7A4E06
            $0.navy = 0x211B42; $0.navySurface = 0x312A5C; $0.navyText = 0xFBF6EE
            $0.terracotta = 0xB5297A; $0.coral = 0xD2452E
            $0.tintSage = 0xE3EEE4; $0.tintGold = 0xFCEBCF; $0.tintTerra = 0xF6DDEB
        },

        .holi: theme {
            $0.ivory = 0xFFFFFF; $0.ink = 0x1F1D2B; $0.inkSoft = 0x4A4858; $0.inkMute = 0x62606F
            $0.sage = 0xC2185B; $0.sageDeep = 0x961246; $0.sagePositive = 0x226B3A
            $0.gold = 0xE0A100; $0.goldDay = 0x7A5600
            $0.navy = 0x24183C; $0.navySurface = 0x352553; $0.navyText = 0xFFFFFF
            $0.terracotta = 0xC2185B; $0.coral = 0xE5484D
            $0.tintSage = 0xE2F2E6; $0.tintGold = 0xFFF3C4; $0.tintTerra = 0xDCE6FB
        },

        .pongal: theme {
            $0.ivory = 0xFBF7EC; $0.ink = 0x2A2210; $0.inkSoft = 0x544A30; $0.inkMute = 0x6B614A
            $0.sage = 0x3A722B; $0.sageDeep = 0x2C5821; $0.sagePositive = 0x2F5E24
            $0.gold = 0xE0A800; $0.goldDay = 0x7A5800
            $0.navy = 0x1E2B17; $0.navySurface = 0x2D3E23; $0.navyText = 0xFBF7EC
            $0.terracotta = 0xB8572A; $0.coral = 0xC2502A
            $0.tintSage = 0xE3EFDC; $0.tintGold = 0xFBEFC8; $0.tintTerra = 0xF3E4CF
        },

        .ramadan: theme {
            $0.ivory = 0xF4F3EE; $0.ink = 0x1F2A2B; $0.inkSoft = 0x44514F; $0.inkMute = 0x5D6967
            $0.sage = 0x145C5E; $0.sageDeep = 0x0F4648; $0.sagePositive = 0x1F5E48
            $0.gold = 0xC9952A; $0.goldDay = 0x7A5A12
            $0.navy = 0x0F2E33; $0.navySurface = 0x1A4147; $0.navyText = 0xF4F3EE
            $0.terracotta = 0x145C5E; $0.coral = 0xC2553A
            $0.tintSage = 0xDFECE6; $0.tintGold = 0xF5ECD4; $0.tintTerra = 0xDDEBEA
        },

        .eid: theme {
            $0.ivory = 0xF3F8F3; $0.ink = 0x1F2B25; $0.inkSoft = 0x44534B; $0.inkMute = 0x5D6B63
            $0.sage = 0x1E6A50; $0.sageDeep = 0x16503C; $0.sagePositive = 0x1E6A50
            $0.gold = 0xB8912F; $0.goldDay = 0x7A5C14
            $0.navy = 0x12332A; $0.navySurface = 0x1E4639; $0.navyText = 0xF3F8F3
            $0.terracotta = 0x1E6A50; $0.coral = 0xC2553A
            $0.tintSage = 0xDCEFE3; $0.tintGold = 0xF6EFD9; $0.tintTerra = 0xE3F0E8
        },
    ]
}

// MARK: - The palette in force

/// What `DS.Palette` reads. The theme in force changes only when Settings
/// closes (see `ThemeManager.applyPendingTheme()`), and the app root is rebuilt
/// at that moment, so every view picks the new colours up in one pass.
enum ThemeRuntime {
    static var palette: ThemePalette {
        let manager = ThemeManager.shared
        let id = manager.appliedThemeID
        // Only High contrast has a separately designed night set, so only it
        // pays for the sunset calculation behind `isNight`.
        return id == .highContrast ? id.palette(isNight: manager.isNight) : id.palette
    }
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum ContrastMath {
    /// WCAG 2.x relative luminance.
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
            + 0.7152 * channel((hex >> 8) & 0xFF)
            + 0.0722 * channel(hex & 0xFF)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
