# App Review notes

---

No account, login or network connection is required.

WHAT IS NEW IN 1.2: a daily goal ring and focus streak, session tags and planned lengths, a 5-minute break, a Live Activity (Lock Screen / Dynamic Island timer during a session), Home Screen widgets (Today free, Week with Pro; data shared through the app group group.com.mattbusel.minder), sounds generated on the device (no audio files, no network), a Focus page with stats, shareable posters, Siri/Shortcuts "Start focusing", and seven new in-app purchases.

IN-APP PURCHASES (StoreKit 2, all optional, no subscriptions; Restore is in Settings > Minder Pro):
- Minder Pro (existing, $2.99 non-consumable): eye designer, Follow my face, twelve-week history + CSV, pink noise and ocean, custom tags, Week widget.
- Streak Shield, $0.99 consumable: everyone gets one free shield a month. When a streak of 2+ days misses a day, the main screen shows "Your N-day streak missed yesterday. Save it?"; it opens Focus, where the free shield is used first, then Streak Shield for $0.99. Also in Extras (bag button, top right).
- Focus Posters, $0.99 consumable (3 credits): the first poster is free. After a session of 5+ minutes a "Poster" button appears above the slider; Focus also has "Make a poster of today". Making a poster uses a credit; it can then be shared.
- Ambience Pack, $0.99 non-consumable: Rain and Fireplace in Settings > Sound while focusing.
- Galaxy, Gilded, Toxic, Blood Moon Eyes, $0.99 non-consumables: Extras (bag button). Each adds an iris to the eye designer (usable without Pro), a matching look, and switches the app icon (alternate icons).

HOW TO USE: the app opens to a black screen with animated eyes. Pick a tag and a plan above the slider (optional), then drag the slider right to start. Tap anywhere to show the controls; drag back to stop. Tap "Today" (top left) for the Focus page. The bag button opens Extras; the sliders button opens Settings (eye designer, Pro, sounds, check-ins).

CAMERA: "Follow my face" (Pro) is off by default. The front camera only finds the position of a face (Apple Vision face rectangles); nothing is stored, recorded or sent.

MOTION: device motion is read during a session to notice when the phone is picked up. Nothing is stored except a count per session.

NOTIFICATIONS: only for the optional break, asked when a break is first started.

PRIVACY: no data is collected. Focus minutes and sessions stay on the device.

2. PURPOSE AND TARGET AUDIENCE
Minder is a focus companion: a pair of animated eyes that keep you company while you work ("body doubling"), for people with ADHD or anyone who works better when watched. General audience, rated 4+. It makes no medical claims.

3. SETUP AND ACCESS
No setup or credentials. Launch, slide to focus.

4. EXTERNAL SERVICES
None. No network requests except StoreKit 2. No analytics, ads, AI or third-party SDKs. Built with SwiftUI, WidgetKit, ActivityKit, AppIntents, AVFoundation (generated sound and the optional camera), Vision, CoreMotion, StoreKit 2.

5. REGIONAL DIFFERENCES
None.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. All art, animation, sound and code are my own original work.
