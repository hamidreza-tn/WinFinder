#!/usr/bin/env swift
// make_dmg_background.swift
//
// Programmatically draws the DMG installer background image for WinFinder.
//
// Usage:
//   swift scripts/make_dmg_background.swift <output.png> [scale]
//
// The DMG window is 660 x 510 points. At the default scale of 2 (retina)
// the output PNG is 1320 x 1020 px.
//
// Layout assumptions (window coordinates measured from the TOP-LEFT, in
// points — same frame a DMG screenshot uses):
//   - WinFinder.app icon centered at ~(170, 210), label below the icon
//   - Applications folder icon centered at ~(490, 210), label below
//   - This background only supplies: the flat off-white backdrop, the
//     horizontal arrow between the two icon slots (y ~= 215), a centered
//     title (y ~= 360) and a centered subtitle (y ~= 400). It keeps the
//     icon areas quiet so the real icons/labels read cleanly.
//
// AppKit bitmap contexts use a BOTTOM-LEFT origin, so every top-origin y is
// converted with `canvasH - y` before drawing.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Layout constants (all in points; text/arrow y values are top-origin)

let canvasW: CGFloat = 660
let canvasH: CGFloat = 510

// Icon slot centers, top-origin (informational; nothing is drawn there)
let appIconCenterTop = CGPoint(x: 170, y: 210)
let appsIconCenterTop = CGPoint(x: 490, y: 210)

// Arrow: points from the app-icon slot toward the Applications slot,
// horizontally centered between the two icon centers (x = 330).
let arrowCenterYTop: CGFloat = 215
let arrowStroke: CGFloat = 14
let arrowHeadLength: CGFloat = 19
let arrowHeadHalf: CGFloat = 15

// Text (center-y, top-origin)
let titleText = "Drag WinFinder to Applications"
let subtitleText = "Ad-hoc signed · first launch: right-click WinFinder › Open"
let titleSize: CGFloat = 28
let subtitleSize: CGFloat = 17
let titleCenterYTop: CGFloat = 360
let subtitleCenterYTop: CGFloat = 400
let textCenterX = (canvasW / 2)          // centered on the full 660 pt width

// Bottom-origin conversions for AppKit drawing
func bottomY(_ topOriginY: CGFloat) -> CGFloat { canvasH - topOriginY }
let appIconCenter = CGPoint(x: appIconCenterTop.x, y: bottomY(appIconCenterTop.y))
let appsIconCenter = CGPoint(x: appsIconCenterTop.x, y: bottomY(appsIconCenterTop.y))
let arrowCenterY = bottomY(arrowCenterYTop)
let titleCenterY = bottomY(titleCenterYTop)
let subtitleCenterY = bottomY(subtitleCenterYTop)

// Colors
let backdropTop = NSColor(srgbRed: 0xF2 / 255.0, green: 0xF2 / 255.0, blue: 0xF4 / 255.0, alpha: 1)   // #F2F2F4
let backdropBottom = NSColor(srgbRed: 0xEF / 255.0, green: 0xEF / 255.0, blue: 0xF1 / 255.0, alpha: 1) // #EFEFF1
let arrowColor = NSColor(srgbRed: 0xB9 / 255.0, green: 0xB9 / 255.0, blue: 0xBE / 255.0, alpha: 1)     // #B9B9BE
let titleColor = NSColor(srgbRed: 0x1D / 255.0, green: 0x1D / 255.0, blue: 0x1F / 255.0, alpha: 1)     // #1D1D1F
let subtitleColor = NSColor(srgbRed: 0x86 / 255.0, green: 0x86 / 255.0, blue: 0x8B / 255.0, alpha: 1)  // #86868B

// MARK: - Argument parsing

