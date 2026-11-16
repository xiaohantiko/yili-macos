import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let center = CGPoint(x: 512, y: 512)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func fillDisc(_ context: CGContext, at point: CGPoint, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(
        x: point.x - radius, y: point.y - radius, width: 2 * radius, height: 2 * radius
    ))
}

func strokeRing(_ context: CGContext, radius: CGFloat, width: CGFloat, color: CGColor) {
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.strokeEllipse(in: CGRect(
        x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius
    ))
}

func position(radius: CGFloat, angle: CGFloat) -> CGPoint {
    CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
}

func drawIcon(in context: CGContext) {
    let tile = CGPath(
        roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
        cornerWidth: 198, cornerHeight: 198, transform: nil
    )
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x2B3027), color(0x171B17), color(0x111411)] as CFArray,
        locations: [0, 0.6, 1]
    )!

    context.saveGState()
    context.addPath(tile)
    context.clip()
    context.drawLinearGradient(
        background, start: CGPoint(x: 315, y: 960), end: CGPoint(x: 815, y: 64),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    context.addPath(tile)
    context.setStrokeColor(color(0xC6A367, alpha: 0.27))
    context.setLineWidth(3)
    context.strokePath()

    strokeRing(context, radius: 327, width: 3, color: color(0xC6A367, alpha: 0.35))
    strokeRing(context, radius: 276, width: 3, color: color(0xC6A367, alpha: 0.48))
    strokeRing(context, radius: 250, width: 2, color: color(0xC6A367, alpha: 0.15))

    context.setLineCap(.round)
    for tick in 0..<32 {
        let angle = CGFloat(tick) * .pi / 16
        let isCardinal = tick.isMultiple(of: 8)
        let isMajor = tick.isMultiple(of: 4)
        context.setLineWidth(isMajor ? 5 : 3)
        context.setStrokeColor(color(0xC6A367, alpha: isMajor ? 0.72 : 0.27))
        context.move(to: position(radius: isMajor ? 286 : 302, angle: angle))
        context.addLine(to: position(radius: 315, angle: angle))
        context.strokePath()
        if isCardinal {
            fillDisc(context, at: position(radius: 327, angle: angle), radius: 6, color: color(0xD9BA7E))
        }
    }

    let trigramBars = [
        CGRect(x: 356, y: 589, width: 312, height: 50),
        CGRect(x: 356, y: 487, width: 128, height: 50),
        CGRect(x: 540, y: 487, width: 128, height: 50),
        CGRect(x: 356, y: 385, width: 312, height: 50),
    ]
    let bronze = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0xE7D2A2), color(0xBE985C)] as CFArray,
        locations: [0, 1]
    )!
    context.saveGState()
    for bar in trigramBars {
        context.addPath(CGPath(roundedRect: bar, cornerWidth: 12, cornerHeight: 12, transform: nil))
    }
    context.clip()
    context.drawLinearGradient(
        bronze, start: CGPoint(x: 512, y: 639), end: CGPoint(x: 512, y: 385), options: []
    )
    context.restoreGState()
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift scripts/make-icon.swift <destination.iconset>")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let factor = CGFloat(pixels) / 1024
        context.scaleBy(x: factor, y: factor)
        drawIcon(in: context)

        let suffix = scale == 2 ? "@2x" : ""
        let path = directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else {
            fatalError("Could not write \(path.path)")
        }
    }
}
