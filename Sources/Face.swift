import CoreGraphics

/// The shape of one eye and its brow. Every value is a plain number so the
/// whole face can be sprung toward a target, component by component.
struct EyeShape {
    var open: CGFloat = 1        // 1 wide open, 0 shut
    var lidTilt: CGFloat = 0     // + inner corner of the upper lid drops (cross), - it lifts (sad)
    var lower: CGFloat = 0       // lower lid rise; high values make the happy ^ shape
    var browY: CGFloat = 0       // points, + raises the brow
    var browTilt: CGFloat = 0    // + inner end down (stern), - inner end up (worried)
    var browCurve: CGFloat = 0.18
    var scale: CGFloat = 1

    static let count = 7
    var values: [CGFloat] { [open, lidTilt, lower, browY, browTilt, browCurve, scale] }
    init(open: CGFloat = 1, lidTilt: CGFloat = 0, lower: CGFloat = 0, browY: CGFloat = 0,
         browTilt: CGFloat = 0, browCurve: CGFloat = 0.18, scale: CGFloat = 1) {
        self.open = open; self.lidTilt = lidTilt; self.lower = lower; self.browY = browY
        self.browTilt = browTilt; self.browCurve = browCurve; self.scale = scale
    }
    init(_ v: ArraySlice<CGFloat>) {
        let a = Array(v)
        self.init(open: a[0], lidTilt: a[1], lower: a[2], browY: a[3], browTilt: a[4], browCurve: a[5], scale: a[6])
    }
}

struct Face {
    var left = EyeShape()
    var right = EyeShape()
    var pupil: CGFloat = 1

    var values: [CGFloat] { left.values + right.values + [pupil] }
    init(left: EyeShape = EyeShape(), right: EyeShape = EyeShape(), pupil: CGFloat = 1) {
        self.left = left; self.right = right; self.pupil = pupil
    }
    init(values v: [CGFloat]) {
        left = EyeShape(v[0..<7]); right = EyeShape(v[7..<14]); pupil = v[14]
    }
    static func both(_ e: EyeShape, pupil: CGFloat = 1) -> Face { Face(left: e, right: e, pupil: pupil) }
}

enum Expression: String, CaseIterable {
    case neutral, attentive, focused, happy, proud, suspicious, stern, surprised, sleepy, sad, curious, asleep

    var face: Face {
        switch self {
        case .neutral:   return .both(EyeShape())
        case .attentive: return .both(EyeShape(browY: 6, browCurve: 0.22), pupil: 1.05)
        case .focused:   return .both(EyeShape(open: 0.84, lidTilt: 0.06, browY: -3, browTilt: 0.1, browCurve: 0.12))
        case .happy:     return .both(EyeShape(open: 1, lower: 0.34, browY: 9, browTilt: -0.08, browCurve: 0.32), pupil: 1.1)
        case .proud:     return .both(EyeShape(open: 0.8, lower: 0.4, browY: 5, browTilt: -0.14, browCurve: 0.28), pupil: 1.1)
        case .suspicious:
            return Face(left: EyeShape(open: 0.42, lidTilt: 0.12, browY: -7, browTilt: 0.26, browCurve: 0.06),
                        right: EyeShape(open: 0.78, browY: 12, browTilt: -0.18, browCurve: 0.3), pupil: 0.85)
        case .stern:     return .both(EyeShape(open: 0.66, lidTilt: 0.28, browY: -9, browTilt: 0.34, browCurve: 0.02), pupil: 0.85)
        case .surprised: return .both(EyeShape(open: 1, browY: 20, browCurve: 0.38, scale: 1.12), pupil: 0.72)
        case .sleepy:    return .both(EyeShape(open: 0.3, lidTilt: -0.12, browY: -3, browTilt: -0.12, browCurve: 0.14), pupil: 1.1)
        case .sad:       return .both(EyeShape(open: 0.78, lidTilt: -0.28, browY: 5, browTilt: -0.36, browCurve: 0.1), pupil: 1.2)
        case .curious:
            return Face(left: EyeShape(open: 1, browY: 15, browTilt: -0.1, browCurve: 0.34, scale: 1.05),
                        right: EyeShape(open: 0.86, browY: 1, browTilt: 0.06, browCurve: 0.16), pupil: 1.05)
        case .asleep:    return .both(EyeShape(open: 0, lidTilt: -0.05, browY: -4, browTilt: -0.1, browCurve: 0.12))
        }
    }
}

/// Damped springs over a fixed-length vector. Semi-implicit Euler, stable at 120 Hz.
struct SpringVector {
    var x: [CGFloat]
    var v: [CGFloat]
    init(_ start: [CGFloat]) { x = start; v = Array(repeating: 0, count: start.count) }

    mutating func step(toward target: [CGFloat], dt: CGFloat, stiffness k: CGFloat, damping ratio: CGFloat) {
        let c = 2 * sqrt(k) * ratio
        for i in x.indices {
            let a = k * (target[i] - x[i]) - c * v[i]
            v[i] += a * dt
            x[i] += v[i] * dt
        }
    }
}
