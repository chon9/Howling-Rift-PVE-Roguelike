# v0.6.1 — Fullscreen clarity

The existing canvas-items rendering mode already renders at the actual window/display dimensions. The old screen effect could blend along an eight-pixel direction span at full strength, softening texture detail and camera-scaled overhead text. Its replacement uses local half-pixel samples with restrained edge blending and a higher edge threshold, preserving fine detail rather than broadly averaging it.

A separate World Sharpness slider restores local detail with a 35% default. Strength decreases on high-contrast edges and results are clamped to nearby colors to avoid bright/dark overshoot halos. Sharpening works independently of smoothing. Disable light edge smoothing and set sharpness to 0% to remove the extra screen pass completely. Both controls are saved; older profiles get the balanced default. HUD/menu/cursor layers render above the effect and retain their existing font rendering.

Names, status timers and damage numbers now share a distance-field font instead of enlarging small raster glyphs with the battlefield camera. Character names have a less heavy outline. This uses Godot’s built-in fallback font data, with one shared font resource and no new external font dependency.

Native GPU tests capture actual 1920×1080, 2560×1440 and 3840×2160 images and check fullscreen against the display dimensions. A fixed thin-line/text pattern has lower average deviation from the unprocessed image than the v0.6.0 shader at all three resolutions. This measures detail preservation, not a percentage improvement in perceived sharpness. HUD pixels remain identical with the screen effect enabled, and flat backgrounds remain unchanged. Tests also cover settings persistence/migration/clamping, independent sharpening, pass bypass, input behavior and scalable glyphs. Status, Deadeye, fullscreen and repeated-match resource checks remain passing.

No low-resolution framebuffer, new supersampling buffer, temporal history, DLSS or FSR was introduced. Existing bitmap sprite/terrain resolution still limits the amount of genuine fine detail available at high display resolutions.

Reference documentation: [native canvas-items scaling](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html), [screen texture base-level sampling](https://docs.godotengine.org/en/4.5/tutorials/shaders/screen-reading_shaders.html), and [scalable distance-field fonts](https://docs.godotengine.org/en/4.3/classes/class_fontfile.html#class-fontfile-property-multichannel-signed-distance-field).
