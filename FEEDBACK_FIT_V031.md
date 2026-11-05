# Effect sizing and alignment — v0.3.1

- Hero impact radius reduced from 30–55 to 16–26 world units, with less expansion during the animation. The brief bright contact flash remains.
- Kill flame reduced from a 170-unit square to an approximately 48 × 75 unit upright effect. It anchors at the fallen hero's feet and grows upward. Normal alpha blending preserves its painted detail and prevents the large white additive wash.
- K.O. and multikill crest width reduced to 500 UI units, with a smaller entrance pulse. Rendering preserves the selected sprite frame's aspect ratio; title and subtitle sizing now fit the crest.
- Sprite regions have a two-pixel inset to prevent neighboring atlas cells bleeding into the effect during linear filtering.

81 native feedback checks, 199 death/respawn checks and 14 camera-reset checks passed. The native exported Steam smoke test passed. Visual captures: `tests/feedback-*-v031.png`.

Extract the complete release folder before launching. All co-op players need v0.3.1. Steam testing uses AppID 480.
