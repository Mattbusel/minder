import SwiftUI

/// Two small drawn eyes, for places the full Canvas eyes can't go (widgets, Live Activities).
struct MiniEyes: View {
    let iris: IrisStyle
    var open: CGFloat = 1
    var look: CGPoint = .zero
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { _ in
                GeometryReader { g in
                    let w = g.size.width, h = g.size.height
                    ZStack {
                        Ellipse().fill(Color(white: 0.93))
                        Circle()
                            .fill(RadialGradient(colors: [iris.inner, iris.light, iris.dark], center: .center, startRadius: 0, endRadius: w * 0.3))
                            .frame(width: w * 0.58, height: w * 0.58)
                            .overlay(Circle().fill(.black).frame(width: w * 0.26, height: w * 0.26))
                            .overlay(Circle().fill(.white).frame(width: w * 0.12, height: w * 0.12).offset(x: -w * 0.08, y: -w * 0.08))
                            .offset(x: look.x * w * 0.14, y: h * 0.06 + look.y * h * 0.1)
                    }
                    .clipShape(Ellipse())
                    .mask(alignment: .bottom) { Rectangle().frame(height: h * max(0.08, open)) }
                }
            }
        }
    }
}

/// What the widgets show, read straight from the shared ledger.
struct FocusSnapshot {
    var today: Double
    var goal: Double
    var streak: Int
    var week: [(label: String, seconds: Double)]
    var iris: IrisStyle
    var pro: Bool
    var fraction: Double { goal > 0 ? min(1, today / goal) : 0 }

    static func load() -> FocusSnapshot {
        FocusSnapshot(today: Ledger.today, goal: Double(Shared.goalMinutes) * 60, streak: Ledger.streak, week: Ledger.week,
                      iris: IrisStyle.named(Shared.irisID), pro: Shared.pro)
    }
}

struct GoalRing: View {
    let fraction: Double
    let tint: IrisStyle
    var width: CGFloat = 6
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: width)
            Circle().trim(from: 0, to: fraction)
                .stroke(AngularGradient(colors: [tint.dark, tint.light, tint.inner], center: .center), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Small: today's focus against the goal, the streak, and the eyes.
struct TodayWidgetView: View {
    let snap: FocusSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    GoalRing(fraction: snap.fraction, tint: snap.iris, width: 5)
                    MiniEyes(iris: snap.iris, open: snap.fraction >= 1 ? 0.75 : 1).frame(width: 30, height: 14)
                }.frame(width: 50, height: 50)
                Spacer()
                if snap.streak > 0 {
                    Label("\(snap.streak)", systemImage: "flame.fill").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(snap.iris.light)
                }
            }
            Spacer(minLength: 0)
            Text(spoken(snap.today)).font(.system(size: 28, weight: .light, design: .rounded)).foregroundStyle(.white).minimumScaleFactor(0.7)
            Text(snap.fraction >= 1 ? "Goal done today" : "of \(spoken(snap.goal)) today").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
        }
    }
}

/// Medium: the week, bar by bar.
struct WeekWidgetView: View {
    let snap: FocusSnapshot
    var body: some View {
        let peak = max(snap.week.map(\.seconds).max() ?? 1, snap.goal, 1800)
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                MiniEyes(iris: snap.iris).frame(width: 46, height: 20)
                Spacer(minLength: 0)
                Text(spoken(snap.week.map(\.seconds).reduce(0, +))).font(.system(size: 26, weight: .light, design: .rounded)).foregroundStyle(.white)
                Text("this week").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                if snap.streak > 0 { Label("\(snap.streak) days", systemImage: "flame.fill").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(snap.iris.light) }
            }
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(snap.week.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(i == 6 ? AnyShapeStyle(LinearGradient(colors: [snap.iris.light, snap.iris.dark], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(d.seconds >= snap.goal ? 0.4 : d.seconds > 0 ? 0.2 : 0.07)))
                            .frame(height: max(4, 90 * d.seconds / peak))
                        Text(d.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(i == 6 ? 0.9 : 0.35))
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct LockedWeekView: View {
    let iris: IrisStyle
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MiniEyes(iris: iris, open: 0.4).frame(width: 46, height: 20)
            Text("Minder Pro").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Text("Your week, bar by bar, comes with Pro. The Today widget is free.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The Live Activity on the Lock Screen.
struct FocusActivityView: View {
    let iris: IrisStyle
    let state: FocusAttributes.ContentState
    var body: some View {
        HStack(spacing: 14) {
            MiniEyes(iris: iris, open: state.onBreak ? 0.15 : 1).frame(width: 56, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.onBreak ? "ON A BREAK" : "FOCUSING · \(state.tag.uppercased())").font(.system(size: 11, weight: .semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.5))
                if state.onBreak, let end = state.breakEnds {
                    Text(timerInterval: Date.now...max(end, Date.now), countsDown: true).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                } else {
                    Text(state.start, style: .timer).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                }
                if state.planned > 0 && !state.onBreak {
                    ProgressView(timerInterval: state.start...state.start.addingTimeInterval(Double(state.planned) * 60), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.linear).tint(iris.light)
                    Text("\(state.planned)-minute plan").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
