import StoreKit
import SwiftUI

/// Minder Plus: an auto-renewable subscription (monthly, or yearly with a free week) in its own group.
/// Everything in Pro, plus while subscribed: every eye pack and the ambience pack, the Eye of the Month,
/// 3 Streak Shields and 5 poster credits each month, Insights, and iCloud backup.
/// Pro stays a one-time purchase and is never taken away from anyone.
@MainActor
@Observable
final class Plus {
    static let monthlyID = "com.mattbusel.minder.plus.monthly"
    static let yearlyID = "com.mattbusel.minder.plus.yearly"
    static let ids = [yearlyID, monthlyID]
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://tensorust.com/apps/minder/privacy/")!

    private(set) var active: Bool
    private(set) var currentID: String?
    private(set) var renews = true
    private(set) var expires: Date?
    private(set) var products: [String: Product] = [:]
    private(set) var trialEligible = true
    var busy = false
    var message: String?

    private var updates: Task<Void, Never>?
    private let forced: Bool
    private let d = UserDefaults.standard

    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { active = forced; currentID = forced ? Plus.yearlyID : nil; return }
        // Remembered so the app opens with the right features offline; StoreKit confirms right after.
        let until = d.object(forKey: "plus.until") as? Date
        active = (until ?? .distantPast) > .now
        updates = Task { [weak self] in
            for await r in Transaction.updates {
                if case .verified(let t) = r, Plus.ids.contains(t.productID) { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    var yearly: Product? { products[Plus.yearlyID] }
    var monthly: Product? { products[Plus.monthlyID] }
    func price(_ id: String) -> String {
        if let p = products[id] { return p.displayPrice }
        if forced { return id == Plus.yearlyID ? "$14.99" : "$2.99" }
        return "…"
    }

    /// The yearly plan's price spread over twelve months, in the store's currency.
    var yearlyPerMonth: String? {
        guard let y = yearly else { return forced ? "$1.25" : nil }
        return (y.price / 12).formatted(y.priceFormatStyle)
    }

    func load() async {
        guard !forced, products.count < Plus.ids.count else { return }
        if let ps = try? await Product.products(for: Plus.ids) { for p in ps { products[p.id] = p } }
        if let y = yearly, let sub = y.subscription { trialEligible = await sub.isEligibleForIntroOffer }
    }

    func refresh() async {
        guard !forced else { return }
        await load()
        var best: StoreKit.Transaction?
        for await r in Transaction.currentEntitlements {
            guard case .verified(let t) = r, Plus.ids.contains(t.productID), t.revocationDate == nil else { continue }
            if let e = t.expirationDate, e < .now { continue }
            if best == nil || (t.expirationDate ?? .distantFuture) > (best?.expirationDate ?? .distantPast) { best = t }
        }
        if let best {
            active = true
            currentID = best.productID
            expires = best.expirationDate
            d.set(best.expirationDate ?? Date.now.addingTimeInterval(86_400 * 31), forKey: "plus.until")
            if let p = products[best.productID], let statuses = try? await p.subscription?.status {
                for s in statuses {
                    if case .verified(let info) = s.renewalInfo, info.currentProductID == best.productID { renews = info.willAutoRenew }
                }
            }
        } else {
            active = false
            currentID = nil
            expires = nil
            d.removeObject(forKey: "plus.until")
        }
    }

    func buy(_ id: String) async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        await load()
        guard let p = products[id] else { message = "The App Store did not answer. Check your connection and try again."; return }
        do {
            switch try await p.purchase() {
            case .success(let r):
                if case .verified(let t) = r { await t.finish() }
                await refresh()
                if active { Haptics.success() } else { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending: message = "Waiting for approval. Plus starts by itself once it is approved."
            case .userCancelled: break
            @unknown default: message = "Something unexpected happened. You were not charged."
            }
        } catch { message = "The purchase did not go through: \(error.localizedDescription)" }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = active ? "Minder Plus is active. Welcome back." : "No active Minder Plus subscription on this Apple ID."
    }

    /// Plus refills: 3 Streak Shields and 5 poster credits at the start of each month you are subscribed.
    func refill(_ extras: Extras) -> Bool {
        guard active, !forced else { return false }
        let m = Extras.month
        guard d.string(forKey: "plus.refill") != m else { return false }
        d.set(m, forKey: "plus.refill")
        extras.shields += 3
        extras.posters += 5
        return true
    }

    /// Every Eye of the Month a subscriber has been around for. This month's is always in.
    var collected: [IrisStyle] {
        var have = Set(d.stringArray(forKey: "plus.eyes") ?? [])
        have.insert(IrisStyle.ofTheMonth.id)
        return IrisStyle.monthly.filter { have.contains($0.id) }
    }
    func collect() {
        guard active else { return }
        var have = Set(d.stringArray(forKey: "plus.eyes") ?? [])
        have.insert(IrisStyle.ofTheMonth.id)
        d.set(Array(have), forKey: "plus.eyes")
    }
}

// MARK: - The month: a challenge for everyone, an Eye of the Month for Plus

struct Challenge {
    enum Kind { case days, hours, long, streak }
    let kind: Kind
    let target: Int
    let title: String
    let detail: String

    static func current(_ date: Date = .now) -> Challenge {
        let m = Calendar.current.component(.month, from: date)
        let list: [Challenge] = [
            .init(kind: .days, target: 15, title: "Fifteen days", detail: "Focus on 15 different days this month."),
            .init(kind: .hours, target: 15, title: "Fifteen hours", detail: "Log 15 hours of focus this month."),
            .init(kind: .long, target: 8, title: "Eight deep ones", detail: "Eight sessions of 50 minutes or more."),
            .init(kind: .streak, target: 7, title: "A full week", detail: "Reach a 7-day streak this month."),
            .init(kind: .days, target: 18, title: "Eighteen days", detail: "Focus on 18 different days this month."),
            .init(kind: .hours, target: 20, title: "Twenty hours", detail: "Log 20 hours of focus this month."),
            .init(kind: .long, target: 10, title: "Ten deep ones", detail: "Ten sessions of 50 minutes or more."),
            .init(kind: .streak, target: 10, title: "Ten in a row", detail: "Reach a 10-day streak this month."),
            .init(kind: .days, target: 20, title: "Twenty days", detail: "Focus on 20 different days this month."),
            .init(kind: .hours, target: 25, title: "Twenty-five hours", detail: "Log 25 hours of focus this month."),
            .init(kind: .long, target: 12, title: "Twelve deep ones", detail: "Twelve sessions of 50 minutes or more."),
            .init(kind: .streak, target: 14, title: "Two weeks straight", detail: "Reach a 14-day streak this month."),
        ]
        return list[(m + 11) % 12]
    }

    /// Progress this month, in the challenge's own unit.
    func progress(_ date: Date = .now) -> Int {
        let cal = Calendar.current
        let prefix = String(Ledger.key(date).prefix(7))
        switch kind {
        case .days: return Ledger.all.filter { $0.key.hasPrefix(prefix) && $0.value >= 60 }.count
        case .hours: return Int(Ledger.all.filter { $0.key.hasPrefix(prefix) }.values.reduce(0, +) / 3600)
        case .long: return SessionLog.shared.sessions.filter { cal.isDate($0.start, equalTo: date, toGranularity: .month) && $0.seconds >= 50 * 60 }.count
        case .streak: return Ledger.streak
        }
    }
    var unit: String {
        switch kind { case .days: return "days"; case .hours: return "hours"; case .long: return "sessions"; case .streak: return "day streak" }
    }
    var fraction: Double { min(1, Double(progress()) / Double(target)) }
    var done: Bool { progress() >= target }
}

struct MonthSheet: View {
    @Environment(Plus.self) private var plus
    @Environment(\.dismiss) private var dismiss
    @State private var look = Look.shared
    @State private var paywall = false
    @State private var brain = Brain()

    var body: some View {
        let c = Challenge.current()
        let tint = look.iris
        let eye = IrisStyle.ofTheMonth
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(Date.now.formatted(.dateTime.month(.wide))).font(.system(size: 32, weight: .semibold, design: .rounded))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                    }.accessibilityLabel("Close")
                }

                // The challenge, for everyone.
                VStack(alignment: .leading, spacing: 14) {
                    Text("THIS MONTH'S CHALLENGE").font(.system(size: 12, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.45))
                    HStack(spacing: 18) {
                        ZStack {
                            GoalRing(fraction: c.fraction, tint: tint, width: 9)
                            Image(systemName: c.done ? "trophy.fill" : "flag.checkered")
                                .font(.system(size: 26, weight: .medium)).foregroundStyle(tint.light)
                                .symbolEffect(.bounce, value: c.done)
                        }.frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.title).font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text(c.detail).font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                            Text(c.done ? "Done. Nicely watched." : "\(min(c.progress(), c.target)) of \(c.target) \(c.unit)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(tint.light).padding(.top, 2)
                        }
                    }
                }
                .padding(18).card()

                // The Eye of the Month, for Plus.
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("EYE OF THE MONTH").font(.system(size: 12, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        PlusBadge(tint: eye)
                    }
                    ZStack {
                        RadialGradient(colors: [eye.dark.opacity(0.7), .clear], center: .center, startRadius: 4, endRadius: 200)
                        PreviewEyes(irisID: eye.id, zoom: 2.3).frame(height: 160)
                    }.frame(height: 170)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eye.name).font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text("A new look every month while you have Plus. Collected ones stay in your set.")
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Button {
                            if plus.active { Haptics.success(); withAnimation(.spring(duration: 0.4)) { Look.monthPreset(eye.id)?.apply(look) } } else { paywall = true }
                        } label: {
                            Text(plus.active ? (look.irisID == eye.id ? "On" : "Use") : "Get Plus").font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black).padding(.horizontal, 18).frame(height: 40).background(eye.light, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                    if plus.active && plus.collected.count > 1 {
                        Text("YOUR COLLECTION").font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(.white.opacity(0.4)).padding(.top, 4)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(plus.collected) { s in
                                    Button { Haptics.tap(); withAnimation(.spring(duration: 0.4)) { Look.monthPreset(s.id)?.apply(look) } } label: {
                                        VStack(spacing: 6) {
                                            IrisSwatch(style: s).frame(width: 38, height: 38)
                                                .overlay(Circle().strokeBorder(.white, lineWidth: look.irisID == s.id ? 2.5 : 0).padding(-4))
                                            Text(s.name).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                                        }
                                    }.buttonStyle(.plain).accessibilityLabel("\(s.name) eyes")
                                }
                            }.padding(.vertical, 6).padding(.horizontal, 4)
                        }
                    }
                }
                .padding(18).card()
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $paywall) { PaywallView(reason: .month).presentationBackground(.black).presentationCornerRadius(34) }
    }
}

