import ActivityKit
import Foundation

/// The app group, so the widgets see the same minutes the app counts.
enum Shared {
    static let group = "group.com.mattbusel.minder"
    static let defaults = UserDefaults(suiteName: group) ?? .standard
    static var container: URL { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) ?? URL.documentsDirectory }
    /// Mirrored by the app for the widgets.
    static var irisID: String {
        get { defaults.string(forKey: "iris") ?? "amber" }
        set { defaults.set(newValue, forKey: "iris") }
    }
    static var pro: Bool {
        get { defaults.bool(forKey: "pro") }
        set { defaults.set(newValue, forKey: "pro") }
    }
    static var goalMinutes: Int {
        get { defaults.object(forKey: "goalMinutes") as? Int ?? 60 }
        set { defaults.set(newValue, forKey: "goalMinutes") }
    }
}

/// Focus minutes per day, a tiny dictionary. 1.1 kept it in the app's own defaults; 1.2 moves
/// it to the app group (copied once, never dropped) so the widgets can read it.
enum Ledger {
    private static let key = "ledger.v1"
    private static let shieldKey = "ledger.shielded"
    static var store: UserDefaults { Shared.defaults }
    static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    static func key(_ d: Date) -> String { fmt.string(from: d) }

    static func migrate() {
        guard store.object(forKey: key) == nil, let old = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] else { return }
        store.set(old, forKey: key)
    }

    static var all: [String: Double] {
        get { store.dictionary(forKey: key) as? [String: Double] ?? [:] }
        set { store.set(newValue, forKey: key) }
    }
    /// Days a Streak Shield covered: the streak holds over them without counting them.
    static var shielded: Set<String> {
        get { Set(store.stringArray(forKey: shieldKey) ?? []) }
        set { store.set(Array(newValue), forKey: shieldKey) }
    }
    static func add(_ seconds: Double, on day: Date = .now) {
        guard seconds >= 30 else { return }
        var a = all; a[key(day), default: 0] += seconds; all = a
    }
    static func seconds(on day: Date) -> Double { all[key(day)] ?? 0 }
    static var today: Double { seconds(on: .now) }
    static var week: [(label: String, seconds: Double)] {
        let cal = Calendar.current
        let d = DateFormatter(); d.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: .now)!
            return (d.string(from: day), seconds(on: day))
        }
    }
    static func counts(_ day: Date) -> Bool { seconds(on: day) >= 60 }
    /// Consecutive days with at least a minute of focus. A shielded day keeps it going.
    static var streak: Int { streak(endingBefore: nil) }
    static func streak(endingBefore end: Date?) -> Int {
        let cal = Calendar.current
        var n = 0
        var day = end.map { cal.date(byAdding: .day, value: -1, to: $0)! } ?? Date.now
        if end == nil && !counts(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        let sh = shielded
        while counts(day) || sh.contains(key(day)) {
            if counts(day) { n += 1 }
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }
    static var best: Int {
        let keys = Set(all.filter { $0.value >= 60 }.keys).union(shielded).sorted()
        var b = 0, run = 0; var prev: Date?
        for k in keys {
            guard let d = fmt.date(from: k) else { continue }
            let real = (all[k] ?? 0) >= 60 ? 1 : 0
            if let p = prev, Calendar.current.dateComponents([.day], from: p, to: d).day == 1 { run += real } else { run = real }
            b = max(b, run)
            prev = d
        }
        return b
    }
    static var total: Double { all.values.reduce(0, +) }
    /// A streak that broke yesterday and is worth saving: (the missed day, the days it would keep).
    static var rescue: (day: Date, kept: Int)? {
        let cal = Calendar.current
        let y = cal.date(byAdding: .day, value: -1, to: .now)!
        guard !counts(y), !shielded.contains(key(y)) else { return nil }
        let kept = streak(endingBefore: y)
        return kept >= 2 ? (y, kept) : nil
    }
    static func seed() {
        let cal = Calendar.current
        var a: [String: Double] = [:]
        // Twelve weeks of history for the store screenshots, the last week a strong one.
        for back in 0..<84 {
            let m: Double = back < 7 ? [74, 118, 41, 130, 95, 52, 88][back] : (back % 9 == 4 ? 0 : Double((back * 37) % 110 + 20))
            a[key(cal.date(byAdding: .day, value: -back, to: .now)!)] = m * 60
        }
        all = a
        shielded = [key(cal.date(byAdding: .day, value: -13, to: .now)!)]
    }
}

func clock(_ seconds: Double) -> String {
    let s = Int(seconds)
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%02d:%02d", s / 60, s % 60)
}

func spoken(_ seconds: Double) -> String {
    let m = Int(seconds / 60)
    if m < 60 { return "\(m)m" }
    return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
}

/// The Lock Screen and Dynamic Island timer while a session runs.
struct FocusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var planned: Int        // minutes, 0 = open-ended
        var tag: String
        var onBreak: Bool = false
        var breakEnds: Date? = nil
    }
    var irisID: String
}
