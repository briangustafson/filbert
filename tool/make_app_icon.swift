// Makes the app icon sources in assets/icon/ from the artwork (1024 px
// square, opaque). Then `dart run flutter_launcher_icons` builds every size.
//
//   swift tool/make_app_icon.swift <artwork.jpg|png>
//
// - source.png: the artwork as it is.
// - full.png: the subject enlarged 1.25× around its centre, for icons shown
//   whole (macOS, legacy Android).
// - android_foreground.png: the subject at 0.88×, so the round masks of
//   Android's adaptive icons (middle 66%) don't clip the flourish.
import CoreGraphics
import Foundation
import ImageIO

let size = 1024
let source = CGImageSourceCreateWithURL(
  URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil)!
let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let out = URL(fileURLWithPath: "assets/icon", isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

/// The subject's centre in the artwork, in pixels from the top left.
let centre = CGPoint(x: 547, y: 512)

func render(_ name: String, scale: CGFloat, around c: CGPoint, fill: CGColor?) {
  // Opaque RGB (no alpha channel in the PNG).
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.interpolationQuality = .high
  ctx.setFillColor(fill ?? CGColor(gray: 0, alpha: 1))
  ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
  let s = CGFloat(size) * scale
  // Flipped y: Core Graphics' origin is bottom left.
  let x = CGFloat(size) / 2 - c.x * scale
  let y = CGFloat(size) / 2 - (CGFloat(size) - c.y) * scale
  ctx.draw(artwork, in: CGRect(x: x, y: y, width: s, height: s))
  let url = out.appendingPathComponent(name) as CFURL
  let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
  CGImageDestinationFinalize(dest)
}

/// The mean colour of the artwork's border, to fill around a shrunk copy.
func borderColour() -> CGColor {
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.draw(artwork, in: CGRect(x: 0, y: 0, width: size, height: size))
  let px = ctx.data!.assumingMemoryBound(to: UInt8.self)
  var sum = [0.0, 0.0, 0.0], n = 0.0
  for i in stride(from: 0, to: size, by: 4) {
    for (x, y) in [(i, 2), (i, size - 3), (2, i), (size - 3, i)] {
      for k in 0..<3 { sum[k] += Double(px[(y * size + x) * 4 + k]) }
      n += 1
    }
  }
  let mean = sum.map { ($0 / n).rounded() }
  print(String(format: "background #%02X%02X%02X", Int(mean[0]), Int(mean[1]), Int(mean[2])))
  return CGColor(
    srgbRed: mean[0] / 255, green: mean[1] / 255, blue: mean[2] / 255, alpha: 1)
}

let mid = CGPoint(x: size / 2, y: size / 2)
render("source.png", scale: 1, around: mid, fill: nil)
render("full.png", scale: 1.25, around: centre, fill: nil)
render("android_foreground.png", scale: 0.88, around: mid, fill: borderColour())
