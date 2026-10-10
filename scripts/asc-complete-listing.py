#!/usr/bin/env python3
"""Fill the App Store Connect fields fastlane deliver does not create for a first version.

Sets the age rating questionnaire, free app price, categories, copyright, content rights, and the
App Review contact on the editable version. The review phone comes from
ASC_REVIEW_PHONE so it never lives in this repository.
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_lib as A

BUNDLE_ID = "com.jackwallner.sunset"
META = Path(__file__).resolve().parent.parent / "fastlane" / "metadata" / "en-US"

AGE_RATING = {
    "advertising": False, "gambling": False, "healthOrWellnessTopics": False,
    "lootBox": False, "messagingAndChat": False, "parentalControls": False,
    "ageAssurance": False, "unrestrictedWebAccess": False, "userGeneratedContent": False,
    **{key: "NONE" for key in (
        "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated",
        "gunsOrOtherWeapons", "medicalOrTreatmentInformation", "profanityOrCrudeHumor",
        "sexualContentGraphicAndNudity", "sexualContentOrNudity", "horrorOrFearThemes",
        "matureOrSuggestiveThemes", "violenceCartoonOrFantasy",
        "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic")},
}

REVIEW_NOTES = (
    "Sunset scores each sunrise and sunset from the Open-Meteo forecast. No account or login is needed. "
    "Onboarding asks for approximate location (used only to fetch the forecast with rounded coordinates), "
    "lets you pick sunrise, sunset or both, offers free alerts (notification permission), then shows the Sun+ "
    "offer with a Not now button. Free: today and tomorrow, the factor breakdown, the widget, and sunrise and "
    "sunset alerts at the default score. Sun+ (monthly and yearly subscriptions with a one-week free trial, plus "
    "a lifetime purchase) adds the full week (shown blurred when free), thunderstorm, rainbow and fog alerts, and "
    "a custom alert score and lead time. Restore purchases, Privacy Policy, Terms and the Apple Standard EULA are "
    "on the paywall and in Settings. Scores are forecasts, not promises."
)


def ensure_free_pricing(c: A.ASCClient, app_id: str) -> None:
    has_manual = False
    try:
        sched = c.get(f"/apps/{app_id}/appPriceSchedule")
        sched_id = (sched.get("data") or {}).get("id")
        if sched_id:
            mp = c.get(f"/appPriceSchedules/{sched_id}/manualPrices")
            has_manual = bool(mp.get("data"))
    except RuntimeError as e:
        if "404" not in str(e):
            raise
    if has_manual:
        print("app price schedule already has manual prices")
        return

    points = A.list_all(c, f"/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")
    free = min(
        (p for p in points if float(p["attributes"]["customerPrice"]) == 0.0),
        key=lambda p: p["id"],
        default=None,
    )
    if not free:
        raise SystemExit("error: no free USA app price point")
    c.post(
        "/appPriceSchedules",
        {
            "data": {
                "type": "appPriceSchedules",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "appPrices", "id": "${price0}"}]},
                },
            },
            "included": [
                {
                    "type": "appPrices",
                    "id": "${price0}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "appPricePoint": {
                            "data": {"type": "appPricePoints", "id": free["id"]}
                        },
                    },
                }
            ],
        },
    )
    print("app price set to free (USA base)")


def meta(field: str) -> str:
    return (META / f"{field}.txt").read_text().strip()


def main() -> None:
    phone = os.environ.get("ASC_REVIEW_PHONE")
    if not phone:
        raise SystemExit("error: set ASC_REVIEW_PHONE")
    c = A.ASCClient.from_credentials()
    app = A.find_app(c, BUNDLE_ID)
    version = A.find_editable_version(c, app["id"])
    info = A.find_editable_app_info(c, app["id"])

    decl = c.get(f"/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    c.patch(f"/ageRatingDeclarations/{decl['id']}", {"data": {
        "type": "ageRatingDeclarations", "id": decl["id"], "attributes": AGE_RATING}})
    print("age rating set")

    c.patch(f"/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "WEATHER"}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": "PHOTO_AND_VIDEO"}},
    }}})
    print("categories set")

    c.patch(f"/apps/{app['id']}", {"data": {"type": "apps", "id": app["id"], "attributes": {
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    c.patch(f"/appStoreVersions/{version['id']}", {"data": {
        "type": "appStoreVersions", "id": version["id"],
        "attributes": {"copyright": meta("copyright"), "releaseType": "MANUAL"}}})
    print("copyright, content rights, manual release set")

    review = {
        "contactFirstName": "Jack", "contactLastName": "Wallner",
        "contactEmail": "jackwallner@gmail.com", "contactPhone": phone,
        "demoAccountRequired": False, "notes": REVIEW_NOTES,
    }
    existing = c.get(f"/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    if existing:
        c.patch(f"/appStoreReviewDetails/{existing['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": existing["id"], "attributes": review}})
    else:
        c.post("/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": review,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    print("review contact set")

    ensure_free_pricing(c, app["id"])


if __name__ == "__main__":
    main()
