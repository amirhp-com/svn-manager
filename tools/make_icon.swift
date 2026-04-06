#!/usr/bin/env swift
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Foundation
import AppKit  // for NSColor.cgColor convenience

let fm = FileManager.default
let buildDir = "build"
let setDir = "\(buildDir)/AppIcon.iconset"
try? fm.createDirectory(atPath: setDir, withIntermediateDirectories: true)

func render(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil,
                              width: size, height: size,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Rounded rect clip
    let radius = s * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path); ctx.clip()

    // Diagonal gradient background
    let colors = [
        CGColor(red: 0.27, green: 0.45, blue: 0.92, alpha: 1.0),
        CGColor(red: 0.39, green: 0.30, blue: 0.78, alpha: 1.0),
        CGColor(red: 0.55, green: 0.20, blue: 0.62, alpha: 1.0)
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: locations) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: s, y: 0),
                               options: [])
    }

    // Soft top highlight
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.fillEllipse(in: CGRect(x: -s*0.2, y: s*0.45, width: s*1.4, height: s*0.9))

    // Tiny tag bar
    let tagRect = CGRect(x: s * 0.13, y: s * 0.13, width: s * 0.18, height: s * 0.06)
    let tagPath = CGPath(roundedRect: tagRect, cornerWidth: s*0.02, cornerHeight: s*0.02, transform: nil)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
    ctx.addPath(tagPath); ctx.fillPath()

    // "svn" wordmark with CoreText
    let fontSize = s * 0.42
    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    ]
    let attr = NSAttributedString(string: "svn", attributes: attrs)
    let line = CTLineCreateWithAttributedString(attr)
    let bounds = CTLineGetImageBounds(line, ctx)
    let x = (s - bounds.width) / 2 - bounds.origin.x
    let y = (s - bounds.height) / 2 - bounds.origin.y
    // shadow
    ctx.setShadow(offset: CGSize(width: 0, height: -max(1, s*0.01)),
                  blur: max(1, s*0.04),
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString,
                                                     1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let entries: [(name: String, size: Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png",  1024)
]

for entry in entries {
    if let img = render(size: entry.size) {
        writePNG(img, to: "\(setDir)/\(entry.name)")
        print("wrote \(entry.name) (\(entry.size)px)")
    }
}

let proc = Process()
proc.launchPath = "/usr/bin/env"
proc.arguments  = ["iconutil", "-c", "icns", setDir, "-o", "\(buildDir)/AppIcon.icns"]
try? proc.run()
proc.waitUntilExit()
print("iconutil exited with \(proc.terminationStatus)")
