# Daily quests and permanent Rift Relics — v0.4.0

Open **Daily Quests / Equipment** on the main menu. Equipment is saved alongside permanent credits and upgrades. Existing saves migrate without losing their credits, ranks, difficulty, audio or casting settings.

## Five daily rewards

Each objective gives one random equipment drop, automatically awarded on completion:

| Quest | Objective |
| --- | --- |
| Into the Rift | Complete one match |
| Claim the Throne | Win one match |
| Hero Hunter | Earn twelve hero kills across completed matches |
| Lane Harvester | Last-hit eighty minions across completed matches |
| Rift Veteran | Complete three matches |

There are at most **five gear drops per local calendar day**. Progress accumulates at match completion, including co-op, and survives restarting. Victories count; defeated runs require at least two minutes to advance quests. Leaving an unfinished match grants no quest progress. Daily progress resets at local midnight; existing gear stays saved. An older system date does not reopen an already completed day. Offline local saves are used; this is not a server-verified daily service.

## Equipment and randomized stats

Nine slots: head, body armor, weapon, sub weapon, shoes, ring I, ring II, necklace and gloves. Two different rings can be worn; the same item cannot occupy both slots. Slot-compatible items replace the previous item without destroying it. Common, Magic, Rare, Epic and Legendary items have one through five distinct random modifiers, plus their base equipment stats. Weapon bases include AD blades, AP staves and bruiser mauls. Modifiers include AD, AP, health, mana, armor, magic resistance, health regeneration, attack speed, movement speed, cooldown reduction, critical chance and lifesteal.

The stash holds 200 items, sorted by level and rarity, with category filters. Select an item to inspect its stats and compare it with the destination slot; hover for individual modifier rolls. Equipped items have coloured rarity borders. Unequip before salvaging. Salvage requires confirmation and gives `5 + item_level × (rarity_index + 1) × 2` permanent credits. A full stash holds a completed quest reward pending until space is freed and **Claim Waiting Drops** is pressed; its originally earned difficulty is retained. Unclaimed daily rewards expire at the next daily reset.

Equipment contributes to starting stats alongside permanent credit upgrades. It remains separate from the six-item match inventory and match stat consumables. Buying shop items, dying and respawning preserve equipped bonuses. Equipment changes are locked during a match; enemy bots do not receive the player's gear. Multiplayer transmits all supported equipment stats for each player's own hero.

Percentage equipment totals have caps: +75% attack speed, +12% movement speed, 20% cooldown reduction, +35% critical chance and 20% lifesteal. Flat equipment stats stack. The existing 40% overall cooldown-reduction cap still applies after match purchases. Item level is equipment power, not a hero-level requirement: level-one heroes can use saved high-level relics.

## Difficulty and item level

A completed quest rolls item level **N−2 through N**, bounded to 1–99, using the difficulty captured at match launch. Equipment keeps its rolled level and stats; changing the menu difficulty does not upgrade old items. Flat base stats scale with `(1 + (level−1) × .035) × (1 + rarity_index × .12)` and a 90–110% roll. Flat affixes scale by `1 + (level−1) × .04`; percentage rolls scale more slowly by `1 + (level−1) × .008`.

| Difficulty | Common | Magic | Rare | Epic | Legendary |
| --- | --- | --- | --- | --- | --- |
| N1 | 35% | 40% | 19% | 5% | 1% |
| N99 | 5% | 20% | 35% | 25% | 15% |

Odds interpolate between these stages. Higher difficulty also raises enemy health, damage, armor and magic resistance more strongly. N1 remains unchanged. At N99, enemy health is approximately ×17.9 and damage ×9.7; existing tower health/damage scaling and increasing AI aggression/reaction remain in effect. Rewards are based on the actual run difficulty, including the host's difficulty for co-op.

## Validation

The dedicated native equipment test passed 7,267 checks, covering generated items, slot/ring rules, random-roll persistence, old-save migration, daily cap/reset, clock rollback, duplicate results, full-stash deferred rewards, failed-save rollback, menu layout/Esc, actual champion stats, shopping, death/respawn, difficulty growth and result-screen rewards. Existing progression, PvE, menu input and all-hero death tests passed. Three real local peers passed equipment replication and daily rewards using the release Godot 4.7.2 engine with no errors. Godot 4.6.3 produced an ENet teardown diagnostic after the same peers passed; the release engine completed cleanly.

Visual captures: `tests/equipment-menu-v040.png` and `tests/equipment-result-v040.png`. Tests use isolated profiles and do not modify the player's save. New profile writes use a temporary file and replace the old file only after a successful complete write. No new generated artwork is needed: relics reuse the established painted item icon system.

All co-op players should update to v0.4.0.

The actual exported AppID 480 Steam smoke test passed with zero failures, including the equipment menu, painted icons, equipped bonuses in a hosted match, safe respawn and daily gear rewards from the result.
