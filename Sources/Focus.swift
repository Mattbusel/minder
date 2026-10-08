import SwiftUI

/// The numbers: today against the goal, the streak (and saving it), the week, where the time went.
/// The long view (twelve weeks, every session, CSV) is Pro.
struct FocusSheet: View {
    @Environment(Pro.self) private var pro
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    @AppStorage("goalMinutes", store: Shared.defaults) private var goal = 60
    @State private var look = Look.shared
    @State private var log = SessionLog.shared
    @State private var poster: PosterKind? = nil
    @State private var shop = false
    @State private var tick = 0
    @State private var csvURL: URL? = nil

    var body: some View {
        let tint = look.iris
        let today = Ledger.today
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Focus").font(.system(size: 32, weight: .semibold, design: .rounded))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                    }.accessibilityLabel("Close")
                }

                // Today against the goal.
                HStack(spacing: 20) {
                    ZStack {
                        GoalRing(fraction: min(1, today / Double(goal * 60)), tint: tint, width: 10)
                        VStack(spacing: 0) {
                            Text(spoken(today)).font(.system(size: 26, weight: .light, design: .rounded))
                            Text("of \(spoken(Double(goal * 60)))").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                        }
                    }.frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily goal").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach([30, 45, 60, 90, 120, 180], id: \.self) { m in
                                Button { goal = m; Haptics.tap(); WidgetMirror.push(pro: pro.unlocked, iris: look.irisID) } label: {
                                    Text(spoken(Double(m * 60))).font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(goal == m ? .black : .white.opacity(0.75))
                                        .frame(maxWidth: .infinity).frame(height: 30)
                                        .background(goal == m ? AnyShapeStyle(tint.light) : AnyShapeStyle(Color.white.opacity(0.07)), in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(18).card()

                streakCard(tint)

                week(tint)

                tags(tint)

                Button { poster = .today } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 15, weight: .medium)).foregroundStyle(tint.light)
                            .frame(width: 32, height: 32).background(tint.light.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Make a poster of today").font(.system(size: 16, weight: .medium))
                            Text(extras.firstPosterFree ? "Your first one is free." : "\(extras.posters) poster credit\(extras.posters == 1 ? "" : "s") left").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    }.padding(16).card()
                }.buttonStyle(.plain)