/// The eyes wearing a given month's look without touching the user's own.
struct PreviewEyes: View {
    let irisID: String
    var zoom: CGFloat = 1.4
    @State private var look = Look.scratch()
    @State private var brain = Brain()
    var body: some View {
        EyesCanvas(brain: brain, look: look, zoom: zoom)
            .allowsHitTesting(false)
            .onAppear { (Look.monthPreset(irisID) ?? Look.packPreset(irisID))?.apply(look) }
    }
}

struct PlusBadge: View {
    let tint: IrisStyle
    var body: some View {
        Text("PLUS").font(.system(size: 10, weight: .heavy)).tracking(1.2).foregroundStyle(.black)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(LinearGradient(colors: [tint.inner, tint.light], startPoint: .leading, endPoint: .trailing), in: Capsule())
    }
}

// MARK: - Insights (Plus)

struct InsightsCard: View {
    @Environment(Plus.self) private var plus
    let tint: IrisStyle
    var ask: () -> Void
    @State private var log = SessionLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("INSIGHTS").font(.system(size: 12, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.4))
                Spacer()
                PlusBadge(tint: tint)
            }
            content
                .padding(18).card()
                .blur(radius: plus.active ? 0 : 7)
                .allowsHitTesting(plus.active)
                .accessibilityHidden(!plus.active)
                .overlay {
                    if !plus.active {
                        VStack(spacing: 10) {
                            Text("When do you focus best?").font(.system(size: 17, weight: .semibold, design: .rounded))
                            Button(action: ask) {
                                Text("See Minder Plus").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                                    .padding(.horizontal, 20).frame(height: 42).background(tint.light, in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
        }
    }

    private var content: some View {
        let hours = Insights.byHour(log.sessions)
        let peak = max(hours.max() ?? 1, 1)
        let best = Insights.bestWindow(hours)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your best hours").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                Text(Insights.windowLabel(best))
                    .font(.system(size: 22, weight: .light, design: .rounded)).foregroundStyle(tint.light)
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 2).fill(barColour(h, best: best, hours: hours))
                        .frame(height: barHeight(hours[h], peak: peak))
                }
            }
            .frame(height: 64, alignment: .bottom)
            .accessibilityElement().accessibilityLabel("Focus by hour of day")
            HStack {
                ForEach(["12a", "6a", "12p", "6p"], id: \.self) { t in Text(t).frame(maxWidth: .infinity, alignment: .leading) }
            }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.35))

            HStack {
                stat(Insights.average(log.sessions), "average session")
                stat(Insights.pickupsPerHour(log.sessions), "pick-ups an hour")
                stat(Insights.bestDay(log.sessions), "strongest day")
            }
            MonthGrid(tint: tint)
        }
    }

    private func barColour(_ h: Int, best: Int?, hours: [Double]) -> Color {
        if let b = best, (h - b + 24) % 24 < 3 { return tint.light }
        return Color.white.opacity(hours[h] > 0 ? 0.25 : 0.07)
    }
    private func barHeight(_ v: Double, peak: Double) -> CGFloat {
        let x: Double = 64 * v / peak
        return CGFloat(max(3, x))
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 19, weight: .light, design: .rounded))
            Text(l).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.45))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum Insights {
    /// Focus seconds by the hour each session started, the last 8 weeks.
    static func byHour(_ s: [Session]) -> [Double] {
        var h = Array(repeating: 0.0, count: 24)
        let since = Date.now.addingTimeInterval(-56 * 86_400)
        let cal = Calendar.current
        for x in s where x.start >= since { h[cal.component(.hour, from: x.start)] += x.seconds }
        return h
    }
    /// The start of the strongest three-hour window.
    static func bestWindow(_ h: [Double]) -> Int? {
        let total: Double = h.reduce(0, +)
        guard total > 0 else { return nil }
        var best = 0
        var bestSum: Double = -1
        for start in 0..<24 {
            let sum: Double = h[start % 24] + h[(start + 1) % 24] + h[(start + 2) % 24]
            if sum > bestSum { bestSum = sum; best = start }
        }
        return best
    }
    static func windowLabel(_ best: Int?) -> String {
        guard let b = best else { return "Focus a few times to see" }
        let from: String = hourLabel(b)
        let to: String = hourLabel((b + 3) % 24)
        return "\(from) to \(to)"
    }
    static func hourLabel(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h
        let d = Calendar.current.date(from: c) ?? .now
        return d.formatted(.dateTime.hour())
    }
    static func average(_ s: [Session]) -> String {
        guard !s.isEmpty else { return "–" }
        return spoken(s.map(\.seconds).reduce(0, +) / Double(s.count))
    }
    static func pickupsPerHour(_ s: [Session]) -> String {
        let secs = s.map(\.seconds).reduce(0, +)
        guard secs > 600 else { return "–" }
        return String(format: "%.1f", Double(s.map(\.pickups).reduce(0, +)) / (secs / 3600))
    }
    static func bestDay(_ s: [Session]) -> String {
        guard !s.isEmpty else { return "–" }
        let cal = Calendar.current
        var t: [Int: Double] = [:]
        for x in s { t[cal.component(.weekday, from: x.start), default: 0] += x.seconds }
        guard let w = t.max(by: { $0.value < $1.value })?.key else { return "–" }
        return cal.weekdaySymbols[w - 1]
    }
}

