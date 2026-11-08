# 2026-11-05
V1.2.6 app release authorized by user. Keep static optical shapes; use blur 12, thickness 22 and restrained saturation to avoid duplicated background text. Preserve fallback and plain active bubble.

Vendor change is scoped to app V1.2.6. No geometry animation added; drag bubble uses plain UI feedback.

V1.2.7: user requested fully transparent glass with strong refraction. Use zero blur/tint, refractive index 1.45, thickness 24. Match Flutter and SDF rounded rectangle boundaries; highp shader arithmetic. Keep geometry static and move only the plain selection widget. App release authorized explicitly; no package publication.

Final V1.2.7: clear mode moved to one analytic capsule pass without geometry readback. Monotonic lens mapping avoids folded text; local contrast protects navigation labels. Outer-only shadows prevent gray clear glass. Legacy cached geometry also fixes premultiplication, derivative stability and highlight bounds. Validated light/dark and five backgrounds on Impeller, app tests 130 passed. No package publication.

V1.2.8: user rejected per-item contrast halos and corner ghosts. Remove radial masks and clear-mode shadow; clip the complete foreground to the capsule. Use strong rim refraction with calm interior, a single reflected-light term and live Theme-bound shader uniforms. Keep geometry static. V1.2.8 release explicitly authorized.

V1.2.8 validated: no issues, 132 tests passed, corner/inactive-item pixels checked in both themes. Actual system theme toggles and preference picker retain the process and update immediately. Gradient-button overlap scene verified. Keep only one flat selection with theme-adjusted ink; no radial per-item masks.

V1.2.9: user explicitly authorized app release. Replace the outward whole-pane mapping with Snell-law inward refraction on a 7dp slab bevel; the center samples the original screen location. A second analytic convex filter follows the selection without LiquidGlass geometry, toImageSync, or texture readback. Foreground icons/text remain outside both filters. Drag enlargement can extend beyond the base capsule; each optical pass clips to its own exact silhouette. Pointer cancellation does not commit navigation.

The first V1.2.9 device preview was rejected by the user for excessive transparency and poor readability. Restore continuous backdrop softening (6dp base, 1.5dp convex lens), shared tonal compression and reflected light. Do not reintroduce per-item opacity disks or corner rectangles. This deliberately supersedes the old zero-blur tuning; the material must preserve recognizable color while protecting control text. Decorative application actions share a live palette with the ambient background; semantic payment and utility colors remain stable.

Final selection feedback: the user rejected both the barely visible clear selection and the added colored stroke. Remove the drawn selection border. Use a theme-tinted interior with clear Fresnel highlights, stronger selected type and dimmer inactive ink. Dark selection ink is nearly white, with reduced interior reflection to retain contrast; light selection ink is deepened. Keep all unselected items free of individual fills. Unsupported shader backends use one continuous softened pane rather than becoming fully transparent.

V1.2.9 validated: 137 app tests passed, analysis clean; matrix covers nineteen pages in both themes and five effects. Connected-device live theme/palette, held selection, settings divider, glass choice panels and production cover-install/cold-start checks passed. App release only; package is not published separately.
