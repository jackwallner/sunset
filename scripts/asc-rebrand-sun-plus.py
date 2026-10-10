#!/usr/bin/env python3
"""Rename the customer-facing products to Sun+ and refresh their review notes.

Idempotent. Reference names (Sunset Plus ...) are internal and immutable, so
only localizations and review notes change. Product IDs stay the same.
"""
from __future__ import annotations

import sys
from contextlib import contextmanager
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.sunset"
GROUP_NAME = "Sun+"
REVIEW_NOTE = (
    "Unlocks Sun+: the full seven-day sunrise and sunset outlook, alerts before "
    "thunderstorms, rainbow chances and fog, and a custom alert score and lead time. "
    "Today's and tomorrow's scores, the factor breakdown, sunrise and sunset alerts at "
    "the default score, and the Home Screen widget are free."
)
NAMES = {
    "com.jackwallner.sunset.yearly": ("Sun+ Yearly", "Yearly access to Sun+."),
    "com.jackwallner.sunset.monthly": ("Sun+ Monthly", "Monthly access to Sun+."),
    "com.jackwallner.sunset.lifetime": ("Sun+ Lifetime", "Unlock Sun+ forever. One payment."),
}


@contextmanager
def v2():
    """In-app purchases are a v2 resource; the client prefixes v1."""
    v1 = asc_lib.API
    asc_lib.API = v1.replace("/v1", "/v2")
    try:
        yield
    finally:
        asc_lib.API = v1


def patch_localizations(c: asc_lib.ASCClient, path: str, res_type: str, name: str, description: str | None,
                        listed: list[dict] | None = None) -> None:
    for loc in listed if listed is not None else asc_lib.list_all(c, path):
        attrs = loc["attributes"]
        wanted = {"name": name}
        if description is not None:
            wanted["description"] = description
        if all(attrs.get(k) == v for k, v in wanted.items()):
            print(f"  {attrs.get('locale')}: already {name}")
            continue
        c.patch(f"/{res_type}/{loc['id']}", {"data": {"type": res_type, "id": loc["id"], "attributes": wanted}})
        print(f"  {attrs.get('locale')}: -> {name}")


def main() -> None:
    c = asc_lib.ASCClient.from_credentials()
    app_id = asc_lib.find_app(c, BUNDLE)["id"]

    for group in asc_lib.list_all(c, f"/apps/{app_id}/subscriptionGroups"):
        print(f"group {group['attributes']['referenceName']}")
        patch_localizations(c, f"/subscriptionGroups/{group['id']}/subscriptionGroupLocalizations",
                            "subscriptionGroupLocalizations", GROUP_NAME, None)
        for sub in asc_lib.list_all(c, f"/subscriptionGroups/{group['id']}/subscriptions"):
            pid = sub["attributes"]["productId"]
            name, description = NAMES[pid]
            print(pid)
            patch_localizations(c, f"/subscriptions/{sub['id']}/subscriptionLocalizations",
                                "subscriptionLocalizations", name, description)
            if sub["attributes"].get("reviewNote") != REVIEW_NOTE:
                c.patch(f"/subscriptions/{sub['id']}", {"data": {"type": "subscriptions", "id": sub["id"],
                                                                 "attributes": {"reviewNote": REVIEW_NOTE}}})
                print("  review note updated")

    for iap in asc_lib.list_all(c, f"/apps/{app_id}/inAppPurchasesV2"):
        pid = iap["attributes"]["productId"]
        name, description = NAMES[pid]
        print(pid)
        with v2():
            locs = asc_lib.list_all(c, f"/inAppPurchases/{iap['id']}/inAppPurchaseLocalizations")
        patch_localizations(c, "", "inAppPurchaseLocalizations", name, description, listed=locs)
        if iap["attributes"].get("reviewNote") != REVIEW_NOTE:
            with v2():
                c.patch(f"/inAppPurchases/{iap['id']}",
                        {"data": {"type": "inAppPurchases", "id": iap["id"], "attributes": {"reviewNote": REVIEW_NOTE}}})
            print("  review note updated")


if __name__ == "__main__":
    main()
