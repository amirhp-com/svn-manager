#!/usr/bin/env swift
// Reads docs/screenshot.jpeg and writes docs/screenshot.png with rounded
// corners so it renders nicely in the README. Pure CoreGraphics — no AppKit
// session needed.
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let inPath  = "docs/screenshot.jpeg"
let outPath = "docs/screenshot.png"

guard FileManager.default.fileExists(atPath: inPath) else {
    print("skip: \(inPath) not found")
    exit(0)
}

let inURL = URL(fileURLWithPath: inPath)
guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("error: could not read \(inPath)")
    exit(1)
}

let w = img.width, h = img.height
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil,
                          width: w, height: h,
                          bitsPerComponent: 8,
                          bytesPerRow: 0,
                          space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("error: could not create context"); exit(1)
}

let rect = CGRect(x: 0, y: 0, width: w, height: h)
let radius = CGFloat(min(w, h)) * 0.025   // ~2.5% rounded corners
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path); ctx.clip()
ctx.draw(img, in: rect)

guard let rounded = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    print("error: could not write \(outPath)"); exit(1)
}
CGImageDestinationAddImage(dest, rounded, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath) (\(w)×\(h), corner radius \(Int(radius))px)")
