"""Minder 1.3 In-App Events: a feature premiere and the November focus challenge.

    python Store/events.py create <media dir>     events, localizations, card + details art (idempotent)
    python Store/events.py status

<media dir>/<event key>/card.png (1920x1080) and details-<locale>.png (1080x1920) from Store/art/event_art.mjs.
Each event deep links into the matching screen (minderfocus://focus, minderfocus://challenge).
They go to review in the same submission as the version (see Store/submit13.py).
"""
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813451929"
EVENTS = {
    "insights": {
        "ref": "minder 1.3 insights premiere", "badge": "MAJOR_UPDATE", "purchase": "IN_APP_PURCHASE", "deepLink": "minderfocus://focus",
        "purpose": "APPROPRIATE_FOR_ALL_USERS", "priority": "HIGH",
        "schedule": {"publishStart": "2026-10-22T16:00:00Z", "eventStart": "2026-10-24T16:00:00Z", "eventEnd": "2026-11-21T16:00:00Z"},
        "copy": {
            "en-US": ("Find Your Best Focus Hours", "Insights, Lock Screen widgets and more",
                      "See when you focus best, how long your sessions run and your month at a glance, then start from your Lock Screen."),
            "ja": ("集中できる時間帯を発見", "インサイトとロック画面ウィジェット",
                   "いつ一番集中できるか、平均セッション、1か月のカレンダー。ロック画面からすぐ集中を始めよう。"),
            "ko": ("가장 집중 잘 되는 시간 찾기", "인사이트와 잠금 화면 위젯",
                   "언제 가장 집중이 잘 되는지, 평균 세션, 한 달 달력까지. 잠금 화면에서 바로 집중을 시작하세요."),
            "zh-Hans": ("找到你的最佳专注时段", "洞察与锁屏小组件",
                        "看看你什么时候最专注、平均时长和整月日历,还能直接从锁屏开始专注。"),
        },
    },
    "november": {
        "ref": "minder november 2026 challenge", "badge": "CHALLENGE", "purchase": "NO_COST_ASSOCIATED", "deepLink": "minderfocus://challenge",
        "purpose": "APPROPRIATE_FOR_ALL_USERS", "priority": "NORMAL",
        "schedule": {"publishStart": "2026-10-26T16:00:00Z", "eventStart": "2026-11-01T04:00:00Z", "eventEnd": "2026-12-01T04:00:00Z"},
        "copy": {
            "en-US": ("November: Twelve Deep Ones", "Twelve 50-minute sessions this month",
                      "Do twelve sessions of 50 minutes or more in November while the eyes watch. Finish for the trophy."),
            "ja": ("11月チャレンジ:深い集中12回", "50分以上のセッションを12回",
                   "11月中に50分以上のセッションを12回。目に見守られながら達成して、トロフィーを手に入れよう。"),
            "ko": ("11월 챌린지: 깊은 집중 12번", "50분 이상 세션 12번 도전",
                   "11월 한 달 동안 50분 이상 세션 12번. 눈이 지켜보는 동안 완주하고 트로피를 받으세요."),
            "zh-Hans": ("11月挑战:12次深度专注", "本月完成12次50分钟专注",
                        "在11月完成12次50分钟以上的专注,眼睛全程陪着你。完成就能拿到奖杯。"),
        },
    },
}


def upload(lid, kind, f: Path):
    data = f.read_bytes()
    made = asc.call("POST", "/v1/appEventScreenshots", {"data": {"type": "appEventScreenshots",
                    "attributes": {"fileName": f.name, "fileSize": len(data), "appEventAssetType": kind},
                    "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": lid}}}}})
    if not made:
        print("   reserve FAILED", kind); return
    made = made["data"]
    for op in made["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    asc.call("PATCH", f"/v1/appEventScreenshots/{made['id']}", {"data": {"type": "appEventScreenshots", "id": made["id"], "attributes": {"uploaded": True}}})
    print("   uploaded", kind, f.name)


def all_events():
    return asc.call("GET", f"/v1/apps/{APP}/appEvents", params={"limit": 50})["data"]


def create(media: Path):
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    have = {e["attributes"]["referenceName"]: e for e in all_events()}
    for key, ev in EVENTS.items():
        for loc, (n, s, l) in ev["copy"].items():
            assert len(n) <= 30 and len(s) <= 50 and len(l) <= 120, (key, loc, len(n), len(s), len(l))
            assert "—" not in n + s + l
        e = have.get(ev["ref"])
        attrs = {"referenceName": ev["ref"], "badge": ev["badge"], "deepLink": ev["deepLink"], "primaryLocale": "en-US",
                 "priority": ev["priority"], "purpose": ev["purpose"], "purchaseRequirement": ev["purchase"], "territorySchedules": [dict(territories=terr, **ev["schedule"])]}
        if not e:
            r = asc.call("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": attrs,
                         "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
            if not r:
                print(key, "create FAILED"); continue
            e = r["data"]
            print(key, "created", e["id"])
        else:
            asc.call("PATCH", f"/v1/appEvents/{e['id']}", {"data": {"type": "appEvents", "id": e["id"], "attributes": attrs}})
            print(key, "exists", e["id"], e["attributes"]["eventState"])
        locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/appEvents/{e['id']}/localizations")["data"]}
        for loc, (n, s, l) in ev["copy"].items():
            a = {"name": n, "shortDescription": s, "longDescription": l}
            if loc in locs:
                asc.call("PATCH", f"/v1/appEventLocalizations/{locs[loc]['id']}", {"data": {"type": "appEventLocalizations", "id": locs[loc]["id"], "attributes": a}})
            else:
                made = asc.call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations", "attributes": dict(locale=loc, **a),
                                "relationships": {"appEvent": {"data": {"type": "appEvents", "id": e["id"]}}}}})
                if not made:
                    print(" ", loc, "l10n FAILED"); continue
                locs[loc] = made["data"]
            lid = locs[loc]["id"]
            got = {x["attributes"]["appEventAssetType"] for x in asc.call("GET", f"/v1/appEventLocalizations/{lid}/appEventScreenshots")["data"]}
            for kind, f in (("EVENT_CARD", media / key / "card.png"), ("EVENT_DETAILS_PAGE", media / key / f"details-{loc}.png")):
                if kind not in got and f.exists():
                    upload(lid, kind, f)
            print(" ", loc, "ok")


def status():
    for e in all_events():
        a = e["attributes"]
        print(e["id"], a["referenceName"], a["eventState"], a.get("badge"), a.get("deepLink"))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "create":
        create(Path(sys.argv[2]))
    else:
        status()
