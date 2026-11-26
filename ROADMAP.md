# Gaia roadmap

Add features below in the order you want to explore them. Implement one selected feature per PR; leave the remaining ideas queued. Mark a feature complete after implementation and validation.

## Next

No next feature selected yet. Add your feature requests here.

<!-- Copy this template for each feature:
- [ ] Feature title
  - Behaviour: what the user should be able to do.
  - Done when: concrete acceptance criteria.
-->

## Completed

- [x] **Refine star appearance and expand the sample**
  - Radius-scaled markers with temperature colours and labelled estimates.
  - Hide unresolved stars until zoom makes them visible.
  - Expand to 51,983 Gaia DR3 sources within 50 pc.
  - Batch camera-facing stars with a dedicated Metal glow shader.
  - Keep the Milky Way grid in both focus modes.

- [x] **3D star map adapted from Stars**
  - Plot all 315 bundled Gaia sources around the Sun using their Galactic coordinates and parallax distances.
  - Orbit, pinch to zoom, change field of view, and reset the camera.
  - Animate between the Sun and Galactic centre, with thin/thick Milky Way wireframes for context.
  - Adjust marker size and switch between constant screen size and perspective sizing.
  - Tap a star for its measurements; keep the searchable catalogue in its own tab.
  - Target iOS 27 and retain macOS package tests.

## Ideas

- [ ] Stream spatial tiles from the full Gaia catalogue, with distance/visibility-based loading and memory limits.
- [ ] Iterate on the star glow shader and appearance controls.

Move one idea to **Next** when it is ready to implement.
