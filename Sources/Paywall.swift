import StoreKit
import SwiftUI

/// One paywall for both ways in: Minder Plus (yearly with a free week, or monthly) and Minder Pro (one time).
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(Plus.self) private var plus
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let reason: Pro.Reason
    @State private var look = Look.scratch()
    @State private var brain = Brain()
    @State private var presetIndex = 0
    @State private var plan = Plus.yearlyID
    @State private var redeem = false
    @State private var manage = false

    private let parade = ["Crush", "Night owl", "Grump", "Cat", "Robot"]
    private static let proPlan = "pro"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(plus.active ? "MINDER PLUS" : "MINDER PLUS AND PRO").font(.system(size: 12, weight: .semibold)).tracking(3).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 34, height: 34).background(.white.opacity(0.1), in: Circle())
                    }.accessibilityLabel("Close")
                }

                EyesCanvas(brain: brain, look: look, zoom: 1.5)
                    .frame(height: 150)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                Text(headline).font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if plus.active {
                    activeCard
                } else {
                    plans
                    if let m = plus.message ?? pro.message {
                        Text(m).font(.system(size: 14, weight: .medium)).foregroundStyle(look.iris.light)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    Button { Task { await buy() } } label: {
                        Text(plus.busy || pro.busy ? "One moment" : cta)
                            .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(LinearGradient(colors: [look.iris.light, look.iris.dark], startPoint: .top, endPoint: .bottom), in: Capsule())
                            .shadow(color: look.iris.light.opacity(0.4), radius: 18)
                    }
                    .buttonStyle(.plain).disabled(plus.busy || pro.busy)
                    Text(terms).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.45)).fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    feature("paintpalette.fill", "Design your own eyes", "Every look and knob, Follow my face, twelve weeks of history, CSV, more sounds, your own tags.", both: true)
                    line
                    feature("sparkles", "Every eye pack and the Eye of the Month", "Galaxy, Gilded, Toxic, Blood moon, rain and fireplace, and a new look every month.", both: false)
                    line
                    feature("shield.lefthalf.filled", "3 Streak Shields and 5 posters a month", "Topped up at the start of every month you have Plus.", both: false)
                    line
                    feature("chart.bar.xaxis", "Insights", "Your best hours, average session, pick-ups an hour, the month at a glance.", both: false)
                    line
                    feature("icloud.fill", "iCloud backup", "Your focus history, safe in your own iCloud and back on a new phone.", both: false)
                }
                .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))

                if pro.purchased && !plus.active {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "gift.fill").foregroundStyle(look.iris.light)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Thanks for owning Pro").font(.system(size: 15, weight: .semibold))
                            Text("Pro stays yours whatever you choose. Pro owners can try three months of Plus with offer code PROEYES.")
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                            Button("Redeem code") { redeem = true }.font(.system(size: 14, weight: .semibold)).foregroundStyle(look.iris.light)
                        }
                    }
                    .padding(16).card()
                }

                links
            }
            .padding(22)
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .offerCodeRedemption(isPresented: $redeem) { _ in Task { await plus.refresh() } }
        .manageSubscriptionsSheet(isPresented: $manage)
        .task {
            await plus.load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.8))
                presetIndex = (presetIndex + 1) % parade.count
                withAnimation(.spring(duration: 0.4)) { Look.presets.first { $0.id == parade[presetIndex] }?.apply(look) }
                brain.touched(at: CGPoint(x: Double.random(in: -0.6...0.6), y: Double.random(in: -0.3...0.3)), t: Date.now.timeIntervalSinceReferenceDate)
            }
        }
        .onAppear { Look.presets.first { $0.id == parade[0] }?.apply(look) }
        .onChange(of: plus.active) { _, now in if now { dismiss() } }
        .onChange(of: pro.purchased) { _, now in if now && plan == Self.proPlan { dismiss() } }
    }

    private var line: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 60) }

    var headline: String {
        switch reason {
        case .face: return "Eyes that follow you."
        case .stats: return "See the long game."
        case .sound: return "More to focus to."
        case .tags: return "Tag it your way."
        case .insights: return "Know when you focus best."
        case .month: return "A new pair of eyes every month."
        case .packs: return "Every look, all of them."
        case .backup: return "Never lose a streak."
        default: return "Make them yours."
        }
    }

    // MARK: plans

    private var plans: some View {
        VStack(spacing: 10) {
            planRow(Plus.yearlyID, title: "Plus, yearly",
                    price: "\(plus.price(Plus.yearlyID)) a year",
                    note: plus.trialEligible ? "1 week free, then \(plus.price(Plus.yearlyID)) a year" : (plus.yearlyPerMonth.map { "Works out to \($0) a month" } ?? ""),
                    badge: plus.trialEligible ? "FREE WEEK" : "BEST VALUE")
            planRow(Plus.monthlyID, title: "Plus, monthly", price: "\(plus.price(Plus.monthlyID)) a month", note: "Cancel any time", badge: nil)
            if !pro.purchased {
                planRow(Self.proPlan, title: "Pro, one time", price: "\(pro.price) once", note: "The designer, Follow my face, history and sounds. No renewals.", badge: nil)
            }
        }
    }

    private func planRow(_ id: String, title: String, price: String, note: String, badge: String?) -> some View {
        let on = plan == id
        return Button { Haptics.tap(); withAnimation(.spring(duration: 0.3)) { plan = id } } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                    .foregroundStyle(on ? look.iris.light : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 16, weight: .semibold))
                        if let badge {
                            Text(badge).font(.system(size: 9.5, weight: .heavy)).tracking(1).foregroundStyle(.black)
                                .padding(.horizontal, 7).padding(.vertical, 3).background(look.iris.light, in: Capsule())
                        }
                    }
                    Text(note).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text(price).font(.system(size: 15, weight: .semibold, design: .rounded)).multilineTextAlignment(.trailing)
            }
            .padding(16)
            .background(Color(white: on ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? look.iris.light : .white.opacity(0.07), lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
    }

    private var cta: String {
        switch plan {
        case Self.proPlan: return "Unlock Pro for \(pro.price)"
        case Plus.yearlyID: return plus.trialEligible ? "Start the free week" : "Subscribe for \(plus.price(Plus.yearlyID)) a year"
        default: return "Subscribe for \(plus.price(Plus.monthlyID)) a month"
        }
    }

    private var terms: String {
        if plan == Self.proPlan {
            return "Minder Pro is a single payment of \(pro.price), yours for good, with Family Sharing. It does not renew. The eyes, slide to focus, the timer, your goal and streak, tags, breaks, the Lock Screen timer, widgets, Control Center, brown noise and the monthly challenge stay free."
        }
        let yearly = plan == Plus.yearlyID
        let price = yearly ? "\(plus.price(Plus.yearlyID)) a year" : "\(plus.price(Plus.monthlyID)) a month"
        let trial = yearly && plus.trialEligible ? "After the 1-week free trial, " : ""
        return "\(trial)Minder Plus costs \(price) and renews automatically until you cancel. Payment is charged to your Apple ID at confirmation\(yearly && plus.trialEligible ? " when the trial ends" : ""). It renews unless cancelled at least 24 hours before the end of the current period, and your account is charged for renewal within 24 hours before it ends. Manage or cancel any time in Settings > Apple ID > Subscriptions. Cancelling during the trial costs nothing."
    }

    private func buy() async {
        if plan == Self.proPlan { await pro.buy() } else { await plus.buy(plan) }
    }

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Minder Plus is on", systemImage: "checkmark.seal.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(look.iris.light)
            if let e = plus.expires {
                Text(plus.renews ? "Renews \(e.formatted(date: .abbreviated, time: .omitted))." : "Ends \(e.formatted(date: .abbreviated, time: .omitted)). It will not renew.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
            }
            Button("Manage subscription") { manage = true }.font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).card()
    }

    private var links: some View {
        VStack(spacing: 12) {
            HStack {
                Button { Task { await plus.restore(); await pro.restore() } } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise").font(.system(size: 14, weight: .medium))
                }
                Spacer()
                Button("Redeem code") { redeem = true }.font(.system(size: 14, weight: .medium))
            }
            HStack(spacing: 18) {
                Button("Terms of Use") { openURL(Plus.terms) }
                Button("Privacy Policy") { openURL(Plus.privacy) }
                if plus.active || plus.currentID != nil { Button("Manage") { manage = true } }
                Spacer()
                Button("Not now") { dismiss() }
            }
            .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    private func feature(_ icon: String, _ title: String, _ body: String, both: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium))
                .foregroundStyle(look.iris.light)
                .frame(width: 30, height: 30)
                .background(look.iris.light.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 16, weight: .medium))
                    Text(both ? "PRO + PLUS" : "PLUS").font(.system(size: 9, weight: .heavy)).tracking(0.8).foregroundStyle(.white.opacity(0.45))
                }
                Text(body).font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

