# Compact shoreline points v3

Four PNG assets based on the compact north-point artwork approved on
2026-09-23, with matching east, south and west variants.

These are the visual outer land tips; the game's historical resource keys
are `water_inner_point_n/e/s/w`. The regular shoreline corner family is separate.

- Logical ground diamond: 64 x 32 pixels, 2:1 projection.
- Transparent RGBA canvas: 96 x 72 pixels.
- Identical opaque bounds: x=16, y=36, width=64, height=32.
- Ground anchor: (48, 52).
- N/E/S/W mean the top/right/bottom/left vertex on screen.
- Land and beach retain the small footprint of the approved artwork.

Asset preparation removes isolated alpha specks, aligns all four diamond
vertices to the same projection, downsamples, and applies one shared raster
diamond footprint. There is no runtime sprite rotation. The PNG bounds are
identical because the current water renderer normalizes their used rectangles.

`meta/manifest.json` records source image hashes, measured source vertices,
asset paths and geometry. The warm-pixel fractions are a colour-based QA
estimate, not an exact semantic segmentation of land and beach.
