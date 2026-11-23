#!/bin/bash
# Downloads the Gaia DR3 sources within 10 parsecs from the ESA Gaia archive.
set -euo pipefail

OUTPUT="$(dirname "$0")/../Packages/Gaia/Sources/Gaia/Resources/nearby_stars.csv"

QUERY="SELECT source_id, ra, dec, l, b, parallax, parallax_error, pmra, pmdec,
  phot_g_mean_mag, bp_rp, teff_gspphot, radial_velocity
FROM gaiadr3.gaia_source
WHERE parallax >= 100
ORDER BY parallax DESC"

curl -sS --fail --max-time 120 "https://gea.esac.esa.int/tap-server/tap/sync" \
  --data-urlencode "REQUEST=doQuery" \
  --data-urlencode "LANG=ADQL" \
  --data-urlencode "FORMAT=csv" \
  --data-urlencode "QUERY=$QUERY" \
  -o "$OUTPUT"

echo "Wrote $(($(wc -l < "$OUTPUT") - 1)) stars to $OUTPUT"
