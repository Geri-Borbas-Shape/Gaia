#!/bin/bash
# Refresh the Gaia DR3 sample. Optional argument: radius in parsecs (default 50).
set -euo pipefail

CATALOG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG_DISTANCE="${1:-50}"
CATALOG_PARALLAX="$(python3 - "$CATALOG_DISTANCE" <<'PY'
import math, sys
distance = float(sys.argv[1])
if not math.isfinite(distance) or not 0 < distance <= 100:
    raise SystemExit('Choose a radius between 0 and 100 pc; larger catalogues need streaming.')
print(1000 / distance)
PY
)"
CATALOG_OUTPUT="$CATALOG_ROOT/Packages/Gaia/Sources/Gaia/Resources/nearby_stars.csv"
CATALOG_TEMP="$(mktemp)"
trap 'rm -f "$CATALOG_TEMP"' EXIT

QUERY="SELECT TOP 100000 g.source_id, g.ra, g.dec, g.l, g.b, g.parallax, g.parallax_error, g.pmra, g.pmdec,
  g.phot_g_mean_mag, g.bp_rp, g.teff_gspphot, g.radial_velocity, a.radius_gspphot
FROM gaiadr3.gaia_source AS g
LEFT OUTER JOIN gaiadr3.astrophysical_parameters AS a ON g.source_id = a.source_id
WHERE g.parallax >= $CATALOG_PARALLAX
ORDER BY parallax DESC"

# The mirror serves the same DR3 tables during ESA maintenance.
for CATALOG_ENDPOINT in "${GAIA_TAP_URL:-https://gea.esac.esa.int/tap-server/tap/sync}" \
    "https://gaia.aip.de/tap/sync" "https://gaia.ari.uni-heidelberg.de/tap/sync"; do
    if curl -sS --fail --max-time 120 "$CATALOG_ENDPOINT" \
        --data-urlencode "REQUEST=doQuery" --data-urlencode "LANG=ADQL" \
        --data-urlencode "FORMAT=csv" --data-urlencode "MAXREC=100000" \
        --data-urlencode "QUERY=$QUERY" -o "$CATALOG_TEMP"; then
        if python3 - "$CATALOG_TEMP" "$CATALOG_PARALLAX" <<'PY'
import csv, math, sys
import xml.etree.ElementTree as ET
from pathlib import Path
path = Path(sys.argv[1])
# AIP returns a TABLEDATA VOTable for its default format. Reject errors/overflow
# before converting; a maintenance page must never replace the bundled catalogue.
if path.read_text().lstrip().startswith('<'):
    root = ET.parse(path).getroot()
    if any(info.get('value') != 'OK' for info in root.findall('.//{*}INFO[@name="QUERY_STATUS"]')):
        raise SystemExit('Archive query failed or overflowed; previous file preserved.')
    table = root.find('.//{*}TABLE')
    data = root.find('.//{*}TABLEDATA')
    if table is None or data is None:
        raise SystemExit('Archive did not return a table; trying the next mirror.')
    fields = [field.get('name') for field in table.findall('{*}FIELD')]
    with path.open('w') as output:
        writer = csv.writer(output, lineterminator='\n')
        writer.writerow(fields)
        writer.writerows([[cell.text or '' for cell in row] for row in data])
with path.open() as source:
    reader = csv.DictReader(source)
    required = {'source_id', 'ra', 'dec', 'l', 'b', 'parallax', 'parallax_error', 'pmra', 'pmdec',
                'phot_g_mean_mag', 'bp_rp', 'teff_gspphot', 'radial_velocity', 'radius_gspphot'}
    if not required.issubset(reader.fieldnames or []):
        raise SystemExit('Archive did not return CSV; trying the mirror.')
    rows = list(reader)
if not 0 < len(rows) < 100_000:
    raise SystemExit('Empty or possibly truncated catalogue; previous file preserved.')
if len({row['source_id'] for row in rows}) != len(rows) or any(
    not math.isfinite(float(row['parallax'])) or float(row['parallax']) < float(sys.argv[2]) for row in rows
):
    raise SystemExit('Invalid catalogue; previous file preserved.')
print(f'Validated {len(rows):,} Gaia DR3 sources.')
PY
        then
            mv "$CATALOG_TEMP" "$CATALOG_OUTPUT"
            echo "Wrote catalogue from $CATALOG_ENDPOINT"
            exit 0
        fi
    fi
done
echo "No valid catalogue received; previous file preserved." >&2
exit 1
