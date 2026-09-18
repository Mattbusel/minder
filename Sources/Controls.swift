import SwiftUI

/// Slide right to start working, slide back to stop. A slider rather than a
/// button so it can't be started or stopped by a stray thumb.
struct FocusSlider: View {
    @Binding var on: Bool
    let tint: IrisStyle
    var changed: (Bool) -> Void

    @State private var drag: CGFloat = 0
    @State private var armed = false
    @State private var shimmer: CGFloat = -1

    private let height: CGFloat = 70
    private let pad: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let knob = height - pad * 2
            let travel = geo.size.width - knob - pad * 2
            let rest: CGFloat = on ? travel : 0
            let x = min(max(rest + drag, 0), travel)
            let progress = travel > 0 ? x / travel : 0

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.09), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)],
                                                                   startPoint: .top, endPoint: .bottom), lineWidth: 1))

                // Fill that follows the knob
                Capsule()
                    .fill(LinearGradient(colors: [tint.dark.opacity(0.55), tint.light.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + knob + pad * 2)
                    .opacity(0.2 + progress * 0.8)
                    .blur(radius: 0.5)

                // Label
                ZStack {
                    label(on ? "slide back to rest" : "slide to focus")
                        .foregroundStyle(.white.opacity(0.28))
                    label(on ? "slide back to rest" : "slide to focus")
                        .foregroundStyle(.white.opacity(0.95))
                        .mask(
                            LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 110)
                                .offset(x: shimmer * geo.size.width * 0.6)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, on ? 0 : knob)
                .padding(.trailing, on ? knob : 0)
                .opacity(labelOpacity(progress))

                // Knob
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.white, Color(white: 0.82)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: knob * 0.8))
                        .shadow(color: tint.light.opacity(0.35 + progress * 0.4), radius: 14 + progress * 10)
                    KnobEyes(closed: !on && progress < 0.02, tint: tint)
                        .frame(width: knob * 0.56, height: knob * 0.36)
                }
                .frame(width: knob, height: knob)
                .offset(x: pad + x)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { v in
                            drag = v.translation.width
                            let p = min(max(rest + drag, 0), travel) / travel
                            let past = on ? p < 0.25 : p > 0.75
                            if past != armed { armed = past; Haptics.tap(past ? .medium : .light) }
                        }
                        .onEnded { _ in
                            let p = min(max(rest + drag, 0), travel) / travel
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                if !on && p > 0.75 { on = true; changed(true) }
                                else if on && p < 0.25 { on = false; changed(false) }
                                drag = 0
                            }
                            armed = false
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(on ? "Stop working" : "Start working")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { on.toggle(); changed(on) }
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { shimmer = 1 }
        }
    }

    private func labelOpacity(_ progress: CGFloat) -> Double {
        let p = Double(progress)
        return on ? 1.0 - (1.0 - p) * 2.2 : 1.0 - p * 2.2
    }

    private func label(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .tracking(0.6)
    }
}

/// Two tiny eyes on the knob: shut while resting, open when working.
private struct KnobEyes: View {
    let closed: Bool
    let tint: IrisStyle
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<2, id: \.self) { _ in
                ZStack {
                    if closed {
                        Capsule().fill(Color(white: 0.12)).frame(height: 3.5).offset(y: 3)
                    } else {
                        Ellipse().fill(Color(white: 0.1))
                        Circle().fill(tint.light).frame(width: 7, height: 7).offset(y: 1.5)
                        Circle().fill(.white).frame(width: 2.5, height: 2.5).offset(x: -1, y: 0)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: closed)
    }
}

struct SettingsSheet: View {
    @Binding var irisID: String
    @Binding var cameraOn: Bool
    @Binding var motionOn: Bool
    @Binding var hapticsOn: Bool
    @Binding var chimeMinutes: Int
    @Environment(\.dismiss) private var dismiss
    @State private var cameraDenied = false
    @State private var preview = Brain()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text("Minder")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                    }
                }

                WeekCard(tint: IrisStyle.named(irisID))

                section("Eyes") {
                    EyesCanvas(brain: preview, iris: IrisStyle.named(irisID))
                        .frame(height: 150)
                        .allowsHitTesting(false)
                    HStack(spacing: 0) {
                        ForEach(IrisStyle.all) { style in
                            Button {
                                Haptics.tap(); irisID = style.id
                            } label: {
                                VStack(spacing: 7) {
                                    Circle()
                                        .fill(RadialGradient(colors: [style.light, style.dark], center: .center, startRadius: 2, endRadius: 20))
                                        .frame(width: 36, height: 36)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: irisID == style.id ? 2.5 : 0).padding(-4))
                                    Text(style.name).font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(irisID == style.id ? 0.9 : 0.4))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 14)
                }

                section("While you work") {
                    toggle("Follow my face", "Uses the front camera to track where you are. Nothing is recorded or leaves the phone.",
                           icon: "face.dashed", isOn: Binding(get: { cameraOn }, set: { want in
                               if want && !FaceTracker.authorized {
                                   FaceTracker.requestAccess { ok in cameraOn = ok; cameraDenied = !ok }
                               } else { cameraOn = want }
                           }))
                    if cameraDenied {
                        Text("Camera access is off for Minder. Turn it on in Settings, then come back.")
                            .font(.footnote).foregroundStyle(.orange.opacity(0.9)).padding(.horizontal, 16).padding(.bottom, 12)
                    }
                    divider
                    toggle("Notice when I pick up the phone", "The eyes get suspicious if the phone moves mid-session.",
                           icon: "iphone.radiowaves.left.and.right", isOn: $motionOn)
                    divider
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            icon("bell.badge")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Check-in").font(.system(size: 16, weight: .medium))
                                Text("A proud look and a buzz every so often.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                            }
                        }
                        Picker("Check-in", selection: $chimeMinutes) {
                            Text("Off").tag(0); Text("15m").tag(15); Text("25m").tag(25); Text("45m").tag(45); Text("60m").tag(60)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    divider
                    toggle("Haptics", nil, icon: "hand.tap", isOn: $hapticsOn)
                }

                Text("Tip: prop the phone up facing you and slide to focus. Tap the eyes any time.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .tint(IrisStyle.named(irisID).light)
    }

    private var divider: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 60) }

    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 15, weight: .medium))
            .foregroundStyle(IrisStyle.named(irisID).light)
            .frame(width: 30, height: 30)
            .background(IrisStyle.named(irisID).light.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
    }

    private func toggle(_ title: String, _ sub: String?, icon name: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                icon(name)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .medium))
                    if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)) }
                }
            }
        }
        .padding(16)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.4))
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))
        }
    }
}

private struct WeekCard: View {
    let tint: IrisStyle
    var body: some View {
        let week = Ledger.week
        let peak = max(week.map(\.seconds).max() ?? 1, 60 * 30)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                    Text(spoken(week.map(\.seconds).reduce(0, +)))
                        .font(.system(size: 34, weight: .light, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Streak").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                    Text("\(Ledger.streak) days").font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(tint.light)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i == 6 ? AnyShapeStyle(LinearGradient(colors: [tint.light, tint.dark], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(Color.white.opacity(d.seconds > 0 ? 0.22 : 0.07)))
                            .frame(height: max(6, 96 * d.seconds / peak))
                        Text(d.label).font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(i == 6 ? 0.9 : 0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 118, alignment: .bottom)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [tint.dark.opacity(0.35), Color(white: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}
