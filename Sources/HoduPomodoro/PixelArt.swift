import SwiftUI
import AppKit

// A sprite palette maps characters to Colors.
// "." is reserved for transparent.
struct PixelSprite {
    let rows: [String]
    let palette: [Character: Color]

    var width: Int { rows.map(\.count).max() ?? 0 }
    var height: Int { rows.count }
}

// Hand-drawn color palette, kept warm and soft to feel cute.
enum HoduPalette {
    static let orange      = Color(red: 1.00, green: 0.62, blue: 0.32)
    static let darkOrange  = Color(red: 0.82, green: 0.42, blue: 0.20)
    static let white       = Color(red: 1.00, green: 0.98, blue: 0.94)
    static let spriteOutline = Color(red: 0.20, green: 0.13, blue: 0.10)
    static let pink        = Color(red: 1.00, green: 0.68, blue: 0.72)
    static let eyeWhite    = Color(red: 1.00, green: 0.98, blue: 0.85)
    static let eyePupil    = Color(red: 0.10, green: 0.08, blue: 0.06)
    static let sunYellow   = Color(red: 1.00, green: 0.90, blue: 0.40)
    static let sunRim      = Color(red: 1.00, green: 0.73, blue: 0.28)
    static let trunkDark   = Color(red: 0.45, green: 0.28, blue: 0.14)
    static let trunk       = Color(red: 0.62, green: 0.42, blue: 0.24)
    static let leafLight   = Color(red: 0.38, green: 0.75, blue: 0.38)
    static let leafDark    = Color(red: 0.22, green: 0.55, blue: 0.28)
    static let coconut     = Color(red: 0.35, green: 0.20, blue: 0.10)
    static let waveLight   = Color(red: 0.74, green: 0.92, blue: 0.98)
    static let crabRed     = Color(red: 0.95, green: 0.38, blue: 0.32)
    static let crabDark   = Color(red: 0.70, green: 0.22, blue: 0.18)
    static let shellPink  = Color(red: 1.00, green: 0.82, blue: 0.80)
    static let shellDeep  = Color(red: 0.92, green: 0.60, blue: 0.64)
    static let starYellow = Color(red: 1.00, green: 0.88, blue: 0.46)
    static let moonGlow   = Color(red: 0.95, green: 0.89, blue: 0.62)
    static let moonShade  = Color(red: 0.64, green: 0.68, blue: 0.84)

    // Selection chrome — tints scale with the number of selected tasks so the
    // user can feel "too many" at a glance. See `SelectionLoadLevel`.
    static let selectionCalmFill      = Color(red: 1.00, green: 0.62, blue: 0.32).opacity(0.22)
    static let selectionCalmBorder    = Color(red: 1.00, green: 0.62, blue: 0.32)
    static let selectionCautionFill   = Color(red: 0.95, green: 0.70, blue: 0.25).opacity(0.30)
    static let selectionCautionBorder = Color(red: 0.91, green: 0.66, blue: 0.20)
    static let selectionOverloadFill  = Color(red: 0.92, green: 0.36, blue: 0.32).opacity(0.32)
    static let selectionOverloadBorder = Color(red: 0.88, green: 0.30, blue: 0.26)

    static func selectionFill(for level: SelectionLoadLevel) -> Color {
        switch level {
        case .none: return .clear
        case .calm: return selectionCalmFill
        case .caution: return selectionCautionFill
        case .overload: return selectionOverloadFill
        }
    }

    static func selectionBorder(for level: SelectionLoadLevel) -> Color {
        switch level {
        case .none: return .clear
        case .calm: return selectionCalmBorder
        case .caution: return selectionCautionBorder
        case .overload: return selectionOverloadBorder
        }
    }

