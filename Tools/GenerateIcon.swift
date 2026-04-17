#!/usr/bin/env swift
// Generates a 1024×1024 PNG of Hodu on an orange squircle background.
// Run: swift Tools/GenerateIcon.swift /tmp/icon.png

import Foundation
import AppKit
import CoreGraphics

// Full Hodu sprite (kept in sync with Sources/HoduPomodoro/PixelArt.swift).
let hodu: [String] = [
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
]

let palette: [Character: CGColor] = [
    "B": CGColor(srgbRed: 0.20, green: 0.13, blue: 0.10, alpha: 1),
    "O": CGColor(srgbRed: 1.00, green: 0.62, blue: 0.32, alpha: 1),
    "o": CGColor(srgbRed: 0.82, green: 0.42, blue: 0.20, alpha: 1),
    "W": CGColor(srgbRed: 1.00, green: 0.98, blue: 0.94, alpha: 1),
    "P": CGColor(srgbRed: 1.00, green: 0.68, blue: 0.72, alpha: 1),
    "E": CGColor(srgbRed: 0.10, green: 0.08, blue: 0.06, alpha: 1)
]

let size: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Couldn't create bitmap context") }

// Background: transparent outside the squircle, warm orange inside.
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

// macOS-style squircle (approximated with rounded rect).
let corner = size * 0.224
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
ctx.saveGState()
ctx.addPath(path)
ctx.clip()

// Warm peach → deeper orange gradient.
let colors = [
    CGColor(srgbRed: 1.00, green: 0.86, blue: 0.58, alpha: 1),
    CGColor(srgbRed: 1.00, green: 0.62, blue: 0.28, alpha: 1)
] as CFArray
let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end:   CGPoint(x: 0, y: 0),
    options: []
)

// Soft sandy strip at the bottom suggesting the beach.
let sandHeight = size * 0.18
let sandRect = CGRect(x: 0, y: 0, width: size, height: sandHeight)
let sandColors = [
    CGColor(srgbRed: 0.98, green: 0.85, blue: 0.55, alpha: 0.95),
    CGColor(srgbRed: 0.94, green: 0.74, blue: 0.42, alpha: 1)
] as CFArray
let sandGrad = CGGradient(colorsSpace: cs, colors: sandColors, locations: [0, 1])!
ctx.drawLinearGradient(
    sandGrad,
    start: CGPoint(x: 0, y: sandHeight),
    end:   CGPoint(x: 0, y: 0),
    options: []
)

// Hodu: scale to fill ~75% of the icon, centered and sitting on the sand.
let grid = 16.0
let pixel = (size * 0.72) / CGFloat(grid)
let artW = pixel * CGFloat(grid)
let artH = pixel * CGFloat(hodu.count)
let offsetX = (size - artW) / 2
// Sit Hodu so his feet rest on the sand line (y ~= sandHeight from bottom).
let offsetYFromTop = size - sandHeight * 0.7 - artH

for (y, row) in hodu.enumerated() {
    for (x, ch) in row.enumerated() {
        guard ch != ".", let color = palette[ch] else { continue }
        let px = offsetX + CGFloat(x) * pixel
        // Flip Y because CGContext is bottom-up.
        let py = size - offsetYFromTop - CGFloat(y + 1) * pixel
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: px, y: py, width: pixel, height: pixel))
    }
}

ctx.restoreGState()

guard let cgImage = ctx.makeImage() else { fatalError("Couldn't snapshot image") }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Couldn't encode PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let url = URL(fileURLWithPath: outputPath)
try data.write(to: url)
FileHandle.standardError.write(Data("Wrote \(url.path)\n".utf8))
