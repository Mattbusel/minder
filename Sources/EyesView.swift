import SwiftUI

struct IrisStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let light: Color
    let dark: Color

    static let all: [IrisStyle] = [
        IrisStyle(id: "ink", name: "Ink", light: Color(red: 0.30, green: 0.32, blue: 0.38), dark: Color(red: 0.07, green: 0.08, blue: 0.10)),
        IrisStyle(id: "amber", name: "Amber", light: Color(red: 1.0, green: 0.72, blue: 0.28), dark: Color(red: 0.62, green: 0.30, blue: 0.04)),
        IrisStyle(id: "ice", name: "Ice", light: Color(red: 0.52, green: 0.84, blue: 1.0), dark: Color(red: 0.08, green: 0.34, blue: 0.62)),
        IrisStyle(id: "moss", name: "Moss", light: Color(red: 0.55, green: 0.92, blue: 0.62), dark: Color(red: 0.07, green: 0.42, blue: 0.24)),
        IrisStyle(id: "rose", name: "Rose", light: Color(red: 1.0, green: 0.58, blue: 0.72), dark: Color(red: 0.62, green: 0.12, blue: 0.32)),
        IrisStyle(id: "violet", name: "Violet", light: Color(red: 0.76, green: 0.62, blue: 1.0), dark: Color(red: 0.30, green: 0.14, blue: 0.62)),
    ]
    static func named(_ id: String) -> IrisStyle { all.first { $0.id == id } ?? all[1] }
}

