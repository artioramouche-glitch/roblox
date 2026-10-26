# Local changes to the vendored skill

Copied from https://github.com/majidmanzarpour/blender-game-skills (skills/blender-image-to-3d, MIT).
Keep this list up to date when updating the copy from upstream.

Added (Roblox Ultimate MCP, run through `blender_image_to_3d`):
- `scripts/compose_review_bpy.py`: compose_review.py in Blender's Python (no system Python or Pillow), plus
  `--detail`: a per-cell check of detail and colour inside the silhouette, which IoU cannot see.
- `assets/detail_kit.py`: bolts, plates, corner caps, planks, straps, tubes, padlock, ring handle, merge; appended
  to the build template by the `build` action.
- `scripts/make_matte_bpy.py`: cleans a reference into a matte (corner colour, thin lines, holes, labels).
- `scripts/fit_camera_bpy.py`: finds the `--ref-cam AZ EL LENS` of a perspective reference by IoU.

Changed:
- `scripts/review_render.py`: Standard view transform in every mode (was AgX for `--mode material`,
  which washed out saturated cartoon colours).