/// Plus and Pro status in Settings, with Restore, Redeem and Manage always in reach.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    @Environment(Plus.self) private var plus
    let tint: IrisStyle
    @State private var redeem = false
    @State private var manage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: plus.active ? "sparkles" : "eye.fill").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(plus.active ? .black : tint.light)
                    .frame(width: 40, height: 40)
                    .background(plus.active ? AnyShapeStyle(tint.light) : AnyShapeStyle(tint.light.opacity(0.13)), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minder Plus").font(.system(size: 16, weight: .medium))
                    Text(plus.active ? "On. Every look, Insights, monthly shields, iCloud backup." : "Everything in Pro, every eye pack, the Eye of the Month, Insights and iCloud backup.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button { if plus.active { manage = true } else { pro.askPlus(.plus) } } label: {
                    Text(plus.active ? "Manage" : "See").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 16).frame(height: 32).background(tint.light, in: Capsule())
                }.buttonStyle(.plain)
            }
            Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
            HStack(spacing: 14) {
                Image(systemName: pro.purchased ? "checkmark" : "lock.open").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint.light).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pro.purchased ? "Minder Pro" : "Minder Pro, \(pro.price) once").font(.system(size: 15, weight: .medium))
                    Text(pro.purchased ? (pro.grandfathered ? "Unlocked. Thanks for buying Minder early." : "Unlocked for good. Thank you.") : "The designer, Follow my face, history and sounds, without a subscription.")
                        .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.45)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if !pro.purchased {
                    Button { pro.askPlus(.settings) } label: {
                        Text("See").font(.system(size: 13, weight: .semibold)).foregroundStyle(tint.light)
                    }.buttonStyle(.plain)
                }
            }
            if let m = plus.message ?? pro.message, pro.paywall == nil { Text(m).font(.system(size: 12, weight: .medium)).foregroundStyle(tint.light) }
            HStack(spacing: 16) {
                Button("Restore Purchases") { Task { await plus.restore(); await pro.restore() } }
                Button("Redeem code") { redeem = true }
                Spacer()
            }
            .font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white.opacity(0.55))
        }
        .padding(18)
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06)))
        .offerCodeRedemption(isPresented: $redeem) { _ in Task { await plus.refresh() } }
        .manageSubscriptionsSheet(isPresented: $manage)
    }
}
