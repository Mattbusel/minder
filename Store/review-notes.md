# App Review notes

---

No account, login or network connection is required.

VERSION 1.1, IN-APP PURCHASE: Minder is now free. One non-consumable in-app purchase, "Minder Pro" (com.mattbusel.minder.pro, $2.99, one time, no subscription), unlocks the full eye designer (all presets, colours, shapes, pupils, brows, sliders and the dice) and Follow my face. The eyes, focus sessions, timer, week and streak, check-ins and pick-up detection stay free, with the Classic, Robot and Cat looks. To see the paywall: tap the settings button (top right), then tap a locked preset (lock icon), the dice, "See Minder Pro" under the frosted designer, or the "Follow my face (Pro)" switch. Buy and Restore purchase are on the paywall; Restore is also on the Minder Pro card in Settings. People who bought the paid version get Pro automatically (checked with StoreKit AppTransaction in production only, so the sandbox always shows the paywall).

HOW TO USE: The app opens to a black screen with a pair of animated eyes. Drag the slider at the bottom to the right ("slide to focus") to start a work session. The eyes watch, blink and change expression while a timer runs; tap anywhere to see the controls again, and drag the slider back to stop. The settings button (top right, when not working) opens the eye customisation panel and options.

CAMERA: "Follow my face" (Pro) is OFF by default. If turned on, the front camera is used only to find the position of a face in each frame (Apple Vision face rectangles) so the eyes can look toward the user. No image is stored, recorded, or transmitted; frames are discarded immediately. The camera is only active during a work session.

MOTION: device motion is read during a session to notice when the phone is picked up, which makes the eyes look suspicious. Nothing is stored.

PRIVACY: no data is collected. Focus minutes are stored locally on the device.

GUIDELINE 2.1 INFORMATION (a screen recording was sent in the App Review reply)

2. PURPOSE AND TARGET AUDIENCE
Minder is a focus companion. It turns the phone into a pair of animated eyes that watch you while you work. Many people, especially people with ADHD, find it much easier to stay on task when someone is in the room with them ("body doubling"). Minder provides that feeling without another person: you prop the phone on the desk, slide to start a session, and the eyes blink, look around, and react when you pick the phone up. It also removes the phone as a distraction, because the phone is busy being the minder. A gentle check-in chime marks each focus interval, and the app keeps a simple local total of focus minutes and a day streak. The audience is students, remote workers and anyone who struggles to stay focused alone. It is rated 4+.

3. SETUP AND ACCESS
No setup, login, credentials or sample files are required. Launch the app and the eyes appear. Drag the slider at the bottom to the right to start a session; tap anywhere to show the controls again; drag the slider back to stop. The settings button (top right, when not in a session) opens eye customisation and options. "Follow my face" is OFF by default; if turned on, the app asks for camera permission and uses the front camera only to find the position of a face so the eyes can look toward the user. The app works fully with the camera off.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
None. The app makes no network requests of its own; the only traffic is StoreKit 2 talking to the App Store for the in-app purchase. It uses no data providers, no authentication service, no third-party payment processor, no AI service, no analytics, no crash reporting, no advertising SDK and no third-party frameworks. It is built only with Apple frameworks: SwiftUI, StoreKit 2, AVFoundation and Vision (optional on-device face position; frames are discarded immediately and never stored or transmitted), CoreMotion (to notice the phone being picked up during a session) and UIKit haptics. Focus minutes are stored locally on the device.

5. REGIONAL DIFFERENCES
None. The app functions identically in every region. It is offline and has no region-dependent features, content or restrictions.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. The app does not operate in a regulated industry. It is a productivity tool and makes no medical claims; it does not diagnose, treat or monitor any condition. All art, animation, text and code are my own original work, and no third-party or licensed material appears.
