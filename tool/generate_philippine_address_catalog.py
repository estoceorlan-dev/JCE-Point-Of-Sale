"""Generate the offline province/area and locality catalog used by branch forms."""

from __future__ import annotations

import json
from pathlib import Path
from urllib.request import Request, urlopen


PACKAGE_VERSION = "0.2.1"
SOURCE_RELEASE = "2025-2Q"
TARGET_RELEASE = "2Q 2026"
BASE_URL = (
    f"https://unpkg.com/@jobuntux/psgc@{PACKAGE_VERSION}/data/"
    f"{SOURCE_RELEASE}"
)

# PSA releases after 2025-2Q changed three municipality names. No province,
# city, or municipality records were added or removed through 2026-2Q.
NAME_CORRECTIONS = {
    "0201522000": "Sanchez Mira",
    "1004217000": "Don Victoriano",
    "1102324000": "Sawata",
}

# Highly urbanized cities are province-level in PSGC. For the branch address
# form, group them under their commonly used geographic province.
HUC_PARENT_AREA = {
    "City of Angeles": "Pampanga",
    "City of Bacolod": "Negros Occidental",
    "City of Baguio": "Benguet",
    "City of Butuan": "Agusan del Norte",
    "City of Cagayan De Oro": "Misamis Oriental",
    "City of Cebu": "Cebu",
    "City of Davao": "Davao del Sur",
    "City of General Santos": "South Cotabato",
    "City of Iligan": "Lanao del Norte",
    "City of Iloilo": "Iloilo",
    "City of Lapu-Lapu": "Cebu",
    "City of Lucena": "Quezon",
    "City of Mandaue": "Cebu",
    "City of Olongapo": "Zambales",
    "City of Puerto Princesa": "Palawan",
    "City of Tacloban": "Leyte",
    "City of Zamboanga": "Zamboanga del Sur",
}

SPECIAL_PARENT_AREA = {
    "817": "Metro Manila",
    "901": "Basilan",
    "999": "Maguindanao del Sur",
}


def fetch_json(name: str) -> list[dict[str, object]]:
    request = Request(
        f"{BASE_URL}/{name}.json",
        headers={"User-Agent": "JCE-POS-address-catalog-generator"},
    )
    with urlopen(request) as response:
        return json.load(response)


def main() -> None:
    provinces = fetch_json("provinces")
    municipalities = fetch_json("muncities")

    standard_provinces = {
        str(item["provCode"]): item
        for item in provinces
        if item.get("cityClass") is None
    }
    hucs = {
        str(item["provCode"]): item
        for item in provinces
        if item.get("cityClass") == "HUC"
    }
    areas: dict[str, list[dict[str, str]]] = {
        str(item["provName"]).strip(): []
        for item in standard_provinces.values()
    }
    areas["Metro Manila"] = []

    for item in municipalities:
        psgc_code = str(item["psgcCode"])
        region_code = str(item["regCode"])
        province_code = str(item["provCode"])

        # Exclude Manila's fourteen sub-municipalities. The app stores a
        # city/municipality, and these are districts below the City of Manila.
        if region_code == "13" and len(psgc_code) == 10 and province_code != "817":
            continue

        if province_code in standard_provinces:
            area_name = str(standard_provinces[province_code]["provName"]).strip()
        elif province_code in hucs:
            huc_name = str(hucs[province_code]["provName"]).strip()
            if region_code == "13":
                area_name = "Metro Manila"
            else:
                area_name = HUC_PARENT_AREA[huc_name]
            if len(psgc_code) != 10:
                psgc_code = str(hucs[province_code]["psgcCode"])
        else:
            area_name = SPECIAL_PARENT_AREA[province_code]

        locality_name = NAME_CORRECTIONS.get(
            psgc_code,
            str(item["munCityName"]).strip(),
        )
        areas[area_name].append({"code": psgc_code, "name": locality_name})

    for localities in areas.values():
        localities.sort(key=lambda item: item["name"].casefold())

    catalog = {
        "country": "Philippines",
        "timezone": "Asia/Manila",
        "release": TARGET_RELEASE,
        "source": "Philippine Statistics Authority PSGC",
        "areas": [
            {"name": name, "localities": localities}
            for name, localities in sorted(
                areas.items(), key=lambda item: item[0].casefold()
            )
        ],
    }

    locality_count = sum(len(item["localities"]) for item in catalog["areas"])
    if len(catalog["areas"]) != 83 or locality_count != 1642:
        raise RuntimeError(
            "Unexpected PSGC catalog size: "
            f"{len(catalog['areas'])} areas, {locality_count} localities"
        )

    output = (
        Path(__file__).resolve().parents[1]
        / "assets"
        / "data"
        / "philippine_address_catalog.json"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {output} ({locality_count} localities)")


if __name__ == "__main__":
    main()
