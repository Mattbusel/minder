import SwiftUI

struct IrisStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let light: Color
    let dark: Color
    /// Colour of the ring around the pupil. Hazel eyes are the reason this exists.
    let inner: Color

    init(_ id: String, _ name: String, light: Color, dark: Color, inner: Color? = nil) {
        self.id = id; self.name = name; self.light = light; self.dark = dark; self.inner = inner ?? light
    }

    static let all: [IrisStyle] = [
        IrisStyle("amber", "Amber", light: Color(red: 1.0, green: 0.72, blue: 0.28), dark: Color(red: 0.55, green: 0.24, blue: 0.03), inner: Color(red: 1.0, green: 0.86, blue: 0.5)),
        IrisStyle("hazel", "Hazel", light: Color(red: 0.55, green: 0.66, blue: 0.32), dark: Color(red: 0.24, green: 0.2, blue: 0.08), inner: Color(red: 0.86, green: 0.58, blue: 0.22)),
        IrisStyle("ice", "Ice", light: Color(red: 0.56, green: 0.86, blue: 1.0), dark: Color(red: 0.06, green: 0.3, blue: 0.58), inner: Color(red: 0.82, green: 0.95, blue: 1.0)),
        IrisStyle("moss", "Moss", light: Color(red: 0.55, green: 0.92, blue: 0.6), dark: Color(red: 0.05, green: 0.36, blue: 0.2), inner: Color(red: 0.86, green: 0.94, blue: 0.5)),
        IrisStyle("rose", "Rose", light: Color(red: 1.0, green: 0.6, blue: 0.74), dark: Color(red: 0.55, green: 0.1, blue: 0.3)),
        IrisStyle("violet", "Violet", light: Color(red: 0.78, green: 0.64, blue: 1.0), dark: Color(red: 0.26, green: 0.12, blue: 0.58), inner: Color(red: 0.95, green: 0.8, blue: 1.0)),
        IrisStyle("ruby", "Ruby", light: Color(red: 1.0, green: 0.36, blue: 0.3), dark: Color(red: 0.42, green: 0.02, blue: 0.04), inner: Color(red: 1.0, green: 0.7, blue: 0.4)),
        IrisStyle("silver", "Silver", light: Color(red: 0.84, green: 0.88, blue: 0.93), dark: Color(red: 0.3, green: 0.34, blue: 0.4)),
        IrisStyle("ink", "Ink", light: Color(red: 0.36, green: 0.3, blue: 0.26), dark: Color(red: 0.06, green: 0.05, blue: 0.05), inner: Color(red: 0.5, green: 0.36, blue: 0.22)),
    ]
    static func named(_ id: String) -> IrisStyle { all.first { $0.id == id } ?? all[0] }
}

/// Draws the whole face from one Brain frame.
struct EyesCanvas: View {
    let brain: Brain
    var look: Look = .shared
    var dimmed: Bool = false
    var zoom: CGFloat = 1

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let f = brain.step(at: tl.date.timeIntervalSinceReferenceDate)
                EyesCanvas.draw(f, look: look, zoom: zoom, in: &ctx, size: size)
            }
        }
        .opacity(dimmed ? 0.82 : 1)
        .animation(.easeInOut(duration: 1.2), value: dimmed)
    }

    static func draw(_ f: Brain.Frame, look: Look, zoom: CGFloat = 1, in ctx: inout GraphicsContext, size: CGSize) {
        let s: CGFloat = min(size.width, size.height * 0.75) / 440 * CGFloat(look.size) * zoom
        var w: CGFloat = 136 * s, h: CGFloat = 160 * s
        switch look.outline {
        case .round: break
        case .almond: w *= 1.16; h *= 0.8
        case .tall: w *= 0.88; h *= 1.14
        }
        let gap: CGFloat = (w * 0.5 + 20 * s) * CGFloat(look.spacing)
        let cx: CGFloat = size.width / 2 + f.gaze.x * 10 * s
        let cy: CGFloat = size.height * (zoom > 1 ? 0.56 : 0.44) + f.gaze.y * 8 * s + f.bob * s
        let eye = EyeRenderer(look: look, s: s, f: f)
        eye.draw(f.face.left, isLeft: true, at: CGPoint(x: cx - gap, y: cy), w: w, h: h, iris: look.iris, ctx: &ctx)
        eye.draw(f.face.right, isLeft: false, at: CGPoint(x: cx + gap, y: cy), w: w, h: h, iris: look.rightIris, ctx: &ctx)
    }
}