/// This month as a calendar, each day lit by how close it came to the goal.
struct MonthGrid: View {
    let tint: IrisStyle
    static func colour(seconds v: Double, goal: Double, shielded: Bool, tint: IrisStyle) -> Color {
        if shielded { return Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.6) }
        if v >= goal { return tint.light }
        if v > 0 {
            let f: Double = min(1, v / goal)
            return tint.light.opacity(0.2 + 0.5 * f)
        }
        return Color.white.opacity(0.06)
    }
    static func label(_ met: Bool) -> Color { met ? Color.black.opacity(0.6) : Color.white.opacity(0.4) }
    var body: some View {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now))!
        let count = cal.range(of: .day, in: .month, for: .now)?.count ?? 30
        let lead = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        let goal = Double(Shared.goalMinutes) * 60
        let shielded = Ledger.shielded
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.month(.wide))).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.45))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(0..<(lead + count), id: \.self) { i in
                    if i < lead { Color.clear.frame(height: 26) } else {
                        let day: Date = cal.date(byAdding: .day, value: i - lead, to: start)!
                        let v: Double = Ledger.seconds(on: day)
                        let sh: Bool = shielded.contains(Ledger.key(day))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(MonthGrid.colour(seconds: v, goal: goal, shielded: sh, tint: tint))
                            .frame(height: 26)
                            .overlay(Text("\(i - lead + 1)").font(.system(size: 10, weight: .semibold)).foregroundStyle(MonthGrid.label(v >= goal)))
                    }
                }
            }
        }
    }
}