                proSection(tint)
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $poster) { k in PosterSheet(kind: k).presentationBackground(.black).presentationCornerRadius(34) }
        .sheet(isPresented: $shop) { ShopSheet().presentationBackground(.black).presentationCornerRadius(34) }
        .task {
            let u = URL.temporaryDirectory.appending(path: "Minder focus \(Ledger.key(.now)).csv")
            try? log.csv().write(to: u, atomically: true, encoding: .utf8)
            csvURL = u
        }
        .id(tick)
    }

    @ViewBuilder private func streakCard(_ tint: IrisStyle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                    Text(days(Ledger.streak)).font(.system(size: 30, weight: .light, design: .rounded)).foregroundStyle(tint.light)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Best").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                    Text(days(max(Ledger.best, Ledger.streak))).font(.system(size: 20, weight: .medium, design: .rounded))
                }
            }
            if let r = Ledger.rescue {
                RescueCard(day: r.day, kept: r.kept, tint: tint) { tick += 1 }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled").foregroundStyle(tint.light)
                    Text(extras.freeShieldLeft ? "This month's free Streak Shield is ready" : "Free shield used this month")
                    Spacer()
                    if extras.shields > 0 { Text("+\(extras.shields) banked").foregroundStyle(tint.light) }
                }.font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(18).card()
    }

    private func week(_ tint: IrisStyle) -> some View {
        let w = Ledger.week
        let peak = max(w.map(\.seconds).max() ?? 1, Double(goal * 60), 1800)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(spoken(w.map(\.seconds).reduce(0, +))).font(.system(size: 20, weight: .light, design: .rounded))
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(w.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i == 6 ? AnyShapeStyle(LinearGradient(colors: [tint.light, tint.dark], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(Color.white.opacity(d.seconds >= Double(goal * 60) ? 0.42 : d.seconds > 0 ? 0.2 : 0.07)))
                            .frame(height: max(6, 96 * d.seconds / peak))
                        Text(d.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(i == 6 ? 0.9 : 0.35))
                    }.frame(maxWidth: .infinity)
                }
            }
            .frame(height: 118, alignment: .bottom)
            .overlay(alignment: .bottom) {
                Rectangle().fill(tint.light.opacity(0.35)).frame(height: 1).offset(y: -(18 + 96 * Double(goal * 60) / peak))
            }
        }
        .padding(18).card()
    }

    private func tags(_ tint: IrisStyle) -> some View {
        let since = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now))!
        let t = log.byTag(since: since)
        let top = t.first?.1 ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Text("Where the week went").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
            if t.isEmpty { Text("Pick a tag before you slide to focus and it shows up here.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.4)) }
            ForEach(t, id: \.0) { name, secs in
                HStack(spacing: 10) {
                    Text(name).font(.system(size: 14, weight: .medium)).frame(width: 64, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(LinearGradient(colors: [tint.dark, tint.light], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, g.size.width * secs / top))
                    }.frame(height: 10)
                    Text(spoken(secs)).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6)).frame(width: 58, alignment: .trailing)
                }
            }
        }
        .padding(18).card()
    }

    @ViewBuilder private func proSection(_ tint: IrisStyle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TWELVE WEEKS").font(.system(size: 12, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.4))
                Spacer()
                if !pro.unlocked { Text("PRO").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.black).padding(.horizontal, 7).padding(.vertical, 3).background(tint.light, in: Capsule()) }
            }
            VStack(alignment: .leading, spacing: 16) {
                Heatmap(tint: tint, goal: Double(goal * 60)).frame(height: 104)
                HStack {
                    stat("\(spoken(Ledger.total))", "all time")
                    stat(log.longest.map { spoken($0.seconds) } ?? "–", "longest session")
                    stat("\(log.sessions.count)", "sessions")
                }
                ForEach(log.sessions.sorted { $0.start > $1.start }.prefix(6)) { s in
                    HStack {
                        Text(s.start.formatted(.dateTime.weekday(.abbreviated).hour().minute())).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                        Text(s.tag).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint.light)
                        Spacer()
                        if s.pickups > 0 { Label("\(s.pickups)", systemImage: "iphone.radiowaves.left.and.right").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4)) }
                        Text(spoken(s.seconds)).font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                }
                if let csvURL, pro.unlocked {
                    ShareLink(item: csvURL) { Label("Export every session as CSV", systemImage: "tablecells").font(.system(size: 15, weight: .medium)).foregroundStyle(tint.light) }
                }
            }
            .padding(18).card()
            .blur(radius: pro.unlocked ? 0 : 6)
            .allowsHitTesting(pro.unlocked)
            .overlay {
                if !pro.unlocked {
                    VStack(spacing: 10) {
                        Text("Twelve weeks, every session, CSV").font(.system(size: 17, weight: .semibold, design: .rounded))
                        Button { pro.ask(.stats) } label: {
                            Text("See Minder Pro, \(pro.price) once").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                                .padding(.horizontal, 20).frame(height: 42).background(tint.light, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 20, weight: .light, design: .rounded))
            Text(l).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.45))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Twelve weeks of days, coloured by how close each came to the goal.
struct Heatmap: View {
    let tint: IrisStyle
    let goal: Double
    var body: some View {
        Canvas { ctx, size in
            let cal = Calendar.current
            let cols = 12, cell = min(size.width / CGFloat(cols), size.height / 7), s = cell - 3
            let todayDow = (cal.component(.weekday, from: .now) + 5) % 7
            for c in 0..<cols { for r in 0..<7 {
                let back = (cols - 1 - c) * 7 + (todayDow - r)
                guard back >= 0, let day = cal.date(byAdding: .day, value: -back, to: .now) else { continue }
                let v = Ledger.seconds(on: day)
                let shield = Ledger.shielded.contains(Ledger.key(day))
                let col: Color = shield ? Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.7) : v >= goal ? tint.light : v > 0 ? tint.light.opacity(0.18 + 0.5 * min(1, v / goal)) : .white.opacity(0.07)
                ctx.fill(Path(roundedRect: CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: s, height: s), cornerRadius: 3), with: .color(col))
            } }
        }
    }
}

