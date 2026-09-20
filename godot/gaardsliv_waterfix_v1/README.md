# Gårdsspillet WaterFix v1.1

This revision is built to the actual 64×32 grid used by the game.

Key corrections:
- water surface uses one common seamless base
- no dark perimeter line between ordinary water tiles
- shoreline is layered over the same base, so adjacent water remains visually continuous
- all tiles use the same exact logical diamond and bottom-center anchor
- current Godot grid-to-asset direction rotation is documented in the manifest

Default:
`water/base/water_center_plain.png`

Decorated tiles are optional variants only.
