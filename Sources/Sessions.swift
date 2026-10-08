import ActivityKit
import AppIntents
import AVFoundation
import SwiftUI
import UserNotifications
import WidgetKit

/// One stretch of focus. 1.2 starts keeping these; earlier days only exist as minutes in the Ledger.
struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Date
    var seconds: Double
    var tag: String
    var planned: Int = 0
    var pickups: Int = 0

    init(start: Date, seconds: Double, tag: String, planned: Int, pickups: Int) {
        self.start = start; self.seconds = seconds; self.tag = tag; self.planned = planned; self.pickups = pickups
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        start = try c.decode(Date.self, forKey: .start)
        seconds = try c.decodeIfPresent(Double.self, forKey: .seconds) ?? 0
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? "Work"
        planned = try c.decodeIfPresent(Int.self, forKey: .planned) ?? 0
        pickups = try c.decodeIfPresent(Int.self, forKey: .pickups) ?? 0
    }
}

@Observable
final class SessionLog {
    static let shared = SessionLog()
    private(set) var sessions: [Session] = []
    private var url: URL { Shared.container.appending(path: "sessions.json") }
    static let builtInTags = ["Work", "Study", "Read", "Write", "Create"]

    init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode([Session].self, from: d) { sessions = s }
    }
    func add(_ s: Session) {
        guard s.seconds >= 30 else { return }
        sessions.append(s)
        save()
    }
    private func save() {
        if let d = try? JSONEncoder().encode(sessions) { try? d.write(to: url, options: .atomic) }
    }
    var customTags: [String] {
        get { UserDefaults.standard.stringArray(forKey: "customTags") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "customTags") }
    }
    var tags: [String] { SessionLog.builtInTags + customTags }
    func byTag(since: Date) -> [(String, Double)] {
        var t: [String: Double] = [:]
        for s in sessions where s.start >= since { t[s.tag, default: 0] += s.seconds }
        return t.sorted { $0.value > $1.value }
    }
    var longest: Session? { sessions.max { $0.seconds < $1.seconds } }
    func csv() -> String {
        let f = ISO8601DateFormatter()
        var rows = ["start,minutes,tag,planned_minutes,pickups"]
        for s in sessions.sorted(by: { $0.start < $1.start }) {
            rows.append("\(f.string(from: s.start)),\(Int((s.seconds / 60).rounded())),\"\(s.tag)\",\(s.planned),\(s.pickups)")
        }
        rows.append("")
        rows.append("date,minutes")
        for (k, v) in Ledger.all.sorted(by: { $0.key < $1.key }) { rows.append("\(k),\(Int((v / 60).rounded()))") }
        return rows.joined(separator: "\n")
    }
    func seed() {
        let cal = Calendar.current
        let tags = ["Work", "Study", "Work", "Read", "Write", "Work", "Create"]
        sessions = (0..<40).map { i in
            let d = cal.date(byAdding: .hour, value: -i * 9, to: .now)!
            return Session(start: d, seconds: Double(25 + (i * 17) % 70) * 60, tag: tags[i % tags.count], planned: [25, 50, 0][i % 3], pickups: i % 4)
        }
    }
}

/// Keeps the Live Activity in step with the session.
enum FocusActivity {
    static var current: Activity<FocusAttributes>? { Activity<FocusAttributes>.activities.first }
    static func start(at start: Date, planned: Int, tag: String, iris: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let state = FocusAttributes.ContentState(start: start, planned: planned, tag: tag)
        _ = try? Activity.request(attributes: FocusAttributes(irisID: iris), content: .init(state: state, staleDate: nil))
    }
    static func onBreak(until end: Date, iris: String) {
        let state = FocusAttributes.ContentState(start: .now, planned: 0, tag: "Break", onBreak: true, breakEnds: end)
        if let a = current {
            Task { await a.update(.init(state: state, staleDate: end.addingTimeInterval(60))) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: FocusAttributes(irisID: iris), content: .init(state: state, staleDate: end.addingTimeInterval(60)))
        }
    }
    static func end() {
        for a in Activity<FocusAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}

/// Everything the widgets need, pushed to the app group whenever it changes.
enum WidgetMirror {
    static func push(pro: Bool, iris: String) {
        Shared.pro = pro
        Shared.irisID = iris
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// "Start focus in Minder": opens the app and starts a session.
struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start focusing"
    static var description = IntentDescription("Opens Minder and starts a focus session.")
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "pendingStart")
        await MainActor.run { NotificationCenter.default.post(name: .minderStartFocus, object: nil) }
        return .result()
    }
}

struct MinderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartFocusIntent(), phrases: ["Start focusing in \(.applicationName)", "Focus with \(.applicationName)"],
                    shortTitle: "Start focusing", systemImageName: "eye.fill")
    }
}

