import SwiftUI

/// A pixel-art beach scene that scales crisply with window size.
struct BeachScene: View {
    /// Virtual grid width in pixels. Smaller = chunkier pixels.
    let gridWidth: CGFloat = 96
    var isNight: Bool = false

    var body: some View {
        GeometryReader { geo in
            let pixel = max(2, floor(geo.size.width / gridWidth))
            let gridH = max(32, floor(geo.size.height / pixel))

            ZStack(alignment: .topLeading) {
                // Sky gradient
                LinearGradient(
                    colors: isNight ? nightSkyColors : daySkyColors,
                    startPoint: .top, endPoint: .bottom
                )

                // Ocean band (middle third)
                Rectangle()
                    .fill(LinearGradient(
                        colors: isNight ? nightOceanColors : dayOceanColors,
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(height: pixel * gridH * 0.24)
                    .offset(y: pixel * gridH * 0.48)

                // Wave highlights
                Rectangle()
                    .fill((isNight ? Color(red: 0.48, green: 0.56, blue: 0.76) : HoduPalette.waveLight).opacity(isNight ? 0.45 : 1))
                    .frame(height: pixel)
                    .offset(y: pixel * gridH * 0.58)
                Rectangle()
                    .fill((isNight ? Color(red: 0.48, green: 0.56, blue: 0.76) : HoduPalette.waveLight).opacity(isNight ? 0.32 : 0.7))
                    .frame(height: pixel)
                    .offset(y: pixel * gridH * 0.63)

                // Sand
                Rectangle()
                    .fill(LinearGradient(
                        colors: isNight ? nightSandColors : daySandColors,
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(height: pixel * gridH * 0.28)
                    .offset(y: pixel * gridH * 0.72)

                if isNight {
                    PixelSpriteView(sprite: Sprites.moon, pixelSize: pixel)
                        .offset(x: pixel * (gridWidth - 14), y: pixel * 4)
                    PixelSpriteView(sprite: Sprites.star, pixelSize: max(2, pixel * 0.55))
                        .offset(x: pixel * 15, y: pixel * 5)
                    PixelSpriteView(sprite: Sprites.star, pixelSize: max(2, pixel * 0.45))
                        .offset(x: pixel * 37, y: pixel * 8)
                    PixelSpriteView(sprite: Sprites.star, pixelSize: max(2, pixel * 0.5))
                        .offset(x: pixel * 68, y: pixel * 6)
                    PixelSpriteView(sprite: Sprites.star, pixelSize: max(2, pixel * 0.4))
                        .offset(x: pixel * 82, y: pixel * 13)
                } else {
                    // Sun (upper right)
                    PixelSpriteView(sprite: Sprites.sun, pixelSize: pixel)
                        .offset(x: pixel * (gridWidth - 16), y: pixel * 3)
                }

                // Clouds drifting near the ocean horizon line.
                PixelSpriteView(sprite: isNight ? Sprites.nightCloud : Sprites.cloud, pixelSize: pixel)
                    .offset(x: pixel * 10, y: pixel * gridH * 0.42)
                PixelSpriteView(sprite: isNight ? Sprites.nightCloud : Sprites.cloud, pixelSize: pixel)
                    .offset(x: pixel * 48, y: pixel * gridH * 0.46)

                // Seagulls (drift along the ocean band so they sit on water,
                // not overlapping the UI panels above)
                PixelSpriteView(sprite: Sprites.seagull, pixelSize: pixel)
                    .offset(x: pixel * 30, y: pixel * gridH * 0.5)
                PixelSpriteView(sprite: Sprites.seagull, pixelSize: pixel)
                    .offset(x: pixel * 66, y: pixel * gridH * 0.55)

                // Palm tree (left, rooted in sand)
                PixelSpriteView(sprite: Sprites.palmTree, pixelSize: pixel)
                    .offset(x: pixel * 4, y: pixel * (gridH - 16))

                // Hodu — center-stage on the sand.
                PixelSpriteView(sprite: isNight ? Sprites.hoduSleeping : Sprites.hodu, pixelSize: pixel)
                    .offset(x: pixel * (gridWidth * 0.5 - 8),
                            y: pixel * (gridH - 18))

                if isNight {
                    Text("Zzz")
                        .font(.system(size: max(12, pixel * 3), weight: .heavy, design: .rounded))
                        .foregroundStyle(HoduPalette.moonGlow.opacity(0.85))
                        .offset(x: pixel * (gridWidth * 0.5 + 9),
                                y: pixel * (gridH - 20))
                }

                // Shell (foreground left of Hodu)
                PixelSpriteView(sprite: Sprites.shell, pixelSize: pixel)
                    .offset(x: pixel * 22, y: pixel * (gridH - 6))

                // Crab (to Hodu's right)
                PixelSpriteView(sprite: Sprites.crab, pixelSize: pixel)
                    .offset(x: pixel * 64, y: pixel * (gridH - 8))

                // Starfish (far right on the sand)
                PixelSpriteView(sprite: Sprites.starfish, pixelSize: pixel)
                    .offset(x: pixel * 82, y: pixel * (gridH - 9))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    private var daySkyColors: [Color] {
        [
            Color(red: 1.00, green: 0.86, blue: 0.72),
            Color(red: 0.75, green: 0.89, blue: 0.98),
            Color(red: 0.53, green: 0.80, blue: 0.95)
        ]
    }

    private var nightSkyColors: [Color] {
        [
            Color(red: 0.06, green: 0.08, blue: 0.18),
            Color(red: 0.10, green: 0.15, blue: 0.30),
            Color(red: 0.18, green: 0.25, blue: 0.42)
        ]
    }

    private var dayOceanColors: [Color] {
        [
            Color(red: 0.35, green: 0.64, blue: 0.82),
            Color(red: 0.48, green: 0.76, blue: 0.88)
        ]
    }

    private var nightOceanColors: [Color] {
        [
            Color(red: 0.08, green: 0.18, blue: 0.34),
            Color(red: 0.15, green: 0.30, blue: 0.48)
        ]
    }

    private var daySandColors: [Color] {
        [
            Color(red: 0.99, green: 0.89, blue: 0.62),
            Color(red: 0.93, green: 0.78, blue: 0.48)
        ]
    }

    private var nightSandColors: [Color] {
        [
            Color(red: 0.42, green: 0.35, blue: 0.27),
            Color(red: 0.31, green: 0.25, blue: 0.20)
        ]
    }
}