/// A broken streak, and how to keep it.
struct RescueCard: View {
    @Environment(Extras.self) private var extras
    let day: Date
    let kept: Int
    let tint: IrisStyle
    var done: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Text("Your \(kept)-day streak missed \(day.formatted(.dateTime.weekday(.wide))).").font(.system(size: 15, weight: .medium))
            }
            Text("A Streak Shield covers that day so the streak carries on. The day itself doesn't count, the streak just holds.")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
            if extras.freeShieldLeft || extras.shields > 0 {
                Button { if extras.useShield(on: day) { Haptics.success(); done() } } label: {
                    Label(extras.freeShieldLeft ? "Use this month's free shield" : "Use a banked shield (\(extras.shields))", systemImage: "shield.lefthalf.filled")
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 46).background(tint.light, in: Capsule())
                }.buttonStyle(.plain)
            } else {
                Button { Task { if await extras.buy(Extras.shieldID), extras.useShield(on: day) { done() } } } label: {
                    Group { if extras.busy == Extras.shieldID { ProgressView().tint(.black) } else { Text("Shield it for \(extras.price(Extras.shieldID))") } }
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 46).background(tint.light, in: Capsule())
                }.buttonStyle(.plain).disabled(extras.busy != nil)
            }
            if let m = extras.message { Text(m).font(.system(size: 12, weight: .medium)).foregroundStyle(tint.light) }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.orange.opacity(0.35)))
    }
}

// MARK: - Posters

enum PosterKind: String, Identifiable { case today, lastSession; var id: String { rawValue } }

struct PosterSheet: View {
    @Environment(Extras.self) private var extras
    @Environment(\.dismiss) private var dismiss
    let kind: PosterKind
    @State private var look = Look.shared
    @State private var image: UIImage? = nil
    @State private var spent = false

    var body: some View {
        let tint = look.iris
        VStack(spacing: 18) {
            HStack {
                Text("Poster").font(.system(size: 26, weight: .semibold, design: .rounded))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                }
            }
            PosterView(kind: kind, look: look)
                .frame(width: 300, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.1)))
                .shadow(color: tint.light.opacity(0.25), radius: 30)
            if spent, let image {
                ShareLink(item: Image(uiImage: image), preview: SharePreview("Focus with Minder", image: Image(uiImage: image))) {
                    Label("Share poster", systemImage: "square.and.arrow.up").font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 54).background(tint.light, in: Capsule())
                }
            } else if extras.firstPosterFree || extras.posters > 0 {
                Button { if extras.spendPoster() { render(); spent = true; Haptics.success() } } label: {
                    Text(extras.firstPosterFree ? "Make it, your first one is free" : "Make it, uses 1 of \(extras.posters)").font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 54).background(tint.light, in: Capsule())
                }.buttonStyle(.plain)
            } else {
                Button { Task { if await extras.buy(Extras.postersID), extras.spendPoster() { render(); spent = true } } } label: {
                    Group { if extras.busy == Extras.postersID { ProgressView().tint(.black) } else { Text("3 posters for \(extras.price(Extras.postersID))") } }
                        .font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 54).background(tint.light, in: Capsule())
                }.buttonStyle(.plain).disabled(extras.busy != nil)
            }
            if let m = extras.message { Text(m).font(.system(size: 12, weight: .medium)).foregroundStyle(tint.light) }
            Spacer(minLength: 0)
        }
        .padding(22)
        .foregroundStyle(.white)
    }

    @MainActor private func render() {
        let r = ImageRenderer(content: PosterView(kind: kind, look: look).frame(width: 300, height: 400))
        r.scale = 4
        image = r.uiImage
    }
}

