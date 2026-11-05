# v0.6.6 — match loading and first-use stutter

Pressing Play after hero selection now prepares the actual match lineup before the match clock starts. The gold loading panel shows progress and supports Back to Main Menu or Escape. Solo, LAN and Steam use the same native loading path.

## What changed

- Resolve and retain one roster for both loading and spawning; loading cannot prepare one random lineup and then spawn another.
- Load every action page and override page for the selected heroes, plus melee/caster/siege/super/Tibbers actions. Idle, movement, attacks, hits, all casts, recall and death pages are available before play.
- Prepare the lineup's skill sheets, ordinary and expansion projectiles, wind effects, impact sheets, all status families and all six kill crests. Prime the existing runtime caches and crop tables.
- Background resource loading uses at most two requests at once and retrieves resources only after their requests complete. The loading screen draws before requests start.
- Draw the textures with ordinary, team-cloth and additive materials beneath the opaque loading screen. Warm kill-feed fonts. Draw the actual HUD, unit materials and world screen effect before releasing gameplay. No dummy attacks, damage, particles or game rewards are generated.
- Match-scoped resource ownership keeps these resources resident during play. Returning to the menu releases that owner. The existing 128 MiB action cache and roster-specific effect trimming remain in use; the loader does not preload all 32 heroes for every match.
- Cancellation drains outstanding resource requests and invalidates the pending launch. Cancelling and immediately launching again cannot resurrect the previous match or leave an orphan loader.
- The match clock, farming and combat remain stopped while loading. Floating text and unit animation pause while the built match waits, keeping its starting presentation intact.

## Multiplayer

All players load the same configured lineup. The host waits for reliable loading acknowledgements from every remaining player before starting simulation. Leaving during loading removes that player from the barrier and hands over their slot using the existing bot rules. Guests that do not finish within three minutes are disconnected. A reconnecting PvP guest warms locally without pausing the already running host match; current snapshots restore the live state. A match result arriving during that guest’s warmup is buffered and applied after its world is built, so it cannot be lost behind the loading screen.

Steam protocol is now **10**. All players in a room must use v0.6.6.

## Validation

The cold-start probe on RTX 3080 / Windows / Compatibility rendering at 1280×720 and a 120 FPS cap found all 13 action pages for its six-hero lineup still unloaded after synchronous match creation. First action/effect access reached a **213.3ms** frame stall.

The native loading test prepares two different six-hero lineups, verifies every action override is resident, verifies status/effect/kill sheets, checks the exact spawned roster, and exercises cancellation/relaunch. Its isolated first-action frames were approximately **8.3–8.7ms** after warming. These measurements are specific to this PC and scenario; gameplay can still have CPU or driver spikes, and this change does not guarantee a fixed FPS on other hardware.

Three native game instances passed both PvE and PvP start barriers with a deliberately delayed guest. A departing guest also passed the barrier cleanup scenario. Existing three-peer co-op/support, reconnecting 1v1 PvP, support/tactics, updater and exported Steam smoke tests cover regression behavior. Twenty native matches through the loading path passed 198 memory/lifecycle checks; there were no accumulating menu nodes, signal connections or orphan objects, and texture memory remained bounded as rosters changed.

The implementation follows Godot's [background loading API](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) and its [Compatibility renderer warm-up guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html). New sprites or audio were not required for this fix.
