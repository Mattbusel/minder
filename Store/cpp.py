"""Custom Product Pages for Minder 1.3: three audiences, each with its own screenshots and promotional text.

    python Store/cpp.py create      pages, en-US localization, screenshots from Store/cpp/<key>/*.png (idempotent)
    python Store/cpp.py keywords    assign search keywords to each page (if the API allows)
    python Store/cpp.py status

Screenshots come from `node Store/art/frame.mjs <shots> en-US <key>` (no price words).
"""
import hashlib
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813451929"
ROOT = Path(__file__).resolve().parent
PAGES = {
    "adhd": ("ADHD body double", "A body double for ADHD brains: two eyes that keep you on task, notice when you pick up your phone, and look proud when you finish.",
             ["accountability", "concentration", "productivity", "streak"]),
    "study": ("Study timer", "The study timer that watches back. Plan 25, 50 or 90 minutes, take breaks, keep a streak and see when you study best.",
              ["pomodoro", "homework", "deep work", "concentration"]),
    "cute": ("Cute focus eyes", "Make the eyes yours: galaxy pupils, heart eyes, cat eyes and a new look every month, all watching you get things done.",
             ["widget", "streak", "productivity"]),
}
DISPLAY = "APP_IPHONE_67"


def pages():
    return (asc.call("GET", f"/v1/apps/{APP}/appCustomProductPages", params={"limit": 50}) or {"data": []})["data"]


def localization(page_id):
    vers = asc.call("GET", f"/v1/appCustomProductPages/{page_id}/appCustomProductPageVersions")["data"]
    v = vers[0]
    locs = asc.call("GET", f"/v1/appCustomProductPageVersions/{v['id']}/appCustomProductPageLocalizations")["data"]
    return v, next((l for l in locs if l["attributes"]["locale"] == "en-US"), None)


def upload_set(loc_id, files):
    sets = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc_id}/appScreenshotSets")["data"]
    s = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == DISPLAY), None)
    if s:
        old = asc.call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots", params={"limit": 20})["data"]
        if [o["attributes"].get("sourceFileChecksum") for o in old] == [hashlib.md5(f.read_bytes()).hexdigest() for f in files]:
            print("   screenshots MATCH"); return
        for o in old:
            asc.call("DELETE", f"/v1/appScreenshots/{o['id']}")
    else:
        s = asc.call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY},
                     "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc_id}}}}})["data"]
    for f in files:
        data = f.read_bytes()
        r = asc.call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                     "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": s["id"]}}}}})["data"]
        for op in r["attributes"]["uploadOperations"]:
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        asc.call("PATCH", f"/v1/appScreenshots/{r['id']}", {"data": {"type": "appScreenshots", "id": r["id"],
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"   uploaded {len(files)} screenshots")


def create():
    have = {p["attributes"]["name"]: p for p in pages()}
    for key, (name, promo, _) in PAGES.items():
        assert len(promo) <= 170 and "—" not in promo
        p = have.get(name)
        if not p:
            r = asc.call("POST", "/v1/appCustomProductPages", {
                "data": {"type": "appCustomProductPages", "attributes": {"name": name},
                         "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                                           "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
                "included": [
                    {"type": "appCustomProductPageVersions", "id": "${v1}",
                     "relationships": {"appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": "${l1}"}]}}},
                    {"type": "appCustomProductPageLocalizations", "id": "${l1}", "attributes": {"locale": "en-US", "promotionalText": promo}}]})
            if not r:
                print(key, "create FAILED"); continue
            p = r["data"]
            print(key, "created", p["id"])
            time.sleep(3)
        else:
            print(key, "exists", p["id"])
        v, loc = localization(p["id"])
        asc.call("PATCH", f"/v1/appCustomProductPageLocalizations/{loc['id']}", {"data": {"type": "appCustomProductPageLocalizations",
                 "id": loc["id"], "attributes": {"promotionalText": promo}}}, quiet=True)
        files = sorted((ROOT / "cpp" / key).glob("*.png"))
        if files:
            upload_set(loc["id"], files)
        print("  version", v["id"], v["attributes"].get("state"))


def keywords():
    have = {p["attributes"]["name"]: p for p in pages()}
    for key, (name, _, kws) in PAGES.items():
        p = have.get(name)
        if not p:
            continue
        _, loc = localization(p["id"])
        r = asc.call("POST", f"/v1/appCustomProductPageLocalizations/{loc['id']}/relationships/searchKeywords",
                     {"data": [{"type": "appKeywords", "id": k} for k in kws]})
        print(key, "keywords", "set" if r is not None else "FAILED")


def status():
    for p in pages():
        v, loc = localization(p["id"])
        print(p["id"], p["attributes"]["name"], p["attributes"].get("url"), v["attributes"].get("state"))


if __name__ == "__main__":
    {"create": create, "keywords": keywords, "status": status}.get(sys.argv[1] if len(sys.argv) > 1 else "status", status)()
