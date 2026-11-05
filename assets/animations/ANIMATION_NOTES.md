# Howling Rift animated unit art

All artwork was created with the built-in `image_gen.imagegen` tool using real transparent backgrounds. Exact prompts, including reference-sheet repair passes, are in `GENERATION_PROMPTS.json`. Original tool outputs remain in the Codex generated-images directory; copied production assets live here. No external art service or credentials were used.

## Coverage

12 heroes: Yasuo, Lee Sin, Garen, Katarina, Zed, Jinx, Kayle, Ashe, Annie, Lux, Ahri and Ezreal. Each has six frames for idle, run, attack, Q, W, E, R, hit, death and recall. Five minion/summon types (melee, caster, siege, super, Tibbers) each have six frames for idle, run, attack, hit and death. Total: 870 mapped frames.

- `heroes/<hero>-actions-v1.png`: primary hero atlases.
- `minions/<type>-actions-v1.png`: primary minion atlases.
- `hero-action-supplements-v1.png`: Katarina E, Annie hit and Lux R, in that row order.
- `yasuo-ultimate-v1.png`: six complete launch/leap/slash/landing R poses. The primary repaired sheet omitted one R pose, so this strip supplies the complete sequence.
- `source-history/`: retained crowded Yasuo/Ahri sheets replaced by the repair pass.
- `manifest.json`: actual source rectangles, feet pivots, main actor bounds, optional alternate texture paths, scale adjustments and isolated-neighbor exclusion rectangles.
- `ATLAS_REPORT.json`: coverage and source-size audit.

The source grids are generated artwork, so rows and columns are not assumed to be exactly uniform. `tools/analyze_action_sprites.py` reads alpha silhouettes and transparent gutters, selects the main connected actor and records safe exclusion rectangles for detached neighboring fragments. It does not alter the original art pixels. The game applies those exclusions while rendering the corresponding atlas; unrelated VFX retain their own material sampling. Run the analyzer after replacing sheets, then import resources in Godot.

## Runtime mapping

`UnitAnimator.gd` selects locomotion from actual distance traveled. A hero run cycle uses 162 world pixels of travel independently of visual scale, preserving its established pacing when body art is resized. Minions use 1.5 times body height. Idle has a separate slow clock; a 60ms movement hold prevents intermittent updates from flashing the idle row. Animation clocks freeze during pause. Art currently faces right in three-quarter view and mirrors horizontally when facing left; it does not include separate eight-direction views. Facing keeps its previous side during nearly vertical movement to prevent left/right flicker.

Hero attack frames 0-2 follow the actual queued auto-attack windup. Frames 3-5 start when melee damage or the ranged shot is released. Movement/stop orders cancel unfinished swings and interrupt visual recovery. Minions now queue a real 80-200ms windup before their melee contact or shot. Skill rows start only after successful casts, with Lee Q1 using frames 0-2 and marked-target Q2 using frames 3-5. Garen/Katarina spin rows loop while their spin buff is active, with other successful casts taking temporary priority. Recall uses its authoritative channel duration, and stun stops locomotion in a flinch pose.

Living and collapsed bodies use per-frame ground anchors. Yasuo's airborne R preserves a shared ground baseline. Death creates a separate, untargetable animated corpse: six frames over 720ms, a brief hold and fade, then removal at 1.8s. Respawn clears stale animation state. Portraits retain the existing menu art.

`LanSnapshot.gd` sends action, elapsed time, duration, windup, release state, serial and subclip limits for heroes and minions. Guests animate the same authored poses; replicated deaths/removals create local corpses. Projectile dimensions and visual altitude are also replicated.

## Projectile and overhead UI adjustments

Hero bodies are 56px tall, around 30-38% taller than ordinary melee/caster minions (43.2px/40.5px). Siege units are about hero height, with super minions and Tibbers larger. `Constants.CHAMP_ART_HEIGHT` controls living sprites, corpses and targeting art bounds. Hero auto missiles are 26% of body height (about 14.6px); regular skills are capped at 48% of body height and ultimates at 85%. Painted missile aspect ratios are slimmer. Hero shots render about 27px above the ground simulation point and minion shots 18px above it. Their ground-plane hitbox radius, damage and travel speed remain independent. Trail placement follows visual altitude, and homing steering uses delta-based smoothing. Yasuo's blade wave/tornado visuals scale with hero height (about 39x15 and 31x54 respectively). Hero health, shield, mana, name and status displays were raised above the new body art.

Targeting combines stable idle-body bounds with a small footprint, so clicking a creep's feet still selects it ahead of a nearby hero. Swinging weapons and spell glows do not expand the click target.

## Verification and previews

Godot 4.6.3 was used for the checks. `tests/ActionAnimationTests.tscn` checks all atlas cells, all 48 real hero casts, queued melee contact timing, movement cancellation, gait progression, pause, recall, stun, Lee Q subclips, minions, corpses, projectile scale/altitude and LAN packet coverage. Existing attack-move, ARAM, mechanics, status, grounding, shield and presentation suites are also run.

`tests/AnimationShowcase.tscn` is a native rendering review of all 17 units and action rows. `tests/AnimationCombatPreview.tscn` captures live ARAM with the real AI, projectiles, camera and HUD. Previews: `tests/action-animation-preview.mp4`, `tests/action-animation-preview.gif` and `tests/aram-animation-preview.mp4`. The LAN harness is `tests/RunLanTests.ps1 -Native`, including guest run/cast/corpse checks.
