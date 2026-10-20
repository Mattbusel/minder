// Promoted in-app purchase art, 1024x1024, no text and no prices: Minder Plus (monthly, yearly).
//   node Store/art/promo.mjs   -> Store/promo/plus-monthly.png, plus-yearly.png
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync } from "fs";
const eye = (flip, c) => {
  const pupil = c.cat ? `<div style="position:absolute;left:62px;top:22px;width:22px;height:100px;border-radius:50%;background:#050505"></div>`
    : c.star ? `<svg style="position:absolute;left:30px;top:30px" width="86" height="86" viewBox="0 0 100 100"><polygon fill="#050505" points="50,2 61,38 98,38 68,60 79,96 50,74 21,96 32,60 2,38 39,38"/></svg>`
    : `<div style="position:absolute;left:38px;top:38px;width:62px;height:62px;border-radius:50%;background:#050505"></div>`;
  return `
 <div style="position:relative;width:250px;height:300px">
  <div style="position:absolute;left:10px;top:-80px;width:230px;height:40px;border-radius:30px;background:#f0f0f0;transform:rotate(${flip ? -8 : 8}deg);box-shadow:0 0 30px ${c.glow}"></div>
  <div style="position:absolute;inset:0;border-radius:50%;background:radial-gradient(circle at 38% 30%,#fff,#eceef3 55%,#c7ccd8);overflow:hidden;box-shadow:0 0 70px ${c.glow}">
    <div style="position:absolute;left:${flip ? 78 : 52}px;top:112px;width:150px;height:150px;border-radius:50%;background:radial-gradient(circle,${c.inner} 20%,${c.light} 55%,${c.dark} 100%);border:6px solid ${c.ring}">
      ${pupil}
      <div style="position:absolute;left:20px;top:16px;width:40px;height:40px;border-radius:50%;background:#fff"></div>
    </div>
    <div style="position:absolute;left:-20px;top:-20px;width:300px;height:70px;background:#000"></div>
  </div>
 </div>`;
};
const out = "C:/Users/Matthew/minder/Store/promo";
mkdirSync(out, { recursive: true });
const looks = {
  "plus-yearly": { inner: "#fff27a", light: "#ff8c00", dark: "#401000", ring: "#3d0d00", glow: "rgba(255,140,0,.45)", star: true, bg: "radial-gradient(700px 600px at 50% 45%,#3a1500,#000 75%)" },
  "plus-monthly": { inner: "#ffd1dc", light: "#ff6185", dark: "#73002a", ring: "#5c0020", glow: "rgba(255,97,133,.45)", heart: false, bg: "radial-gradient(700px 600px at 50% 45%,#3a0018,#000 75%)" },
};
const sparkle = (x, y, s, c) => `<svg style="position:absolute;left:${x}px;top:${y}px" width="${s}" height="${s}" viewBox="0 0 100 100"><path fill="${c}" d="M50 0 C55 35 65 45 100 50 C65 55 55 65 50 100 C45 65 35 55 0 50 C35 45 45 35 50 0Z"/></svg>`;
const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, c] of Object.entries(looks)) {
  await p.setContent(`<html><body style="margin:0"><div style="position:relative;width:1024px;height:1024px;background:${c.bg};display:flex;gap:90px;align-items:center;justify-content:center;padding-top:80px;box-sizing:border-box">${eye(false, c)}${eye(true, c)}
  ${sparkle(110, 120, 120, c.inner)}${sparkle(820, 150, 80, c.light)}${sparkle(800, 780, 110, c.inner)}${sparkle(150, 790, 70, c.light)}</div></body></html>`);
  await p.screenshot({ path: `${out}/${name}.png` });
  console.log("wrote", name);
}
await b.close();
