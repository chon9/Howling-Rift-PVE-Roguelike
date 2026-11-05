# Combat feedback — v0.3.0

Hero combat now uses stronger contact feedback and animated kill celebrations.

- Physical hits use concentrated gold-white slash impacts; magic hits use cyan/violet shards. Periodic burn and reflected damage use the smaller crimson impact style. Contact effects appear at the hero's body rather than underneath their feet.
- The hero sprite briefly flashes bright on contact, then returns to its painted colors. Co-op guests receive the same impact and flash; corpses and respawns reset the flash shader.
- Champion deaths trigger a larger upward gold/cyan soul eruption. Minions retain their existing restrained sparks and sounds. A per-victim 55 ms interval bounds overlapping hit effects.
- The announcement panel is replaced by an animated generated crest: **K.O.**, **Double Kill**, **Triple Kill**, **Quadra Kill**, and **Penta Kill** each have progressively more ornate wings and energy. Killing spree and shutdown use a crimson/emerald crest. The first kill keeps its First Blood subtitle and voice announcement.
- Crests enter with a short scale pulse, hold, and fade. Labels are drawn at runtime for clear spelling at any resolution. Celebrations ignore mouse input. The large build-ready prompt temporarily yields to the celebration; its persistent top-left badge and U shortcut remain available.

AI image generation used the built-in tool in **generate** mode with transparency. Saved assets: `assets/vfx/combat-impact-v1.png` (4 × 4, 16 frames) and `assets/vfx/kill-celebration-v1.png` (4 × 6, 24 frames). The original alpha is preserved. Exact prompts: `assets/vfx/COMBAT_FEEDBACK_PROMPTS.json`. Animation mapping: `scripts/CombatFeedbackArt.gd`.

Validation: 70 native combat-feedback checks; 199 native death/respawn checks; 192 skill-remake, 14 camera-reset, 26 attack/scoreboard, 52 presentation, and 28 compact-HUD checks passed. Native captures are under `tests/feedback-*-v030.png`. Release and co-op logs are under `tests/v030-*`.

Co-op players must all update to v0.3.0.

The three-player LAN test and native exported Steam AppID 480 lobby smoke test passed with zero failures. The exported test also loaded both atlases and played the Penta Kill crest. Two-account remote Steam play was not exercised.