/// One eye, layer by layer: glow, sclera, veins, iris, fibres, pupil, catchlights, lids, lashes, brow.
struct EyeRenderer {
    let look: Look
    let s: CGFloat
    let f: Brain.Frame

    func draw(_ e: EyeShape, isLeft: Bool, at c: CGPoint, w: CGFloat, h: CGFloat, iris: IrisStyle, ctx: inout GraphicsContext) {
        let ew: CGFloat = w * e.scale, eh: CGFloat = h * e.scale
        let rect = CGRect(x: c.x - ew / 2, y: c.y - eh / 2, width: ew, height: eh)
        let shape = outlinePath(rect)
        let open: CGFloat = max(0, min(1, e.open * (1 - f.blink)))
        let inner: CGFloat = isLeft ? 1 : -1
        let lid = LidGeometry(center: c, rect: rect, open: open, tilt: e.lidTilt, inner: inner, s: s)

        drawGlow(rect: rect, open: open, iris: iris, ctx: &ctx)

        ctx.drawLayer { g in
            g.clip(to: shape)
            drawSclera(shape: shape, rect: rect, isLeft: isLeft, g: &g)
            drawIris(c: c, ew: ew, eh: eh, inner: inner, iris: iris, g: &g)
            drawShading(shape: shape, rect: rect, g: &g)
            drawLids(e, lid: lid, rect: rect, ew: ew, eh: eh, g: &g)
        }

        drawRim(shape: shape, lid: lid, rect: rect, open: open, ctx: &ctx)
        if look.lashes && open > 0.04 { drawLashes(lid: lid, shape: shape, rect: rect, ctx: &ctx) }
        if open < 0.08 { drawClosedLine(c: c, rect: rect, ew: ew, eh: eh, ctx: &ctx) }
        if look.brow != .none { drawBrow(e, c: c, rect: rect, ew: ew, eh: eh, inner: inner, iris: iris, ctx: &ctx) }
    }

    // MARK: shape

    private func outlinePath(_ r: CGRect) -> Path {
        switch look.outline {
        case .round, .tall:
            return Path(ellipseIn: r)
        case .almond:
            var p = Path()
            let w: CGFloat = r.width, h: CGFloat = r.height
            p.move(to: CGPoint(x: r.minX, y: r.midY + h * 0.04))
            p.addCurve(to: CGPoint(x: r.maxX, y: r.midY - h * 0.04),
                       control1: CGPoint(x: r.minX + w * 0.12, y: r.minY - h * 0.2),
                       control2: CGPoint(x: r.maxX - w * 0.2, y: r.minY - h * 0.22))
            p.addCurve(to: CGPoint(x: r.minX, y: r.midY + h * 0.04),
                       control1: CGPoint(x: r.maxX - w * 0.12, y: r.maxY + h * 0.2),
                       control2: CGPoint(x: r.minX + w * 0.2, y: r.maxY + h * 0.22))
            p.closeSubpath()
            return p
        }
    }

    // MARK: layers

