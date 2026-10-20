import SwiftUI
import TipKit

@main
struct MinderApp: App {
    @State private var pro: Pro
    @State private var extras: Extras
    @State private var plus: Plus
    @Environment(\.scenePhase) private var phase

    init() {
        Ledger.migrate()
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay") || a.contains("-preview")
        // Store screenshots and the review recording show everything; the paywall shot is the free app.
        let lockedShot = a.contains("paywall") || a.contains("-locked")
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot) : Pro())
        _extras = State(initialValue: Extras(demo: demo, locked: a.contains("shop")))
        _plus = State(initialValue: demo ? Plus(forced: !lockedShot && !a.contains("-noplus")) : Plus())
        if demo {
            Tips.hideAllTipsForTesting()
        }
        try? Tips.configure([.displayFrequency(.daily)])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pro)
                .environment(extras)
                .environment(plus)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .onChange(of: plus.active, initial: true) { was, on in
                    pro.viaPlus = on
                    extras.plus = on
                    guard on else {
                        // Plus ended: a look it lent goes back to Classic. Anything bought stays.
                        let id = Look.shared.irisID
                        if was && (IrisStyle.monthly.contains(where: { $0.id == id }) || (IrisStyle.packs.contains(where: { $0.id == id }) && !extras.ownsPack(id))) {
                            Look.presets.first?.apply(Look.shared)
                        }
                        return
                    }
                    plus.collect()
                    _ = plus.refill(extras)
                    if !ProcessInfo.processInfo.arguments.contains("-shot") {
                        CloudBackup.pull()
                        CloudBackup.push()
                    }
                }
                .onChange(of: phase) { _, p in
                    guard plus.active, !ProcessInfo.processInfo.arguments.contains("-shot") else { return }
                    if p == .active { Task { await plus.refresh(); _ = plus.refill(extras); plus.collect(); CloudBackup.pull() } }
                    if p == .background { CloudBackup.push() }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
                    if plus.active { CloudBackup.pull() }
                }
        }
    }
}
