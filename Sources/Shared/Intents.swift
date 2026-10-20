import AppIntents
import Foundation

/// "Start focusing in Minder": opens the app and starts a session. Compiled into the app and the widget
/// extension so the Control Center control and the widgets can run it; the app picks the flag up as it opens.
struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start focusing"
    static var description = IntentDescription("Opens Minder and starts a focus session.")
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        Shared.pendingStart = true
        await MainActor.run { NotificationCenter.default.post(name: .minderStartFocus, object: nil) }
        return .result()
    }
}

/// "How long have I focused today in Minder?" Answers without opening the app.
struct TodayFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Focus today"
    static var description = IntentDescription("Tells you how long you have focused today and your streak.")
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let today = Ledger.today
        let goal = Double(Shared.goalMinutes) * 60
        let streak = Ledger.streak
        var line = today < 60 ? "No focus yet today." : "\(spoken(today)) of focus today"
        if today >= 60 { line += today >= goal ? ", goal done." : ", \(spoken(goal - today)) to your goal." }
        if streak > 1 { line += " Streak: \(streak) days." }
        return .result(value: Int(today / 60), dialog: IntentDialog(stringLiteral: line))
    }
}

extension Notification.Name { static let minderStartFocus = Notification.Name("minderStartFocus") }

extension Shared {
    /// Set by Siri, Shortcuts, the control and the widgets; the app starts a session and clears it.
    static var pendingStart: Bool {
        get { defaults.bool(forKey: "pendingStart") }
        set { defaults.set(newValue, forKey: "pendingStart") }
    }
}
