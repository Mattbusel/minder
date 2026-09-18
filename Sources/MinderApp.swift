import SwiftUI

@main
struct MinderApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

/// Focus minutes per day, kept as a tiny dictionary in UserDefaults.
enum Ledger {
    private static let key = "ledger.v1"
    private static var fmt: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }
    private static var all: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func add(_ seconds: Double, on day: Date = .now) {
        guard seconds >= 30 else { return }
        var a = all; a[fmt.string(from: day), default: 0] += seconds; all = a
    }
    static func seconds(on day: Date) -> Double { all[fmt.string(from: day)] ?? 0 }
    static var today: Double { seconds(on: .now) }
    static var week: [(label: String, seconds: Double)] {
        let cal = Calendar.current
        let d = DateFormatter(); d.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: .now)!
            return (d.string(from: day), seconds(on: day))
        }
    }
    static var streak: Int {
        let cal = Calendar.current
        var n = 0
        var day = Date.now
        if seconds(on: day) < 60 { day = cal.date(byAdding: .day, value: -1, to: day)! }
        while seconds(on: day) >= 60 { n += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        return n
    }
    static var total: Double { all.values.reduce(0, +) }
    static func seed() {
        let cal = Calendar.current
        let mins: [Double] = [52, 95, 0, 130, 74, 118, 41]
        var a: [String: Double] = [:]
        for (i, m) in mins.enumerated() {
            a[fmt.string(from: cal.date(byAdding: .day, value: -(6 - i), to: .now)!)] = m * 60
        }
        all = a
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
