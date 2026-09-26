"""Minder Pro: the one in-app purchase, and the switch from paid to free.

    python Store/iap.py create              # the IAP, its listing, price, availability
    python Store/iap.py screenshot PATH     # review screenshot of the paywall
    python Store/iap.py free                # app price to Free
    python Store/iap.py status

Every step is idempotent: it looks before it makes.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

PRODUCT_ID = "com.mattbusel.minder.pro"
NAME = "Minder Pro"
PRICE = "2.99"
DESCRIPTION = "Every eye look and knob, plus Follow my face."  # 55 chars max
REVIEW_NOTE = (
    "Non-consumable, one-time unlock. The app is free: the eyes, slide to focus, the session timer, the week "
    "and streak, the check-in and the pick-up suspicion are free forever, with three looks (Classic, Robot, "
    "Cat). Pro unlocks the full eye designer (all presets, colours, shapes, pupils, brows, sliders and the dice) "
    "and Follow my face (front camera tracking, on device only). To see the paywall: tap the settings button "
    "(top right), then tap a locked preset, the dice, See Minder Pro under the frosted designer, or the "
    "Follow my face switch. Restore purchase is on the paywall and on the Minder Pro card in Settings."
)


def app_id():
    a = asc.find_app()
    if not a:
        sys.exit("no app record")
    return a["id"]


def find_iap(aid):
    r = asc.call("GET", f"/v1/apps/{aid}/inAppPurchasesV2", params={"filter[productId]": PRODUCT_ID, "limit": 5})
    return (r or {}).get("data", [None])[0] if (r or {}).get("data") else None


def create():
    aid = app_id()
    iap = find_iap(aid)
    if iap:
        print(f"IAP exists: {iap['id']} state={iap['attributes'].get('state')}")
    else:
        r = asc.call("POST", "/v2/inAppPurchases", {"data": {
            "type": "inAppPurchases",
            "attributes": {"name": NAME, "productId": PRODUCT_ID, "inAppPurchaseType": "NON_CONSUMABLE",
                           "reviewNote": REVIEW_NOTE, "familySharable": True},
            "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
        if not r:
            sys.exit("IAP create failed (check the Paid Apps Agreement in App Store Connect > Business)")
        iap = r["data"]
        print(f"IAP created: {iap['id']}")
    iid = iap["id"]
    asc.call("PATCH", f"/v2/inAppPurchases/{iid}", {"data": {"type": "inAppPurchases", "id": iid,
             "attributes": {"reviewNote": REVIEW_NOTE, "familySharable": True}}})

    locs = asc.call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations") or {"data": []}
    en = next((l for l in locs["data"] if l["attributes"]["locale"] == "en-US"), None)
    if en:
        asc.call("PATCH", f"/v1/inAppPurchaseLocalizations/{en['id']}", {"data": {"type": "inAppPurchaseLocalizations",
                 "id": en["id"], "attributes": {"name": NAME, "description": DESCRIPTION}}})
        print("localization updated")
    else:
        r = asc.call("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
                     "attributes": {"locale": "en-US", "name": NAME, "description": DESCRIPTION},
                     "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
        print("localization created" if r else "localization FAILED")

    points = asc.call("GET", f"/v2/inAppPurchases/{iid}/pricePoints", params={"filter[territory]": "USA", "limit": 8000})
    point = next((d["id"] for d in (points or {}).get("data", []) if d["attributes"].get("customerPrice") == PRICE), None)
    if not point:
        sys.exit(f"no USA IAP price point at {PRICE}")
    r = asc.call("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p1}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p1}", "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point}}}}]})
    print(f"price set to ${PRICE}" if r is not None else "price FAILED")

    have = asc.call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability", quiet=True)
    if have and have.get("data"):
        print("availability exists")
    else:
        terr = asc.call("GET", "/v1/territories", params={"limit": 200}) or {"data": []}
        r = asc.call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities",
                     "attributes": {"availableInNewTerritories": True},
                     "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                                       "availableTerritories": {"data": [{"type": "territories", "id": t["id"]} for t in terr["data"]]}}}})
        print(f"availability set ({len(terr['data'])} territories)" if r else "availability FAILED")
    status()


def screenshot(path):
    iid = find_iap(app_id())["id"]
    old = asc.call("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot", quiet=True)
    if old and old.get("data"):
        asc.call("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{old['data']['id']}")
    data = Path(path).read_bytes()
    r = asc.call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": Path(path).name, "fileSize": len(data)},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
    sid = r["data"]["id"]
    for op in r["data"]["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=chunk, timeout=120).raise_for_status()
    r = asc.call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("review screenshot uploaded" if r else "review screenshot FAILED")


def free():
    aid = app_id()
    points = asc.call("GET", f"/v1/apps/{aid}/appPricePoints", params={"filter[territory]": "USA", "limit": 200})
    point = next((d["id"] for d in (points or {}).get("data", []) if float(d["attributes"].get("customerPrice") or 0) == 0), None)
    if not point:
        sys.exit("no free price point")
    r = asc.call("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": aid}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${p1}"}]}}},
        "included": [{"type": "appPrices", "id": "${p1}", "attributes": {"startDate": None, "endDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": point}}}}]})
    print("app price set to Free" if r is not None else "free FAILED")


def status():
    aid = app_id()
    iap = find_iap(aid)
    if iap:
        print(f"IAP {PRODUCT_ID}: {iap['attributes'].get('state')}")
    sched = asc.call("GET", f"/v1/appPriceSchedules/{aid}/manualPrices", params={"include": "appPricePoint", "limit": 5}, quiet=True)
    for inc in (sched or {}).get("included", []):
        if inc["type"] == "appPricePoints":
            print(f"app price now: {inc['attributes'].get('customerPrice')}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    {"create": create, "free": free, "status": status}.get(cmd, lambda: screenshot(sys.argv[2]))()
