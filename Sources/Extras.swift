import StoreKit
import SwiftUI

/// The 99-cent corner, kept apart from Pro so Pro's grandfathering stays exactly as it was.
/// Streak Shields and Focus Posters are consumables people buy again; eye packs and the
/// ambience pack are one-time.
@MainActor
@Observable
final class Extras {
    static let shieldID = "com.mattbusel.minder.shield"
    static let postersID = "com.mattbusel.minder.posters"
    static let ambienceID = "com.mattbusel.minder.ambience"
    static func packID(_ id: String) -> String { "com.mattbusel.minder.pack." + id }

    struct Pack: Identifiable {
        let id: String        // also the iris id and the icon suffix
        let name: String
        let blurb: String
        var icon: String { "AppIcon-" + name.replacingOccurrences(of: " ", with: "") }
    }
    static let packs: [Pack] = [
        Pack(id: "galaxy", name: "Galaxy", blurb: "Nebula irises and star pupils."),
        Pack(id: "gilded", name: "Gilded", blurb: "Molten gold, a cat's stare."),
        Pack(id: "toxic", name: "Toxic", blurb: "Glow-in-the-dark green."),
        Pack(id: "bloodmoon", name: "Blood moon", blurb: "Ember eyes for late nights."),
    ]
    static var allIDs: [String] { [shieldID, postersID, ambienceID] + packs.map { packID($0.id) } }

    private(set) var owned: Set<String> = []
    private(set) var products: [String: Product] = [:]
    var busy: String?
    var message: String?
    private var updates: Task<Void, Never>?
    private let demo: Bool
    private let d = UserDefaults.standard

    /// Banked consumables.
    var shields: Int { didSet { d.set(shields, forKey: "extras.shields") } }
    var posters: Int { didSet { d.set(posters, forKey: "extras.posters") } }

    init(demo: Bool, locked: Bool = false) {
        self.demo = demo
        shields = d.integer(forKey: "extras.shields")
        posters = d.integer(forKey: "extras.posters")
        if demo {
            owned = locked ? [] : [Extras.ambienceID, Extras.packID("galaxy")]
            return
        }
        owned = Set(d.stringArray(forKey: "extras.owned") ?? [])
        updates = Task { [weak self] in
            for await r in Transaction.updates { await self?.handle(r) }
        }
        Task {
            for await r in Transaction.unfinished { await handle(r) }
            await refresh()
        }
    }

    func price(_ id: String) -> String { products[id]?.displayPrice ?? (demo ? "$0.99" : "…") }
    func owns(_ id: String) -> Bool { owned.contains(id) }
    func ownsPack(_ id: String) -> Bool { owned.contains(Extras.packID(id)) }
    var ownsAmbience: Bool { owned.contains(Extras.ambienceID) }

    /// One free shield a month for everyone.
    var freeShieldLeft: Bool { d.string(forKey: "extras.freeShieldMonth") != Self.month }
    static var month: String { String(Ledger.key(.now).prefix(7)) }
    var firstPosterFree: Bool { !d.bool(forKey: "extras.freePosterUsed") }

    func loadProducts() async {
        guard !demo, products.count < Extras.allIDs.count else { return }
        if let ps = try? await Product.products(for: Extras.allIDs) { for p in ps { products[p.id] = p } }
    }

    func refresh() async {
        guard !demo else { return }
        var has: Set<String> = []
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.revocationDate == nil, t.productType == .nonConsumable, t.productID != Pro.productID { has.insert(t.productID) }
        }
        owned = has
        d.set(Array(has), forKey: "extras.owned")
        await loadProducts()
    }

    private func handle(_ r: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = r, Extras.allIDs.contains(t.productID) else { return }
        credit(t)
        await t.finish()
        await refresh()
    }

    /// Bank a consumable once per transaction, however many times StoreKit reports it.
    private func credit(_ t: StoreKit.Transaction) {
        guard t.productType == .consumable, t.revocationDate == nil else { return }
        var seen = Set(d.stringArray(forKey: "extras.credited") ?? [])
        guard !seen.contains(String(t.id)) else { return }
        seen.insert(String(t.id)); d.set(Array(seen), forKey: "extras.credited")
        if t.productID == Extras.shieldID { shields += 1 }
        if t.productID == Extras.postersID { posters += 3 }
    }

    @discardableResult
    func buy(_ id: String) async -> Bool {
        message = nil
        if demo {
            if id == Extras.shieldID { shields += 1 } else if id == Extras.postersID { posters += 3 } else { owned.insert(id) }
            return true
        }
        await loadProducts()
        guard let p = products[id] else { message = "The App Store did not answer. Check your connection and try again."; return false }
        busy = id; defer { busy = nil }
        do {
            switch try await p.purchase() {
            case .success(let r):
                guard case .verified(let t) = r else { message = "Apple could not confirm that purchase. Try Restore in a minute."; return false }
                credit(t)
                await t.finish()
                await refresh()
                Haptics.success()
                return true
            case .pending: message = "Waiting for approval. It arrives by itself once approved."
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = "The purchase did not go through: \(error.localizedDescription)" }
        return false
    }

    /// Cover a missed day with a shield: the free monthly one first, then a banked one.
    func useShield(on day: Date) -> Bool {
        if freeShieldLeft { d.set(Self.month, forKey: "extras.freeShieldMonth") }
        else if shields > 0 { shields -= 1 }
        else { return false }
        var s = Ledger.shielded; s.insert(Ledger.key(day)); Ledger.shielded = s
        return true
    }

    /// Spend a poster credit (or the free first one). False if there is nothing to spend.
    func spendPoster() -> Bool {
        if firstPosterFree { d.set(true, forKey: "extras.freePosterUsed"); return true }
        guard posters > 0 else { return false }
        posters -= 1
        return true
    }
}

