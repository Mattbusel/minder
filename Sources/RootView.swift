import SwiftUI

struct RootView: View {
    @State private var look = Look.shared
    @AppStorage("camera") private var cameraOn = false
    @AppStorage("motion") private var motionOn = true
    @AppStorage("haptics") private var hapticsOn = true
    @AppStorage("chimeMinutes") private var chimeMinutes = 25

    @State private var brain = Brain()
    @State private var tracker = FaceTracker()
    @State private var motion = MotionWatcher()

    @State private var working = false
    @State private var workStart = Date.now
    @State private var controlsVisible = true
    @State private var lastTouch = Date.now
    @State private var showSettings = false
    @State private var toast: String?
    @State private var chimes = 0

    @Environment(\.scenePhase) private var phase

    private var iris: IrisStyle { look.iris }
    private var args: [String] { ProcessInfo.processInfo.arguments }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                EyesCanvas(brain: brain, look: look, dimmed: working && !controlsVisible)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { p in
                        let g = CGPoint(x: (p.x - geo.size.width / 2) / (geo.size.width / 2),
                                        y: (p.y - geo.size.height * 0.44) / (geo.size.height * 0.4))
                        brain.touched(at: g, t: now)
                        Haptics.tap(.soft)
                        reveal()
                    }

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    if let toast {
                        Text(toast)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.white.opacity(0.07), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 22)
                    }
                    FocusSlider(on: $working, tint: iris) { on in on ? startWork() : stopWork() }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                        .opacity(controlsVisible ? 1 : 0.1)
                }
                .animation(.easeInOut(duration: 0.6), value: controlsVisible)
                .animation(.spring(duration: 0.5), value: toast)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(cameraOn: $cameraOn, motionOn: $motionOn,
                          hapticsOn: $hapticsOn, chimeMinutes: $chimeMinutes)
                .presentationDetents([.large])
                .presentationBackground(.black)
                .presentationCornerRadius(34)
        }
        .onAppear(perform: boot)
        .onChange(of: cameraOn) { _, on in applyCamera(on) }
        .onChange(of: hapticsOn) { _, on in Haptics.enabled = on }
        .onChange(of: chimeMinutes) { _, m in brain.chimeInterval = Double(m) * 60 }
        .onChange(of: phase) { _, p in
            if p == .active { if working { tracker.start(); motion.start() } }
            else { tracker.stop(); motion.stop() }
        }
        .task {
            // Controls fade away once you have been left alone for a few seconds.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if working && controlsVisible && Date.now.timeIntervalSince(lastTouch) > 4.5 && !showSettings {
                    controlsVisible = false
                }
            }
        }
    }

    private var now: Double { Date.now.timeIntervalSinceReferenceDate }

    // MARK: top

    @ViewBuilder private var topBar: some View {
        if working {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                VStack(spacing: 6) {
                    Text(clock(tl.date.timeIntervalSince(workStart)))
                        .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(controlsVisible ? 0.8 : 0.28))
                        .contentTransition(.numericText())
                    HStack(spacing: 5) {
                        Text("WORKING").font(.system(size: 11, weight: .semibold)).tracking(3)
                        if chimes > 0 {
                            ForEach(0..<min(chimes, 8), id: \.self) { _ in
                                Circle().fill(iris.light).frame(width: 5, height: 5)
                            }
                        }
                    }
                    .foregroundStyle(.white.opacity(controlsVisible ? 0.4 : 0.14))
                }
                .padding(.top, 28)
            }
        } else {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today").font(.system(size: 12, weight: .semibold)).tracking(1.5).textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.38))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(spoken(Ledger.today))
                            .font(.system(size: 26, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        if Ledger.streak > 1 {
                            Label("\(Ledger.streak) days", systemImage: "flame.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(iris.light.opacity(0.9))
                        }
                    }
                }
                Spacer()
                Button {
                    Haptics.tap(); showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.07), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.1)))
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .transition(.opacity)
        }
    }

    // MARK: lifecycle

    private func boot() {
        Haptics.enabled = hapticsOn
        brain.chimeInterval = Double(chimeMinutes) * 60
        brain.onChime = {
            chimes += 1
            Haptics.success()
            let lines = ["\(chimeMinutes) minutes. Proud of you.", "Another \(chimeMinutes). Keep going.", "Still here. Still watching.", "That was a good one."]
            flashToast(lines[(chimes - 1) % lines.count])
        }
        tracker.onFace = { [brain] p in brain.sawFace(p, at: Date.now.timeIntervalSinceReferenceDate) }
        motion.onMove = { [brain] in
            if motionOn { brain.phoneMoved(at: Date.now.timeIntervalSinceReferenceDate) }
        }

        // Store screenshots: -shot idle|work|settings, -expr <expression>
        if let i = args.firstIndex(of: "-shot"), i + 1 < args.count {
            Ledger.seed()
            if let j = args.firstIndex(of: "-preset"), j + 1 < args.count {
                Look.presets.first { $0.id == args[j + 1].replacingOccurrences(of: "_", with: " ") }?.apply(look)
            }
            let mode = args[i + 1]
            if mode == "work" {
                working = true
                workStart = Date.now.addingTimeInterval(-(23 * 60 + 14))
                chimes = 0
                brain.engage(at: now)
            }
            if mode == "settings" { showSettings = true }
            if let j = args.firstIndex(of: "-expr"), j + 1 < args.count {
                brain.pinned = Expression(rawValue: args[j + 1])
            }
            if mode == "work" && brain.pinned == nil { brain.pinned = .focused }
        }

        if args.contains("-demoAutoplay") { Task { await autoplay() } }
    }

    /// App Review recording: a typical first use, through the same functions the controls call.
    @MainActor private func autoplay() async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        await wait(3)
        for p in [CGPoint(x: -0.6, y: -0.2), CGPoint(x: 0.7, y: 0.3), CGPoint(x: 0, y: 0)] {
            brain.touched(at: p, t: now)
            await wait(1.4)
        }

        showSettings = true
        await wait(2.5)
        for id in ["Cat", "Robot", "Classic"] {
            withAnimation { Look.presets.first { $0.id == id }?.apply(look) }
            await wait(1.8)
        }
        showSettings = false
        await wait(2)

        withAnimation(.spring(duration: 0.6)) { working = true }
        startWork()
        await wait(12)
        brain.phoneMoved(at: now)
        await wait(4)
        reveal()
        await wait(2.5)
        withAnimation(.spring(duration: 0.6)) { working = false }
        stopWork()
        await wait(4.5)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? Data().write(to: docs.appendingPathComponent("demo_done"))
    }

    private func startWork() {
        workStart = .now
        chimes = 0
        brain.engage(at: now)
        UIApplication.shared.isIdleTimerDisabled = true
        Haptics.success()
        applyCamera(cameraOn)
        motion.start()
        lastTouch = .now
        flashToast("Okay. I'm watching.")
    }

    private func stopWork() {
        let worked = Date.now.timeIntervalSince(workStart)
        Ledger.add(worked)
        brain.disengage(at: now)
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.stop(); motion.stop()
        controlsVisible = true
        Haptics.tap(.medium)
        flashToast(worked >= 60 ? "\(spoken(worked)) of focus. Nice." : "Short one. That's fine.")
    }

    private func applyCamera(_ on: Bool) {
        brain.cameraOn = on && FaceTracker.authorized
        if on && working { tracker.start() } else { tracker.stop() }
    }

    private func reveal() {
        lastTouch = .now
        controlsVisible = true
    }

    private func flashToast(_ s: String) {
        toast = s
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            if toast == s { toast = nil }
        }
    }
}
