# Skill remake — v0.2.9

Warden (Thresh) and Vexel (Veigar) now use dedicated skill art and more recognizable interactions. This remains a fast ARAM adaptation with custom balance, rather than an exact reproduction of every League mechanic.

- **Flay:** a 440 × 130 directional sweep across both sides of Warden. Aim toward an enemy to push; aim behind yourself to pull an enemy in front. Displacement animates over 0.25 seconds and respects crowd-control shields. Waiting between attacks charges a bonus magic hit, with AD scaling shown in the tooltip.
- **The Prison:** five individually breakable walls, a 0.5-second formation delay, and five-second lifetime. The first broken wall damages and slows by 99% for two seconds. Later walls only slow for one second. Standing in the center causes no damage. Minions cannot break its walls.
- **Death Hook:** animated hook and chain, smooth drag, and a 1.5-second Q2 dash window, shown on the action bar and marked target. Second cast consumes the mark without another mana cost. Bots check tower safety before dashing.
- **Soul Lantern:** a visible four-second lantern that shields nearby allies. An ally standing near it can right-click the lantern to dash to Warden. The caster cannot use their own lantern.
- **Falling Star:** visible warning, falling meteor, impact, and fade; damage starts after one second. Moving out before impact avoids the hit.
- **Event Horizon:** 0.5-second warning followed by three active seconds. The rim stuns and interrupts dashes; the interior is safe. A ground outline shows the exact circular collision boundary beneath the painted pillars.
- **Primordial Burst:** its own large dark homing orb, with damage increasing to twice the base value at one-third target HP or lower. Tooltip and AI damage estimates use the same multiplier.

Three new transparent AI-generated atlases provide **96 frames across all 24 Q/W/E/R skills** of Warden, Vexel, Rook, Granite, Noctra, and Vesper. Existing heroes retain their current sheets. Ground spells, utility shields, buffs, and projectiles now select the appropriate skill row rather than sharing a generic hero-colored effect. Atlas cropping uses one stable bound per animation row to prevent size jitter. Co-op snapshots replicate effect IDs, directions, arming delays, and broken walls; gameplay stays authoritative on the host.

Generation mode: **generate**, transparent background. Assets: `assets/vfx/warden-vexel-skills-v1.png`, `rook-granite-skills-v1.png`, and `noctra-vesper-skills-v1.png`. Exact prompts and grid specification: `assets/vfx/KIT_EFFECT_PROMPTS.json`. Sprite mapping and bounds: `scripts/KitEffectArt.gd` and `assets/vfx/kit-effect-crops-v1.json`.

Kit reference: [official Thresh overview](https://www.leagueoflegends.com/en-us/champions/thresh/) and [official Veigar overview](https://www.leagueoflegends.com/en-us/champions/veigar/).

Validation: `KitRemakeTests` exercises atlas bounds, push/pull direction, CC immunity, wall breaks, hook recast, lantern right-click, meteor timing and dodging, cage boundary/arming, execute scaling, and co-op effect fields. Native captures are saved under `tests/kit-remake-*-v029.png`. Release validation logs are under `tests/v029-*`.

Verified: 192 native kit checks, 410 expansion checks, 199 native death lifecycle checks, 38 tactics checks, 52 presentation checks, 81 core PvE checks, 25 casting checks, and 800 balance checks; all passed. Three-player LAN and the exported native Steam AppID 480 lobby smoke test passed with zero failures. Two-account remote Steam play was not exercised.
