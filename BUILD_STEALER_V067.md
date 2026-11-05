# v0.6.7 — build stealer

The host records completed PvE runs by human players with **15 or more hero kills and K/D ≥ 5**, counting zero deaths as a denominator of one. At least one match item must be owned. Victories and defeats can qualify; abandoning a match cannot. Solo saves locally; co-op captures every qualifying connected human teammate on the host. Bots never teach their own builds. PvP neither uses nor records the feature.

## Best 10

Only the best **10** distinct blueprints are stored in the host's existing atomic progression profile. Up to 20 candidates can be evaluated at once; no extra 20-build history is persisted. Identical blueprints keep their strongest recorded performance. The signature includes hero, final items, exact level-up rolls, skill order, summoner choices and elixir goals; player names and result scores do not produce duplicate builds.

Each record shows source difficulty N, kills/deaths/assists, outcome and score. Score is `round(difficulty_reward_multiplier × (100 × kills + 15 × assists) / max(1, deaths))`, plus 500 for a victory. Saved scores are recalculated on load. Unknown heroes/items, invalid skill histories, non-finite rolls and unsupported fields are filtered. Existing credits, equipment and daily quests remain in the same profile.

## Two Echoes, one fresh enemy

The next PvE lineup assigns two enemy slots to saved blueprints. Different archived heroes are preferred, and recent blueprint picks are rotated when alternatives exist. With only one saved build, both Echoes can borrow it. The remaining normal bot stays on its regular item and upgrade logic and picks a fresh distinct hero; its previous hero is avoided on the next match. An empty library leaves all three opponents ordinary. Echoes may mirror a player's hero.

Echoes use the blueprint's actual hero and summoner choices, preserving the hero's real kit and passives. They start at normal match level and buy with actual gold and recipe credit, including affordable components. Goals retain the final loadout without consuming final component items into another final item. Saved randomized upgrades unlock once at their original earned milestones; missing milestones use normal bot choices. Recorded skill paths obey normal rank gates. Recorded late-game elixir stacks cost normal escalating prices, then the bot continues ordinary late-game training.

Permanent account upgrades, saved equipment, source level, veteran level stats, saved gold, temporary buffs and cooldowns are **not** granted to Echoes. Current match difficulty supplies the normal enemy scaling. Source N is ranking metadata, not a second difficulty multiplier. This prevents a level-3 match from starting against a free level-100 inventory.

## UI and multiplayer

Main menu → **Build Stealer** opens the ranked library with portraits, source scores, item tooltips, summoner icons, upgrades and elixir targets. Hover upgrade text for exact rolled stats. Enemy Echo names and their scoreboard tooltip expose the borrowed build. The match end screen reports qualifying builds and retention. Guests see the host's selected Echoes and final learning report while keeping their own local archive untouched.

The host includes the chosen blueprints and heroes in the start configuration **before** every player's loading screen prepares the lineup. Item inventories, actual stats and upgrades continue through existing authoritative snapshots. Native warmup checks verify the chosen Echo action pages are resident. Steam protocol is **11**; everyone in a room must use v0.6.7.

## Validation

Coverage includes threshold boundaries, deduplication, ranking 20 candidates down to 10, score sanitization, profile restart, completed/abandoned runs, human/co-op eligibility, normal-price purchases, all 32 recommended hero builds, retained components, exact milestone rolls, legal skill priority, single-record and empty libraries, two Echoes/one normal bot, current difficulty and PvP isolation. A three-process co-op scenario checks both guests' exact inventories, copied rolls, source metadata and the host-only recording of all three humans. Native UI capture and Echo warmup verify rendering and actual loading behavior. Existing support, enemy progression, item, PvP/updater and exported Steam checks cover regression behavior.
