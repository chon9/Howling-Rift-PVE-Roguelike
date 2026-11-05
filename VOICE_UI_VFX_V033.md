# Voice, kill feed and Vexel circle fixes — v0.3.3

- The announcer loads **only the twelve recordings supplied in BGM**. Synthesized Enemy Slain / Ally Slain fallbacks are removed, as are the synthesized shutdown, victory and defeat voices. Events without supplied recordings remain silent; their visual announcements and instrumental sound effects remain available. Your supplied You Have Slain An Enemy recording still plays for your ordinary kills.
- Kill feed sits in a fixed frame below the enemy team panel, with consistent right margin, clipped contents and a maximum of five rows. Names use separate plain-text slots with ellipsis, so long names and brackets cannot expand the board or inject markup. The frame hides with the HUD.
- Vexel's meteor and cage use a new circular ground atlas rather than the old isometric sheet. Target previews and active effects share the same sprite mapping and ground anchor. The painted rim maps to the actual radius, without using the outer pillar/glow bounds for sizing. Collision timing and gameplay radius remain unchanged.

Image generation: built-in tool, **generate** mode, transparent output. Saved asset: `assets/vfx/vexel-ground-v2.png` (4 columns × 2 rows, eight frames). Exact prompt and ground mapping: `assets/vfx/VEXEL_GROUND_V2_PROMPT.json`. The generated alpha is preserved. Mapping implementation: `scripts/KitEffectArt.gd`.

Validation includes 72 supplied-audio / no-TTS checks, 25 native feed-layout checks with long names, 192 native skill checks, music and compact-HUD checks. Current captures: `tests/kill-feed-fit-v033.png` and `tests/kit-remake-*-v033.png`. Logs are under `tests/v033-*`.

All co-op players must update to v0.3.3.

The native death/respawn test passed all 199 checks, and the exported Steam AppID 480 smoke test passed with zero failures. Export validation confirmed the absence of TTS fallbacks, the new Vexel sheet and the clipped kill-feed frame.
