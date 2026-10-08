"""Minder 1.2 in-app purchases: Streak Shield and Focus Posters (consumables), the ambience pack and four eye packs.

    python Store/iap2.py create                 make every product (idempotent): text, $0.99, all territories
    python Store/iap2.py shot <kind> <png>      review screenshot for every product of a kind (shield | posters | ambience | pack)
    python Store/iap2.py status                 show each product's state
    python Store/iap2.py submit                 queue every product for the next version submission
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402
import iap  # noqa: E402

PACK_NOTE = ("Non-consumable, one-time. The bag button (top right on the main screen) opens Extras; also Settings > Extras. "
             "Tapping a pack's price buys it: it adds a new iris to the eye designer's colours (usable without Pro), a matching "
             "look, and switches the app icon to match. Restore purchase is in Settings > Minder Pro.")
PRODUCTS = [
    # product id suffix, type, name (30 max), description (55 max), kind, review note
    ("shield", "CONSUMABLE", "Streak Shield", "Covers one missed day so your focus streak holds.", "shield",
     "Consumable. Everyone gets one free shield a month. When a streak of 2+ days misses a day, the main screen shows "
     "'Your N-day streak missed yesterday. Save it?'; tapping opens Focus, where the free shield is offered first and then "
     "Streak Shield for $0.99. Also sold in Extras (bag button). Each purchase covers one missed day."),
    ("posters", "CONSUMABLE", "Focus Posters", "Three shareable posters of your focus, with your eyes.", "posters",
     "Consumable, 3 credits per purchase. The first poster is free. After a session of 5+ minutes a 'Poster' button appears "
     "above the slider; Focus (tap Today at top left) also has 'Make a poster of today'. Each poster made uses one credit, then "
     "it can be shared. Also sold in Extras (bag button)."),
    ("ambience", "NON_CONSUMABLE", "Ambience Pack", "Rain and fireplace sounds for focus, made on the phone.", "ambience",
     "Non-consumable, one-time. Settings > Sound while focusing: Rain and Fireplace show 99c until bought (also in Extras). "
     "The sounds are generated on the device while a session runs. Brown noise is free; pink noise and ocean are Pro."),
    ("pack.galaxy", "NON_CONSUMABLE", "Galaxy Eyes", "A nebula iris, a star-pupil look and its app icon.", "pack", PACK_NOTE),
    ("pack.gilded", "NON_CONSUMABLE", "Gilded Eyes", "A gold iris, a cat-eye look and its app icon.", "pack", PACK_NOTE),
    ("pack.toxic", "NON_CONSUMABLE", "Toxic Eyes", "A neon green iris, a glowing look and its app icon.", "pack", PACK_NOTE),
    ("pack.bloodmoon", "NON_CONSUMABLE", "Blood Moon Eyes", "An ember iris, a late-night look and its app icon.", "pack", PACK_NOTE),
]
PRICE = "0.99"
BASE = "com.mattbusel.minder."


def find(pid: str):
    got = asc.call("GET", f"/v1/apps/{iap.app_id()}/inAppPurchasesV2", params={"filter[productId]": pid, "limit": 10})
    for d in (got or {}).get("data", []):
        if d["attributes"]["productId"] == pid:
            return d
    return None


def create():
    terr = None
    for suffix, kind, name, desc, _, note in PRODUCTS:
        pid = BASE + suffix
        it = find(pid)
        if not it:
            made = asc.call("POST", "/v2/inAppPurchases", {"data": {
                "type": "inAppPurchases",
                "attributes": {"name": name, "productId": pid, "inAppPurchaseType": kind, "reviewNote": note, "familySharable": False},
                "relationships": {"app": {"data": {"type": "apps", "id": iap.app_id()}}}}})
            if not made:
                print(f"{pid}: create FAILED"); continue
            it = made["data"]
        iid = it["id"]
        print(f"{pid}: {iid} {it['attributes'].get('state')}")
        locs = asc.call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations") or {"data": []}
        if not any(l["attributes"]["locale"] == "en-US" for l in locs["data"]):
            r = asc.call("POST", "/v1/inAppPurchaseLocalizations", {"data": {
                "type": "inAppPurchaseLocalizations", "attributes": {"locale": "en-US", "name": name, "description": desc},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
            print("  localization", "added" if r else "FAILED")
        sched = asc.call("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule", quiet=True)
        if not sched or not sched.get("data"):
            points = asc.call("GET", f"/v2/inAppPurchases/{iid}/pricePoints", params={"filter[territory]": "USA", "limit": 200})
            pp = next((d["id"] for d in (points or {}).get("data", []) if d["attributes"].get("customerPrice") == PRICE), None)
            r = pp and asc.call("POST", "/v1/inAppPurchasePriceSchedules", {
                "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p1}"}]}}},
                "included": [{"type": "inAppPurchasePrices", "id": "${p1}", "attributes": {"startDate": None},
                              "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp}}}}]})
            print("  price", f"${PRICE}" if r else "FAILED")
        avail = asc.call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability", quiet=True)
        if not avail or not avail.get("data"):
            terr = terr or [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
            r = asc.call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
                "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
                "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                                  "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", f"{len(terr)} territories" if r else "FAILED")


def shot(kind: str, png: str):
    data = Path(png).read_bytes()
    for suffix, _, _, _, k, _ in PRODUCTS:
        if k != kind:
            continue
        it = find(BASE + suffix)
        if not it:
            continue
        iid = it["id"]
        cur = asc.call("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{cur['data']['id']}")
        made = asc.call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
        if not made:
            print(suffix, "reserve FAILED"); continue
        sid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(suffix, "screenshot", "uploaded" if r else "FAILED")


def status():
    for suffix, *_ in PRODUCTS:
        it = find(BASE + suffix)
        print(f"{BASE + suffix}: {it['id'] + ' ' + it['attributes']['state'] if it else 'missing'}")


def submit():
    for suffix, *_ in PRODUCTS:
        it = find(BASE + suffix)
        if not it:
            continue
        r = asc.call("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
                     "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": it["id"]}}}}})
        print(suffix, "queued" if r else "refused")


def release(version: str = None):
    """Queue every product, then submit the version with them in one review submission."""
    submit()
    aid = iap.app_id()
    version = version or "1.2"
    v = asc.call("GET", f"/v1/apps/{aid}/appStoreVersions", params={"filter[versionString]": version})["data"][0]
    subs = asc.call("GET", "/v1/reviewSubmissions", params={"filter[app]": aid, "filter[state]": "READY_FOR_REVIEW", "filter[platform]": "IOS"})
    sub = subs["data"][0] if subs and subs.get("data") else asc.call("POST", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
    items = asc.call("GET", f"/v1/reviewSubmissions/{sub['id']}/items") or {"data": []}
    if not items["data"]:
        r = asc.call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}})
        print("version item", "added" if r else "FAILED")
    done = asc.call("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("review submission:", "SUBMITTED" if done else "failed")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2], sys.argv[3])
    else:
        {"create": create, "status": status, "submit": submit, "release": release}.get(cmd, lambda: sys.exit(__doc__))()
