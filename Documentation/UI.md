# UI

`GaiaScreen` provides a **3D Map** tab and a **Catalogue** tab on iOS. The [3D map](3D.md) opens first and supports orbiting, zooming, Galactic context and star details. The catalogue keeps the star list and star detail in its own `NavigationStack`.

## Star list

[`StarListScreen`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L4) is the root screen of the Catalogue tab, titled "Nearby Stars".

- The list shows `StarListViewModel.stars`, one [`StarRow`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L42) per star.
- The search field binds to `searchText`, with the prompt "Name or Gaia source ID".
- A toolbar picker binds to `sort` and offers Distance, Brightness and Name.
- When loading fails, a "Catalogue unavailable" placeholder covers the list.
- Tapping a row pushes `StarDetailScreen` through `navigationDestination(for: Star.self)`.

### Row

A row shows a colour dot, the title, the G magnitude with 2 decimals, and the distance in light-years with 2 decimals. A star without a magnitude shows "No magnitude". Long titles truncate in the middle.

> See [`StarRow.UI`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L70-L75)

### Colour

The map and list share a smooth temperature-based palette: cool stars are orange-red, Sun-like stars warm white, and hot stars blue-white. Gaia effective temperature takes priority; BP−RP supplies a rough fallback. Missing temperature and colour render neutral grey.

See `Model/StarAppearance.swift` for the palette, temperature classes and radius estimates.

## Star detail

[`StarDetailScreen`](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L4) shows one star in four sections, titled with the star's title.

| Section | Rows |
|---|---|
| Star appearance | Approximate temperature class, Gaia radius or estimated radius (solar radii) |
| [Derived](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L10-L15) | Distance, Distance error, Absolute magnitude, Transverse velocity |
| [Position](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L16-L21) | Right ascension, Declination, Galactic longitude, Galactic latitude |
| [Gaia DR3](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L22-L30) | Source ID, Parallax, Proper motion, Magnitude (G), Colour (BP−RP), Temperature, Radial velocity |

Radii show 3 decimals. Other values show 2 decimals, positions and the distance error 4, and the temperature none. A missing value shows as "—".

> See [`StarDetailScreen.row(_:_:unit:digits:)`](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L35-L39) and [`StarDetailScreen.UI`](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L45-L49)