    static let outline = Color(nsColor: NSColor(name: "HoduOutline") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
        return isDark
            ? NSColor(red: 1.00, green: 0.94, blue: 0.86, alpha: 1.0)
            : NSColor(red: 0.20, green: 0.13, blue: 0.10, alpha: 1.0)
    })

    static let panelFill = Color(nsColor: NSColor(name: "HoduPanelFill") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
        return isDark
            ? NSColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 0.88)
            : NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.82)
    })

    static let panelStroke = Color(nsColor: NSColor(name: "HoduPanelStroke") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
        return isDark
            ? NSColor(red: 0.33, green: 0.39, blue: 0.56, alpha: 0.85)
            : NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.90)
    })

    static let controlFill = Color(nsColor: NSColor(name: "HoduControlFill") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
        return isDark
            ? NSColor(red: 0.16, green: 0.20, blue: 0.31, alpha: 0.90)
            : NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.72)
    })

    static let selectedControlFill = Color(nsColor: NSColor(name: "HoduSelectedControlFill") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
        return isDark
            ? NSColor(red: 0.25, green: 0.29, blue: 0.42, alpha: 0.95)
            : NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.88)
    })

    // Adaptive text color for surfaces that follow the system appearance
    // (menu-bar popover, its sub-popovers, the timer-settings popover).
    // The fixed `outline` brown is unreadable on the dark vibrant material
    // macOS uses for popovers in dark mode, so these surfaces use this
    // color instead. Stays warm in light mode; flips to a soft cream in
    // dark mode so it still feels on-palette.
    static let adaptiveText = Color(nsColor: NSColor(name: "HoduAdaptiveText") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
            .map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
        return isDark
            ? NSColor(red: 1.00, green: 0.94, blue: 0.86, alpha: 1.0)
            : NSColor(red: 0.20, green: 0.13, blue: 0.10, alpha: 1.0)
    })
}

enum Sprites {

    // Hodu — orange cat with white chest/belly, sitting front-facing. 16x16.
    static let hodu = PixelSprite(
        rows: [
            "...BB......BB...",
            "..BoOB....BOoB..",
            ".BoPOOB..BOOPoB.",
            "BOOOOOOBBOOOOOOB",
            "BOOOOOOOOOOOOOOB",
            "BOoOEOOOOOOEOoOB",
            "BOOOOOOPPOOOOOOB",
            "BOOOOWWWWWWOOOOB",
            ".BOOOWWWWWWWOOB.",
            ".BOOWWWWWWWWOOB.",
            "..BOWWWWWWWWWOB.",
            "..BOWWWWWWWWWOB.",
            "..BOWWWWWWWWWOB.",
            "..BOWWBWWBWWBWOB",
            "..BOWWBWWBWWBWOB",
            "..BBBB.BB.BB.BBB"
        ],
        palette: [
            "B": HoduPalette.spriteOutline,
            "O": HoduPalette.orange,
            "o": HoduPalette.darkOrange,
            "W": HoduPalette.white,
            "P": HoduPalette.pink,
            "E": HoduPalette.eyePupil,
            "Y": HoduPalette.eyeWhite
        ]
    )

    // Sleeping Hodu — same sitting silhouette with closed eyes and a quiet face.
    static let hoduSleeping = PixelSprite(
        rows: [
            "...BB......BB...",
            "..BoOB....BOoB..",
            ".BoPOOB..BOOPoB.",
            "BOOOOOOBBOOOOOOB",
            "BOOOOOOOOOOOOOOB",
            "BOoOBBOOOOBBoOOB",
            "BOOOOOOPPOOOOOOB",
            "BOOOOWWWWWWOOOOB",
            ".BOOOWWWWWWWOOB.",
            ".BOOWWWWWWWWOOB.",
            "..BOWWWWWWWWWOB.",
            "..BOWWWWWWWWWOB.",
            "..BOWWWWWWWWWOB.",
            "..BOWWBWWBWWBWOB",
            "..BOWWBWWBWWBWOB",
            "..BBBB.BB.BB.BBB"
        ],
        palette: [
            "B": HoduPalette.spriteOutline,
            "O": HoduPalette.orange,
            "o": HoduPalette.darkOrange,
            "W": HoduPalette.white,
            "P": HoduPalette.pink
        ]
    )

    // Palm tree — leafy top with a short curving trunk. 14x14.
    static let palmTree = PixelSprite(
        rows: [
            "...GGgg..gggG.",
            ".GGgggGgGgggGG",
            "GggGGGgGGgGgGg",
            "GggGGCCcgGggGg",
            ".gGgCCCcGggg..",
            "..gGGgggGgg...",
            "....TTTt......",
            "....TtTT......",
            "....TTtT......",
            "...TTTtT......",
            "...TtTTT......",
            "...TTTtT......",
            "..TTTtTT......",
            "..TTTTTT......"
        ],
        palette: [
            "G": HoduPalette.leafDark,
            "g": HoduPalette.leafLight,
            "T": HoduPalette.trunk,
            "t": HoduPalette.trunkDark,
            "C": HoduPalette.coconut,
            "c": HoduPalette.trunkDark
        ]
    )

