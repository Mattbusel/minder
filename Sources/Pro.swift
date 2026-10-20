import SwiftUI
import StoreKit

/// Minder Pro: one non-consumable. The eyes, slide to focus, the timer, the week, the goal,
/// tags, breaks, the Live Activity, the Today widget, brown noise, the check-in and the pick-up
/// suspicion are free forever; Pro is the eye designer (every look and knob), Follow my face,
/// twelve weeks of history with every session and CSV, pink noise and ocean, your own tags,
/// and the Week widget.
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

    enum Reason: String, Identifiable { case designer, face, settings, stats, sound, tags, plus, month, insights, packs, backup; var id: String { rawValue } }

    /// The one-time purchase (or a grandfathered paid download). Never taken away by anything Plus does.
    private(set) var purchased: Bool
    /// Minder Plus includes everything in Pro while it is active.
    var viaPlus = false { didSet { if viaPlus != oldValue { Shared.pro = unlocked } } }
    var unlocked: Bool { purchased || viaPlus }
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
        if let forced { purchased = forced; return }
        purchased = UserDefaults.standard.bool(forKey: key)
        Shared.pro = purchased
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$2.99" }

    func ask(_ why: Reason) { if !unlocked { paywall = why } }
    /// Plus things are offered to Pro owners too.
    func askPlus(_ why: Reason) { paywall = why }

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
                if !purchased { message = "Apple could not confirm the purchase. Try Restore in a minute." }
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
        message = purchased ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !purchased else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { purchased = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
        Shared.pro = true
    }

    private func revoke() {
        purchased = false
        UserDefaults.standard.set(false, forKey: key)
        Shared.pro = unlocked
    }
}

// MARK: - Paywall: see Paywall.swift
