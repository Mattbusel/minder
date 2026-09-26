import SwiftUI

/// The "make them yours" panel: live preview, presets, and every knob.
struct EyeDesigner: View {
    @Environment(Pro.self) private var pro
    @Bindable var look: Look
    let brain: Brain

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                EyesCanvas(brain: brain, look: look, zoom: 1.75)
                    .frame(height: 250)
                    .allowsHitTesting(false)
                Button {
                    guard pro.unlocked else { pro.ask(.designer); return }
                    Haptics.tap(.medium)
                    withAnimation(.spring(duration: 0.4)) { look.randomize() }
                } label: {
                    Image(systemName: pro.unlocked ? "dice.fill" : "lock.fill").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(look.iris.light, in: Circle())
                }
                .padding(12)
                .accessibilityLabel("Surprise me")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Look.presets) { p in
                        let open = pro.unlocked || Pro.freePresets.contains(p.id)
                        Button {
                            guard open else { pro.ask(.designer); return }
                            Haptics.tap(); withAnimation(.spring(duration: 0.4)) { p.apply(look) }
                        } label: {
                            HStack(spacing: 5) {
                                if !open { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5)) }
                                Text(p.id).font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 14).frame(height: 34)
                                .background(.white.opacity(0.08), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)

            knobs
                .blur(radius: pro.unlocked ? 0 : 5)
                .allowsHitTesting(pro.unlocked)
                .overlay { if !pro.unlocked { lockedKnobs } }
        }
        .tint(look.iris.light)
    }

    /// For a free user: the real knobs, frosted, with a way in.
    private var lockedKnobs: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette.fill").font(.system(size: 20, weight: .medium)).foregroundStyle(look.iris.light)
                .frame(width: 48, height: 48).background(look.iris.light.opacity(0.14), in: Circle())
            Text("Design your own eyes").font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("Colours, odd eyes, shapes, pupils, brows, glow.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
            Button { pro.ask(.designer) } label: {
                Text("See Minder Pro, \(pro.price) once").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                    .padding(.horizontal, 20).frame(height: 42).background(look.iris.light, in: Capsule())
            }.buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.45))
    }

    @ViewBuilder private var knobs: some View {
        VStack(alignment: .leading, spacing: 0) {
            divider
            label("Iris")
            swatches(selection: $look.irisID)

            Toggle(isOn: $look.oddEyes.animation(.spring(duration: 0.3))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Odd eyes").font(.system(size: 15, weight: .medium))
                    Text("A different colour for the right eye").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            if look.oddEyes { swatches(selection: $look.secondIrisID).transition(.opacity) }

            divider
            picker("Shape", EyeOutline.allCases, $look.outline)
            picker("Pupil", PupilStyle.allCases, $look.pupil)
            picker("Brows", BrowStyle.allCases, $look.brow)
            picker("Whites", ScleraStyle.allCases, $look.sclera)

            divider
            slider("Size", value: $look.size, in: 0.8...1.25, icon: "arrow.up.left.and.arrow.down.right")
            slider("Spacing", value: $look.spacing, in: 0.8...1.3, icon: "arrow.left.and.right")
            slider("Glow", value: $look.glow, in: 0...1, icon: "sun.max")
            Toggle(isOn: $look.lashes) {
                Text("Lashes").font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private var divider: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.vertical, 6) }

    private func label(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.4)
            .foregroundStyle(.white.opacity(0.4)).padding(.horizontal, 16).padding(.top, 10)
    }

    private func swatches(selection: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(IrisStyle.all) { style in
                    let on = selection.wrappedValue == style.id
                    Button { Haptics.tap(); withAnimation(.spring(duration: 0.3)) { selection.wrappedValue = style.id } } label: {
                        VStack(spacing: 6) {
                            IrisSwatch(style: style)
                                .frame(width: 38, height: 38)
                                .overlay(Circle().strokeBorder(.white, lineWidth: on ? 2.5 : 0).padding(-4))
                                .scaleEffect(on ? 1.06 : 1)
                            Text(style.name).font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(.white.opacity(on ? 0.9 : 0.4))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
    }

    private func picker<T: Hashable & Identifiable & RawRepresentable>(_ title: String, _ options: [T], _ sel: Binding<T>) -> some View where T.RawValue == String {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 15, weight: .medium)).frame(width: 64, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(options) { o in
                    let on = sel.wrappedValue == o
                    Button { Haptics.tap(); withAnimation(.spring(duration: 0.3)) { sel.wrappedValue = o } } label: {
                        Text(o.rawValue).font(.system(size: 12.5, weight: on ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(on ? Color.black : Color.white.opacity(0.7))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity).frame(height: 32)
                            .background(on ? AnyShapeStyle(look.iris.light) : AnyShapeStyle(Color.white.opacity(0.06)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, icon: String) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 15, weight: .medium)).frame(width: 64, alignment: .leading)
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            Slider(value: value, in: range)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
    }
}

/// A tiny drawn iris for the colour picker, so the swatch looks like the eye it makes.
struct IrisSwatch: View {
    let style: IrisStyle
    var body: some View {
        Canvas { ctx, size in
            let r: CGFloat = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            let grad = Gradient(stops: [.init(color: style.inner, location: 0.25), .init(color: style.light, location: 0.55), .init(color: style.dark, location: 1)])
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(grad, center: c, startRadius: 0, endRadius: r))
            var fib = Path()
            for k in 0..<24 {
                let a: CGFloat = CGFloat(k) / 24 * .pi * 2
                fib.move(to: CGPoint(x: c.x + cos(a) * r * 0.45, y: c.y + sin(a) * r * 0.45))
                fib.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.9, y: c.y + sin(a) * r * 0.9))
            }
            ctx.stroke(fib, with: .color(style.dark.opacity(0.35)), lineWidth: 0.8)
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)), with: .color(style.dark), lineWidth: 2)
            let pr: CGFloat = r * 0.36
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - pr, y: c.y - pr, width: pr * 2, height: pr * 2)), with: .color(.black))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.55, width: r * 0.34, height: r * 0.3)), with: .color(.white.opacity(0.9)))
        }
    }
}
