import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct MinderWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WeekWidget()
        LockWidget()
        FocusLiveActivity()
        if #available(iOS 18.0, *) {
            StartFocusControl()
        }
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snap: FocusSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, snap: Self.sample) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let s = FocusSnapshot.load()
        completion(Entry(date: .now, snap: context.isPreview && s.today == 0 ? Self.sample : s))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [Entry(date: .now, snap: FocusSnapshot.load())], policy: .after(midnight)))
    }
    static var sample: FocusSnapshot {
        FocusSnapshot(today: 52 * 60, goal: 3600, streak: 6, week: zip(["M", "T", "W", "T", "F", "S", "S"], [74, 118, 41, 130, 95, 0, 52]).map { (label: $0, seconds: Double($1) * 60) },
                      iris: IrisStyle.named(Shared.irisID), pro: true)
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: Provider()) { e in
            TodayWidgetView(snap: e.snap).containerBackground(.black, for: .widget)
                .widgetURL(URL(string: "minderfocus://start"))
        }
        .configurationDisplayName("Today")
        .description("Today's focus against your goal and your streak. Tap it to start focusing.")
        .supportedFamilies([.systemSmall])
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "week", provider: Provider()) { e in
            Group {
                if e.snap.pro { WeekWidgetView(snap: e.snap) } else { LockedWeekView(iris: e.snap.iris) }
            }
            .overlay(alignment: .topTrailing) {
                Link(destination: URL(string: "minderfocus://start")!) {
                    Image(systemName: "eye.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 30, height: 30).background(e.snap.iris.light, in: Circle())
                }
                .accessibilityLabel("Start focusing")
            }
            .containerBackground(.black, for: .widget)
            .widgetURL(URL(string: "minderfocus://focus"))
        }
        .configurationDisplayName("Week")
        .description("Your focus this week, day by day.")
        .supportedFamilies([.systemMedium])
    }
}

/// Lock Screen and StandBy: the goal ring, a line with the streak, or an inline status.
struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "lock", provider: Provider()) { e in
            LockWidgetView(snap: e.snap)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "minderfocus://start"))
        }
        .configurationDisplayName("Focus")
        .description("Today's focus and streak on your Lock Screen. Tap to start focusing.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snap: FocusSnapshot
    var body: some View {
        switch family {
        case .accessoryCircular: LockCircularView(snap: snap)
        case .accessoryRectangular: LockRectView(snap: snap)
        default: Label(lockInline(snap), systemImage: "eye.fill")
        }
    }
}

/// Control Center, the Lock Screen and the Action button: one tap starts a session.
@available(iOS 18.0, *)
struct StartFocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.mattbusel.minder.start") {
            ControlWidgetButton(action: StartFocusIntent()) {
                Label("Start focusing", systemImage: "eye.fill")
            }
        }
        .displayName("Start focusing")
        .description("Opens Minder and starts a focus session.")
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { ctx in
            FocusActivityView(iris: IrisStyle.named(ctx.attributes.irisID), state: ctx.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            let iris = IrisStyle.named(ctx.attributes.irisID)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MiniEyes(iris: iris, open: ctx.state.onBreak ? 0.15 : 1).frame(width: 50, height: 22).padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(ctx.state).font(.system(size: 24, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(iris.light).frame(width: 96)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(ctx.state.onBreak ? "On a break. The eyes are resting too." : "Focusing on \(ctx.state.tag.lowercased())" + (ctx.state.planned > 0 ? ", \(ctx.state.planned) minutes planned" : ""))
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            } compactLeading: {
                MiniEyes(iris: iris, open: ctx.state.onBreak ? 0.15 : 1).frame(width: 26, height: 12)
            } compactTrailing: {
                timer(ctx.state).monospacedDigit().foregroundStyle(iris.light).frame(width: 52)
            } minimal: {
                Image(systemName: ctx.state.onBreak ? "cup.and.saucer.fill" : "eye.fill").foregroundStyle(iris.light)
            }
        }
    }

    @ViewBuilder func timer(_ s: FocusAttributes.ContentState) -> some View {
        if s.onBreak, let end = s.breakEnds { Text(timerInterval: Date.now...max(end, Date.now), countsDown: true) }
        else { Text(s.start, style: .timer) }
    }
}
