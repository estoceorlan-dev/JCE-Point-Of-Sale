# Philippine address catalog

`philippine_address_catalog.json` is an offline subset of the Philippine
Standard Geographic Code (PSGC), containing province/area and
city/municipality names used by the branch form.

- Official source: Philippine Statistics Authority, PSGC 2Q 2026
- Base machine-readable data: `@jobuntux/psgc` 2025-2Q (MIT)
- Generator: `tool/generate_philippine_address_catalog.py`

The generator applies the municipality name corrections published by the PSA
through 30 June 2026 and validates the expected 83 province/area groups and
1,642 city/municipality entries.

PSA site content is available under CC BY 4.0 unless otherwise stated.
