# Kill banner layout fixes — v0.3.4

The old four-frame banner atlas contained wings, glow and ornaments crossing cell boundaries. Small sampling insets could not recover complete crests or remove neighbouring artwork. Kill banners now draw six separate transparent crest images, preserving each image's aspect ratio. Entrance pulse and fade animate the whole crest without sampling another frame. Art stays inside the banner control at every animation phase.

Gold fantasy serif lettering uses Windows Georgia, with Constantia/Times fallbacks. Each crest has its own measured clear plaque rectangle. Headlines fit the available width and height, names shorten with ellipsis when needed, and both lines center using font ascent/descent. Text stays clear of gems, rims and wings. The right-side feed also uses matching serif text, subdued team colours and gold board outlines; five-row clipping and long-name shortening remain active.

Generated assets: `assets/vfx/crests-v2/knockout.png`, `double.png`, `triple.png`, `maniac.png`, `savage.png`, `spree.png`. Built-in image generation: six new transparent crests in generate mode, then three padding/complete-tip refinements in edit mode. Exact original prompts are in `assets/vfx/crests-v2/PROMPTS.json`; the edit prompt is in `assets/vfx/crests-v2/PADDING_PROMPT.txt`. Original generated sources remain in the Codex generated_images directory. No font files are redistributed.

Native rendered validation: 313 checks covering every announcement title, six tiers, entrance/hold/fade bounds, line centering and oversized player names; 63 combat feedback checks; 25 kill-feed layout checks; 199 death/respawn checks. All passed. Rendered preview: `tests/banner-gallery-v034.png`; actual HUD captures: `tests/feedback-*-v034.png`, `tests/kill-feed-fit-v034.png`. Logs: `tests/v034-*`.

All co-op players should use v0.3.4.

The exported AppID 480 Steam smoke test also passed with zero failures, including loading all six standalone crests from the release PCK.
