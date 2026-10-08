import SwiftUI

struct RootView: View {
    @Environment(Pro.self) private var pro
    @Environment(Extras.self) private var extras
    @State private var look = Look.shared
    @AppStorage("camera") private var cameraOn = false
    @AppStorage("motion") private var motionOn = true
    @AppStorage("haptics") private var hapticsOn = true
    @AppStorage("chimeMinutes") private var chimeMinutes = 25
    @AppStorage("tag") private var tag = "Work"
    @AppStorage("planned") private var planned = 0
    @AppStorage("ambience") private var ambience = Ambience.off.rawValue
    @AppStorage("goalMinutes", store: Shared.defaults) private var goalMinutes = 60

    @State private var brain = Brain()
    @State private var tracker = FaceTracker()
    @State private var motion = MotionWatcher()

    @State private var working = false
    @State private var workStart = Date.now
    @State private var controlsVisible = true
    @State private var lastTouch = Date.now
    @State private var showSettings = false
    @State private var showFocus = false
    @State private var showShop = false
    @State private var poster: PosterKind? = nil
    @State private var toast: String?
    @State private var chimes = 0
    @State private var pickups = 0
    @State private var plannedCheered = false
    @State private var breakEnds: Date? = nil
    @State private var offerAfter: Date? = nil
    @State private var newTag = false
    @State private var tagText = ""
    @State private var showcase = false

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
                    if !working, breakEnds == nil, let r = Ledger.rescue {
                        rescuePill(kept: r.kept).padding(.top, 14).transition(.opacity)
                    }
                    Spacer()
                    if let toast {
                        Text(toast)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.white.opacity(0.07), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 14)
                    }
                    if !working, let until = offerAfter, until > .now, breakEnds == nil {
                        afterPills.padding(.bottom, 14).transition(.opacity)
                    }
                    if !working && breakEnds == nil {
                        setupRow.padding(.bottom, 12).transition(.opacity)
                    }
                    FocusSlider(on: $working, tint: iris) { on in on ? startWork() : stopWork() }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 14)
                        .opacity(controlsVisible ? 1 : 0.1)
                }
                .animation(.easeInOut(duration: 0.6), value: controlsVisible)
                .animation(.spring(duration: 0.5), value: toast)
                .animation(.spring(duration: 0.4), value: working)
                if showcase { WidgetShowcase() }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(cameraOn: $cameraOn, motionOn: $motionOn,
                          hapticsOn: $hapticsOn, chimeMinutes: $chimeMinutes, ambience: $ambience)
                .presentationDetents([.large])
                .presentationBackground(.black)
                .presentationCornerRadius(34)
        }
        .sheet(isPresented: $showFocus) {
            FocusSheet().presentationBackground(.black).presentationCornerRadius(34)
                .sheet(item: Binding(get: { pro.paywall }, set: { pro.paywall = $0 })) { r in PaywallView(reason: r).presentationBackground(.black).presentationCornerRadius(34) }
        }
        .sheet(isPresented: $showShop) { ShopSheet().presentationBackground(.black).presentationCornerRadius(34) }
        .sheet(item: $poster) { k in PosterSheet(kind: k).presentationBackground(.black).presentationCornerRadius(34) }
        .sheet(isPresented: $newTag) { tagSheet.presentationDetents([.height(240)]).presentationBackground(Color(white: 0.06)) }
        .onAppear(perform: boot)
        .onChange(of: cameraOn) { _, on in applyCamera(on) }
        .onChange(of: pro.unlocked) { _, _ in applyCamera(cameraOn); WidgetMirror.push(pro: pro.unlocked, iris: look.irisID) }
        .onChange(of: look.irisID) { _, id in WidgetMirror.push(pro: pro.unlocked, iris: id) }
        .onChange(of: hapticsOn) { _, on in Haptics.enabled = on }
        .onChange(of: chimeMinutes) { _, m in brain.chimeInterval = Double(m) * 60 }
        .onChange(of: ambience) { _, a in if working { SoundEngine.shared.play(allowed(Ambience(rawValue: a) ?? .off)) } }
        .onChange(of: phase) { _, p in
            if p == .active {
                if working { applyCamera(cameraOn); motion.start() }
                if !working, UserDefaults.standard.bool(forKey: "pendingStart") { begin() }
            } else { tracker.stop(); motion.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .minderStartFocus)) { _ in if !working { begin() } }
        .task {
            // Controls fade away once you have been left alone for a few seconds; the plan and the break keep time.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if working && controlsVisible && Date.now.timeIntervalSince(lastTouch) > 4.5 && !showSettings {
                    controlsVisible = false
                }
                if working, planned > 0, !plannedCheered, Date.now.timeIntervalSince(workStart) >= Double(planned) * 60 {
                    plannedCheered = true
                    brain.cheer(at: now)
                    Haptics.success()
                    flashToast("\(planned) minutes, as planned. Keep going or slide back.")
                }
                if let end = breakEnds, Date.now >= end { endBreak(alarm: true) }
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
                        Text(planned > 0 ? "\(tag.uppercased()) · \(planned)M PLAN" : tag.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(3)
                        if chimes > 0 {
                            ForEach(0..<min(chimes, 8), id: \.self) { _ in
                                Circle().fill(iris.light).frame(width: 5, height: 5)
                            }
                        }
                    }
                    .foregroundStyle(.white.opacity(controlsVisible ? 0.4 : 0.14))
                    if planned > 0 {
                        Capsule().fill(.white.opacity(0.08)).frame(width: 120, height: 3)
                            .overlay(alignment: .leading) {
                                Capsule().fill(iris.light.opacity(controlsVisible ? 0.8 : 0.3))
                                    .frame(width: 120 * min(1, tl.date.timeIntervalSince(workStart) / (Double(planned) * 60)), height: 3)
                            }
                    }
                }
                .padding(.top, 28)
            }
        } else if let end = breakEnds {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                VStack(spacing: 6) {
                    Text(clock(max(0, end.timeIntervalSince(tl.date))))
                        .font(.system(size: 44, weight: .ultraLight, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                    Text("ON A BREAK").font(.system(size: 11, weight: .semibold)).tracking(3).foregroundStyle(.white.opacity(0.4))
                    Button("End break") { endBreak(alarm: false) }
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(iris.light).padding(.top, 4)
                }
                .padding(.top, 28)
            }
        } else {
            HStack(alignment: .center, spacing: 14) {
                Button { Haptics.tap(); showFocus = true } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            GoalRing(fraction: min(1, Ledger.today / Double(goalMinutes * 60)), tint: iris, width: 4)
                            Text("\(Int(min(1, Ledger.today / Double(goalMinutes * 60)) * 100))").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        }.frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Today").font(.system(size: 12, weight: .semibold)).tracking(1.5).textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.38))
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(spoken(Ledger.today))
                                    .font(.system(size: 26, weight: .light, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.9))
                                if Ledger.streak > 1 {
                                    Label(days(Ledger.streak), systemImage: "flame.fill")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(iris.light.opacity(0.9))
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Focus stats")
                Spacer()
                roundButton("bag", label: "Extras") { showShop = true }
                roundButton("slider.horizontal.3", label: "Settings") { showSettings = true }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .transition(.opacity)
        }
    }

    private func roundButton(_ icon: String, label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.07), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.1)))
        }
        .accessibilityLabel(label)
    }

    private func rescuePill(kept: Int) -> some View {
        Button { showFocus = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(iris.light)
                Text("Your \(kept)-day streak missed yesterday. Save it?").foregroundStyle(.white.opacity(0.85))
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .padding(.horizontal, 16).frame(height: 40)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.4)))
        }.buttonStyle(.plain)
    }

    /// Before a session: what it's for, and how long it's meant to be.
    private var setupRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SessionLog.shared.tags, id: \.self) { t in
                        Button { tag = t; Haptics.tap() } label: {
                            Text(t).font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(tag == t ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 13).frame(height: 32)
                                .background(tag == t ? AnyShapeStyle(iris.light) : AnyShapeStyle(Color.white.opacity(0.07)), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                    Button { if pro.unlocked { newTag = true } else { pro.ask(.tags); showSettings = true } } label: {
                        Image(systemName: pro.unlocked ? "plus" : "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32).background(Color.white.opacity(0.07), in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("New tag")
                }
                .padding(.leading, 22)
            }
            Menu {
                Picker("Plan", selection: $planned) {
                    Text("Open-ended").tag(0); Text("25 minutes").tag(25); Text("50 minutes").tag(50); Text("90 minutes").tag(90)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.system(size: 12, weight: .semibold))
                    Text(planned == 0 ? "Open" : "\(planned)m").font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75)).padding(.horizontal, 12).frame(height: 32)
                .background(Color.white.opacity(0.07), in: Capsule())
            }
            .padding(.trailing, 22)
        }
    }

    /// Right after a session: a break, or a poster of it.
    private var afterPills: some View {
        HStack(spacing: 10) {
            Button { startBreak() } label: {
                Label("5-minute break", systemImage: "cup.and.saucer.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                    .padding(.horizontal, 16).frame(height: 38).background(iris.light, in: Capsule())
            }.buttonStyle(.plain)
            Button { poster = .lastSession; offerAfter = nil } label: {
                Label("Poster", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 16).frame(height: 38).background(.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
            }.buttonStyle(.plain)
        }
    }

    private var tagSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New tag").font(.system(size: 22, weight: .semibold, design: .rounded)).padding(.top, 22)
            TextField("Side project", text: $tagText).font(.system(size: 18, weight: .medium)).padding(14)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            Button {
                let t = tagText.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty, !SessionLog.shared.tags.contains(t) { SessionLog.shared.customTags.append(String(t.prefix(16))); tag = String(t.prefix(16)) }
                tagText = ""; newTag = false
            } label: {
                Text("Add").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 48).background(iris.light, in: Capsule())
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 22).foregroundStyle(.white)
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
            if motionOn {
                brain.phoneMoved(at: Date.now.timeIntervalSinceReferenceDate)
                DispatchQueue.main.async { if working { pickups += 1 } }
            }
        }

        // Store screenshots: -shot idle|work|settings|focus|shop|poster|rescue|widgets|break|after|paywall, -expr <expression>
        if let i = args.firstIndex(of: "-shot"), i + 1 < args.count {
            Ledger.seed()
            SessionLog.shared.seed()
            Shared.goalMinutes = 120
            goalMinutes = 120
            tag = "Write"; planned = 50
            if let j = args.firstIndex(of: "-preset"), j + 1 < args.count {
                let id = args[j + 1].replacingOccurrences(of: "_", with: " ")
                (Look.presets.first { $0.id == id } ?? Look.packPreset(id.lowercased().replacingOccurrences(of: " ", with: "")))?.apply(look)
            }
            let mode = args[i + 1]
            if mode == "rescue" {
                var a = Ledger.all; a[Ledger.key(Calendar.current.date(byAdding: .day, value: -1, to: .now)!)] = nil; Ledger.all = a
                showFocus = true
            }
            if mode == "work" {
                working = true
                workStart = Date.now.addingTimeInterval(-(38 * 60 + 14))
                chimes = 1
                brain.engage(at: now)
            }
            if mode == "break" { breakEnds = .now.addingTimeInterval(4 * 60 + 12); brain.resting = true }
            if mode == "after" { offerAfter = .now.addingTimeInterval(600); flashToast("52m of focus. Nice.") }
            if mode == "settings" { showSettings = true }
            if mode == "widgets" { showcase = true }
            if mode == "focus" { showFocus = true }
            if mode == "shop" { showShop = true }
            if mode == "poster" { poster = .today }
            if mode == "paywall" { showSettings = true; pro.paywall = .designer }
            if let j = args.firstIndex(of: "-expr"), j + 1 < args.count {
                brain.pinned = Expression(rawValue: args[j + 1])
            }
            if mode == "work" && brain.pinned == nil { brain.pinned = .focused }
            return
        }

        WidgetMirror.push(pro: pro.unlocked, iris: look.irisID)
        if args.contains("-demoAutoplay") { Task { await autoplay() } }
        else if UserDefaults.standard.bool(forKey: "pendingStart") { begin() }
    }

    /// App Review recording: a typical first use, through the same functions the controls call.
    @MainActor private func autoplay() async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        Ledger.seed(); SessionLog.shared.seed()
        await wait(3)
        for p in [CGPoint(x: -0.6, y: -0.2), CGPoint(x: 0.7, y: 0.3), CGPoint(x: 0, y: 0)] {
            brain.touched(at: p, t: now)
            await wait(1.4)
        }
        tag = "Study"; planned = 25
        await wait(1.5)
        withAnimation(.spring(duration: 0.6)) { working = true }
        startWork()
        await wait(10)
        brain.phoneMoved(at: now)
        await wait(4)
        reveal()
        await wait(2)
        withAnimation(.spring(duration: 0.6)) { working = false }
        stopWork()
        await wait(3)
        startBreak()
        await wait(4)
        endBreak(alarm: false)
        await wait(1.5)
        showFocus = true
        await wait(5)
        showFocus = false
        await wait(1.5)
        showShop = true
        await wait(5)
        showShop = false
        await wait(1.5)
        showSettings = true
        await wait(2.5)
        for id in ["Cat", "Robot", "Classic"] {
            withAnimation { Look.presets.first { $0.id == id }?.apply(look) }
            await wait(1.8)
        }
        showSettings = false
        await wait(2)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? Data().write(to: docs.appendingPathComponent("demo_done"))
    }

    /// Start from outside the slider (Shortcuts, Siri).
    private func begin() {
        UserDefaults.standard.set(false, forKey: "pendingStart")
        withAnimation(.spring(duration: 0.6)) { working = true }
        startWork()
    }

    private func allowed(_ a: Ambience) -> Ambience {
        switch a.tier {
        case .free: return a
        case .pro: return pro.unlocked ? a : .off
        case .pack: return extras.ownsAmbience ? a : .off
        }
    }

    private func startWork() {
        if breakEnds != nil { endBreak(alarm: false) }
        offerAfter = nil
        workStart = .now
        chimes = 0
        pickups = 0
        plannedCheered = false
        brain.resting = false
        brain.engage(at: now)
        UIApplication.shared.isIdleTimerDisabled = true
        Haptics.success()
        applyCamera(cameraOn)
        motion.start()
        lastTouch = .now
        SoundEngine.shared.play(allowed(Ambience(rawValue: ambience) ?? .off))
        FocusActivity.start(at: workStart, planned: planned, tag: tag, iris: look.irisID)
        flashToast("Okay. I'm watching.")
    }

    private func stopWork() {
        let worked = Date.now.timeIntervalSince(workStart)
        let before = Ledger.today
        Ledger.add(worked)
        SessionLog.shared.add(Session(start: workStart, seconds: worked, tag: tag, planned: planned, pickups: pickups))
        brain.disengage(at: now)
        UIApplication.shared.isIdleTimerDisabled = false
        tracker.stop(); motion.stop()
        SoundEngine.shared.stop()
        FocusActivity.end()
        WidgetMirror.push(pro: pro.unlocked, iris: look.irisID)
        controlsVisible = true
        Haptics.tap(.medium)
        let goal = Double(goalMinutes * 60)
        if before < goal && Ledger.today >= goal {
            flashToast("Daily goal done. \(spoken(Ledger.today)) today.")
        } else {
            flashToast(worked >= 60 ? "\(spoken(worked)) of focus. Nice." : "Short one. That's fine.")
        }
        if worked >= 5 * 60 { offerAfter = .now.addingTimeInterval(90) }
    }

    private func startBreak() {
        let end = Date.now.addingTimeInterval(5 * 60)
        breakEnds = end
        offerAfter = nil
        brain.resting = true
        BreakAlarm.schedule(at: end)
        FocusActivity.onBreak(until: end, iris: look.irisID)
        Haptics.tap(.medium)
    }

    private func endBreak(alarm: Bool) {
        breakEnds = nil
        brain.resting = false
        brain.touched(at: .zero, t: now)
        BreakAlarm.cancel()
        FocusActivity.end()
        if alarm { Haptics.success(); flashToast("Break's over. Ready when you are.") }
    }

    private func applyCamera(_ on: Bool) {
        // Follow my face is Pro. The setting is remembered either way; it only runs with Pro.
        let live = on && pro.unlocked
        brain.cameraOn = live && FaceTracker.authorized
        if live && working { tracker.start() } else { tracker.stop() }
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