struct PosterView: View {
    let kind: PosterKind
    let look: Look
    var body: some View {
        let tint = look.iris
        let last = SessionLog.shared.sessions.max { $0.start < $1.start }
        let big = kind == .today ? Ledger.today : (last?.seconds ?? 0)
        ZStack {
            Color.black
            RadialGradient(colors: [tint.dark.opacity(0.7), .clear], center: .top, startRadius: 10, endRadius: 320)
            VStack(spacing: 10) {
                StaticEyes(look: look, expression: .proud).frame(height: 130).padding(.top, 26)
                Text(kind == .today ? "TODAY I FOCUSED" : "ONE SESSION, \((last?.tag ?? "Work").uppercased())")
                    .font(.system(size: 11, weight: .semibold)).tracking(3).foregroundStyle(.white.opacity(0.55))
                Text(spoken(big)).font(.system(size: 64, weight: .ultraLight, design: .rounded)).foregroundStyle(.white)
                HStack(spacing: 18) {
                    VStack(spacing: 1) { Text("\(Ledger.streak)").font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(tint.light); Text("day streak").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5)) }
                    VStack(spacing: 1) { Text(spoken(Ledger.week.map(\.seconds).reduce(0, +))).font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(tint.light); Text("this week").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5)) }
                }
                Spacer(minLength: 0)
                Text("MINDER · FOCUS EYES").font(.system(size: 9, weight: .bold)).tracking(3).foregroundStyle(.white.opacity(0.3)).padding(.bottom, 16)
            }
        }
    }
}

/// The eyes, settled into one expression and drawn once: for posters and screenshots.
struct StaticEyes: View {
    let look: Look
    let expression: Expression
    var body: some View {
        Canvas { ctx, size in
            let b = Brain()
            b.pinned = expression
            var f = b.step(at: 0)
            for i in 1...120 { f = b.step(at: Double(i) / 60) }
            f.blink = 0
            EyesCanvas.draw(f, look: look, zoom: 1, in: &ctx, size: size)
        }
    }
}

// MARK: - Screenshot only

/// The widgets and the Live Activity on a Lock Screen, for the App Store screenshot.
struct WidgetShowcase: View {
    @State private var look = Look.shared
    var body: some View {
        let snap = FocusSnapshot(today: Ledger.today, goal: 3600, streak: Ledger.streak, week: Ledger.week, iris: look.iris, pro: true)
        ZStack {
            LinearGradient(colors: [look.iris.dark, Color(white: 0.04), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                    Text("9:41").font(.system(size: 88, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.92))
                }.padding(.top, 60)
                FocusActivityView(iris: look.iris, state: .init(start: .now.addingTimeInterval(-(23 * 60 + 14)), planned: 50, tag: "Write"))
                    .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 14)
                HStack(spacing: 16) {
                    widget(TodayWidgetView(snap: snap), w: 170, h: 170)
                    VStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in
                            HStack(spacing: 14) { ForEach(0..<2, id: \.self) { _ in RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)).frame(width: 64, height: 64) } }
                        }
                    }
                }
                widget(WeekWidgetView(snap: snap), w: 364, h: 170)
                Spacer()
            }
        }
    }
    private func widget<V: View>(_ v: V, w: CGFloat, h: CGFloat) -> some View {
        v.padding(16).frame(width: w, height: h, alignment: .topLeading)
            .background(.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}

extension View {
    /// Minder's dark glass card.
    func card() -> some View {
        background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

/// "1 day", "21 days".
func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }
