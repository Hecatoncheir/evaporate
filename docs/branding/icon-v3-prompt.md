# Evaporate icon v3 — liquid color

Created with the built-in imagegen tool (style-transfer edit, no fallback CLI).

Source: [evaporate-icon-v3.png](evaporate-icon-v3.png).
Previous monochrome source is preserved: [evaporate-icon-v2.png](evaporate-icon-v2.png).
The user's colorful typography image was used only for palette, ink-flow,
offset-print edges, and paper texture; its lettering was not reused.

Runtime master: `assets/branding/app_icon.png`.
Export all application and tray sizes on macOS: `python3 tool/make_icon.py`.

## Final prompt

Use case: style-transfer.
Asset type: production desktop application icon, square 1024x1024.
Input images: Image 1 is the EXISTING Evaporate icon to edit; Image 2 is ONLY a color and print-effect reference, do not reproduce its typography or layout.
Primary request: Add the vivid psychedelic liquid-color palette and effects from Image 2 to the existing icon in Image 1. Preserve the exact recognizable geometry: same large centered midnight-indigo circular disc, same three broad S-curved rising parallel vapor ribbons with their cut diagonal tips, same positions, proportions, spacing, and warm ivory full-bleed square outer canvas. Do not redesign the symbol.
Style treatment: turn the three ivory ribbons into luminous flowing multicolor ink streams, hot magenta and coral red through golden yellow, turquoise/cyan and violet, with fine marbled streaks following each ribbon's existing curve. Retain bright cream/yellow highlights for strong contrast against the near-black indigo disc. Add subtle cyan/magenta offset-print fringes at the ribbon edges and thin disc contour, a soft controlled colored ink bleed adjacent to the ribbons, and restrained tiny colored pigment flecks with tactile vintage paper grain like Image 2. Keep the dark negative spaces clear and the three ribbons distinctly separated; concentrate the saturated color within the existing ribbons, no new long trails outside the circle. Keep the ivory outside background predominantly clean, with just sparse fine pigment flecks.
Constraints: only change palette and surface effects, preserve silhouette and layout. Recognizable and bold at 32px. Flat graphic print effect, not glossy 3D. No letters, no words, no new shapes or objects, no watermark, no presentation mockup, no border, no checkerboard, no transparent background. Deliver one finished square icon.
