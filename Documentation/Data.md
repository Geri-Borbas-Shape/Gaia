# Data

## Source

All data comes from Gaia Data Release 3, table `gaiadr3.gaia_source`, queried from the [ESA Gaia archive](https://gea.esac.esa.int/archive/).

[`fetch_catalog.sh`](../Scripts/fetch_catalog.sh#L7-L11) selects every source with a parallax of at least 100 milliarcseconds, which is a distance of at most 10 parsecs, ordered from nearest to farthest. The result has 315 rows.

```bash
./Scripts/fetch_catalog.sh
```

The script overwrites `Packages/Gaia/Sources/Gaia/Resources/nearby_stars.csv`.

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

> See [`CatalogParser.Column`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L11-L14)

Two of the 315 sources have no G magnitude.

## Parsing

[`CatalogParser.stars(from:)`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L18-L39) reads the header first and looks columns up by name, so the column order in the file does not matter.

- A missing column throws `ParseError.missingColumn` with the column name.
- A row that lacks a required value, or has a parallax of zero or less, is skipped and logged as a warning.
- An empty optional field becomes `nil`.

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
