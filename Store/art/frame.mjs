// App Store screenshots: a headline over each raw simulator shot, on charcoal.
//   node Store/art/frame.mjs <dir of CI shots>
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const out = "C:/Users/Matthew/minder/fastlane/screenshots/en-US";
const plan = [
  ["idle", "Eyes that keep<br>you on task.", "Prop it up, slide to focus, <b>get to work.</b>"],
  ["work", "Slide to focus.", "A plan, a timer and check-ins, <b>while they watch.</b>"],
  ["suspicious", "Pick up your phone?<br>They notice.", "Body doubling for <b>ADHD brains.</b>"],
  ["widgets", "On your Lock Screen<br>and Home Screen.", "A live timer, and <b>widgets.</b>"],
  ["focus", "Goals, streaks,<br>and where it went.", "Your day, your week, <b>your tags.</b>"],
  ["rescue", "Missed a day?<br>Shield the streak.", "One free shield <b>every month.</b>"],
  ["break", "Then take a break.", "The eyes <b>doze off too.</b>"],
  ["galaxy", "Make them yours.", "Eye packs with <b>matching app icons.</b>"],
  ["poster", "Share the focus.", "A poster of your day, <b>with your eyes on it.</b>"],
  ["paywall", "One payment.<br>No subscription.", "Design every detail, and <b>Follow my face.</b>"],
];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub] of plan) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;800;900&display=block" rel="stylesheet">
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#000;font-family:Nunito,sans-serif}
  .glow{position:absolute;inset:0;background:radial-gradient(1100px 900px at 85% -5%,rgba(255,184,74,.20),transparent 60%),radial-gradient(900px 700px at 0% 100%,rgba(255,184,74,.07),transparent 60%)}
  .eyes{position:absolute;right:80px;top:96px;display:flex;gap:16px}
  .eyes i{display:block;width:46px;height:56px;border-radius:50%;background:radial-gradient(circle at 50% 62%,#050505 0 9px,#ffb84a 10px 20px,#7a3a06 21px 23px,#eceef3 24px)}
  .col{position:absolute;left:96px;right:96px;top:190px;display:flex;flex-direction:column}
  h1{margin:0;color:#f5f5f5;font-weight:900;font-size:108px;line-height:1.02;letter-spacing:-2px}
  p{margin:28px 0 0;color:rgba(245,245,245,.62);font-weight:700;font-size:50px;line-height:1.2}
  p b{color:#ffb84a;font-weight:800}
  .phone{margin:70px auto 0;width:1080px;border-radius:120px;padding:22px;background:#141416;box-shadow:0 0 0 3px rgba(255,255,255,.12),0 60px 140px rgba(0,0,0,.7)}
  .phone img{display:block;width:100%;border-radius:100px}
</style></head><body><div class="glow"></div>
<div class="eyes"><i></i><i></i></div>
<div class="col"><h1>${head}</h1><p>${sub}</p>
<div class="phone"><img src="data:image/png;base64,${img}"></div></div>
</body></html>`);
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const name = `${String(n).padStart(2, "0")}_iPhone.png`;
  await p.screenshot({ path: `${out}/${name}`, clip: { x: 0, y: 0, width: 1320, height: 2868 } });
  console.log("wrote", name, key);
  n++;
}
await b.close();
