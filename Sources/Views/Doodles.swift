import SwiftUI

/// Hand-drawn-style line-art doodles for onboarding. Vector (Canvas), so they
/// scale crisply and tint with the accent. Slightly wobbly strokes give the
/// "doodle" feel without raster assets.
struct Doodle: View {
    enum Kind { case heartToDoc, privacy, askAI }
    let kind: Kind
    var color: Color = Theme.accent

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let lw: CGFloat = max(3, w * 0.018)
            let stroke = GraphicsContext.Shading.color(color)
            func draw(_ p: Path, _ width: CGFloat = lw) {
                ctx.stroke(p, with: stroke, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }

            switch kind {
            case .heartToDoc:
                // Heart on the left
                let hc = CGPoint(x: w * 0.27, y: h * 0.42)
                draw(heartPath(center: hc, s: w * 0.16))
                // Arrow to the right
                let ay = h * 0.42
                draw(wobblyLine(from: CGPoint(x: w * 0.44, y: ay), to: CGPoint(x: w * 0.58, y: ay)))
                draw(Path { p in
                    p.move(to: CGPoint(x: w * 0.54, y: ay - h * 0.04))
                    p.addLine(to: CGPoint(x: w * 0.585, y: ay))
                    p.addLine(to: CGPoint(x: w * 0.54, y: ay + h * 0.04))
                })
                // Document on the right with text lines
                let dx = w * 0.62, dy = h * 0.22, dw = w * 0.26, dh = h * 0.42
                draw(roundedRectPath(x: dx, y: dy, w: dw, h: dh, r: w * 0.03))
                for i in 0..<3 {
                    let ly = dy + dh * (0.3 + Double(i) * 0.22)
                    draw(wobblyLine(from: CGPoint(x: dx + dw * 0.18, y: ly),
                                    to: CGPoint(x: dx + dw * 0.82, y: ly), amp: 1.5), lw * 0.7)
                }

            case .privacy:
                // Phone outline
                let px = w * 0.34, py = h * 0.16, pw = w * 0.32, ph = h * 0.6
                draw(roundedRectPath(x: px, y: py, w: pw, h: ph, r: w * 0.04))
                // Lock inside
                let lcx = w * 0.5, lcy = h * 0.46
                draw(roundedRectPath(x: lcx - w * 0.07, y: lcy, w: w * 0.14, h: h * 0.15, r: w * 0.02))
                draw(Path { p in // shackle
                    p.addArc(center: CGPoint(x: lcx, y: lcy), radius: w * 0.045,
                             startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                })
                // little "no upload" arc with slash above
                let cy = h * 0.16
                draw(Path { p in
                    p.addArc(center: CGPoint(x: w * 0.5, y: cy), radius: w * 0.05,
                             startAngle: .degrees(20), endAngle: .degrees(160), clockwise: true)
                }, lw * 0.8)

            case .askAI:
                // Speech bubble
                let bx = w * 0.18, by = h * 0.22, bw = w * 0.5, bh = h * 0.34
                draw(roundedRectPath(x: bx, y: by, w: bw, h: bh, r: w * 0.05))
                draw(Path { p in // tail
                    p.move(to: CGPoint(x: bx + bw * 0.25, y: by + bh))
                    p.addLine(to: CGPoint(x: bx + bw * 0.18, y: by + bh + h * 0.08))
                    p.addLine(to: CGPoint(x: bx + bw * 0.42, y: by + bh))
                })
                // sparkle (AI)
                let sx = w * 0.74, sy = h * 0.6
                draw(sparklePath(center: CGPoint(x: sx, y: sy), s: w * 0.09))
                let sx2 = w * 0.84, sy2 = h * 0.42
                draw(sparklePath(center: CGPoint(x: sx2, y: sy2), s: w * 0.05))
                // question dots in bubble
                for i in 0..<3 {
                    let dx = bx + bw * (0.3 + Double(i) * 0.2)
                    draw(Path { p in p.addEllipse(in: CGRect(x: dx, y: by + bh * 0.45, width: lw, height: lw)) }, lw)
                }
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
    }

    // MARK: - Path helpers

    private func heartPath(center c: CGPoint, s: CGFloat) -> Path {
        Path { p in
            var pts: [CGPoint] = []
            var t = 0.0
            while t <= 2 * Double.pi + 0.1 {
                let x = 16 * pow(sin(t), 3)
                let y = -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))
                pts.append(CGPoint(x: c.x + CGFloat(x) * s / 16, y: c.y + CGFloat(y) * s / 16))
                t += 0.15
            }
            if let f = pts.first { p.move(to: f); for q in pts.dropFirst() { p.addLine(to: q) }; p.closeSubpath() }
        }
    }

    private func roundedRectPath(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private func wobblyLine(from a: CGPoint, to b: CGPoint, amp: CGFloat = 2.5) -> Path {
        Path { p in
            p.move(to: a)
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - amp)
            p.addQuadCurve(to: b, control: mid)
        }
    }

    private func sparklePath(center c: CGPoint, s: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: c.x, y: c.y - s))
            p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: CGPoint(x: c.x + s * 0.25, y: c.y - s * 0.25))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: CGPoint(x: c.x + s * 0.25, y: c.y + s * 0.25))
            p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: CGPoint(x: c.x - s * 0.25, y: c.y + s * 0.25))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x - s * 0.25, y: c.y - s * 0.25))
        }
    }
}