extension Notification.Name { static let minderStartFocus = Notification.Name("minderStartFocus") }

enum BreakAlarm {
    static func schedule(at end: Date) {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "Break's over"
            content.body = "The eyes are awake. Ready for another one?"
            content.sound = .default
            c.add(UNNotificationRequest(identifier: "minder-break", content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)))
        }
    }
    static func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["minder-break"]) }
}

// MARK: Sound

/// Background sound made on the phone, sample by sample. No recordings, nothing downloaded.
enum Ambience: String, CaseIterable, Identifiable {
    case off, brown, pink, ocean, rain, fire
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .brown: return "Brown noise"
        case .pink: return "Pink noise"
        case .ocean: return "Ocean"
        case .rain: return "Rain"
        case .fire: return "Fireplace"
        }
    }
    var icon: String {
        switch self {
        case .off: return "speaker.slash"
        case .brown: return "waveform"
        case .pink: return "waveform.path"
        case .ocean: return "water.waves"
        case .rain: return "cloud.rain"
        case .fire: return "flame"
        }
    }
    /// free: off and brown. Pro: pink and ocean. The ambience pack: rain and fire.
    enum Tier { case free, pro, pack }
    var tier: Tier {
        switch self {
        case .off, .brown: return .free
        case .pink, .ocean: return .pro
        case .rain, .fire: return .pack
        }
    }
}

final class SoundEngine {
    static let shared = SoundEngine()
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private(set) var playing: Ambience = .off
    var volume: Float = 0.5 { didSet { engine.mainMixerNode.outputVolume = volume } }

    func play(_ a: Ambience) {
        stop()
        guard a != .off else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let format = engine.outputNode.inputFormat(forBus: 0)
        let rate = format.sampleRate > 0 ? format.sampleRate : 44_100
        var gen = Generator(kind: a, rate: rate)
        let n = AVAudioSourceNode { _, _, frames, list -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(list)
            for f in 0..<Int(frames) {
                let v = gen.next()
                for buf in abl { buf.mData?.assumingMemoryBound(to: Float.self)[f] = v }
            }
            return noErr
        }
        let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
        engine.attach(n)
        engine.connect(n, to: engine.mainMixerNode, format: mono)
        engine.mainMixerNode.outputVolume = volume
        node = n
        try? engine.start()
        playing = a
    }

    func stop() {
        engine.stop()
        if let node { engine.detach(node) }
        node = nil
        playing = .off
    }

    /// The sample maker. White noise shaped into brown, pink, swells, drops and crackles.
    struct Generator {
        let kind: Ambience
        let rate: Double
        var seed: UInt32 = 0x9E3779B9
        var brown: Float = 0
        var p: (Float, Float, Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0, 0, 0)
        var t: Double = 0
        var drop: Float = 0
        var crackle: Float = 0
        var low: Float = 0

        mutating func white() -> Float {
            seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
            return Float(seed) / Float(UInt32.max) * 2 - 1
        }
        mutating func brownNext() -> Float {
            brown = (brown + 0.02 * white()) / 1.02
            return brown * 3.5
        }
        mutating func pinkNext() -> Float {
            // Paul Kellet's refined pink filter.
            let w = white()
            p.0 = 0.99886 * p.0 + w * 0.0555179; p.1 = 0.99332 * p.1 + w * 0.0750759
            p.2 = 0.96900 * p.2 + w * 0.1538520; p.3 = 0.86650 * p.3 + w * 0.3104856
            p.4 = 0.55000 * p.4 + w * 0.5329522; p.5 = -0.7616 * p.5 - w * 0.0168980
            let out = p.0 + p.1 + p.2 + p.3 + p.4 + p.5 + p.6 + w * 0.5362
            p.6 = w * 0.115926
            return out * 0.11
        }
        mutating func next() -> Float {
            t += 1 / rate
            switch kind {
            case .off: return 0
            case .brown: return brownNext() * 0.8
            case .pink: return pinkNext()
            case .ocean:
                let swell = Float(0.35 + 0.65 * pow(sin(t * 2 * .pi / 9.0) * 0.5 + 0.5, 2))
                return brownNext() * swell
            case .rain:
                let bed = pinkNext() * 0.45
                if white() > 0.9993 { drop = 0.6 + 0.4 * abs(white()) }
                drop *= 0.996
                let hp = white() - low; low += (white() - low) * 0.3
                return bed + hp * drop * 0.35
            case .fire:
                let rumble = brownNext() * 0.7
                if white() > 0.99985 { crackle = 1 }
                crackle *= 0.985
                return rumble + white() * crackle * 0.5
            }
        }
    }
}
