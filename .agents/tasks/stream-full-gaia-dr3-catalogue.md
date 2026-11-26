# Stream the full Gaia DR3 catalogue and show its observed extent

Status: planned. Target: iOS 27 and later. This PR contains the task specification only.

## Goal

Make every star in Gaia DR3 available to explore through streaming, while rendering only the detail useful for the current view. In the Milky Way view, show the extent of Gaia's observations relative to the Sun and the Galactic disk, including where the available data become sparse or uncertain.

The final dataset must cover the full catalogue. A small prototype is an implementation milestone, not completion of this task.

## Catalogue scope and distance policy

- Use the complete `gaiadr3.gaia_source` table as the ingestion baseline: **1,811,709,771 sources**. This is a source count, not a count of confirmed stars; classifications include non-stellar and uncertain objects. Preserve every source ID and classification so uncertain stars are not lost through a strict stellar-classification filter. Reconcile the baseline count against the pinned release manifest. [ESA DR3 contents](https://cesar.esa.int/upload/202210/RG_Gaia_DataRelease3.pdf)
- Remove the current nearby-sample limit from catalogue availability. Distance, brightness and quality filters may affect the view, but must not permanently exclude records from the streaming dataset. Retain sources without radius, temperature, colour, magnitude or a reliable parallax, with explicit missing-value flags and display fallbacks.
- A source must remain searchable and retrievable by its exact 64-bit Gaia ID even when its tile is unloaded. Keep IDs as integers or decimal strings through transport; never round them through floating-point JSON consumers.
- Separate catalogue availability from trustworthy 3D placement. Evaluate published DR3-compatible geometric/photogeometric distance estimates, validate the source-ID join, and retain the estimate's provenance and uncertainty. Do not blindly invert noisy or negative parallax, assign an arbitrary common distance, or discard those records. [Bailer-Jones et al., distance estimates](https://arxiv.org/abs/2012.05220)
- Give sources with usable distances a measured/estimated 3D placement. Keep sources without defensible distances accessible in a clearly labelled Sun-centred sky layer and source search/details. The sky layer must not acquire fictitious parallax when the camera moves. Show the counts in each placement category. This fallback is required for full-catalogue support.
- Keep known non-stellar objects distinguishable. The Milky Way footprint must describe its stated stellar sample rather than being stretched by galaxies, quasars or unsupported distance estimates.

## Proposed architecture

These are implementation recommendations to validate, not claims about existing app behaviour. Gaia Sky provides a relevant precedent for octree-based star catalogues and compact binary pages. [Gaia Sky catalogue format and streaming](https://gaia.ari.uni-heidelberg.de/gaiasky/docs/master/Format-star-catalog.html)

### 1. Build the dataset offline

- Ingest official bulk partitions in a resumable preprocessing job, with a pinned release, source URLs, checksums, attribution and a count/deduplication audit. Use bounded-memory processing; do not load the full catalogue into one process's memory. [ESA bulk catalogue entry point](https://cdn.gea.esac.esa.int/?prefix=Gaia/gdr3/gaia_source/)
- Partition stars with usable distances into a 3D octree. Put prominent stars and spatially representative detail in coarse levels, then progressively add fainter detail. A fixed ranking by brightness seen from Earth must not prevent a faint star becoming visible when approached from another viewpoint.
- Give every canonical source one addressable record. Document whether LOD pages add records or replace representations; deduplicate IDs when parent and child pages overlap.
- Partition sources needing the sky fallback by a spherical hierarchy such as HEALPix/HiPS. Connect both indexes to a source-ID lookup. HiPS is designed for progressive astronomical catalogues over the sky. [IVOA HiPS recommendation](https://arxiv.org/abs/1708.09704)
- Publish compressed binary pages plus a versioned manifest. Include bounds, counts, child references, brightness summaries, coordinate frame, units, epoch, distance policy, schema version and checksums. Page the index itself so the client does not need the whole billion-source hierarchy at launch.
- Store compact render attributes separately from full measurements. Use tile-local positions and camera-relative GPU coordinates to preserve precision from Galactic distances down to nearby stars. Measure compression and quantisation errors against visual and selection requirements.
- Precompute coarse density/light summaries and the survey-extent products from the full dataset. Their appearance must not depend on which detailed pages happen to be resident.

### 2. Stream according to the view

- Ship a lightweight Galactic overview and nearby starter data. Host immutable, versioned pages on object storage/CDN. Resolve detailed source records on demand. Do not issue archive-wide ADQL queries on every camera movement.
- Traverse only relevant branches of the hierarchy. Prioritise pages by projected screen coverage, expected visual contribution, proximity and selection/search targets. Refine where individual stars can become useful on screen; retain coarse context elsewhere.
- Bound concurrent requests, decoding work, GPU uploads, resident CPU/GPU memory and disk cache independently. Cancel obsolete requests, retry transient failures with backoff, verify payloads, and avoid mixing dataset versions.
- Prefetch around the view and along camera movement. Cache recently visited regions and evict the least useful pages under pressure. Retain the coarse parent until replacement detail is ready, including on slow or disconnected networks.
- Pin selected stars and their metadata while needed. A search result must be able to request its exact page without traversing/downloading the entire catalogue.

### 3. Render a useful, stable subset

- Use GPU batches and culling rather than one scene entity per star or a CPU scan of the full catalogue. Combine view bounds, projected size and estimated brightness; nearest-only or size-only selection is insufficient.
- Use an adaptive frame budget. Start experiments near 100,000 individual visible stars, then tune on devices; this is an initial budget, not a catalogue limit or a demonstrated capacity. Account for billboard/glow pixel coverage as well as star count. Keep the live glow controls and separate screen-blended glow pass working.
- For moved viewpoints, derive brightness from the available intrinsic-light/distance model and label approximations, particularly extinction. Do not reuse Earth-observed apparent magnitude unchanged as though it applied from every camera position.
- Represent unresolved groups with labelled density/light approximations. Transition to individual stars without double-counting their contribution or making the galaxy's brightness jump. Aggregates must not masquerade as selectable individual Gaia sources.
- Use deterministic membership, smooth transitions and different enter/exit thresholds to prevent popping, flicker and repeated downloads near LOD boundaries. Preserve selection IDs across transitions.

## Show the boundaries of Gaia's observations

Gaia is an all-sky survey. Its catalogue completeness varies with apparent magnitude, sky position, crowding and scanning coverage; there is no single hard distance boundary around the Sun. A completeness model describes detection probability, not a universal surveyed volume. [Cantat-Gaudin et al., DR3 selection function](https://arxiv.org/abs/2208.09335)

Implement a **Gaia coverage** overlay in the Milky Way view:

- Show an irregular, translucent volume or contour with the Sun and existing Galactic grid visible. The first required layer is **Observed extent (estimated)**, derived from the pinned catalogue and a documented distance-quality policy.
- Evaluate adaptive HEALPix direction bins plus radial bins. Derive robust outer-distance contours, for example a documented percentile of the usable-distance sample, with counts and uncertainty per region. Choose and validate the percentile and minimum support during prototyping. A percentile envelope intentionally does not enclose every outlier; disclose that and keep sources outside it accessible.
- Do not use the farthest source in each direction, a single sphere, or a convex hull of all points as proof of survey coverage. Avoid connecting detached populations into one misleading solid volume. Leave unsupported regions visibly unknown rather than inventing a continuous shell.
- Distinguish **observed extent**, **estimated completeness**, and **currently loaded data**. A low source density can reflect astronomy, extinction or selection effects; it is not by itself a completeness measurement. Download failures and cache eviction must never move the survey boundary.
- Include a legend with the release, sample/quality policy, distance model, contour definition and uncertainty. Explain that the volume describes this catalogue's observations, not the edge of the Milky Way or a star-free exterior. Show how many sources lack usable distances.
- Offer overlay visibility and opacity controls; keep the footprint legible at Galactic scale and aligned with the app's Galactic coordinates and Sun position. Detail streaming, glow tuning and the coverage layer must remain independently controllable.

Research a separate **completeness** mode after the observed-extent layer: use a published selection function for an explicitly chosen stellar population, magnitude range, extinction model and probability threshold. GaiaUnlimited's Red Clump example demonstrates why such a 3D surface depends on the population and dust model. Do not label the first empirical extent contour as “90% complete.” Scanning-law visit counts, if shown, belong to a separately labelled angular coverage layer. [GaiaUnlimited explanation and 3D example](https://gaia-unlimited.org/what-is-a-selection-function/)

## Delivery sequence

Implement these stages in separate, reviewable changes. Reconcile with the latest renderer and other agents' work before implementation.

- [ ] Define the pinned input manifest, source/distance categories, binary schema, lookup mechanism and audit report. Estimate preprocessing disk/time, hosting size and transfer costs before a full production run.
- [ ] Build a representative multi-million-source prototype containing nearby stars, dense Galactic fields, faint sources, missing distances and distant populations. Produce both 3D and sky pages plus coarse coverage products.
- [ ] Add view-driven streaming, bounded caches and source lookup. Demonstrate startup, navigation, selection and recovery with local fixtures and a remote test endpoint.
- [ ] Add adaptive GPU detail, unresolved-light representations and stable transitions. Preserve the existing map controls, colours, selection and custom glow behaviour.
- [ ] Add the observed-extent overlay and its legend, confidence treatment and controls in Milky Way view. Validate its interpretation independently of rendering residency.
- [ ] Run the reproducible pipeline over the entire baseline, publish all pages, and reconcile every source ID. A prototype or a permanent quality/distance cut does not satisfy this stage.
- [ ] Profile and validate the complete service on iOS 27 simulator and physical devices; document practical budgets and capture screenshots and native GitHub video evidence in the implementation PRs.

The optional population-specific completeness mode can follow in another task; the observed-extent overlay and full-catalogue streaming are required here.

## Acceptance criteria

- [ ] A reproducible full-release audit accounts for all 1,811,709,771 baseline source IDs, with no silent losses or duplicate canonical records. Placement categories and non-stellar classifications reconcile to that baseline; all potentially stellar records remain accessible.
- [ ] Deterministic samples from every input partition, including the faintest and poorest-distance records, resolve to retrievable records/pages. Searching an unloaded source works; missing distances produce the labelled sky fallback rather than a fabricated 3D position.
- [ ] The user can move from Galactic overview into different neighbourhoods without downloading the full dataset or encountering a permanent 50 pc cutoff. Coarse context remains available while finer data arrive.
- [ ] Automated tests cover page integrity/versioning, ID preservation, coordinate transforms, distance-policy flags, LOD deduplication, request cancellation, retry, eviction and selection continuity.
- [ ] Recorded dense-field, rapid-movement, zoom and extreme-glow scenarios remain within explicit memory/request limits. Target 60 fps on the agreed physical iOS 27 device; report measured frame-time percentiles, memory, bytes transferred, time to first useful view and refinement latency. Adjust detail under load rather than exhausting memory. Simulator results alone are insufficient for performance claims.
- [ ] Offline startup and network interruption preserve bundled/cached context and clearly distinguish unavailable detail from empty space. Returning to cached regions avoids unnecessary downloads.
- [ ] The Milky Way view shows the Gaia observed-extent overlay, Sun and Galactic reference together. The overlay is reproducible from its manifest and unchanged by star-budget changes, loading failures or cache eviction; controls and legend explain its statistical boundary and unknown regions.
- [ ] Coverage validation compares derived contours against independently computed binned catalogue statistics, checks outlier/uncertainty handling and demonstrates that any completeness claims use an explicit population and published model.

Research checked on 2026-11-26. Recheck data-product versions, attribution and implementation dependencies when starting the corresponding stage.
