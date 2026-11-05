# v0.5.0 — Thirty-hero roster

Twelve original heroes join the existing eighteen. Their kits preserve recognizable MOBA combinations, with ranges, durations and damage tuned for Howling Rift's ARAM scale. These are adapted kits, not identical live League balance or every champion-specific progression rule.

| Hero | Role | Inspiration | Signature mechanics |
| --- | --- | --- | --- |
| Aegis | Tank | Leona | Empowered stun, timed defensive explosion, champion-seeking blade dash, delayed center-stun ultimate, allied Sunlight proc |
| Bolt | Tank | Blitzcrank | First-hit hook, overdrive/exhaustion, uppercut, shield-stripping silence, mana barrier and delayed lightning |
| Saur | Bruiser | Renekton | Attack-generated Fury, empowered heal/stun/shield break, hit-gated dash recast, temporary-health aura |
| Lancer | Bruiser | Xin Zhao | Three-hit knockup, sweep/thrust, challenge dash, knockback and protection against distant attackers |
| Riftblade | Bruiser | Riven | Three Q casts, final knockup, stun, expiring dash shield, rune attacks, AD/range buff and execute crescent recast |
| Duelia | Bruiser | Fiora | Lunge refund, damage/CC parry, two empowered attacks, directional true-damage vitals and allied healing field |
| Caliber | Marksman | Caitlyn | Piercing rifle shot with falloff, armed hero traps, recoil net, headshots, cancellable aim and interceptable ultimate |
| Solstice | Marksman | Lucian | Piercing targeted line, burst mark, dash, eighteen-shot movable channel, spell-primed second attack |
| Zephyr | Marksman | Sivir | Returning crossblade, bounded attack ricochets, single-spell ward, allied haste |
| Pyre | Mage | Brand | Blaze stacks/burn/detonation, burn-dependent stun and pillar bonus, spreading fire, bounded bouncing ultimate |
| Umbra | Mage | Syndra | Persistent spheres, pickup/throw of spheres or enemy minions, cone push and sphere stun, sphere-count homing barrage |
| Arclight | Mage | Xerath | Charge/release range-growing beam, delayed center-bonus strike, distance-scaled stun, three artillery recasts and attack mana restoration |

Kit references were checked against Riot's official champion pages: [Leona](https://www.leagueoflegends.com/en-us/champions/leona/), [Blitzcrank](https://www.leagueoflegends.com/en-us/champions/blitzcrank/), [Renekton](https://www.leagueoflegends.com/en-us/champions/renekton/), [Riven](https://www.leagueoflegends.com/en-us/champions/riven/), [Fiora](https://www.leagueoflegends.com/en-us/champions/fiora/), [Caitlyn](https://www.leagueoflegends.com/en-us/champions/caitlyn/), [Lucian](https://www.leagueoflegends.com/en-us/champions/lucian/), [Sivir](https://www.leagueoflegends.com/en-us/champions/sivir/), [Brand](https://www.leagueoflegends.com/en-us/champions/brand/), [Syndra](https://www.leagueoflegends.com/en-us/champions/syndra/) and [Xerath](https://www.leagueoflegends.com/en-us/champions/xerath/).

Every hero has idle, run, attack, Q/W/E/R, hit, death and recall animations: six mapped poses per action, 720 new logical frames. Art was generated with the built-in imagegen tool. Separate generated repairs supply Zephyr's missing hit row and full-body ranged release/recovery frames. Mapping uses inspected alpha regions and feet pivots; the original PNGs are not modified. Existing heroes retain their previous mappings. New portraits and 48 skill icons use measured atlas regions. Twelve dedicated VFX sheets contain 192 mapped frames.

Exact prompts, generation mode and source file records are saved in `assets/animations/roster12-generation.json`, `roster12-repairs.json`, `zephyr-hit-prompt.txt`, and `assets/vfx/roster12-generation.json`. Runtime assets live under `assets/animations`, `assets/ui` and `assets/vfx`. Regenerate only these mappings with `python tools/analyze_action_sprites.py --heroes leona blitzcrank renekton xinzhao riven fiora caitlyn lucian sivir brand syndra xerath`.

Skills list mana, cooldown, range, AD/AP scaling and current damage/shield amounts. Recasts use the existing countdown widgets; additional statuses show parry, artillery and charge states, rifle marks and directional vitals. Saur has a Fury display. Every new hero receives role-appropriate shop recommendations, augments and AI casting. Dash AI respects the existing tower-survival checks.

The host owns combat, traps, spheres, channels, Fury, marks and recasts. Guests receive animation states, remaining buff durations, projectile identity and live caster references. Area effects now carry caster references too. Steam protocol is 4; all participants must use v0.5.0. Multi-account internet Steam sessions require real players and connections; local three-process tests exercise the shared replication and command paths through LAN.

Validation includes 1,313 skill/resource/recast/asset checks, twelve-hero AI battle simulations, four batches of one host and two guests covering all twelve selections, native selection/animation captures, older hero/hook/network regressions, and the exported Steam smoke test. Export verification loads all 720 new action frames, icons and dedicated skill sheets from the packaged PCK.
