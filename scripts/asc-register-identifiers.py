#!/usr/bin/env python3
"""Register the Sunset bundle IDs and enable their capabilities."""
from __future__ import annotations

import urllib.parse

import asc_lib


IDENTIFIERS = {
    "com.jackwallner.sunset": ("Sunset Forecast", {"APP_GROUPS", "IN_APP_PURCHASE"}),
    "com.jackwallner.sunset.widget": ("Sunset Widget", {"APP_GROUPS"}),
}


def ensure_bundle_id(client: asc_lib.ASCClient, identifier: str, name: str) -> dict:
    quoted = urllib.parse.quote(identifier, safe="")
    found = client.get(f"/bundleIds?filter[identifier]={quoted}").get("data", [])
    if found:
        print(f"bundle id exists: {identifier}")
        return found[0]
    created = client.post(
        "/bundleIds",
        {"data": {"type": "bundleIds", "attributes": {"identifier": identifier, "name": name, "platform": "IOS"}}},
    )["data"]
    print(f"bundle id created: {identifier}")
    return created


def ensure_capabilities(client: asc_lib.ASCClient, bundle_id: dict, required: set[str]) -> None:
    bundle_id_id = bundle_id["id"]
    existing = asc_lib.list_all(client, f"/bundleIds/{bundle_id_id}/bundleIdCapabilities")
    enabled = {item["attributes"]["capabilityType"] for item in existing}
    for capability in sorted(required - enabled):
        client.post(
            "/bundleIdCapabilities",
            {
                "data": {
                    "type": "bundleIdCapabilities",
                    "attributes": {"capabilityType": capability},
                    "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_id_id}}},
                }
            },
        )
        print(f"  enabled {capability}")


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    for identifier, (name, capabilities) in IDENTIFIERS.items():
        ensure_capabilities(client, ensure_bundle_id(client, identifier, name), capabilities)


if __name__ == "__main__":
    main()
