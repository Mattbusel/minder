"""Submit the current version together with every in-app purchase that is ready.

Apple refuses a first non-consumable on its own ("must be submitted at the same time that
you submit an app version"), and fastlane's submit only sends the version. This opens a
review submission with the version in it, adds the purchases while it is still a draft,
then submits the lot.

    python Store/submit.py            # attach the newest valid build, then submit
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402


def main():
    app = asc.find_app()
    aid = app["id"]
    version = asc.ensure_version(aid)
    vid = version["id"]
    vs = version["attributes"]["versionString"]
    print(f"version {vs}: {version['attributes'].get('appStoreState')}")

    builds = asc.call("GET", "/v1/builds", params={"filter[app]": aid, "filter[preReleaseVersion.version]": vs,
                                                   "filter[processingState]": "VALID", "sort": "-uploadedDate", "limit": 1})
    if not builds or not builds["data"]:
        sys.exit(f"no valid build for {vs} yet")
    bid = builds["data"][0]["id"]
    print(f"build {builds['data'][0]['attributes']['version']} ({bid})")
    asc.call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": bid}})

    notes = asc.read_meta("release_notes.txt")
    locs = asc.call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations") or {"data": []}
    for loc in locs["data"]:
        if loc["attributes"]["locale"] == asc.PRIMARY_LOCALE and notes and loc["attributes"].get("whatsNew") != notes:
            asc.call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": notes}}})
            print("release notes set")

    # Reuse an open draft submission if one exists, otherwise start one.
    open_subs = asc.call("GET", "/v1/reviewSubmissions", params={"filter[app]": aid, "filter[platform]": "IOS",
                                                                 "filter[state]": "READY_FOR_REVIEW"}) or {"data": []}
    if open_subs["data"]:
        sid = open_subs["data"][0]["id"]
    else:
        sid = asc.call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
                       "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]["id"]
    print(f"review submission {sid}")
    items = asc.call("GET", f"/v1/reviewSubmissions/{sid}/items", params={"include": "appStoreVersion"}) or {"data": []}
    if not any((i["relationships"].get("appStoreVersion", {}).get("data") or {}).get("id") == vid for i in items["data"]):
        r = asc.call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        if not r:
            sys.exit("could not add the version to the submission")
    print("version in the submission")

    iaps = asc.call("GET", f"/v1/apps/{aid}/inAppPurchasesV2", params={"limit": 50}) or {"data": []}
    for iap in iaps["data"]:
        if iap["attributes"].get("state") != "READY_TO_SUBMIT":
            continue
        r = asc.call("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
                     "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap["id"]}}}}})
        if not r:
            sys.exit(f"IAP {iap['attributes']['productId']} refused; the version was NOT submitted")
        print(f"IAP {iap['attributes']['productId']} added")

    r = asc.call("PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid,
                 "attributes": {"submitted": True}}})
    print("SUBMITTED" if r else "submit failed")


if __name__ == "__main__":
    main()
