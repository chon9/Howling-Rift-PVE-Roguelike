# Rixa damage audit

Base N1 level-3 stats without items/upgrades: 770 HP, 69 total AD, 0.72 attacks/s, 390 attack range (490 during Rocket Party). Base stats were not changed.

Fixed three reproducible combat errors:
- Rocket autos used already-scaled, already-mitigated primary damage as splash input, then applied difficulty and secondary armor again. Splash now starts from 35% of the raw auto payload and applies each victim's modifiers once. A shield or armor on the primary victim does not modify damage to other victims.
- The three trap areas had independent hit lists, allowing overlaps to damage/stun a champion more than once per cast. They now share a hit list; a fresh cast owns a new list.
- Mega Rocket's primary victim took the direct impact and 65% explosion again. The explosion now excludes the direct victim and still damages neighboring enemies.

Controlled regression examples: raw 100 auto with difficulty x4 produced 560 splash before and 140 after. Rank-2 overlapping traps produced 170 before and 85 after. Rank-1 ultimate with 69 AD produced 480 damage before and 291 after. The tests additionally cover N99, shield/armor interactions, repeated trap occupancy, new casts, AP scaling and tooltip behavior.

RixaBalanceTests.tscn contains focused combat regressions. RixaLaneAudit.tscn runs a 120-second mirrored N1 Jinx/Lee Sin/Lux bot match with fixed gameplay and draft seeds, reporting per-hero level, K/D/A, CS and equipped stats. This is a smoke test, not a broad matchup win-rate estimate. Draft upgrades, items and kill/XP snowballing remain active.