// MARK: - iCloud backup (Plus)

/// Focus history mirrored to the user's own iCloud key-value store, merged both ways.
/// Nothing goes anywhere but the user's iCloud account.
enum CloudBackup {
    static var store: NSUbiquitousKeyValueStore { .default }

    static func push() {
        store.set(Ledger.all, forKey: "ledger")
        store.set(Array(Ledger.shielded), forKey: "shielded")
        let recent = SessionLog.shared.sessions.sorted { $0.start > $1.start }.prefix(3000)
        if let data = try? JSONEncoder().encode(Array(recent)) { store.set(data, forKey: "sessions") }
        store.set(Shared.goalMinutes, forKey: "goal")
        store.set(Date.now, forKey: "updated")
        store.synchronize()
    }

    /// Merge what iCloud has into this phone: the larger minutes per day, every shield, every session.
    @discardableResult
    static func pull() -> Bool {
        store.synchronize()
        var changed = false
        if let remote = store.dictionary(forKey: "ledger") as? [String: Double] {
            var mine = Ledger.all
            for (k, v) in remote where v > (mine[k] ?? 0) { mine[k] = v; changed = true }
            if changed { Ledger.all = mine }
        }
        if let sh = store.array(forKey: "shielded") as? [String] {
            let merged = Ledger.shielded.union(sh)
            if merged.count != Ledger.shielded.count { Ledger.shielded = merged; changed = true }
        }
        if let data = store.data(forKey: "sessions"), let remote = try? JSONDecoder().decode([Session].self, from: data) {
            if SessionLog.shared.merge(remote) { changed = true }
        }
        return changed
    }

    static var lastBackup: Date? { store.object(forKey: "updated") as? Date }
}
