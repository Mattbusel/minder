// App Store screenshots: a headline over each raw simulator shot, on charcoal.
//   node Store/art/frame.mjs <dir of CI shots> [locale: en-US | ja | ko | zh-Hans]
// Writes fastlane/screenshots/en-US/NN_iPhone.png at 1320x2868 (the 6.9" size).
import { chromium } from "file:///C:/Users/Matthew/lastmile/node_modules/playwright/index.mjs";
import { readFileSync, readdirSync, rmSync, mkdirSync } from "fs";

const src = process.argv[2];
const loc = process.argv[3] || "en-US";
const set = process.argv[4];
const out = set ? `C:/Users/Matthew/minder/Store/cpp/${set}` : `C:/Users/Matthew/minder/fastlane/screenshots/${loc}`;
const plan = [
 [
  "idle",
  "Eyes that keep<br>you on task.",
  "Prop it up, slide to focus, <b>get to work.</b>"
 ],
 [
  "work",
  "Slide to focus.",
  "A plan, a timer and check-ins, <b>while they watch.</b>"
 ],
 [
  "suspicious",
  "Picked up your phone?<br>They noticed.",
  "Body doubling for <b>ADHD brains.</b>"
 ],
 [
  "widgets",
  "Lock Screen, Home<br>Screen, Control Center.",
  "A live timer and <b>one-tap focus.</b>"
 ],
 [
  "insights",
  "Know when you<br>focus best.",
  "Best hours, pick-ups, <b>the whole month.</b>"
 ],
 [
  "focus",
  "Goal, streak and<br>where the time went.",
  "Daily, weekly, <b>by tag.</b>"
 ],
 [
  "month",
  "A challenge and new<br>eyes every month.",
  "Something new <b>to chase each month.</b>"
 ],
 [
  "break",
  "Then take a break.",
  "The eyes <b>doze off too.</b>"
 ],
 [
  "galaxy",
  "Make them yours.",
  "Eye packs with <b>matching app icons.</b>"
 ],
 [
  "poster",
  "Share the focus.",
  "A poster of your day, <b>with your eyes on it.</b>"
 ]
];
// Captions for the Japanese, Korean and Chinese store pages; the app screens themselves stay English.
// No price words anywhere (Guideline 2.3.7): not free, not $, not one-time, not subscription.
const L10N = {
 "ja": [
  [
   "idle",
   "作業を見守る<br>ふたつの目。",
   "スマホを立てて、スライドで集中、<b>さあ作業。</b>"
  ],
  [
   "work",
   "スライドで集中。",
   "計画、タイマー、チェックイン。<b>見られながら。</b>"
  ],
  [
   "suspicious",
   "スマホを触った?<br>バレてます。",
   "<b>ADHD</b>のためのボディダブリング。"
  ],
  [
   "widgets",
   "ロック画面から<br>すぐ集中。",
   "ライブタイマーと<b>ワンタップ集中。</b>"
  ],
  [
   "insights",
   "いつ一番<br>集中できる?",
   "ベストな時間帯から<b>1か月まで。</b>"
  ],
  [
   "focus",
   "目標、ストリーク、<br>時間の使い方。",
   "1日、1週間、<b>タグごとに。</b>"
  ],
  [
   "month",
   "毎月のチャレンジと<br>新しい目。",
   "毎月、<b>新しい目標。</b>"
  ],
  [
   "break",
   "そして休憩。",
   "目も<b>うとうと。</b>"
  ],
  [
   "galaxy",
   "自分だけの目に。",
   "アイパックと<b>おそろいのアイコン。</b>"
  ],
  [
   "poster",
   "集中をシェア。",
   "あなたの目が入った<b>1日のポスター。</b>"
  ]
 ],
 "ko": [
  [
   "idle",
   "할 일을 지켜보는<br>두 개의 눈.",
   "폰을 세우고, 밀어서 집중, <b>이제 시작.</b>"
  ],
  [
   "work",
   "밀어서 집중.",
   "계획, 타이머, 체크인. <b>지켜보는 동안.</b>"
  ],
  [
   "suspicious",
   "폰 만졌어요?<br>다 보여요.",
   "<b>ADHD</b>를 위한 바디 더블링."
  ],
  [
   "widgets",
   "잠금 화면, 홈 화면,<br>제어 센터.",
   "라이브 타이머와 <b>원탭 집중.</b>"
  ],
  [
   "insights",
   "언제 가장<br>집중이 잘 될까?",
   "최고의 시간대부터 <b>한 달 전체까지.</b>"
  ],
  [
   "focus",
   "목표, 연속 기록,<br>시간의 흐름.",
   "하루, 한 주, <b>태그별로.</b>"
  ],
  [
   "month",
   "매달 챌린지와<br>새로운 눈.",
   "매달 <b>새로운 목표.</b>"
  ],
  [
   "break",
   "그리고 휴식.",
   "눈도 <b>꾸벅꾸벅.</b>"
  ],
  [
   "galaxy",
   "나만의 눈으로.",
   "아이 팩과 <b>어울리는 앱 아이콘.</b>"
  ],
  [
   "poster",
   "집중을 공유하세요.",
   "내 눈이 담긴 <b>하루 포스터.</b>"
  ]
 ],
 "zh-Hans": [
  [
   "idle",
   "盯着你干活的<br>两只眼睛。",
   "立起手机,滑动专注,<b>开工。</b>"
  ],
  [
   "work",
   "滑动开始专注。",
   "计划、计时和提醒,<b>在它们的注视下。</b>"
  ],
  [
   "suspicious",
   "拿起手机?<br>它们都看见了。",
   "为 <b>ADHD</b> 准备的陪伴专注。"
  ],
  [
   "widgets",
   "锁屏、主屏幕、<br>控制中心。",
   "实时计时和<b>一键专注。</b>"
  ],
  [
   "insights",
   "你什么时候<br>最专注?",
   "最佳时段,<b>整个月一目了然。</b>"
  ],
  [
   "focus",
   "目标、连续记录,<br>时间去哪了。",
   "每天、每周,<b>按标签统计。</b>"
  ],
  [
   "month",
   "每月挑战,<br>每月新眼睛。",
   "每个月都有<b>新目标。</b>"
  ],
  [
   "break",
   "然后休息一下。",
   "眼睛也<b>打个盹。</b>"
  ],
  [
   "galaxy",
   "做成你的眼睛。",
   "眼睛主题包和<b>配套 App 图标。</b>"
  ],
  [
   "poster",
   "分享你的专注。",
   "带着你那双眼睛的<b>每日海报。</b>"
  ]
 ]
};
// Custom Product Page sets (English): same shots, re-ordered and re-captioned per audience.
const CPP = {
  adhd: [
    ["suspicious", "Picked up your phone?<br>They noticed.", "A body double for <b>ADHD brains.</b>"],
    ["work", "Start is the<br>hardest part.", "Slide once. The eyes <b>do the nagging.</b>"],
    ["idle", "Someone to<br>work beside.", "Prop it up, <b>get to it.</b>"],
    ["focus", "Streaks that<br>forgive a bad day.", "A shield covers <b>the day life happens.</b>"],
    ["widgets", "One tap from<br>your Lock Screen.", "Start before <b>the scroll starts.</b>"],
    ["insights", "Learn when your<br>brain shows up.", "Your <b>best hours</b>, mapped."],
  ],
  study: [
    ["work", "The study timer<br>that watches back.", "25, 50 or 90 minutes, <b>eyes on you.</b>"],
    ["insights", "Know when you<br>study best.", "Best hours and <b>the whole month.</b>"],
    ["focus", "Goal, streak, and<br>time per subject.", "Tag it Study, Read, <b>Write.</b>"],
    ["month", "A challenge<br>every month.", "Something to <b>chase all term.</b>"],
    ["break", "Breaks built in.", "The eyes <b>doze off too.</b>"],
    ["widgets", "On your Lock Screen.", "A live timer while <b>you revise.</b>"],
  ],
  cute: [
    ["galaxy", "Galaxy eyes<br>on your desk.", "Packs with <b>matching app icons.</b>"],
    ["happy", "Heart eyes when<br>you're on a roll.", "They <b>react to you.</b>"],
    ["month", "New eyes<br>every month.", "Collect the <b>Eye of the Month.</b>"],
    ["poster", "Share the focus.", "A poster with <b>your eyes on it.</b>"],
    ["idle", "A desk buddy<br>that blinks.", "Tap them. <b>They look.</b>"],
    ["break", "Nap time.", "The eyes <b>doze off too.</b>"],
  ],
};
const steps = set ? CPP[set] : loc === "en-US" ? plan : L10N[loc];
const cjk = { ja: "Noto Sans JP", ko: "Noto Sans KR", "zh-Hans": "Noto Sans SC" }[loc];
const files = readdirSync(src);
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1320, height: 2868 } });
let n = 1;
for (const [key, head, sub] of steps) {
  const f = files.find((x) => x.endsWith(`-${key}.png`));
  if (!f) { console.log("missing", key); continue; }
  const img = readFileSync(`${src}/${f}`).toString("base64");
  await p.setContent(`<!doctype html><html><head>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;800;900&display=block" rel="stylesheet">${cjk ? `
<link href="https://fonts.googleapis.com/css2?family=${cjk.replace(/ /g, "+")}:wght@700;900&display=block" rel="stylesheet">` : ""}
<style>
  body{margin:0;width:1320px;height:2868px;overflow:hidden;background:#000;font-family:Nunito,${cjk ? `"${cjk}",` : ""}sans-serif}
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
