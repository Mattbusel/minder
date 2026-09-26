import SwiftUI
import Observation

enum EyeOutline: String, CaseIterable, Identifiable { case round = "Round", almond = "Almond", tall = "Tall"; var id: String { rawValue } }
enum PupilStyle: String, CaseIterable, Identifiable { case round = "Round", cat = "Cat", heart = "Heart", star = "Star"; var id: String { rawValue } }
enum BrowStyle: String, CaseIterable, Identifiable { case bold = "Bold", thin = "Thin", bushy = "Bushy", none = "None"; var id: String { rawValue } }
enum ScleraStyle: String, CaseIterable, Identifiable { case classic = "Classic", tired = "Tired", void = "Void"; var id: String { rawValue } }

/// Everything about how the eyes look. Persisted key by key in UserDefaults.
@Observable
final class Look {
    static let shared = Look()

    var irisID: String { didSet { save("iris", irisID) } }
    var secondIrisID: String { didSet { save("iris2", secondIrisID) } }
    var oddEyes: Bool { didSet { save("oddEyes", oddEyes) } }
    var outline: EyeOutline { didSet { save("outline", outline.rawValue) } }
    var pupil: PupilStyle { didSet { save("pupil", pupil.rawValue) } }
    var brow: BrowStyle { didSet { save("brow", brow.rawValue) } }
    var sclera: ScleraStyle { didSet { save("sclera", sclera.rawValue) } }
    var lashes: Bool { didSet { save("lashes", lashes) } }
    var size: Double { didSet { save("size", size) } }
    var glow: Double { didSet { save("glow", glow) } }
    var spacing: Double { didSet { save("spacing", spacing) } }

    private let d = UserDefaults.standard
    /// False for the paywall's parade of looks, which must never overwrite the user's own.
    private let persist: Bool
    private init(persist: Bool = true) {
        self.persist = persist
        irisID = d.string(forKey: "iris") ?? "amber"
        secondIrisID = d.string(forKey: "iris2") ?? "ice"
        oddEyes = d.bool(forKey: "oddEyes")
        outline = EyeOutline(rawValue: d.string(forKey: "outline") ?? "") ?? .round
        pupil = PupilStyle(rawValue: d.string(forKey: "pupil") ?? "") ?? .round
        brow = BrowStyle(rawValue: d.string(forKey: "brow") ?? "") ?? .bold
        sclera = ScleraStyle(rawValue: d.string(forKey: "sclera") ?? "") ?? .classic
        lashes = d.object(forKey: "lashes") as? Bool ?? true
        size = d.object(forKey: "size") as? Double ?? 1
        glow = d.object(forKey: "glow") as? Double ?? 0.5
        spacing = d.object(forKey: "spacing") as? Double ?? 1
    }
    private func save(_ k: String, _ v: Any) { if persist { d.set(v, forKey: k) } }
    /// A throwaway Look that starts from the user's and never saves.
    static func scratch() -> Look { Look(persist: false) }

    var iris: IrisStyle { IrisStyle.named(irisID) }
    var rightIris: IrisStyle { oddEyes ? IrisStyle.named(secondIrisID) : iris }

    struct Preset: Identifiable {
        let id: String
        let apply: (Look) -> Void
    }

    static let presets: [Preset] = [
        Preset(id: "Classic") { l in l.set("amber", .round, .round, .bold, .classic, lashes: true, glow: 0.5) },
        Preset(id: "Robot") { l in l.set("ice", .round, .round, .none, .void, lashes: false, glow: 1) },
        Preset(id: "Cat") { l in l.set("moss", .almond, .cat, .thin, .classic, lashes: true, glow: 0.6) },
        Preset(id: "Crush") { l in l.set("rose", .tall, .heart, .thin, .classic, lashes: true, glow: 0.8) },
        Preset(id: "Night owl") { l in l.set("violet", .round, .star, .bushy, .tired, lashes: false, glow: 0.4) },
        Preset(id: "Grump") { l in l.set("ink", .almond, .round, .bushy, .classic, lashes: false, glow: 0.2) },
    ]

    private func set(_ iris: String, _ o: EyeOutline, _ p: PupilStyle, _ b: BrowStyle, _ s: ScleraStyle, lashes: Bool, glow: Double) {
        irisID = iris; outline = o; pupil = p; brow = b; sclera = s; self.lashes = lashes; self.glow = glow
        oddEyes = false; size = 1; spacing = 1
    }

    func randomize() {
        irisID = IrisStyle.all.randomElement()!.id
        secondIrisID = IrisStyle.all.randomElement()!.id
        oddEyes = Double.random(in: 0...1) < 0.2
        outline = EyeOutline.allCases.randomElement()!
        pupil = [PupilStyle.round, .round, .cat, .heart, .star].randomElement()!
        brow = BrowStyle.allCases.randomElement()!
        sclera = [ScleraStyle.classic, .classic, .tired, .void].randomElement()!
        lashes = Bool.random()
        size = Double.random(in: 0.85...1.2)
        glow = Double.random(in: 0.2...1)
        spacing = Double.random(in: 0.85...1.2)
    }
}
