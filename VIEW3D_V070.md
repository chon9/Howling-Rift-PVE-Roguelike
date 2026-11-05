# v0.7.0 — Rift3D: the Howling Rift in 3D

The match is now drawn in 3D by default, with a tilted camera like League of Legends or Mobile Legends. Rift3D is a presentation layer only. The simulation, AI, items, damage, cooldowns, hitboxes and network snapshots are the same as in v0.6.9. Every unit, missile, zone and effect is read from the 2D game each frame and redrawn in 3D. Classic 2D is still available as an option.

## What changed

- **Camera.** The default **LOL** camera looks down at 56° with a 40° field of view. The mouse wheel zooms between 15 m and 21 m. **MLBB** uses a lower 50° pitch at a fixed distance. Edge pan, camera lock, recentre and screen shake all work as before, and the camera keeps both the near rail and the far parapet in frame.
- **Arena.** The ice bridge, parapets, abyss, brush, fountains, crystal cores and ice clusters are built procedurally in 3D. The sun casts shadows, and snow falls on Medium and High. Ground markings such as range rings, skill footprints, aim reticles and move pings are drawn on a world-locked ground canvas, so they stay where they were cast.
- **Units.** Heroes, minions and corpses are the existing painted action sheets shown as upright cards. Their feet sit exactly on the sim position, with a shadow and a team ring under each. Knock-ups lift the card. Death plays the corpse animation, then the corpse dissolves.
- **Structures.** Turrets, inhibitors and nexuses stand on their painted base with a contact shadow. Their attack glow sits at the crystal. Destroyed structures leave a ruin plinth.
- **Missiles and spells.** Missiles fly at chest height and point along their path. Turret bolts start from the crystal. Hook chains run from the caster's chest. Beams, pillars, ring spikes, tornadoes, wind walls, traps and lanterns stand upright. Spell bursts, hit sparks and particle sprays play on the body they hit. Trails, level-up and recall pillars, blink flares and Zed's shadow clone are 3D effects.
- **Overhead UI.** Health and resource bars, names, levels, status icons, floating damage numbers and skill captions are drawn in screen space above each unit. They stay crisp and readable at any zoom. Minion bars are smaller, so a large wave does not become a wall of bars.
- **Picking.** Clicks, hover, attack-move, smart-cast and the cursor use the 3D cards' on-screen shapes, so clicking a hero's body selects that hero. The hovered unit gets a red outline for an enemy or a blue outline for an ally.
- **Loading.** Match loading also warms the 3D shaders and materials before the match clock starts.

## Settings

The new rows are under **PERMANENT UPGRADES / SETTINGS** on the main menu, and **SETTINGS** in a match, below the graphics controls:

- **VIEW:** 3D or CLASSIC 2D. Takes effect for the next match after the main menu reloads (finish or leave a match, or restart).
- **CAMERA:** LOL or MLBB. Applies immediately.
- **3D QUALITY:**
  - **Low** turns off shadows, glow, snow and MSAA, uses a smaller ground canvas, and updates the ground canvas and hover every other frame.
  - **Medium** adds 2x MSAA.
  - **High** (the default) uses 4x MSAA.
  - Applies immediately.
- **RENDERER:** COMPATIBILITY (the default) or FORWARD+. Takes effect after a restart.

The choices are saved with your profile. Existing profiles start in 3D until VIEW is changed.

## Playing in classic 2D

- In the game: set **VIEW** to **CLASSIC 2D**.
- From the project folder: run `Play.cmd 2d`. A plain double-click on `Play.cmd` starts the game in 3D, and `Play.cmd editor` opens the Godot editor. `Play.cmd` finds Godot as `K:\Godot_v4*_win64.exe`, then `K:\Godot\Godot_v4*_win64.exe`, then `godot` on the PATH.
- From the command line: add `-- --view2d` after the Godot arguments, or set the environment variable `HOWLING_VIEW=2d`. `--view3d` and `HOWLING_VIEW=3d` force 3D.

A launch flag or environment variable overrides the saved VIEW choice for that session. The settings panel says when this has happened.

## Multiplayer

The view is local to each player: one guest can play in 3D while another plays in 2D in the same room. Snapshots, effects and the Steam protocol are unchanged (protocol **13**), and no network traffic was added. Replicated units, corpses, missiles and zones get the same 3D views as on the host.

## Known limitations

- **Single-facing painted art.** Heroes and minions are flat painted cards that always face the camera. They flip left and right like the 2D sprites; there are no turn-around angles or 3D models. Up close at a low pitch the cards can look like paper standees.
- **Performance cost.** 3D costs more per frame than classic 2D. Measured at 1920×1080 on an RTX 3080 with Compatibility rendering, using the same 6-hero teamfight scene with 52–63 minions:

  | | 3D High | 3D Low | Classic 2D |
  |---|---|---|---|
  | Whole frame, sim paused | 10.6 ms | 9.6 ms | 6.7 ms |
  | Whole frame, live sim | 13.5 ms | 12.8 ms | 10.7 ms |
  | Render cost (CPU + GPU) | 4.7 ms | 3.1 ms | 2.5 ms |
  | 3D sync script | 1.3 ms | 1.3 ms | — |
  | Draw calls | 737 | 513 | 616 |

  These numbers depend on the PC and on how many minions are alive.

- **VIEW applies to the next match**, not the one in progress.
- The Lux R ground strip is drawn very bright in 3D.
- The first use of a few glow and abyss mist effects can still hitch slightly; loading does not warm those shaders yet.

## Validation

Every presentation package has headless tests, plus windowed screenshot tests in both Compatibility and Forward+.

- **Headless view tests:** View3D, view contracts, arena, units, structures (grounding on all four structure types), picking, overhead UI, VFX coverage of every effect kind, projectiles, zones, unit extras and settings round-trips.
- **3D default, headless suite:** 69 of 82 tests pass. Every failing test also fails in classic 2D, with the same failure messages, and is already on the known-failure list.
- **Classic 2D (`HOWLING_VIEW=2d`):** 70 of 82 pass, with no new failures. The difference from the 3D count is Roster12BattleTests, a known random failure.
- **Windowed visual scenes in 3D:** all 21 pass. This includes the 3D screenshot scenes and the performance scene.
- **Three-peer LAN co-op in 3D:** on each guest, the tests check that:
  - every replicated unit's 3D view sits within 1 mm of its sim position;
  - replicated deaths get corpse views;
  - replicated missiles get views.
- **Network tests:**
  - Three co-op tests (skill footprints, status effects, passive vision) wrongly treated "match not running yet" as "match finished" while the loading barrier was still closed. Their guests now wait for the match to start before counting.
  - The remaining network failures happen in classic 2D too.

Steam protocol is **13**. Everyone in a room must use **v0.7.0**. Extract the full Windows release ZIP or use the verified in-game updater; existing progression is copied to the new save folder on first launch.