/// Draws the whole face from one Brain frame.
struct EyesCanvas: View {
    let brain: Brain
    let iris: IrisStyle
    var dimmed: Bool = false

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let f = brain.step(at: tl.date.timeIntervalSinceReferenceDate)
                EyesCanvas.draw(f, iris: iris, in: &ctx, size: size)
            }
        }
        .opacity(dimmed ? 0.55 : 1)
        .animation(.easeInOut(duration: 1.2), value: dimmed)
    }

    static func draw(_ f: Brain.Frame, iris: IrisStyle, in ctx: inout GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height * 0.62) / 390
        let w = 104 * s, h = 124 * s
        let gap = 70 * s
        let center = CGPoint(x: size.width / 2 + f.gaze.x * 10 * s,
                             y: size.height * 0.44 + f.gaze.y * 8 * s + f.bob * s)
        let lc = CGPoint(x: center.x - gap, y: center.y)
        let rc = CGPoint(x: center.x + gap, y: center.y)
        drawEye(f.face.left, isLeft: true, at: lc, w: w, h: h, s: s, f: f, iris: iris, ctx: &ctx)
        drawEye(f.face.right, isLeft: false, at: rc, w: w, h: h, s: s, f: f, iris: iris, ctx: &ctx)
    }

    private static func drawEye(_ e: EyeShape, isLeft: Bool, at c: CGPoint, w: CGFloat, h: CGFloat, s: CGFloat,
                                f: Brain.Frame, iris: IrisStyle, ctx: inout GraphicsContext) {
        let ew = w * e.scale, eh = h * e.scale
        let rect = CGRect(x: c.x - ew / 2, y: c.y - eh / 2, width: ew, height: eh)
        let eyeShape = Path(ellipseIn: rect)
        let open = max(0, min(1, e.open * (1 - f.blink)))
        let inner: CGFloat = isLeft ? 1 : -1  // direction toward the nose

        // Soft glow, so the eyes sit in the dark rather than on it.
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: 26 * s))
            g.opacity = 0.16 * Double(0.35 + open * 0.65)
            g.fill(Path(ellipseIn: rect.insetBy(dx: -4 * s, dy: -4 * s)), with: .color(iris.light))
        }

        ctx.drawLayer { g in
            g.clip(to: eyeShape)
            drawBall(rect: rect, c: c, ew: ew, eh: eh, inner: inner, s: s, f: f, iris: iris, g: &g)
            drawLids(e, rect: rect, c: c, ew: ew, eh: eh, open: open, inner: inner, s: s, g: &g)
        }

        // A thin rim where the lid meets the eye, reads as an eyelash line when nearly closed.
        if open < 0.08 {
            var line = Path()
            let y = c.y + eh * 0.08
            line.move(to: CGPoint(x: rect.minX + ew * 0.12, y: y))
            line.addQuadCurve(to: CGPoint(x: rect.maxX - ew * 0.12, y: y), control: CGPoint(x: c.x, y: y + eh * 0.16))
            ctx.stroke(line, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
        }

        // Brow
        let bw = ew * 0.95
        let by = rect.minY - 30 * s - e.browY * s + (1 - e.scale) * 20 * s
        let tiltY = e.browTilt * bw * 0.5
        let innerX = c.x + inner * bw / 2, outerX = c.x - inner * bw / 2
        let innerPt = CGPoint(x: innerX, y: by + tiltY)
        let outerPt = CGPoint(x: outerX, y: by - tiltY * 0.6)
        var brow = Path()
        brow.move(to: outerPt)
        brow.addQuadCurve(to: innerPt, control: CGPoint(x: c.x - inner * bw * 0.08, y: by - e.browCurve * eh * 0.55))
        ctx.drawLayer { g in
            g.addFilter(.shadow(color: iris.light.opacity(0.35), radius: 10 * s))
            g.stroke(brow, with: .color(Color(white: 0.94)), style: StrokeStyle(lineWidth: 15 * s, lineCap: .round))
        }
    }

    private static func drawBall(rect: CGRect, c: CGPoint, ew: CGFloat, eh: CGFloat, inner: CGFloat, s: CGFloat,
                                 f: Brain.Frame, iris: IrisStyle, g: inout GraphicsContext) {
        let eyeShape = Path(ellipseIn: rect)
        let scleraCenter = CGPoint(x: rect.midX - ew * 0.12, y: rect.midY - eh * 0.16)
        let sclera = Gradient(colors: [Color(white: 1), Color(white: 0.93), Color(red: 0.78, green: 0.80, blue: 0.86)])
        g.fill(eyeShape, with: .radialGradient(sclera, center: scleraCenter, startRadius: 0, endRadius: eh * 0.72))

        let ir: CGFloat = ew * 0.30
        let ix: CGFloat = c.x + f.gaze.x * ew * 0.22 + inner * ew * 0.015
        let iy: CGFloat = c.y + f.gaze.y * eh * 0.2 + eh * 0.04
        let ic = CGPoint(x: ix, y: iy)
        let irisRect = CGRect(x: ix - ir, y: iy - ir, width: ir * 2, height: ir * 2)
        let irisGrad = Gradient(colors: [iris.light, iris.light.opacity(0.95), iris.dark])
        g.fill(Path(ellipseIn: irisRect), with: .radialGradient(irisGrad, center: ic, startRadius: ir * 0.2, endRadius: ir))

        var fibres = Path()
        for k in 0..<22 {
            let a = CGFloat(k) / 22 * .pi * 2
            let cx: CGFloat = cos(a), sy: CGFloat = sin(a)
            fibres.move(to: CGPoint(x: ix + cx * ir * 0.5, y: iy + sy * ir * 0.5))
            fibres.addLine(to: CGPoint(x: ix + cx * ir * 0.93, y: iy + sy * ir * 0.93))
        }
        g.stroke(fibres, with: .color(iris.dark.opacity(0.28)), lineWidth: 1.2 * s)
        g.stroke(Path(ellipseIn: irisRect.insetBy(dx: s, dy: s)), with: .color(iris.dark.opacity(0.9)), lineWidth: 3 * s)

        let pr: CGFloat = ir * 0.46 * f.face.pupil
        g.fill(Path(ellipseIn: CGRect(x: ix - pr, y: iy - pr, width: pr * 2, height: pr * 2)), with: .color(Color(white: 0.02)))

        let hl: CGFloat = ir * 0.26
        g.fill(Path(ellipseIn: CGRect(x: ix - ir * 0.52, y: iy - ir * 0.58, width: hl * 2, height: hl * 2)), with: .color(.white.opacity(0.95)))
        g.fill(Path(ellipseIn: CGRect(x: ix + ir * 0.28, y: iy + ir * 0.22, width: hl * 0.7, height: hl * 0.7)), with: .color(.white.opacity(0.7)))

        let shade = Gradient(colors: [.black.opacity(0.28), .clear])
        g.fill(eyeShape, with: .linearGradient(shade, startPoint: CGPoint(x: c.x, y: rect.minY),
                                               endPoint: CGPoint(x: c.x, y: rect.minY + eh * 0.32)))
    }

    private static func drawLids(_ e: EyeShape, rect: CGRect, c: CGPoint, ew: CGFloat, eh: CGFloat, open: CGFloat,
                                 inner: CGFloat, s: CGFloat, g: inout GraphicsContext) {
        let tilt: CGFloat = e.lidTilt
        let lidCenterY: CGFloat = rect.minY - 3 * s + (1 - open) * (eh + 6 * s) + abs(tilt) * ew * 0.22
        func lidY(_ x: CGFloat) -> CGFloat { lidCenterY + tilt * inner * (x - c.x) }
        let x0: CGFloat = rect.minX - 10 * s, x1: CGFloat = rect.maxX + 10 * s
        var lid = Path()
        lid.move(to: CGPoint(x: x0, y: rect.minY - 200))
        lid.addLine(to: CGPoint(x: x1, y: rect.minY - 200))
        lid.addLine(to: CGPoint(x: x1, y: lidY(x1)))
        lid.addQuadCurve(to: CGPoint(x: x0, y: lidY(x0)), control: CGPoint(x: c.x, y: lidY(c.x) + eh * 0.1 * open))
        lid.closeSubpath()
        g.fill(lid, with: .color(.black))

        if e.lower > 0.01 {
            let top: CGFloat = rect.maxY - e.lower * eh * 1.05
            g.fill(Path(ellipseIn: CGRect(x: rect.minX - ew * 0.3, y: top, width: ew * 1.6, height: eh * 1.4)), with: .color(.black))
        }
    }
}