    // Sun with rays. 12x12.
    static let sun = PixelSprite(
        rows: [
            "......YY....",
            "..Y...YY...Y",
            ".Y..RRRRRR..",
            "...RYYYYYYR.",
            ".Y.RYYYYYYYR",
            "YYRYYYYYYYYR",
            "YYRYYYYYYYYR",
            ".Y.RYYYYYYYR",
            "...RYYYYYYR.",
            ".Y..RRRRRR..",
            "..Y...YY...Y",
            "......YY...."
        ],
        palette: [
            "Y": HoduPalette.sunYellow,
            "R": HoduPalette.sunRim
        ]
    )

    // Little crab. 9x6.
    static let crab = PixelSprite(
        rows: [
            "C.......C",
            "CC.....CC",
            ".CRRRRRC.",
            "CRRDRDRRC",
            ".RRRRRRR.",
            "..R...R.."
        ],
        palette: [
            "R": HoduPalette.crabRed,
            "C": HoduPalette.crabDark,
            "D": HoduPalette.spriteOutline
        ]
    )

    // Scallop shell. 7x5.
    static let shell = PixelSprite(
        rows: [
            "..SSS..",
            ".SpSpS.",
            "SpSpSpS",
            "SpSpSpS",
            ".SSSSS."
        ],
        palette: [
            "S": HoduPalette.shellPink,
            "p": HoduPalette.shellDeep
        ]
    )

    // Starfish. 7x7.
    static let starfish = PixelSprite(
        rows: [
            "...s...",
            "..sSs..",
            "sssSsss",
            ".sSSSs.",
            ".sSsSs.",
            "ss.s.ss",
            "s.....s"
        ],
        palette: [
            "S": HoduPalette.starYellow,
            "s": HoduPalette.sunRim
        ]
    )

    // Small cloud. 10x4.
    static let cloud = PixelSprite(
        rows: [
            "...CCCC...",
            ".CCccccCC.",
            "CcccccccCC",
            ".CCCCCCCC."
        ],
        palette: [
            "C": Color.white,
            "c": Color(red: 0.93, green: 0.95, blue: 0.99)
        ]
    )

    static let nightCloud = PixelSprite(
        rows: [
            "...CCCC...",
            ".CCccccCC.",
            "CcccccccCC",
            ".CCCCCCCC."
        ],
        palette: [
            "C": Color(red: 0.40, green: 0.45, blue: 0.62),
            "c": Color(red: 0.29, green: 0.33, blue: 0.48)
        ]
    )

    static let moon = PixelSprite(
        rows: [
            "...MMMM...",
            "..MMMMMM..",
            ".MMMMMSS.",
            ".MMMMSSS.",
            ".MMMMMSS.",
            "..MMMMMM..",
            "...MMMM..."
        ],
        palette: [
            "M": HoduPalette.moonGlow,
            "S": HoduPalette.moonShade
        ]
    )

    static let star = PixelSprite(
        rows: [
            "..S..",
            ".SSS.",
            "SSSSS",
            ".SSS.",
            "..S.."
        ],
        palette: [
            "S": HoduPalette.moonGlow
        ]
    )

    // Tiny seagull silhouette (two gull wings). 9x3.
    static let seagull = PixelSprite(
        rows: [
            "GG.....GG",
            ".GG...GG.",
            "..GG.GG.."
        ],
        palette: [
            "G": HoduPalette.spriteOutline
        ]
    )
}

// Renders a PixelSprite into a Canvas at a given pixel scale and origin.
struct PixelSpriteView: View {
    let sprite: PixelSprite
    let pixelSize: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            for (y, row) in sprite.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard ch != ".", let color = sprite.palette[ch] else { continue }
                    let rect = CGRect(
                        x: CGFloat(x) * pixelSize,
                        y: CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(
            width: CGFloat(sprite.width) * pixelSize,
            height: CGFloat(sprite.height) * pixelSize
        )
    }
}
