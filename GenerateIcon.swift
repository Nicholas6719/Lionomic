#!/usr/bin/env swift
// GenerateIcon.swift
// Renders Lionomic's placeholder app icon (1024×1024 PNG) into
// Lionomic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png.
//
// Run from the repo root (the folder that contains Lionomic.xcodeproj):
//     swift GenerateIcon.swift
//
// Design: deep-navy rounded-square background, gold serifed "L" monogram,
// upward green trend line, subtle vignette. Placeholder quality — meant to
// signal "private investing app" without looking like the Xcode default.

import Foundation
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let rect = CGRect(x: 0, y: 0, width: size, height: size)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("Failed to create CGContext\n".utf8))
    exit(1)
}

// Background — deep navy radial gradient
let bgInner = CGColor(red: 0.055, green: 0.10,  blue: 0.18, alpha: 1)
let bgOuter = CGColor(red: 0.018, green: 0.035, blue: 0.07, alpha: 1)

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [bgInner, bgOuter] as CFArray,
    locations: [0.0, 1.0]
)!

ctx.drawRadialGradient(
    gradient,
    startCenter: CGPoint(x: size * 0.45, y: size * 0.55),
    startRadius: 0,
    endCenter:   CGPoint(x: size * 0.5,  y: size * 0.5),
    endRadius:   size * 0.75,
    options: []
)

// Upward trend line — muted gold
let gold = CGColor(red: 0.82, green: 0.68, blue: 0.32, alpha: 0.9)
ctx.setStrokeColor(gold)
ctx.setLineWidth(22)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

ctx.beginPath()
ctx.move(to:    CGPoint(x: size * 0.14, y: size * 0.34))
ctx.addLine(to: CGPoint(x: size * 0.34, y: size * 0.44))
ctx.addLine(to: CGPoint(x: size * 0.50, y: size * 0.30))
ctx.addLine(to: CGPoint(x: size * 0.66, y: size * 0.50))
ctx.addLine(to: CGPoint(x: size * 0.86, y: size * 0.72))
ctx.strokePath()

// Arrowhead at the top-right of the trend line
let tipX = size * 0.86
let tipY = size * 0.72
let arrowSize: CGFloat = 46
ctx.setFillColor(gold)
ctx.beginPath()
ctx.move(to:    CGPoint(x: tipX,              y: tipY + arrowSize * 0.2))
ctx.addLine(to: CGPoint(x: tipX - arrowSize,  y: tipY - arrowSize * 0.05))
ctx.addLine(to: CGPoint(x: tipX - arrowSize * 0.2, y: tipY - arrowSize))
ctx.closePath()
ctx.fillPath()

// "L" monogram — large, centered, gold serif-inspired
let monogramColor = NSColor(srgbRed: 0.96, green: 0.86, blue: 0.52, alpha: 1.0)
let attributedString = NSAttributedString(
    string: "L",
    attributes: [
        .font:            NSFont(name: "Georgia-Bold", size: 620)
                       ?? NSFont.boldSystemFont(ofSize: 620),
        .foregroundColor: monogramColor
    ]
)

// Measure and position
let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)
let bounds = CTLineGetImageBounds(line, ctx)
let glyphX = (size - bounds.width) / 2 - bounds.origin.x
let glyphY = (size - bounds.height) / 2 - bounds.origin.y - size * 0.02

ctx.textPosition = CGPoint(x: glyphX, y: glyphY)
CTLineDraw(line, ctx)

// Vignette — subtle darkening at the corners
let vignetteColors = [
    CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
    CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
] as CFArray
let vignette = CGGradient(
    colorsSpace: colorSpace,
    colors: vignetteColors,
    locations: [0.55, 1.0]
)!
ctx.drawRadialGradient(
    vignette,
    startCenter: CGPoint(x: size / 2, y: size / 2),
    startRadius: 0,
    endCenter:   CGPoint(x: size / 2, y: size / 2),
    endRadius:   size * 0.75,
    options: []
)

// Write PNG
guard let cgImage = ctx.makeImage() else {
    FileHandle.standardError.write(Data("Failed to make CGImage\n".utf8))
    exit(1)
}
let nsImage = NSBitmapImageRep(cgImage: cgImage)
guard let data = nsImage.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to PNG-encode\n".utf8))
    exit(1)
}

let outputPath = "Lionomic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
try data.write(to: outputURL)

print("Wrote \(outputPath) (\(data.count) bytes)")
