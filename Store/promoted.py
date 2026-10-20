"""Promoted in-app purchases on the product page: Plus yearly, Plus monthly, Galaxy Eyes, Ambience Pack.

    python Store/promoted.py images     upload the 1024x1024 promo images (Store/promo, pack icons)
    python Store/promoted.py promote    create the promoted purchases (visible to all) and set their order
    python Store/promoted.py status
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402
import subs  # noqa: E402

APP = "6813451929"
ROOT = Path(__file__).resolve().parent.parent
ART = {
    subs.YEARLY: ROOT / "Store/promo/plus-yearly.png",
    subs.MONTHLY: ROOT / "Store/promo/plus-monthly.png",
    "com.mattbusel.minder.pack.galaxy": ROOT / "Resources/Assets.xcassets/AppIcon-Galaxy.appiconset/icon-1024.png",
    "com.mattbusel.minder.pack.toxic": ROOT / "Resources/Assets.xcassets/AppIcon-Toxic.appiconset/icon-1024.png",
}
ORDER = [subs.YEARLY, subs.MONTHLY, "com.mattbusel.minder.pack.galaxy", "com.mattbusel.minder.pack.toxic"]


def target(pid):
    """('subscriptions', id) or ('inAppPurchases', id)."""
    if pid.startswith("com.mattbusel.minder.plus."):
        return "subscriptions", subs.find(subs.group()["id"], pid)["id"]
    got = asc.call("GET", f"/v1/apps/{APP}/inAppPurchasesV2", params={"filter[productId]": pid, "limit": 5})
    return "inAppPurchases", got["data"][0]["id"]


def _upload(kind, rel, iid, f: Path):
    data = f.read_bytes()
    made = asc.call("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": {"fileName": f.name, "fileSize": len(data)},
                    "relationships": {rel: {"data": {"type": "subscriptions" if rel == "subscription" else "inAppPurchases", "id": iid}}}}})
    if not made:
        return False
    m = made["data"]
    for op in m["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
    return asc.call("PATCH", f"/v1/{kind}/{m['id']}", {"data": {"type": kind, "id": m["id"],
                    "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}) is not None


def images():
    for pid, f in ART.items():
        typ, iid = target(pid)
        if typ == "subscriptions":
            cur = asc.call("GET", f"/v1/subscriptions/{iid}/images", quiet=True) or {"data": []}
            if cur["data"]:
                print(pid, "image exists", cur["data"][0]["attributes"].get("state")); continue
            print(pid, "image", "uploaded" if _upload("subscriptionImages", "subscription", iid, f) else "FAILED")
        else:
            cur = asc.call("GET", f"/v2/inAppPurchases/{iid}/images", quiet=True) or {"data": []}
            if cur["data"]:
                print(pid, "image exists", cur["data"][0]["attributes"].get("state")); continue
            print(pid, "image", "uploaded" if _upload("inAppPurchaseImages", "inAppPurchase", iid, f) else "FAILED")


def existing():
    got = asc.call("GET", f"/v1/apps/{APP}/promotedPurchases", params={"limit": 50, "include": "inAppPurchaseV2,subscription"}) or {"data": []}
    out = {}
    for p in got["data"]:
        r = p.get("relationships", {})
        for k in ("inAppPurchaseV2", "subscription"):
            d = (r.get(k) or {}).get("data")
            if d:
                out[d["id"]] = p
    return out


def promote():
    have = existing()
    ids = []
    for pid in ORDER:
        typ, iid = target(pid)
        if iid in have:
            ids.append(have[iid]["id"]); print(pid, "already promoted", have[iid]["attributes"].get("state")); continue
        rel = {"subscription": {"data": {"type": "subscriptions", "id": iid}}} if typ == "subscriptions" else \
              {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}
        rel["app"] = {"data": {"type": "apps", "id": APP}}
        r = asc.call("POST", "/v1/promotedPurchases", {"data": {"type": "promotedPurchases",
                     "attributes": {"visibleForAllUsers": True, "enabled": True}, "relationships": rel}})
        print(pid, "promoted" if r else "promote FAILED")
        if r:
            ids.append(r["data"]["id"])
    if ids:
        r = asc.call("PATCH", f"/v1/apps/{APP}/relationships/promotedPurchases", {"data": [{"type": "promotedPurchases", "id": i} for i in ids]})
        print("order", "set" if r is not None else "FAILED")


def status():
    for iid, p in existing().items():
        print(iid, p["id"], p["attributes"])


if __name__ == "__main__":
    {"images": images, "promote": promote, "status": status}.get(sys.argv[1] if len(sys.argv) > 1 else "status", status)()
