import SwiftUI

/// Hand-drawn-style line-art doodles for onboarding. Vector (Canvas), so they
/// scale crisply and tint with the accent. Strokes are deliberately wobbly and
/// double-passed for a real sketchbook-doodle feel — not clean geometry.
struct Doodle: View {
    enum Kind { case heartToDoc, privacy, askAI }
    let kind: Kind
    var color: Color = Theme.accent

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let lw: CGFloat = max(3, w * 0.02)
            let shading = GraphicsContext.Shading.color(color)

            // Stroke a polyline of points twice, each pass jittered differently,
            // so it reads as a hand-drawn sketch (slightly overshooting, wobbly).
            func sketch(_ pts: [CGPoint], seed: Int, closed: Bool = false, width: CGFloat = lw) {
                guard pts.count > 1 else { return }
                for pass in 0..<2 {
                    var rng = SeededRNG(seed: UInt64(seed &* 131 &+ pass &* 977 &+ 7))
                    let jit = w * 0.012
                    var jittered = pts.map { pt in
                        CGPoint(x: pt.x + rng.next(jit), y: pt.y + rng.next(jit))
                    }
                    if closed, let f = jittered.first { jittered.append(f) }
                    var path = Path()
                    path.move(to: jittered[0])
                    // Smooth through points with quad curves for a flowing hand line.
                    for i in 1..<jittered.count {
                        let prev = jittered[i-1], cur = jittered[i]
                        let mid = CGPoint(x: (prev.x + cur.x)/2, y: (prev.y + cur.y)/2)
                        path.addQuadCurve(to: mid, control: prev)
                        if i == jittered.count - 1 { path.addLine(to: cur) }
                    }
                    ctx.stroke(path, with: shading,
                               style: StrokeStyle(lineWidth: width * (pass == 0 ? 1 : 0.7),
                                                  lineCap: .round, lineJoin: .round))
                }
            }

            switch kind {
            case .heartToDoc:
                sketch(heartPts(center: CGPoint(x: w*0.26, y: h*0.42), s: w*0.17), seed: 1, closed: true)
                // arrow
                let ay = h*0.42
                sketch([CGPoint(x: w*0.44, y: ay), CGPoint(x: w*0.585, y: ay)], seed: 2)
                sketch([CGPoint(x: w*0.54, y: ay - h*0.045), CGPoint(x: w*0.59, y: ay), CGPoint(x: w*0.54, y: ay + h*0.045)], seed: 3)
                // document
                let dx = w*0.62, dy = h*0.21, dw = w*0.27, dh = h*0.44
                sketch(rectPts(dx, dy, dw, dh), seed: 4, closed: true)
                for i in 0..<3 {
                    let ly = dy + dh*(0.32 + Double(i)*0.2)
                    sketch([CGPoint(x: dx+dw*0.18, y: ly), CGPoint(x: dx+dw*0.82, y: ly)], seed: 10+i, width: lw*0.75)
                }

            case .privacy:
                let px = w*0.33, py = h*0.15, pw = w*0.34, ph = h*0.62
                sketch(rectPts(px, py, pw, ph), seed: 1, closed: true)
                // lock body
                let lx = w*0.43, ly = h*0.44, lwid = w*0.14, lhei = h*0.16
                sketch(rectPts(lx, ly, lwid, lhei), seed: 2, closed: true)
                // shackle
                sketch(arcPts(center: CGPoint(x: w*0.5, y: ly), r: w*0.05, from: 180, to: 360, steps: 10), seed: 3)
                // keyhole dot
                sketch([CGPoint(x: w*0.5, y: ly+lhei*0.4), CGPoint(x: w*0.5, y: ly+lhei*0.65)], seed: 4, width: lw)

            case .askAI:
                let bx = w*0.16, by = h*0.2, bw = w*0.5, bh = h*0.34
                sketch(rectPts(bx, by, bw, bh), seed: 1, closed: true)
                sketch([CGPoint(x: bx+bw*0.22, y: by+bh), CGPoint(x: bx+bw*0.15, y: by+bh+h*0.09), CGPoint(x: bx+bw*0.42, y: by+bh)], seed: 2)
                for i in 0..<3 {
                    let dx = bx + bw*(0.3 + Double(i)*0.2)
                    sketch(arcPts(center: CGPoint(x: dx, y: by+bh*0.5), r: w*0.012, from: 0, to: 360, steps: 8), seed: 20+i, closed: true, width: lw*0.9)
                }
                sketch(sparklePts(center: CGPoint(x: w*0.78, y: h*0.58), s: w*0.1), seed: 5, closed: true)
                sketch(sparklePts(center: CGPoint(x: w*0.87, y: h*0.4), s: w*0.05), seed: 6, closed: true)
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
    }

    // MARK: - Point generators

    private func heartPts(center c: CGPoint, s: CGFloat) -> [CGPoint] {
        var pts: [CGPoint] = []; var t = 0.0
        while t <= 2 * Double.pi {
            let x = 16 * pow(sin(t), 3)
            let y = -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))
            pts.append(CGPoint(x: c.x + CGFloat(x)*s/16, y: c.y + CGFloat(y)*s/16))
            t += 0.32
        }
        return pts
    }

    private func rectPts(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        // Sample along the rectangle edges so jitter affects the whole outline.
        var pts: [CGPoint] = []
        let n = 5
        for i in 0...n { pts.append(CGPoint(x: x + w*CGFloat(i)/CGFloat(n), y: y)) }
        for i in 1...n { pts.append(CGPoint(x: x+w, y: y + h*CGFloat(i)/CGFloat(n))) }
        for i in 1...n { pts.append(CGPoint(x: x+w - w*CGFloat(i)/CGFloat(n), y: y+h)) }
        for i in 1...n { pts.append(CGPoint(x: x, y: y+h - h*CGFloat(i)/CGFloat(n))) }
        return pts
    }

    private func arcPts(center c: CGPoint, r: CGFloat, from: Double, to: Double, steps: Int) -> [CGPoint] {
        (0...steps).map { i in
            let a = (from + (to-from)*Double(i)/Double(steps)) * .pi/180
            return CGPoint(x: c.x + r*CGFloat(cos(a)), y: c.y + r*CGFloat(sin(a)))
        }
    }

    private func sparklePts(center c: CGPoint, s: CGFloat) -> [CGPoint] {
        // four-point star, slightly rounded by sampling
        let pts: [CGPoint] = [
            CGPoint(x: c.x, y: c.y - s),
            CGPoint(x: c.x + s*0.28, y: c.y - s*0.28),
            CGPoint(x: c.x + s, y: c.y),
            CGPoint(x: c.x + s*0.28, y: c.y + s*0.28),
            CGPoint(x: c.x, y: c.y + s),
            CGPoint(x: c.x - s*0.28, y: c.y + s*0.28),
            CGPoint(x: c.x - s, y: c.y),
            CGPoint(x: c.x - s*0.28, y: c.y - s*0.28),
        ]
        return pts
    }
}

/// Tiny deterministic RNG so doodle jitter is stable across redraws (no flicker)
/// but varies per shape/pass.
private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func nextUnit() -> CGFloat {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        let v = (state &* 0x2545F4914F6CDD1D) >> 33
        return CGFloat(Double(v) / Double(UInt32.max)) // 0...1
    }
    /// Symmetric jitter in [-amp, amp].
    mutating func next(_ amp: CGFloat) -> CGFloat { (nextUnit()*2 - 1) * amp }
}
