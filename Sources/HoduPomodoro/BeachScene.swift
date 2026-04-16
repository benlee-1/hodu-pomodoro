import SwiftUI

/// A pixel-art beach scene that scales crisply with window size.
struct BeachScene: View {
    /// Virtual grid width in pixels. Smaller = chunkier pixels.
    let gridWidth: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let pixel = max(2, floor(geo.size.width / gridWidth))
            let gridH = max(32, floor(geo.size.height / pixel))

            ZStack(alignment: .topLeading) {
                // Sky gradient
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.86, blue: 0.72),   // peach horizon
                        Color(red: 0.75, green: 0.89, blue: 0.98),   // light sky
                        Color(red: 0.53, green: 0.80, blue: 0.95)    // blue
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                // Ocean band (middle third)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.64, blue: 0.82),
                            Color(red: 0.48, green: 0.76, blue: 0.88)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(height: pixel * gridH * 0.24)
                    .offset(y: pixel * gridH * 0.48)

                // Wave highlights
                Rectangle()
                    .fill(HoduPalette.waveLight)
                    .frame(height: pixel)
                    .offset(y: pixel * gridH * 0.58)
                Rectangle()
                    .fill(HoduPalette.waveLight.opacity(0.7))
                    .frame(height: pixel)
                    .offset(y: pixel * gridH * 0.63)

                // Sand
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.89, blue: 0.62),
                            Color(red: 0.93, green: 0.78, blue: 0.48)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(height: pixel * gridH * 0.28)
                    .offset(y: pixel * gridH * 0.72)

                // Sun (upper right)
                PixelSpriteView(sprite: Sprites.sun, pixelSize: pixel)
                    .offset(x: pixel * (gridWidth - 16), y: pixel * 3)

                // Clouds drifting near the ocean horizon line.
                PixelSpriteView(sprite: Sprites.cloud, pixelSize: pixel)
                    .offset(x: pixel * 10, y: pixel * gridH * 0.42)
                PixelSpriteView(sprite: Sprites.cloud, pixelSize: pixel)
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
                PixelSpriteView(sprite: Sprites.hodu, pixelSize: pixel)
                    .offset(x: pixel * (gridWidth * 0.5 - 8),
                            y: pixel * (gridH - 18))

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
}
