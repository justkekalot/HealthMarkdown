import AppKit

let S: CGFloat = 1024
let terracotta = NSColor(srgbRed: 0xE0/255, green: 0x69/255, blue: 0x4C/255, alpha: 1)
let cream = NSColor(srgbRed: 0xF4/255, green: 0xF1/255, blue: 0xEA/255, alpha: 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let cg = gctx.cgContext

// Background: warm-dark vertical gradient with a faint glow upper-centre.
let cs = CGColorSpaceCreateDeviceRGB()
let g = CGGradient(colorsSpace: cs, colors: [
    CGColor(srgbRed: 0x24/255, green: 0x1E/255, blue: 0x19/255, alpha: 1),
    CGColor(srgbRed: 0x0B/255, green: 0x09/255, blue: 0x08/255, alpha: 1)] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(g, start: CGPoint(x: S/2, y: S), end: CGPoint(x: S/2, y: 0), options: [])

// SF Symbol, tinted.
func tinted(_ name: String, color: NSColor, pointSize: CGFloat, weight: NSFont.Weight = .semibold) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return nil }
    let img = NSImage(size: base.size)
    img.lockFocus()
    color.set()
    let r = NSRect(origin: .zero, size: base.size)
    base.draw(in: r)
    r.fill(using: .sourceAtop)
    img.unlockFocus()
    return img
}

func draw(_ img: NSImage?, centeredAt c: CGPoint, height h: CGFloat) {
    guard let img = img else { return }
    let ar = img.size.width / img.size.height
    let w = h * ar
    img.draw(in: NSRect(x: c.x - w/2, y: c.y - h/2, width: w, height: h))
}

// Heart (solid) as a filled SF Symbol so it stays crisp & on-brand.
let heartY: CGFloat = 612, bikeY: CGFloat = 372
let contentX: CGFloat = 672
let promptX: CGFloat = 350
// Top row: ">" (cream, left) + heart (terracotta, right).
draw(tinted("heart.fill", color: terracotta, pointSize: 300, weight: .regular), centeredAt: CGPoint(x: contentX, y: heartY), height: 300)
// Bottom row: bike (terracotta, left) + "_" (cream, right) — swapped per request.
draw(tinted("figure.outdoor.cycle", color: terracotta, pointSize: 300, weight: .medium), centeredAt: CGPoint(x: promptX, y: bikeY), height: 292)

cream.set()
// Chevron ">": same width as the dash (200), raised so it clears the cyclist.
let chev = NSBezierPath()
chev.lineWidth = 64
chev.lineCapStyle = .round
chev.lineJoinStyle = .round
let chevY: CGFloat = 658
chev.move(to: NSPoint(x: promptX - 100, y: chevY + 86))
chev.line(to: NSPoint(x: promptX + 100, y: chevY))
chev.line(to: NSPoint(x: promptX - 100, y: chevY - 86))
chev.stroke()
// Underscore "_" (now bottom-right, under the heart).
let und = NSBezierPath(roundedRect: NSRect(x: contentX - 100, y: bikeY - 118, width: 200, height: 54), xRadius: 27, yRadius: 27)
und.fill()

NSGraphicsContext.restoreGraphicsState()
let out = "Sources/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
