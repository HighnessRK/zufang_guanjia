# 2026-11-05
V1.2.6 app release authorized by user. Keep static optical shapes; use blur 12, thickness 22 and restrained saturation to avoid duplicated background text. Preserve fallback and plain active bubble.

Vendor change is scoped to app V1.2.6. No geometry animation added; drag bubble uses plain UI feedback.

V1.2.7: user requested fully transparent glass with strong refraction. Use zero blur/tint, refractive index 1.45, thickness 24. Match Flutter and SDF rounded rectangle boundaries; highp shader arithmetic. Keep geometry static and move only the plain selection widget. App release authorized explicitly; no package publication.

Final V1.2.7: clear mode moved to one analytic capsule pass without geometry readback. Monotonic lens mapping avoids folded text; local contrast protects navigation labels. Outer-only shadows prevent gray clear glass. Legacy cached geometry also fixes premultiplication, derivative stability and highlight bounds. Validated light/dark and five backgrounds on Impeller, app tests 130 passed. No package publication.
