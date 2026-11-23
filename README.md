# Gaia

An iOS app that lists the Milky Way stars within 10 parsecs of the Sun, with measurements from the European Space Agency's Gaia mission (Data Release 3).

- 315 Gaia DR3 sources, bundled as [`nearby_stars.csv`](Packages/Gaia/Sources/Gaia/Resources/nearby_stars.csv)
- Searchable list sorted by distance, brightness or name
- Detail screen with position, Gaia measurements and derived values (distance, absolute magnitude, transverse velocity)

## Structure

| Path | Contents |
|---|---|
| `App/` | App entry point, [`GaiaApp`](App/GaiaApp.swift#L5-L13) |
| `Packages/Gaia/` | Swift package with the model, data and UI code |
| `Scripts/` | [`fetch_catalog.sh`](Scripts/fetch_catalog.sh), downloads the data from the ESA Gaia archive |
| `Documentation/` | Project documentation |

## Setup

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from [`project.yml`](project.yml).

```bash
xcodegen generate
open Gaia.xcodeproj
```

Run the tests from the package folder.

```bash
cd Packages/Gaia
swift test
```

The app targets iOS 17. The package also builds on macOS 14, so the tests run without a simulator.

## Documentation

- [`Architecture`](Documentation/Architecture.md)
- [`Data`](Documentation/Data.md)
- [`UI`](Documentation/UI.md)

## Acknowledgement

This work has made use of data from the European Space Agency (ESA) mission [Gaia](https://www.cosmos.esa.int/gaia), processed by the Gaia Data Processing and Analysis Consortium ([DPAC](https://www.cosmos.esa.int/web/gaia/dpac/consortium)).
