# v0.6.9 — stolen builds continue into normal AI progression

Echo bots follow the saved build first. After their recorded item goals are complete, they continue that hero's **original AI item build**, rather than jumping straight to stat consumables. Purchases use real gold and recipe credit. Items already owned, and components covered by an owned upgrade, are skipped. An alternate saved pair of boots is retained; incompatible boots and purchases that cannot fit are skipped so later valid upgrades can proceed. Bots wait for gold for the next valid original purchase.

Item completion is remembered for that bot for the rest of the match. If the original build upgrades a saved component, the Echo does not buy that component again. It does not sell a saved loadout merely to force another build. Once no original item purchase fits, recorded elixir goals are bought at their escalating prices, followed by the usual AI stat consumables. Full saved loadouts can therefore keep growing in late-game stats.

Recorded skill ranks are followed when legal. Once the recorded path ends, new skill points continue through the hero's normal priority. Remaining level-up upgrade milestones use the normal randomized AI choices. Copied rolls remain applied only once. After all skills are maxed, level-ups grant the existing veteran AD/AP/HP/MP stats through level 100. These level behaviors already worked; this release adds explicit coverage for all 32 heroes.

The host remains authoritative in co-op. Subsequent original purchases, skill ranks, rolled upgrades and consumable stats reach guests through normal snapshots. The library and Echo tooltip explain the continuation behavior. The ten-hero archive, difficulty-weighted replacement rule, unique enemy teams and qualification threshold are unchanged.

Validation covers all 32 heroes progressing beyond partial saved paths, saved components upgraded without being re-bought, alternate boots, full loadouts, actual gold spending, recorded then normal consumables, skill priority, every upgrade milestone and level 100. A real three-peer co-op scenario verifies the saved path first and its later original progression on both guests. Item, enemy progression, archive, updater and exported Steam/gameplay checks cover regressions.

Steam protocol is **13**. Everyone in a room must use **v0.6.9**. Extract the full Windows release ZIP or use the verified in-game updater; existing progression is preserved.
