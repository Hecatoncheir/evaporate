# Evaporate icon v2

Created with the built-in imagegen tool, without the fallback CLI or API key.
The user's soundtrack cover was a style reference only; its lettering and
publisher marks were not reused. The final icon is opaque, full-bleed ivory.

Source: [evaporate-icon-v2.png](evaporate-icon-v2.png).
Runtime master: `assets/branding/app_icon.png`.
This monochrome version is preserved for reference. The active colorful icon
and its prompt are documented in [icon-v3-prompt.md](icon-v3-prompt.md).
To re-export this older variant explicitly on macOS:
`python3 tool/make_icon.py --source docs/branding/evaporate-icon-v2.png`.

## Initial generation prompt

Use case: logo-brand. Asset type: production desktop app icon for Evaporate game launcher. Input image 1 is ONLY a style reference, not an edit target. Generate one original square icon, 1024x1024, on genuinely transparent outer background. A large warm ivory/cream rounded-square tile, with a near-black midnight-indigo circular disc centered inside it. Inside the disc, design a bold original ivory symbol: three parallel broad ribbon-like vapor streams rising diagonally and curving upward, together subtly suggesting a capital E / evaporation. Simple memorable silhouette, balanced negative space, readable at 32px. Style inspired by the reference's retro-futurist 1970s record-sleeve graphic design: flat two-ink geometry, extremely restrained paper grain within filled areas. Keep clean crisp silhouette and high contrast. The tile occupies about 88% of the square canvas with even transparent padding. No text, no ARC Raiders lettering, no publisher marks, no reference logo reproduction, no drop shadow, no 3D, no mockup presentation, no extra objects. Deliver a single finished icon, not a contact sheet.

## Final corrective edit prompt

The initial image had a painted checkerboard instead of transparency. This
imagegen edit produced the selected source:

Use case: precise-object-edit. Input image 1: edit target, the generated Evaporate icon. Keep the midnight indigo disc and three ivory vapor ribbons exactly as they are, same design and restrained texture. Change only the outer canvas: completely REMOVE ALL gray/white checkerboard squares and replace the entire outside area with the same warm ivory paper color as the tile. Make a continuous full-bleed warm ivory SQUARE background filling the entire canvas edge-to-edge; NO rounded-square tile edge, NO transparency, NO checkerboard, NO shadow, NO white border. Keep the disc centered, enlarge it slightly to occupy 82 percent of canvas width for legibility as a desktop icon. No text, no extra symbols. Single finished square PNG icon.
