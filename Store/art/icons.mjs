// The four eye-pack icons: Minder's icon eyes with each pack's iris. Writes Resources/Assets.xcassets/AppIcon-<Name>.appiconset.
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { mkdirSync, writeFileSync } from "fs";
const packs = {
  Galaxy: { inner: "#ff8cd9", light: "#8c73ff", dark: "#140a4d", ring: "#2a1670", glow: "rgba(140,115,255,.35)", star: true },
  Gilded: { inner: "#fff7bf", light: "#ffd95a", dark: "#734d05", ring: "#5c3d03", glow: "rgba(255,217,90,.35)", cat: true },
  Toxic: { inner: "#f2ff99", light: "#bfff33", dark: "#1a5900", ring: "#164a00", glow: "rgba(191,255,51,.4)" },
  Bloodmoon: { inner: "#ffc74d", light: "#ff6b29", dark: "#520300", ring: "#4a0400", glow: "rgba(255,107,41,.35)" },
};
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
const root = "C:/Users/Matthew/minder/Resources/Assets.xcassets";
const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, c] of Object.entries(packs)) {
  await p.setContent(`<html><body style="margin:0"><div style="width:1024px;height:1024px;background:#000;display:flex;gap:90px;align-items:center;justify-content:center;padding-top:80px;box-sizing:border-box">${eye(false, c)}${eye(true, c)}</div></body></html>`);
  const dir = `${root}/AppIcon-${name}.appiconset`;
  mkdirSync(dir, { recursive: true });
  await p.screenshot({ path: `${dir}/icon-1024.png` });
  writeFileSync(`${dir}/Contents.json`, JSON.stringify({ images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }], info: { author: "xcode", version: 1 } }, null, 2));
  console.log("wrote", name);
}
await b.close();
