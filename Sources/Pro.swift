import SwiftUI
import StoreKit

/// Minder Pro: one non-consumable. The eyes, slide to focus, the timer, the week, the check-in
/// and the pick-up suspicion are free forever; Pro is the eye designer (every look and knob)
/// and Follow my face.
///
/// Everyone who installed a build from before Pro existed keeps everything: they paid for it.
/// AppTransaction's originalAppVersion is the build number they first installed. Only trusted in
/// production: sandbox and Xcode report made-up values, and App Review must see the real paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.minder.pro"
    /// The first build with Pro in it. Anything earlier was the paid app with every feature.
    static let firstFreemiumBuild = 2
    /// Looks anyone can pick. The rest of the presets, the dice and every knob are Pro.
    static let freePresets: Set<String> = ["Classic", "Robot", "Cat"]

    enum Reason: String, Identifiable { case designer, face, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "minder.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$2.99" }

    func ask(_ why: Reason) { if !unlocked { paywall = why } }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
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
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall

/// Black glass, a pair of eyes trying on every look, one price.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var look = Look.scratch()
    @State private var brain = Brain()
    @State private var presetIndex = 0

    private let parade = ["Crush", "Night owl", "Grump", "Cat", "Robot"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("MINDER PRO").font(.system(size: 12, weight: .semibold)).tracking(3).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                    }.accessibilityLabel("Close")
                }

                EyesCanvas(brain: brain, look: look, zoom: 1.6)
                    .frame(height: 230)
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottom) {
                        Text(parade[presetIndex]).font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 12).frame(height: 28)
                            .background(.white.opacity(0.08), in: Capsule())
                            .contentTransition(.opacity)
                    }

                Text(headline).font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    feature("paintpalette.fill", "Design your own eyes", "Every look and every knob: iris colours, odd eyes, shapes, pupils, brows, whites, size, glow and the dice.")
                    Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 60)
                    feature("face.dashed", "Follow my face", "The front camera keeps the eyes on you and notices when you wander off. Nothing is recorded or leaves the phone.")
                }
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))

                HStack(alignment: .firstTextBaseline) {
                    Text(pro.price).font(.system(size: 40, weight: .light, design: .rounded)).foregroundStyle(.white)
                    Text("once").font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(look.iris.light)
                    Spacer()
                    Text("No subscription").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                }

                if let m = pro.message {
                    Text(m).font(.system(size: 14, weight: .medium)).foregroundStyle(look.iris.light)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }

                Button { Task { await pro.buy() } } label: {
                    Text(pro.busy ? "One moment" : "Unlock Pro for \(pro.price)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(LinearGradient(colors: [look.iris.light, look.iris.dark], startPoint: .top, endPoint: .bottom), in: Capsule())
                        .shadow(color: look.iris.light.opacity(0.4), radius: 18)
                }
                .buttonStyle(.plain).disabled(pro.busy)

                HStack {
                    Button { Task { await pro.restore() } } label: {
                        Label("Restore purchase", systemImage: "arrow.clockwise").font(.system(size: 15, weight: .medium))
                    }
                    Spacer()
                    Button("Not now") { dismiss() }.font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))

                Text("One payment, yours for good. Family Sharing works. The eyes, slide to focus, the timer, your week, the check-in and the pick-up suspicion stay free.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.35)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .task {
            // The eyes try on looks while you read.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                presetIndex = (presetIndex + 1) % parade.count
                withAnimation(.spring(duration: 0.4)) { Look.presets.first { $0.id == parade[presetIndex] }?.apply(look) }
                brain.touched(at: CGPoint(x: Double.random(in: -0.6...0.6), y: Double.random(in: -0.3...0.3)), t: Date.now.timeIntervalSinceReferenceDate)
            }
        }
        .onAppear { Look.presets.first { $0.id == parade[0] }?.apply(look) }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .face: return "Eyes that follow you."
        default: return "Make them yours."
        }
    }

    private func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium))
                .foregroundStyle(look.iris.light)
                .frame(width: 30, height: 30)
                .background(look.iris.light.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .medium))
                Text(body).font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
    }
}

/// Pro status in Settings, with Restore always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    let tint: IrisStyle
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: pro.unlocked ? "checkmark" : "eye.fill").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pro.unlocked ? .black : tint.light)
                .frame(width: 40, height: 40)
                .background(pro.unlocked ? AnyShapeStyle(tint.light) : AnyShapeStyle(tint.light.opacity(0.13)), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(pro.unlocked ? "Minder Pro" : "Minder Pro, \(pro.price) once").font(.system(size: 16, weight: .medium))
                Text(pro.unlocked ? (pro.grandfathered ? "Unlocked. Thanks for buying Minder early." : "Unlocked. Thank you.") : "Every look, every knob, and Follow my face.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                if let m = pro.message, pro.paywall == nil { Text(m).font(.system(size: 12, weight: .medium)).foregroundStyle(tint.light) }
            }
            Spacer(minLength: 4)
            if !pro.unlocked {
                VStack(alignment: .trailing, spacing: 8) {
                    Button { pro.ask(.settings) } label: {
                        Text("See").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                            .padding(.horizontal, 16).frame(height: 32).background(tint.light, in: Capsule())
                    }.buttonStyle(.plain)
                    Button { Task { await pro.restore() } } label: {
                        Text("Restore").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5)).underline()
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}