let arguments = CommandLine.arguments
guard arguments.count >= 2, arguments.count <= 3 else {
    FileHandle.standardError.write("Usage: swift make_dmg_background.swift <output.png> [scale]\n".data(using: .utf8)!)
    exit(2)
}
let outputPath = arguments[1]
let scale: CGFloat = arguments.count == 3 ? (CGFloat(Double(arguments[2]) ?? 2)) : 2
guard scale > 0 else {
    FileHandle.standardError.write("error: scale must be a positive number\n".data(using: .utf8)!)
    exit(2)
}

let pixelW = Int(round(canvasW * scale))
let pixelH = Int(round(canvasH * scale))

// MARK: - Bitmap context (deterministic: explicit bitmap rep, no lockFocus)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelW,
    pixelsHigh: pixelH,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write("error: could not create bitmap image rep\n".data(using: .utf8)!)
    exit(1)
}
rep.size = NSSize(width: canvasW, height: canvasH) // 1 unit = 1 point

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("error: could not create graphics context\n".data(using: .utf8)!)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

// --- 1. Backdrop: flat, very light off-white with a barely-there vertical gradient
let backdropRect = NSRect(x: 0, y: 0, width: canvasW, height: canvasH)
let gradient = NSGradient(colors: [backdropBottom, backdropTop])
gradient?.draw(in: backdropRect, angle: 90) // subtle #EFEFF1 (bottom) -> #F2F2F4 (top)

// --- 2. Arrow: rounded gray shaft + chevron head, from app slot to Applications slot
let arrowY = arrowCenterY
let shaftStart = CGPoint(x: appIconCenter.x + 75, y: arrowY)           // x = 245
let tip = CGPoint(x: appsIconCenter.x - 75, y: arrowY)                 // x = 415
let headBaseX = tip.x - arrowHeadLength

cg.setLineWidth(arrowStroke)
cg.setLineCap(.round)
cg.setLineJoin(.round)
cg.setShouldAntialias(true)

// Shaft
cg.setStrokeColor(arrowColor.cgColor)
cg.move(to: shaftStart)
cg.addLine(to: CGPoint(x: headBaseX + 2, y: arrowY))
cg.strokePath()

// Head (chevron)
cg.beginPath()
cg.move(to: CGPoint(x: headBaseX, y: arrowY - arrowHeadHalf))
cg.addLine(to: tip)
cg.addLine(to: CGPoint(x: headBaseX, y: arrowY + arrowHeadHalf))
cg.strokePath()

// --- 3. Title + 4. Subtitle: centered horizontally on the full width,
//        vertically centered on their layout y positions.
func drawCentered(_ string: String, font: NSFont, color: NSColor, centerX: CGFloat, centerY: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]
    let attributed = NSAttributedString(string: string, attributes: attrs)
    let size = attributed.size()
    // Round to whole points so repeated runs are pixel-identical.
    let originX = (centerX - size.width / 2).rounded(.toNearestOrEven)
    let originY = (centerY - size.height / 2).rounded(.toNearestOrEven)
    attributed.draw(at: NSPoint(x: originX, y: originY))
}

let titleFont = NSFont.systemFont(ofSize: titleSize, weight: .semibold)
let subtitleFont = NSFont.systemFont(ofSize: subtitleSize, weight: .regular)

drawCentered(titleText, font: titleFont, color: titleColor, centerX: textCenterX, centerY: titleCenterY)
drawCentered(subtitleText, font: subtitleFont, color: subtitleColor, centerX: textCenterX, centerY: subtitleCenterY)

ctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

// MARK: - Write PNG

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("error: could not encode PNG\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write("error: could not write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}

print("wrote \(outputPath) (\(pixelW) x \(pixelH) px, \(canvasW) x \(canvasH) pt @ \(scale)x)")
print("icon slots (top-origin y): app center (\(appIconCenterTop.x), \(appIconCenterTop.y)) pt, Applications center (\(appsIconCenterTop.x), \(appsIconCenterTop.y)) pt")
print("icon slots (bottom-origin y, Finder/.DS_Store frame): app center (\(appIconCenter.x), \(appIconCenter.y)) pt, Applications center (\(appsIconCenter.x), \(appsIconCenter.y)) pt")
