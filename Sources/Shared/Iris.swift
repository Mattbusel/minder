import SwiftUI

struct IrisStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let light: Color
    let dark: Color
    /// Colour of the ring around the pupil. Hazel eyes are the reason this exists.
    let inner: Color

    init(_ id: String, _ name: String, light: Color, dark: Color, inner: Color? = nil) {
        self.id = id; self.name = name; self.light = light; self.dark = dark; self.inner = inner ?? light
    }

    static let all: [IrisStyle] = [
        IrisStyle("amber", "Amber", light: Color(red: 1.0, green: 0.72, blue: 0.28), dark: Color(red: 0.55, green: 0.24, blue: 0.03), inner: Color(red: 1.0, green: 0.86, blue: 0.5)),
        IrisStyle("hazel", "Hazel", light: Color(red: 0.55, green: 0.66, blue: 0.32), dark: Color(red: 0.24, green: 0.2, blue: 0.08), inner: Color(red: 0.86, green: 0.58, blue: 0.22)),
        IrisStyle("ice", "Ice", light: Color(red: 0.56, green: 0.86, blue: 1.0), dark: Color(red: 0.06, green: 0.3, blue: 0.58), inner: Color(red: 0.82, green: 0.95, blue: 1.0)),
        IrisStyle("moss", "Moss", light: Color(red: 0.55, green: 0.92, blue: 0.6), dark: Color(red: 0.05, green: 0.36, blue: 0.2), inner: Color(red: 0.86, green: 0.94, blue: 0.5)),
        IrisStyle("rose", "Rose", light: Color(red: 1.0, green: 0.6, blue: 0.74), dark: Color(red: 0.55, green: 0.1, blue: 0.3)),
        IrisStyle("violet", "Violet", light: Color(red: 0.78, green: 0.64, blue: 1.0), dark: Color(red: 0.26, green: 0.12, blue: 0.58), inner: Color(red: 0.95, green: 0.8, blue: 1.0)),
        IrisStyle("ruby", "Ruby", light: Color(red: 1.0, green: 0.36, blue: 0.3), dark: Color(red: 0.42, green: 0.02, blue: 0.04), inner: Color(red: 1.0, green: 0.7, blue: 0.4)),
        IrisStyle("silver", "Silver", light: Color(red: 0.84, green: 0.88, blue: 0.93), dark: Color(red: 0.3, green: 0.34, blue: 0.4)),
        IrisStyle("ink", "Ink", light: Color(red: 0.36, green: 0.3, blue: 0.26), dark: Color(red: 0.06, green: 0.05, blue: 0.05), inner: Color(red: 0.5, green: 0.36, blue: 0.22)),
    ]
    /// Irises that come with the 99-cent eye packs, one each.
    static let packs: [IrisStyle] = [
        IrisStyle("galaxy", "Galaxy", light: Color(red: 0.55, green: 0.45, blue: 1.0), dark: Color(red: 0.08, green: 0.04, blue: 0.3), inner: Color(red: 1.0, green: 0.55, blue: 0.85)),
        IrisStyle("gilded", "Gilded", light: Color(red: 1.0, green: 0.85, blue: 0.35), dark: Color(red: 0.45, green: 0.3, blue: 0.02), inner: Color(red: 1.0, green: 0.97, blue: 0.75)),
        IrisStyle("toxic", "Toxic", light: Color(red: 0.75, green: 1.0, blue: 0.2), dark: Color(red: 0.1, green: 0.35, blue: 0.0), inner: Color(red: 0.95, green: 1.0, blue: 0.6)),
        IrisStyle("bloodmoon", "Blood moon", light: Color(red: 1.0, green: 0.42, blue: 0.16), dark: Color(red: 0.32, green: 0.02, blue: 0.0), inner: Color(red: 1.0, green: 0.78, blue: 0.3)),
    ]
    /// Minder Plus: one new iris a month (Eye of the Month), kept while subscribed. Index 0 is January.
    static let monthly: [IrisStyle] = [
        IrisStyle("m01", "Frost", light: Color(red: 0.8, green: 0.95, blue: 1.0), dark: Color(red: 0.2, green: 0.42, blue: 0.62), inner: .white),
        IrisStyle("m02", "Valentine", light: Color(red: 1.0, green: 0.38, blue: 0.55), dark: Color(red: 0.45, green: 0.0, blue: 0.16), inner: Color(red: 1.0, green: 0.8, blue: 0.86)),
        IrisStyle("m03", "Clover", light: Color(red: 0.36, green: 0.9, blue: 0.42), dark: Color(red: 0.0, green: 0.3, blue: 0.1), inner: Color(red: 1.0, green: 0.86, blue: 0.3)),
        IrisStyle("m04", "Rainfall", light: Color(red: 0.5, green: 0.7, blue: 0.95), dark: Color(red: 0.12, green: 0.18, blue: 0.4), inner: Color(red: 0.75, green: 0.95, blue: 0.9)),
        IrisStyle("m05", "Blossom", light: Color(red: 1.0, green: 0.75, blue: 0.85), dark: Color(red: 0.5, green: 0.2, blue: 0.4), inner: Color(red: 1.0, green: 0.95, blue: 0.7)),
        IrisStyle("m06", "Sunburst", light: Color(red: 1.0, green: 0.9, blue: 0.2), dark: Color(red: 0.75, green: 0.3, blue: 0.0), inner: Color(red: 1.0, green: 1.0, blue: 0.75)),
        IrisStyle("m07", "Firework", light: Color(red: 0.4, green: 0.6, blue: 1.0), dark: Color(red: 0.55, green: 0.0, blue: 0.1), inner: Color(red: 1.0, green: 0.95, blue: 0.95)),
        IrisStyle("m08", "Lagoon", light: Color(red: 0.2, green: 0.95, blue: 0.85), dark: Color(red: 0.0, green: 0.3, blue: 0.4), inner: Color(red: 0.9, green: 1.0, blue: 0.85)),
        IrisStyle("m09", "Harvest", light: Color(red: 0.95, green: 0.65, blue: 0.25), dark: Color(red: 0.35, green: 0.15, blue: 0.05), inner: Color(red: 0.75, green: 0.8, blue: 0.3)),
        IrisStyle("m10", "Pumpkin", light: Color(red: 1.0, green: 0.55, blue: 0.0), dark: Color(red: 0.25, green: 0.05, blue: 0.0), inner: Color(red: 1.0, green: 0.92, blue: 0.3)),
        IrisStyle("m11", "Maple", light: Color(red: 0.9, green: 0.3, blue: 0.12), dark: Color(red: 0.3, green: 0.08, blue: 0.02), inner: Color(red: 1.0, green: 0.72, blue: 0.3)),
        IrisStyle("m12", "Evergreen", light: Color(red: 0.3, green: 0.75, blue: 0.45), dark: Color(red: 0.02, green: 0.18, blue: 0.1), inner: Color(red: 1.0, green: 0.3, blue: 0.3)),
    ]
    /// This month's Eye of the Month.
    static var ofTheMonth: IrisStyle { monthly[(Calendar.current.component(.month, from: .now) + 11) % 12] }
    static func named(_ id: String) -> IrisStyle { (all + packs + monthly).first { $0.id == id } ?? all[0] }
}

