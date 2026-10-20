// In-App Event art: card.png 1920x1080 (three raw screens, no text: the store draws the name) and
// details-<locale>.png 1080x1920 (that locale's framed screenshot, letterboxed).
//   node Store/art/event_art.mjs <dir of raw CI shots> <out dir>
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, mkdirSync } from "fs";
const [raw, out] = process.argv.slice(2);
const EV = { insights: { shots: ["focus", "insights", "widgets"], frame: "05" }, november: { shots: ["work", "month", "focus"], frame: "07" } };
const files = readdirSync(raw);
const b64 = (p) => readFileSync(p).toString("base64");
const b = await chromium.launch();
for (const [key, ev] of Object.entries(EV)) {
  mkdirSync(`${out}/${key}`, { recursive: true });
  const card = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const phones = ev.shots.map((k, i) => `<div class="ph p${i}"><img src="data:image/png;base64,${b64(`${raw}/${files.find((f) => f.endsWith(`-${k}.png`))}`)}"></div>`).join("");
  await card.setContent(`<!doctype html><html><head><style>
  body{margin:0;width:1920px;height:1080px;overflow:hidden;background:#000}
  .g{position:absolute;inset:0;background:radial-gradient(900px 700px at 50% 40%,rgba(255,184,74,.25),transparent 70%)}
  .ph{position:absolute;top:110px;width:430px;border-radius:64px;padding:14px;background:#1c1c21;box-shadow:0 0 0 3px rgba(255,255,255,.12),0 40px 120px rgba(0,0,0,.7)}
  .ph img{display:block;width:100%;border-radius:52px}
  .p0{left:310px;transform:rotate(-7deg) translateY(60px)} .p1{left:745px;z-index:2;top:70px} .p2{left:1180px;transform:rotate(7deg) translateY(60px)}
</style></head><body><div class="g"></div>${phones}</body></html>`);
  await card.waitForTimeout(300);
  await card.screenshot({ path: `${out}/${key}/card.png`, clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  const det = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  for (const loc of ["en-US", "ja", "ko", "zh-Hans"]) {
    const f = `C:/Users/Matthew/minder/fastlane/screenshots/${loc}/${ev.frame}_iPhone.png`;
    await det.setContent(`<!doctype html><html><body style="margin:0;width:1080px;height:1920px;overflow:hidden;background:#000;display:flex;align-items:center;justify-content:center"><img style="height:1920px" src="data:image/png;base64,${b64(f)}"></body></html>`);
    await det.waitForTimeout(200);
    await det.screenshot({ path: `${out}/${key}/details-${loc}.png`, clip: { x: 0, y: 0, width: 1080, height: 1920 } });
  }
  console.log("event art", key);
}
await b.close();
