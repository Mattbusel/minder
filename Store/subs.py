"""Minder Plus: the auto-renewable subscription group (1.3).

    python Store/subs.py create             group + localizations, both subscriptions, text, prices everywhere, availability (idempotent)
    python Store/subs.py trial              1-week free trial on the yearly plan, every territory
    python Store/subs.py shot <png>         review screenshot for both subscriptions
    python Store/subs.py offercode          Pro-owner offer code (custom code PROEYES): first 3 months of Plus free on monthly
    python Store/subs.py winback            win-back offer on monthly (1 month free) for lapsed subscribers
    python Store/subs.py status

Prices: $2.99 a month, $14.99 a year (Apple's equalised price in every other territory).
Pro (com.mattbusel.minder.pro, one-time) is untouched: Plus is a separate group.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6813451929"
GROUP = "Minder Plus"
MONTHLY = "com.mattbusel.minder.plus.monthly"
YEARLY = "com.mattbusel.minder.plus.yearly"

NOTE = ("Auto-renewable subscription, group Minder Plus (monthly and yearly, same level; yearly has a 1-week free trial). "
        "Plus includes everything in Minder Pro (one-time, still sold) plus, while subscribed: every eye pack and the ambience pack, "
        "3 Streak Shields and 5 poster credits added every month, the Eye of the Month look, Insights (best hours, average "
        "session, pick-up trend, month calendar), and iCloud backup of focus history. To see it: tap the bag (top right) > "
        "Minder Plus, or Settings > Minder Plus, or any locked feature. The paywall shows price, period, trial terms, auto-renew "
        "text, Terms of Use (Apple standard EULA) and Privacy links, Restore Purchases and Manage subscription.")

SUBS = [
    # product id, reference name, period, USD, level
    (MONTHLY, "Minder Plus Monthly", "ONE_MONTH", "2.99", 1),
    (YEARLY, "Minder Plus Yearly", "ONE_YEAR", "14.99", 1),
]

# locale: (group display name, {pid: (name, description)})   name <= 30, description <= 45
L10N = {
    "en-US": ("Minder Plus", {MONTHLY: ("Minder Plus Monthly", "Every look, Insights, monthly shields."),
                              YEARLY: ("Minder Plus Yearly", "Every look, Insights, monthly shields.")}),
    "en-GB": ("Minder Plus", {MONTHLY: ("Minder Plus Monthly", "Every look, Insights, monthly shields."),
                              YEARLY: ("Minder Plus Yearly", "Every look, Insights, monthly shields.")}),
    "ja": ("Minder Plus", {MONTHLY: ("Minder Plus 月額", "すべての目、インサイト、毎月のシールド。"),
                           YEARLY: ("Minder Plus 年額", "すべての目、インサイト、毎月のシールド。")}),
    "ko": ("Minder Plus", {MONTHLY: ("Minder Plus 월간", "모든 눈, 인사이트, 매달 실드."),
                           YEARLY: ("Minder Plus 연간", "모든 눈, 인사이트, 매달 실드.")}),
    "zh-Hans": ("Minder Plus", {MONTHLY: ("Minder Plus 月度", "所有眼睛造型、洞察和每月护盾。"),
                                YEARLY: ("Minder Plus 年度", "所有眼睛造型、洞察和每月护盾。")}),
    "es-MX": ("Minder Plus", {MONTHLY: ("Minder Plus mensual", "Todos los ojos, análisis y escudos al mes."),
                              YEARLY: ("Minder Plus anual", "Todos los ojos, análisis y escudos al mes.")}),
    "es-ES": ("Minder Plus", {MONTHLY: ("Minder Plus mensual", "Todos los ojos, análisis y escudos al mes."),
                              YEARLY: ("Minder Plus anual", "Todos los ojos, análisis y escudos al mes.")}),
    "de-DE": ("Minder Plus", {MONTHLY: ("Minder Plus monatlich", "Alle Augen, Insights, Schilde jeden Monat."),
                              YEARLY: ("Minder Plus jährlich", "Alle Augen, Insights, Schilde jeden Monat.")}),
    "fr-FR": ("Minder Plus", {MONTHLY: ("Minder Plus mensuel", "Tous les yeux, statistiques, boucliers."),
                              YEARLY: ("Minder Plus annuel", "Tous les yeux, statistiques, boucliers.")}),
    "pt-BR": ("Minder Plus", {MONTHLY: ("Minder Plus mensal", "Todos os olhos, análises e escudos mensais."),
                              YEARLY: ("Minder Plus anual", "Todos os olhos, análises e escudos mensais.")}),
    "it": ("Minder Plus", {MONTHLY: ("Minder Plus mensile", "Tutti gli occhi, statistiche, scudi mensili."),
                           YEARLY: ("Minder Plus annuale", "Tutti gli occhi, statistiche, scudi mensili.")}),
}


def _terr(point_id):
    import base64, json
    return json.loads(base64.urlsafe_b64decode(point_id + "=" * (-len(point_id) % 4)))["t"]


def group():
    got = asc.call("GET", f"/v1/apps/{APP}/subscriptionGroups", params={"limit": 50}) or {"data": []}
    for g in got["data"]:
        if g["attributes"]["referenceName"] == GROUP:
            return g
    r = asc.call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": GROUP},
                 "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    if not r:
        sys.exit("subscription group create FAILED (Paid Applications agreement?)")
    print("group created", r["data"]["id"])
    return r["data"]


def find(gid, pid):
    got = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 50}) or {"data": []}
    return next((s for s in got["data"] if s["attributes"]["productId"] == pid), None)


def create():
    g = group()
    gid = g["id"]
    print(f"group {GROUP}: {gid}")
    have = {l["attributes"]["locale"]: l for l in (asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations") or {"data": []})["data"]}
    for loc, (gname, _) in L10N.items():
        if loc in have:
            continue
        r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
                     "attributes": {"locale": loc, "name": gname, "customAppName": "Minder"},
                     "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
        print(f"  group l10n {loc}:", "ok" if r else "FAILED")
    terr = None
    for pid, ref, period, usd, level in SUBS:
        s = find(gid, pid)
        if not s:
            r = asc.call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
                "name": ref, "productId": pid, "subscriptionPeriod": period, "familySharable": False,
                "reviewNote": NOTE, "groupLevel": level},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            if not r:
                print(f"{pid}: create FAILED"); continue
            s = r["data"]
        sid = s["id"]
        print(f"{pid}: {sid} {s['attributes'].get('state')}")
        asc.call("PATCH", f"/v1/subscriptions/{sid}", {"data": {"type": "subscriptions", "id": sid, "attributes": {"reviewNote": NOTE}}})
        locs = {l["attributes"]["locale"]: l for l in (asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations") or {"data": []})["data"]}
        for loc, (_, names) in L10N.items():
            name, desc = names[pid]
            if loc in locs:
                asc.call("PATCH", f"/v1/subscriptionLocalizations/{locs[loc]['id']}", {"data": {"type": "subscriptionLocalizations",
                         "id": locs[loc]["id"], "attributes": {"name": name, "description": desc}}}, quiet=True)
                continue
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": loc, "name": name, "description": desc},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
            print(f"  l10n {loc}:", "ok" if r else "FAILED")
        # availability
        av = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
        if not av or not av.get("data"):
            terr = terr or [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
            r = asc.call("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
                         "attributes": {"availableInNewTerritories": True},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                           "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", f"{len(terr)} territories" if r else "FAILED")
        # prices
        cur = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200, "include": "territory"}) or {"data": []}
        priced = {p["relationships"]["territory"]["data"]["id"] for p in cur["data"] if (p.get("relationships", {}).get("territory") or {}).get("data")}
        pts = asc.call("GET", f"/v1/subscriptions/{sid}/pricePoints", params={"filter[territory]": "USA", "limit": 800}) or {"data": []}
        pp = next((p for p in pts["data"] if p["attributes"]["customerPrice"] == usd), None)
        if not pp:
            print(f"  no USA price point {usd}"); continue
        eq = asc.call("GET", f"/v1/subscriptionPricePoints/{pp['id']}/equalizations", params={"limit": 200, "include": "territory"}) or {"data": []}
        points = [p for p in [pp] + eq["data"] if _terr(p["id"]) not in priced]
        if not points:
            print(f"  prices: all {len(priced)} territories set"); continue
        done = 0
        for p in points:
            r = asc.call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
                         "attributes": {"startDate": None, "preserveCurrentPrice": False},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                           "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": p["id"]}}}}}, quiet=True)
            done += bool(r)
        print(f"  prices: {done}/{len(points)} territories at USD {usd} equalised")


def trial():
    g = group()
    s = find(g["id"], YEARLY)
    sid = s["id"]
    cur = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200}) or {"data": []}
    if len(cur["data"]) >= 150:
        print(f"trial: {len(cur['data'])} territories already"); return
    have = set()
    for o in cur["data"]:
        t = (o.get("relationships", {}).get("territory") or {}).get("data")
        if t: have.add(t["id"])
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    ok = 0
    for t in terr:
        if t in have:
            continue
        r = asc.call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
                     "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                       "territory": {"data": {"type": "territories", "id": t}}}}}, quiet=ok > 0)
        ok += bool(r)
    print(f"trial: 1 week free on yearly in {ok + len(have)}/{len(terr)} territories")


def shot(png):
    g = group()
    data = Path(png).read_bytes()
    for pid, *_ in SUBS:
        s = find(g["id"], pid)
        if not s:
            continue
        sid = s["id"]
        cur = asc.call("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{cur['data']['id']}")
        made = asc.call("POST", "/v1/subscriptionAppStoreReviewScreenshots", {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                        "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
        if not made:
            print(pid, "reserve FAILED"); continue
        rid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{rid}", {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                     "id": rid, "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(pid, "review screenshot", "uploaded" if r else "FAILED")


def offercode():
    g = group()
    s = find(g["id"], MONTHLY)
    sid = s["id"]
    cur = asc.call("GET", f"/v1/subscriptions/{sid}/offerCodes", params={"limit": 50}) or {"data": []}
    oc = next((o for o in cur["data"] if o["attributes"]["name"] == "Pro owners"), None)
    if not oc:
        terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
        # free offers still carry one price entry per territory, pointing at nothing
        inc, refs = [], []
        for i, t in enumerate(terr):
            ref = f"${{p{i}}}"
            refs.append({"type": "subscriptionOfferCodePrices", "id": ref})
            inc.append({"type": "subscriptionOfferCodePrices", "id": ref,
                        "relationships": {"territory": {"data": {"type": "territories", "id": t}}}})
        r = asc.call("POST", "/v1/subscriptionOfferCodes", {"data": {"type": "subscriptionOfferCodes", "attributes": {
            "name": "Pro owners", "customerEligibilities": ["NEW", "EXPIRED"], "offerEligibility": "STACK_WITH_INTRO_OFFERS",
            "duration": "THREE_MONTHS", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                              "prices": {"data": refs}}}, "included": inc})
        if not r:
            print("offer code FAILED"); return
        oc = r["data"]
        print("offer code created", oc["id"])
    custom = asc.call("GET", f"/v1/subscriptionOfferCodes/{oc['id']}/customCodes") or {"data": []}
    if any(c["attributes"]["customCode"] == "PROEYES" for c in custom["data"]):
        print("custom code PROEYES exists"); return
    r = asc.call("POST", "/v1/subscriptionOfferCodeCustomCodes", {"data": {"type": "subscriptionOfferCodeCustomCodes",
                 "attributes": {"customCode": "PROEYES", "numberOfCodes": 25000, "expirationDate": "2027-10-18"},
                 "relationships": {"offerCode": {"data": {"type": "subscriptionOfferCodes", "id": oc["id"]}}}}})
    print("custom code PROEYES", "created" if r else "FAILED")


def winback():
    g = group()
    s = find(g["id"], MONTHLY)
    sid = s["id"]
    cur = asc.call("GET", f"/v1/subscriptions/{sid}/winBackOffers", quiet=True) or {"data": []}
    if cur.get("data"):
        print("win-back exists"); return
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    inc, refs = [], []
    for i, t in enumerate(terr):
        ref = f"${{w{i}}}"
        refs.append({"type": "winBackOfferPrices", "id": ref})
        inc.append({"type": "winBackOfferPrices", "id": ref, "relationships": {"territory": {"data": {"type": "territories", "id": t}}}})
    r = asc.call("POST", "/v1/winBackOffers", {"data": {"type": "winBackOffers", "attributes": {
        "referenceName": "Come back to Plus", "offerId": "plus_winback_1m", "duration": "ONE_MONTH", "offerMode": "FREE_TRIAL",
        "periodCount": 1, "customerEligibilityPaidSubscriptionDurationInMonths": 1,
        "customerEligibilityTimeSinceLastSubscribedInMonths": {"minimum": 1, "maximum": 24},
        "customerEligibilityWaitBetweenOffersInMonths": 6, "startDate": "2026-10-20", "priority": "HIGH", "promotionIntent": "NOT_PROMOTED"},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}, "prices": {"data": refs}}}, "included": inc})
    print("win-back", "created" if r else "FAILED")


def status():
    g = group()
    print(f"group {g['id']} {GROUP}")
    for pid, *_ in SUBS:
        s = find(g["id"], pid)
        print(f"  {pid}: {s['id'] + ' ' + s['attributes'].get('state', '?') if s else 'missing'}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2])
    else:
        {"create": create, "trial": trial, "offercode": offercode, "winback": winback, "status": status}.get(cmd, lambda: sys.exit(__doc__))()
