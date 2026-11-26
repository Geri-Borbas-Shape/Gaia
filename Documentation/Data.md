# Data

## Source

The bundled sample contains **51,983 Gaia DR3 sources within 50 pc** (parallax ≥ 20 mas), including all 315 sources from the original 10 pc sample. It joins `gaiadr3.gaia_source` with `gaiadr3.astrophysical_parameters` for stellar radii. **14,862** sources have GSP-Phot radius and temperature estimates.

Downloaded on 26 November 2026 from [Gaia@AIP](https://gaia.aip.de/tap/), a Gaia DPAC mirror, while ESA's archive was undergoing maintenance. Table metadata: [Gaia sources](https://gaia.aip.de/metadata/gaiadr3/gaia_source/), [astrophysical parameters](https://gaia.aip.de/metadata/gaiadr3/astrophysical_parameters/).

```bash
./Scripts/fetch_catalog.sh       # 50 pc
./Scripts/fetch_catalog.sh 25    # smaller sample
```

The script tries ESA and Gaia mirrors, accepts CSV or TABLEDATA VOTables, and validates the response before replacing `nearby_stars.csv`. It rejects query errors, overflow, duplicate IDs and empty results. The 100,000-row safety cap prevents silently bundling a truncated larger sample. Full Gaia coverage will need spatial streaming rather than a larger CSV.

Distances are inverse parallaxes, without quality or extinction corrections. Some sources have uncertain astrometry; this is an exploratory view, not a volume-complete census.

Gaia's detectors saturate on the brightest stars, so Sirius A, Alpha Centauri A and B, Procyon and Vega are not in the table. Sirius B, a white dwarf, is.

## Columns

| Column | `Star` property | Unit | Required |
|---|---|---|---|
| `source_id` | `id` | | Yes |
| `ra` | `rightAscension` | degrees | Yes |
| `dec` | `declination` | degrees | Yes |
| `l` | `galacticLongitude` | degrees | Yes |
| `b` | `galacticLatitude` | degrees | Yes |
| `parallax` | `parallax` | mas | Yes |
| `parallax_error` | `parallaxError` | mas | Yes |
| `pmra`, `pmdec` | `properMotion` | mas/yr | Yes |
| `phot_g_mean_mag` | `magnitude` | mag | No |
| `bp_rp` | `colorIndex` | mag | No |
| `teff_gspphot` | `effectiveTemperature` | K | No |
| `radial_velocity` | `radialVelocity` | km/s | No |
| `radius_gspphot` | `radiusInSolarRadii` | solar radii | No |

> See [`CatalogParser.Column`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L11-L14)

Photometry and astrophysical parameters are incomplete. Missing values remain optional.

## Parsing

[`CatalogParser.stars(from:)`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L18-L39) reads the header first and looks columns up by name, so the column order in the file does not matter.

- A missing original column throws `ParseError.missingColumn`. The new radius column is optional for compatibility with earlier exports.
- A row that lacks a required value, or has a parallax of zero or less, is skipped and logged as a warning.
- Empty or non-finite optional numbers become `nil`.

> See [`CatalogParser.star(from:)`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L65-L94)

Fields are split on commas. The Gaia export has no quoted fields, so the parser does not handle quotes.

## Names

Gaia carries no star names. [`StarNames.bySourceID`](../Packages/Gaia/Sources/Gaia/Data/StarNames.swift#L8) is a hand-kept table of 32 common names keyed by source identifier. A star without an entry shows as `Gaia DR3 <source_id>`.

> See [`Star.title`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L47-L49)

## Queries

[`StarRepository.stars(matching:within:sortedBy:)`](../Packages/Gaia/Sources/Gaia/Data/StarRepository.swift#L36-L45) filters and sorts the loaded stars.

| Parameter | Default | Behaviour |
|---|---|---|
| `searchText` | `""` | Empty text matches every star |
| `maximumDistance` | [`defaultMaximumDistance`](../Packages/Gaia/Sources/Gaia/Data/StarRepository.swift#L19), 8 parsecs | Keeps stars at or within the distance |
| `sort` | `.distance` | See below |

Search is case-insensitive on the title and also matches any part of the source identifier.

> See [`Star.matches(_:)`](../Packages/Gaia/Sources/Gaia/Data/StarRepository.swift#L63-L65)

`StarRepository.Sort` has three cases.

- `.distance`: nearest first
- `.brightness`: lowest G magnitude first, stars without a magnitude last
- `.name`: named stars alphabetically, then unnamed stars by source identifier

> See [`StarRepository.Sort.areInIncreasingOrder`](../Packages/Gaia/Sources/Gaia/Data/StarRepository.swift#L52-L58)

The immutable bundled catalogue is parsed once and shared by the map and list. Loading starts off the main thread; the map reads all sources, independently of the list’s 8 pc filter.