    private func drawGlow(rect: CGRect, open: CGFloat, iris: IrisStyle, ctx: inout GraphicsContext) {
        let strength: Double = look.glow * (look.sclera == .void ? 0.5 : 0.3)
        guard strength > 0.01 else { return }
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: 30 * s))
            g.opacity = strength * Double(0.35 + open * 0.65)
            g.fill(Path(ellipseIn: rect.insetBy(dx: -6 * s, dy: -6 * s)), with: .color(iris.light))
        }
    }

    private func drawSclera(shape: Path, rect: CGRect, isLeft: Bool, g: inout GraphicsContext) {
        let hi = CGPoint(x: rect.midX - rect.width * 0.14, y: rect.midY - rect.height * 0.18)
        let colors: [Color]
        switch look.sclera {
        case .classic: colors = [Color(white: 1), Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.76, green: 0.78, blue: 0.85)]
        case .tired: colors = [Color(red: 1, green: 0.97, blue: 0.95), Color(red: 0.97, green: 0.88, blue: 0.87), Color(red: 0.84, green: 0.66, blue: 0.68)]
        case .void: colors = [Color(white: 0.13), Color(white: 0.07), Color(white: 0.02)]
        }
        g.fill(shape, with: .radialGradient(Gradient(colors: colors), center: hi, startRadius: 0, endRadius: rect.height * 0.75))
        if look.sclera == .tired { drawVeins(rect: rect, isLeft: isLeft, g: &g) }
    }

    private func drawVeins(rect: CGRect, isLeft: Bool, g: inout GraphicsContext) {
        var veins = Path()
        let seeds: [CGFloat] = [0.1, 0.9, 1.7, 2.6, 3.3, 4.2, 5.0, 5.7]
        let rx: CGFloat = rect.width / 2, ry: CGFloat = rect.height / 2
        for (k, a0) in seeds.enumerated() {
            let a: CGFloat = a0 + (isLeft ? 0 : 0.4)
            let start = CGPoint(x: rect.midX + cos(a) * rx, y: rect.midY + sin(a) * ry)
            let reach: CGFloat = 0.52 + CGFloat(k % 3) * 0.06
            let end = CGPoint(x: rect.midX + cos(a) * rx * reach, y: rect.midY + sin(a) * ry * reach)
            let bend: CGFloat = (k % 2 == 0 ? 1 : -1) * rx * 0.12
            let ctrl = CGPoint(x: (start.x + end.x) / 2 - sin(a) * bend, y: (start.y + end.y) / 2 + cos(a) * bend)
            veins.move(to: start)
            veins.addQuadCurve(to: end, control: ctrl)
            let mid = CGPoint(x: start.x * 0.4 + end.x * 0.6, y: start.y * 0.4 + end.y * 0.6)
            veins.move(to: mid)
            veins.addLine(to: CGPoint(x: mid.x - cos(a + 0.9) * rx * 0.1, y: mid.y - sin(a + 0.9) * ry * 0.1))
        }
        g.stroke(veins, with: .color(Color(red: 0.82, green: 0.14, blue: 0.16).opacity(0.45)), lineWidth: 1.1 * s)
    }

    private func drawIris(c: CGPoint, ew: CGFloat, eh: CGFloat, inner: CGFloat, iris: IrisStyle, g: inout GraphicsContext) {
        let base: CGFloat = min(ew, eh * 0.95)
        let ir: CGFloat = base * 0.31
        let ix: CGFloat = c.x + f.gaze.x * ew * 0.22 + inner * ew * 0.015
        let iy: CGFloat = c.y + f.gaze.y * eh * 0.2 + eh * 0.04
        let ic = CGPoint(x: ix, y: iy)
        let irisRect = CGRect(x: ix - ir, y: iy - ir, width: ir * 2, height: ir * 2)
        let irisPath = Path(ellipseIn: irisRect)

        if look.sclera == .void {
            g.drawLayer { gl in
                gl.addFilter(.blur(radius: 10 * s))
                gl.fill(Path(ellipseIn: irisRect.insetBy(dx: -8 * s, dy: -8 * s)), with: .color(iris.light.opacity(0.7)))
            }
        }

        let grad = Gradient(stops: [
            .init(color: iris.inner, location: 0),
            .init(color: iris.inner, location: 0.3),
            .init(color: iris.light, location: 0.55),
            .init(color: iris.dark, location: 1),
        ])
        g.fill(irisPath, with: .radialGradient(grad, center: ic, startRadius: 0, endRadius: ir))

        // Fibres: light and dark strands of uneven length, seeded so they never shimmer.
        var lightFibres = Path(), darkFibres = Path()
        for k in 0..<72 {
            let kf = CGFloat(k)
            let a: CGFloat = kf / 72 * .pi * 2 + sin(kf * 12.9898) * 0.03
            let noise: CGFloat = abs(sin(kf * 78.233))
            let r0: CGFloat = ir * (0.42 + noise * 0.08)
            let r1: CGFloat = ir * (0.7 + noise * 0.26)
            let wob: CGFloat = sin(kf * 3.7) * 0.06
            let p0 = CGPoint(x: ix + cos(a) * r0, y: iy + sin(a) * r0)
            let p1 = CGPoint(x: ix + cos(a + wob) * r1, y: iy + sin(a + wob) * r1)
            if k % 2 == 0 { lightFibres.move(to: p0); lightFibres.addLine(to: p1) } else { darkFibres.move(to: p0); darkFibres.addLine(to: p1) }
        }
        g.stroke(lightFibres, with: .color(iris.inner.opacity(0.45)), lineWidth: 1.1 * s)
        g.stroke(darkFibres, with: .color(iris.dark.opacity(0.4)), lineWidth: 0.9 * s)

        // Crypts: darker flecks in the outer iris.
        var crypts = Path()
        for k in 0..<9 {
            let a: CGFloat = CGFloat(k) * 0.71 + 0.3
            let r: CGFloat = ir * (0.62 + CGFloat(k % 3) * 0.1)
            let sz: CGFloat = ir * (0.05 + CGFloat(k % 2) * 0.03)
            crypts.addEllipse(in: CGRect(x: ix + cos(a) * r - sz, y: iy + sin(a) * r - sz * 0.6, width: sz * 2, height: sz * 1.2))
        }
        g.fill(crypts, with: .color(iris.dark.opacity(0.35)))

        // Collarette: the jagged ring around the pupil.
        let cr: CGFloat = ir * 0.56
        g.stroke(Path(ellipseIn: CGRect(x: ix - cr, y: iy - cr, width: cr * 2, height: cr * 2)),
                 with: .color(iris.inner.opacity(0.55)), style: StrokeStyle(lineWidth: 2.2 * s, dash: [2.5 * s, 1.6 * s]))

        // Limbal ring: dark band where iris meets white.
        g.stroke(Path(ellipseIn: irisRect.insetBy(dx: ir * 0.05, dy: ir * 0.05)), with: .color(iris.dark.opacity(0.9)), lineWidth: ir * 0.1)

        drawPupil(ix: ix, iy: iy, ir: ir, g: &g)
        drawCatchlights(ix: ix, iy: iy, ir: ir, g: &g)
    }

    private func drawPupil(ix: CGFloat, iy: CGFloat, ir: CGFloat, g: inout GraphicsContext) {
        let pr: CGFloat = ir * 0.44 * f.face.pupil
        let dark = Color(white: 0.02)
        var p = Path()
        switch look.pupil {
        case .round:
            p.addEllipse(in: CGRect(x: ix - pr, y: iy - pr, width: pr * 2, height: pr * 2))
        case .cat:
            let pw: CGFloat = pr * 0.42 * f.face.pupil
            p.addEllipse(in: CGRect(x: ix - pw, y: iy - pr * 1.9, width: pw * 2, height: pr * 3.8))
        case .heart:
            let k: CGFloat = pr * 2.3
            p.move(to: CGPoint(x: ix, y: iy + 0.32 * k))
            p.addCurve(to: CGPoint(x: ix - 0.5 * k, y: iy - 0.12 * k), control1: CGPoint(x: ix - 0.3 * k, y: iy + 0.16 * k), control2: CGPoint(x: ix - 0.5 * k, y: iy + 0.06 * k))
            p.addCurve(to: CGPoint(x: ix, y: iy - 0.22 * k), control1: CGPoint(x: ix - 0.5 * k, y: iy - 0.42 * k), control2: CGPoint(x: ix - 0.06 * k, y: iy - 0.42 * k))
            p.addCurve(to: CGPoint(x: ix + 0.5 * k, y: iy - 0.12 * k), control1: CGPoint(x: ix + 0.06 * k, y: iy - 0.42 * k), control2: CGPoint(x: ix + 0.5 * k, y: iy - 0.42 * k))
            p.addCurve(to: CGPoint(x: ix, y: iy + 0.32 * k), control1: CGPoint(x: ix + 0.5 * k, y: iy + 0.06 * k), control2: CGPoint(x: ix + 0.3 * k, y: iy + 0.16 * k))
            p.closeSubpath()
        case .star:
            let outer: CGFloat = pr * 1.35, innerR: CGFloat = pr * 0.58
            for i in 0..<10 {
                let a: CGFloat = CGFloat(i) / 10 * .pi * 2 - .pi / 2
                let r: CGFloat = i % 2 == 0 ? outer : innerR
                let pt = CGPoint(x: ix + cos(a) * r, y: iy + sin(a) * r)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
        g.drawLayer { gl in
            gl.addFilter(.blur(radius: 2.5 * s))
            gl.fill(p, with: .color(dark.opacity(0.7)))
        }
        g.fill(p, with: .color(dark))
    }

    private func drawCatchlights(ix: CGFloat, iy: CGFloat, ir: CGFloat, g: inout GraphicsContext) {
        // A rounded window, like a lit room reflected in the eye.
        let mw: CGFloat = ir * 0.46, mh: CGFloat = ir * 0.38
        let main = CGRect(x: ix - ir * 0.62, y: iy - ir * 0.68, width: mw, height: mh)
        g.fill(Path(roundedRect: main, cornerRadius: mh * 0.4), with: .color(.white.opacity(0.94)))
        let r2: CGFloat = ir * 0.1
        g.fill(Path(ellipseIn: CGRect(x: ix + ir * 0.34, y: iy + ir * 0.3, width: r2 * 2, height: r2 * 2)), with: .color(.white.opacity(0.75)))
        // Wet sheen along the lower edge of the iris.
        var sheen = Path()
        sheen.addArc(center: CGPoint(x: ix, y: iy), radius: ir * 0.8, startAngle: .degrees(35), endAngle: .degrees(105), clockwise: false)
        g.stroke(sheen, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
    }

    private func drawShading(shape: Path, rect: CGRect, g: inout GraphicsContext) {
        let edge: Double = look.sclera == .void ? 0.1 : 0.28
        let ao = Gradient(stops: [.init(color: .clear, location: 0.62), .init(color: .black.opacity(edge), location: 1)])
        let aoCenter = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.05)
        g.fill(shape, with: .radialGradient(ao, center: aoCenter, startRadius: 0, endRadius: max(rect.width, rect.height) * 0.56))
        let top = Gradient(colors: [.black.opacity(0.34), .clear])
        g.fill(shape, with: .linearGradient(top, startPoint: CGPoint(x: rect.midX, y: rect.minY),
                                            endPoint: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.34)))
    }

    private func drawLids(_ e: EyeShape, lid: LidGeometry, rect: CGRect, ew: CGFloat, eh: CGFloat, g: inout GraphicsContext) {
        var p = Path()
        let x0: CGFloat = rect.minX - 12 * s, x1: CGFloat = rect.maxX + 12 * s
        p.move(to: CGPoint(x: x0, y: rect.minY - 300))
        p.addLine(to: CGPoint(x: x1, y: rect.minY - 300))
        p.addLine(to: CGPoint(x: x1, y: lid.lineY(x1)))
        p.addQuadCurve(to: CGPoint(x: x0, y: lid.lineY(x0)), control: CGPoint(x: lid.center.x, y: lid.lineY(lid.center.x) + lid.sag * 2))
        p.closeSubpath()
        g.drawLayer { gl in
            gl.addFilter(.blur(radius: 5 * s))
            gl.fill(p.offsetBy(dx: 0, dy: 5 * s), with: .color(.black.opacity(0.5)))
        }
        g.fill(p, with: .color(.black))

        if e.lower > 0.01 {
            let top: CGFloat = rect.maxY - e.lower * eh * 1.05
            g.fill(Path(ellipseIn: CGRect(x: rect.minX - ew * 0.7, y: top, width: ew * 2.4, height: eh * 1.2)), with: .color(.black))
        }
    }

    /// A bright line along the lid edge, so the lid reads as a lid and not a hole.
    private func drawRim(shape: Path, lid: LidGeometry, rect: CGRect, open: CGFloat, ctx: inout GraphicsContext) {
        if look.sclera == .void { ctx.stroke(shape, with: .color(.white.opacity(0.08)), lineWidth: 1.2 * s) }
        guard open > 0.04 else { return }
        var edge = Path()
        var started = false
        let steps = 28
        for i in 0...steps {
            let x: CGFloat = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let pt = CGPoint(x: x, y: lid.curveY(x))
            if shape.contains(pt) {
                if started { edge.addLine(to: pt) } else { edge.move(to: pt); started = true }
            }
        }
        ctx.stroke(edge, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3.2 * s, lineCap: .round, lineJoin: .round))
    }

    private func drawLashes(lid: LidGeometry, shape: Path, rect: CGRect, ctx: inout GraphicsContext) {
        var lashes = Path()
        let n = 9
        for i in 0..<n {
            let t: CGFloat = 0.14 + 0.72 * CGFloat(i) / CGFloat(n - 1)
            let x: CGFloat = rect.minX + rect.width * t
            let y: CGFloat = lid.curveY(x)
            guard shape.contains(CGPoint(x: x, y: y + 1)) else { continue }
            let side: CGFloat = (t - 0.5) * 2
            let len: CGFloat = rect.width * (0.11 + 0.05 * (1 - abs(side)))
            let a: CGFloat = -.pi / 2 + side * 0.9
            let tip = CGPoint(x: x + cos(a) * len, y: y + sin(a) * len)
            let ctrl = CGPoint(x: x + cos(a) * len * 0.5 + side * len * 0.35, y: y + sin(a) * len * 0.5)
            lashes.move(to: CGPoint(x: x, y: y))
            lashes.addQuadCurve(to: tip, control: ctrl)
        }
        ctx.stroke(lashes, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round))
    }

    private func drawClosedLine(c: CGPoint, rect: CGRect, ew: CGFloat, eh: CGFloat, ctx: inout GraphicsContext) {
        var line = Path()
        let y: CGFloat = c.y + eh * 0.08
        line.move(to: CGPoint(x: rect.minX + ew * 0.1, y: y))
        line.addQuadCurve(to: CGPoint(x: rect.maxX - ew * 0.1, y: y), control: CGPoint(x: c.x, y: y + eh * 0.16))
        ctx.stroke(line, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
        guard look.lashes else { return }
        var lashes = Path()
        for i in 0..<5 {
            let t: CGFloat = 0.2 + 0.15 * CGFloat(i)
            let x: CGFloat = rect.minX + ew * 0.1 + ew * 0.8 * t
            let yy: CGFloat = y + eh * 0.16 * t * (1 - t) * 2
            lashes.move(to: CGPoint(x: x, y: yy))
            lashes.addLine(to: CGPoint(x: x + (t - 0.5) * ew * 0.12, y: yy + eh * 0.1))
        }
        ctx.stroke(lashes, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
    }

    private func drawBrow(_ e: EyeShape, c: CGPoint, rect: CGRect, ew: CGFloat, eh: CGFloat, inner: CGFloat, iris: IrisStyle, ctx: inout GraphicsContext) {
        let bw: CGFloat = ew * 0.98
        let by: CGFloat = rect.minY - 30 * s - e.browY * s + (1 - e.scale) * 20 * s
        let tiltY: CGFloat = e.browTilt * bw * 0.5
        let innerPt = CGPoint(x: c.x + inner * bw / 2, y: by + tiltY)
        let outerPt = CGPoint(x: c.x - inner * bw / 2, y: by - tiltY * 0.6)
        let ctrl = CGPoint(x: c.x - inner * bw * 0.08, y: by - e.browCurve * eh * 0.55)
        var brow = Path()
        brow.move(to: outerPt)
        brow.addQuadCurve(to: innerPt, control: ctrl)
        let color = Color(white: 0.95)

        switch look.brow {
        case .none:
            return
        case .bold:
            let glowAmt: Double = 0.3 * look.glow + 0.1
            ctx.drawLayer { g in
                g.addFilter(.shadow(color: iris.light.opacity(glowAmt), radius: 10 * s))
                g.stroke(brow, with: .linearGradient(Gradient(colors: [color.opacity(0.8), color]), startPoint: outerPt, endPoint: innerPt),
                         style: StrokeStyle(lineWidth: 16 * s, lineCap: .round))
            }
        case .thin:
            ctx.stroke(brow, with: .color(color), style: StrokeStyle(lineWidth: 6.5 * s, lineCap: .round))
        case .bushy:
            ctx.stroke(brow, with: .color(color.opacity(0.5)), style: StrokeStyle(lineWidth: 9 * s, lineCap: .round))
            ctx.stroke(hairs(outerPt, ctrl, innerPt), with: .color(color), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
        }
    }

    /// Individual brow hairs laid along the curve, fuller toward the inner end.
    private func hairs(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        var hairs = Path()
        for i in 0..<34 {
            let t: CGFloat = CGFloat(i) / 33
            let p = quad(a, b, c, t)
            let d = quadTangent(a, b, c, t)
            let len: CGFloat = max(0.001, sqrt(d.x * d.x + d.y * d.y))
            let tx: CGFloat = d.x / len, ty: CGFloat = d.y / len
            let jitter: CGFloat = sin(CGFloat(i) * 9.17) * 5 * s
            let thick: CGFloat = (6 + 10 * t) * s
            let hairLen: CGFloat = 12 * s + t * 6 * s
            let start = CGPoint(x: p.x - ty * thick * 0.5 + tx * jitter * 0.3, y: p.y + tx * thick * 0.5 + jitter * 0.2)
            let dx: CGFloat = tx * -0.55 - ty, dy: CGFloat = ty * -0.55 + tx
            let norm: CGFloat = max(0.001, sqrt(dx * dx + dy * dy))
            hairs.move(to: start)
            hairs.addLine(to: CGPoint(x: start.x - dx / norm * hairLen, y: start.y - dy / norm * hairLen))
        }
        return hairs
    }

    private func quad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ t: CGFloat) -> CGPoint {
        let u: CGFloat = 1 - t
        let x: CGFloat = u * u * a.x + 2 * u * t * b.x + t * t * c.x
        let y: CGFloat = u * u * a.y + 2 * u * t * b.y + t * t * c.y
        return CGPoint(x: x, y: y)
    }
    private func quadTangent(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ t: CGFloat) -> CGPoint {
        let u: CGFloat = 1 - t
        let x: CGFloat = 2 * u * (b.x - a.x) + 2 * t * (c.x - b.x)
        let y: CGFloat = 2 * u * (b.y - a.y) + 2 * t * (c.y - b.y)
        return CGPoint(x: x, y: y)
    }
}

/// Where the upper lid's edge sits, shared by the lid, the rim and the lashes.
struct LidGeometry {
    let center: CGPoint
    let rect: CGRect
    let open: CGFloat
    let tilt: CGFloat
    let inner: CGFloat
    let s: CGFloat

    var centerY: CGFloat { rect.minY - 3 * s + (1 - open) * (rect.height + 6 * s) + abs(tilt) * rect.width * 0.22 }
    var sag: CGFloat { rect.height * 0.05 * open }
    func lineY(_ x: CGFloat) -> CGFloat { centerY + tilt * inner * (x - center.x) }
    /// The curved edge: the lid line plus the quad curve's sag, which peaks mid-eye.
    func curveY(_ x: CGFloat) -> CGFloat {
        let half: CGFloat = rect.width / 2 + 12 * s
        let u: CGFloat = (x - center.x) / half
        return lineY(x) + sag * (1 - u * u)
    }
}