// MARK: - Shop

struct ShopSheet: View {
    @Environment(Extras.self) private var extras
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var look = Look.shared

    var body: some View {
        let tint = look.iris
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("EXTRAS").font(.system(size: 12, weight: .semibold)).tracking(3).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                    }.accessibilityLabel("Close")
                }
                Text("Small things,\n99 cents each.").font(.system(size: 32, weight: .semibold, design: .rounded))

                // Repeatable
                VStack(spacing: 0) {
                    row(icon: "shield.lefthalf.filled", title: "Streak Shield",
                        sub: "Covers a missed day so your streak carries on. One a month is free" + (extras.freeShieldLeft ? " (yours is ready)." : "; you've used this month's.") + " Banked: \(extras.shields).",
                        id: Extras.shieldID, tint: tint, owned: false)
                    divider
                    row(icon: "photo.on.rectangle.angled", title: "Focus Posters, 3 for 99¢",
                        sub: "A shareable poster of a session or a day, with your eyes on it. " + (extras.firstPosterFree ? "Your first one is free." : "Left: \(extras.posters)."),
                        id: Extras.postersID, tint: tint, owned: false)
                }
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))

                Text("EYE PACKS").font(.system(size: 12, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.4))
                Text("A new iris and a look to go with it, plus a matching app icon. Yours without Pro.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Extras.packs) { p in packCard(p) }
                }

                VStack(spacing: 0) {
                    row(icon: "cloud.rain", title: "Ambience pack: Rain and Fireplace",
                        sub: "Two more sounds for focus, made on the phone. Brown noise stays free; pink and ocean come with Pro.",
                        id: Extras.ambienceID, tint: tint, owned: extras.ownsAmbience)
                }
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))

                if let m = extras.message { Text(m).font(.system(size: 13, weight: .medium)).foregroundStyle(tint.light).frame(maxWidth: .infinity) }
                Text("One-time items restore on all your devices from Settings. Shields and posters are used up as you use them.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.35)).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .task { await extras.loadProducts() }
    }

    private var divider: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 62) }

    private func row(icon: String, title: String, sub: String, id: String, tint: IrisStyle, owned: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(tint.light)
                .frame(width: 32, height: 32).background(tint.light.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .medium))
                Text(sub).font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            if owned {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(tint.light).font(.system(size: 20))
            } else {
                Button { Task { await extras.buy(id) } } label: {
                    Group { if extras.busy == id { ProgressView().tint(.black) } else { Text(extras.price(id)).font(.system(size: 14, weight: .semibold, design: .rounded)) } }
                        .foregroundStyle(.black).padding(.horizontal, 14).frame(height: 32).background(tint.light, in: Capsule())
                }.buttonStyle(.plain).disabled(extras.busy != nil)
            }
        }
        .padding(16)
    }

    private func packCard(_ p: Extras.Pack) -> some View {
        let iris = IrisStyle.named(p.id)
        let owned = extras.ownsPack(p.id)
        return Button {
            if owned {
                withAnimation(.spring(duration: 0.4)) { Look.packPreset(p.id)?.apply(look) }
                if UIApplication.shared.supportsAlternateIcons { UIApplication.shared.setAlternateIconName(p.icon) }
                Haptics.success()
            } else {
                Task { if await extras.buy(Extras.packID(p.id)) { Look.packPreset(p.id)?.apply(look) } }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [iris.dark.opacity(0.6), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                    MiniEyes(iris: iris).frame(width: 84, height: 38)
                }.frame(height: 86)
                HStack {
                    Text(p.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    if owned { Text(look.irisID == p.id ? "On" : "Use").font(.system(size: 12, weight: .semibold)).foregroundStyle(iris.light) }
                    else if extras.busy == Extras.packID(p.id) { ProgressView().tint(iris.light) }
                    else { Text(extras.price(Extras.packID(p.id))).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 4).background(iris.light, in: Capsule()) }
                }
                Text(p.blurb).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.45)).lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(look.irisID == p.id ? iris.light : .white.opacity(0.06), lineWidth: look.irisID == p.id ? 2 : 1))
        }
        .buttonStyle(.plain).disabled(extras.busy != nil)
    }
}
