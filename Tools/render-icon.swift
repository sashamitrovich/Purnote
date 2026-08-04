//
//  render-icon.swift
//  Purnote
//
//  Regenerates the app icon into purenote/Assets.xcassets/AppIcon.appiconset.
//
//      swiftc -O -o /tmp/render-icon Tools/render-icon.swift
//      cd purenote/Assets.xcassets/AppIcon.appiconset && /tmp/render-icon
//
//  The art is drawn rather than exported from a design tool so that the stroke
//  weight, the slant and the colours stay editable here.
//
//  Two rules the design has to keep:
//
//  1. Full bleed, no rounded corners of its own. iOS masks the icon, and
//     baking in a shape gets it clipped twice.
//  2. The mark stays light on a coloured ground in every variant. Inverting
//     the dark variant to orange strokes on near black merged them into a
//     blob at home screen size, because the strokes are heavy relative to
//     their gaps.
//
import AppKit

let size: CGFloat = 1024

func context() -> CGContext {
    CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func save(_ ctx: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
}
func gradient(_ ctx: CGContext, _ bottom: NSColor, _ top: NSColor) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [bottom.cgColor, top.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size), options: [])
}
func hash(_ ctx: CGContext, _ color: NSColor) {
    let cx = size/2, cy = size/2, span = size*0.42, half = span/2, slant = span*0.11
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(size*0.085)
    ctx.setLineCap(.round)
    for dx in [-span*0.20, span*0.20] {
        ctx.move(to: CGPoint(x: cx + dx - slant, y: cy - half))
        ctx.addLine(to: CGPoint(x: cx + dx + slant, y: cy + half))
    }
    for dy in [-span*0.19, span*0.19] {
        ctx.move(to: CGPoint(x: cx - half, y: cy + dy))
        ctx.addLine(to: CGPoint(x: cx + half, y: cy + dy))
    }
    ctx.strokePath()
}

// light
do {
    let ctx = context()
    gradient(ctx, NSColor(srgbRed: 0.95, green: 0.39, blue: 0.04, alpha: 1),
                  NSColor(srgbRed: 1.00, green: 0.66, blue: 0.16, alpha: 1))
    hash(ctx, NSColor(srgbRed: 1.0, green: 0.99, blue: 0.97, alpha: 1))
    save(ctx, "icon-light.png")
}
// dark: a deeper, hotter orange, but the mark stays light on a coloured
// ground. Inverting it -- orange strokes on near black -- merged into a blob
// at home screen size, because the strokes are heavy relative to their gaps.
do {
    let ctx = context()
    gradient(ctx, NSColor(srgbRed: 0.62, green: 0.22, blue: 0.01, alpha: 1),
                  NSColor(srgbRed: 0.82, green: 0.42, blue: 0.05, alpha: 1))
    hash(ctx, NSColor(srgbRed: 0.99, green: 0.95, blue: 0.90, alpha: 1))
    save(ctx, "icon-dark.png")
}
// tinted: greyscale on transparent, the system supplies the tint and the ground
do {
    let ctx = context()
    hash(ctx, NSColor(white: 0.92, alpha: 1))
    save(ctx, "icon-tinted.png")
}
