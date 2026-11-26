# Architecture

The app is one Swift package, `Gaia`, plus a thin app target that shows `GaiaScreen`. On iOS, the root has a 3D Map tab and a Catalogue tab. The catalogue retains its own navigation stack.

The [3D map](3D.md) lives in `UI/StarMap/`. A SwiftUI screen owns catalogue and control state; a representable coordinator owns the RealityKit scene. The coordinate conversion extends `Star` in `Model/Star+Position.swift`. Rendering is iOS-only, while coordinates, projection calculations and catalogue logic remain testable on macOS.

## Layers

| Folder | Role | Types |
|---|---|---|
| `Model/` | Value types and derived values | `Star`, `StarAppearance` |
| `Data/` | Parsing, names, queries | `CatalogParser`, `StarNames`, `StarRepository` |
| `UI/` | View model and screens | `StarListViewModel`, `StarListScreen`, `StarRow`, `StarDetailScreen` |

Dependencies point one way: `UI` → `Data` → `Model`.

## Flow

1. [`StarListScreen`](../Packages/Gaia/Sources/Gaia/UI/StarListScreen.swift#L4) creates a `StarListViewModel` and awaits `load()` in its `.task`.
2. [`StarListViewModel.load()`](../Packages/Gaia/Sources/Gaia/UI/StarListViewModel.swift#L22-L30) loads off the main thread through [`StarRepository.bundled()`](../Packages/Gaia/Sources/Gaia/Data/StarRepository.swift#L28-L34).
3. `StarRepository.bundled()` caches one immutable sample. On first access it reads `nearby_stars.csv` from the package bundle and hands the text to [`CatalogParser.stars(from:)`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L18-L39).
4. The list reads [`StarListViewModel.stars`](../Packages/Gaia/Sources/Gaia/UI/StarListViewModel.swift#L18-L20), which queries the store with the current search text and sort order.

## Model

[`Star`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L4) is a value type. Its `id` is the Gaia DR3 source identifier, an `Int64`.

Position, parallax and proper motion are always present. `magnitude`, `colorIndex`, `effectiveTemperature`, `radiusInSolarRadii` and `radialVelocity` are optional, because Gaia does not publish them for every source.

Derived values are computed properties in an extension.

| Property | Formula | Unit |
|---|---|---|
| [`distanceInParsecs`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L51-L53) | `1000 / parallax` | pc |
| [`distanceInLightYears`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L60-L62) | `distanceInParsecs * 3.26156` | ly |
| [`absoluteMagnitude`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L65-L67) | `magnitude - 5 * (log10(distanceInParsecs) - 1)` | mag |
| [`totalProperMotion`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L70-L72) | length of the `properMotion` vector | mas/yr |
| [`transverseVelocity`](../Packages/Gaia/Sources/Gaia/Model/Star.swift#L75-L77) | `4.74047 * totalProperMotion / parallax` | km/s |

`absoluteMagnitude` is `nil` when the source has no G magnitude.

## State

[`StarListViewModel`](../Packages/Gaia/Sources/Gaia/UI/StarListViewModel.swift#L8) is a `@MainActor` `@Observable` class owned by `StarListScreen` as `@State`. It holds three pieces of state.

- `searchText`, empty at launch
- `sort`, `.distance` at launch
- `hasFailed`, set when the catalogue cannot be loaded

`StarRepository` is a `Sendable` struct, so queries are pure functions of the loaded stars.

## Logging

Logging goes through `OSLog`. [`Logger.catalog`](../Packages/Gaia/Sources/Gaia/Data/CatalogParser.swift#L102) has the category `Catalog` and reports skipped rows and load failures.

## Tests

[`CatalogTests`](../Packages/Gaia/Tests/GaiaTests/CatalogTests.swift) uses Swift Testing and runs against the bundled data, with no mocks.

[`StarMapTests`](../Packages/Gaia/Tests/GaiaTests/StarMapTests.swift) covers coordinates, projection sizing and camera-option reset. [`StarMapUITests`](../Tests/GaiaAppUITests/StarMapUITests.swift) exercises the iOS map gestures, controls, star selection and catalogue navigation through the generated `GaiaApp` scheme.

The map reads `allStars`, independent of the nearby-list filter. `StarSceneRenderer` renders RealityKit's batched core mesh and grid into a texture; `StarGlowPass` screen-blends instanced halo billboards over it without depth testing, then presents in an `MTKView`. `Resources/StarGlow.metal` performs billboarding, projected-size culling and glow shading on the GPU. `StarAppearanceTests` cover the physical-data fallbacks and visibility thresholds. `StarGlowTests` render real Metal textures to verify screen blending and overlapping halos.
