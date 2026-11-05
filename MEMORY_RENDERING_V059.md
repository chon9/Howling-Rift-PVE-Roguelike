# v0.5.9 — Retained texture memory and rendering work

Investigating lag over repeated match starts found retained sprite artwork and unnecessary render/display work. The repeat test did not show accumulating scene nodes, orphan nodes or UI signal connections, so this is not evidence of an unbounded scene-node leak.

Animation pages now use a 128 MiB estimated cache budget with least-recently-used eviction. Pages needed by the current six-hero roster and minions are pinned, including repaired/supplemental action pages. Pinned artwork may exceed the budget when required by a roster; it is never evicted during combat. Unused skill sheets are released as rosters change.

Sprite masks update shader parameters only when the animation frame changes. Existing frame crops, exclusions, team colors and hit flashes remain intact. Spell-impact timing IDs clear between matches, sound gates discard old timestamps, and Deadeye charge IDs retain only current heroes. Rebuilding the main menu no longer reapplies an already-selected fullscreen/V-sync mode.

A native packaged 20-match comparison retained about 477 MiB of texture memory before and 277 MiB after, with stable node counts and zero orphan nodes. The scenario cycles all 30 heroes, loads every animation page for each roster, spawns minions/effects, and returns to the menu. This is a controlled resource-retention scenario, not an FPS guarantee or a diagnosis of every possible lag source. Evicted artwork must reload when switching rosters; this trades some roster-loading time for lower retained texture memory. This test does not measure sustained combat frame times.

The updater now follows the renamed GitHub repository and accepts verified release links from both its current and original names. Older installed builds may need this release downloaded manually because they reject the renamed repository’s asset URLs.

Validation includes full hero/item and Deadeye/fullscreen regression checks, repeated-start resource checks, native co-op and packaged Steam validation.
