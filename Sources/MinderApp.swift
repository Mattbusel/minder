import SwiftUI

@main
struct MinderApp: App {
    @State private var pro: Pro
    @State private var extras: Extras
    init() {
        Ledger.migrate()
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        // Store screenshots and the review recording show everything; the paywall shot is the free app.
        let lockedShot = a.contains("paywall") || a.contains("-locked")
        _pro = State(initialValue: demo ? Pro(forced: !lockedShot) : Pro())
        _extras = State(initialValue: Extras(demo: demo, locked: a.contains("shop")))
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(pro)
                .environment(extras)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
