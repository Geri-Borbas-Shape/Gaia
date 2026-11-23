# UI

Two screens in one `NavigationStack`: the star list and the star detail.

## Star list

[`StarListScreen`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L4) is the root screen, titled "Nearby Stars".

- The list shows `StarListViewModel.stars`, one [`StarRow`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L42) per star.
- The search field binds to `searchText`, with the prompt "Name or Gaia source ID".
- A toolbar picker binds to `sort` and offers Distance, Brightness and Name.
- When loading fails, a "Catalogue unavailable" placeholder covers the list.
- Tapping a row pushes `StarDetailScreen` through `navigationDestination(for: Star.self)`.

### Row

A row shows a colour dot, the title, the G magnitude with 1 decimal, and the distance in light-years with 2 decimals. A star without a magnitude shows "No magnitude". Long titles truncate in the middle.

> See [`StarRow.UI`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L70-L75)

### Colour

The dot colour approximates the star's colour from its BP−RP colour index.

| BP−RP | Colour |
|---|---|
| Below 0.0 | Blue |
| 0.0 to 0.5 | Blue-white |
| 0.5 to 0.8 | White |
| 0.8 to 1.2 | Yellow |
| 1.2 to 1.8 | Orange |
| 1.8 and above | Red |
| Missing | Gray |

> See [`Star.color`](../Packages/Gaia/Sources/Gaia/UI/StarColor.swift#L6-L16)

## Star detail

[`StarDetailScreen`](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L4) shows one star in three sections, titled with the star's title.

| Section | Rows |
|---|---|
| [Derived](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L10-L14) | Distance, Absolute magnitude, Transverse velocity |
| [Position](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L15-L20) | Right ascension, Declination, Galactic longitude, Galactic latitude |
| [Gaia DR3](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L21-L29) | Source ID, Parallax, Proper motion, Magnitude (G), Colour (BP−RP), Temperature, Radial velocity |

Values show 2 decimals, positions 4, and the temperature none. A missing value shows as "—".

> See [`StarDetailScreen.row(_:_:unit:digits:)`](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L34-L38) and [`StarDetailScreen.UI`](../Packages/Gaia/Sources/Gaia/UI/StarDetailScreen.swift#L44-L48)
