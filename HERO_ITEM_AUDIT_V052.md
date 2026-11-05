# v0.5.2 — Full hero and item effect audit

Audited the game's current intended mechanics and descriptions across all 30 heroes, 120 skills and 76 shop items. Mechanics remain PvE adaptations; this is not a claim of exact live LoL patch parity. Existing passive identities are documented in PASSIVES_V051.md.

## Fixed mismatches

- Magic/physical mitigation: per-skill classification now distinguishes Skadi R, Kael E/R, Rokan E, Rixa E and Kaze E from physical skills. Duelia W, Caliber E, Solstice W and Lancer E use magic resistance.
- Skill shields now track their remaining amount and expire independently. Prismatic Barrier, Molten Shield, Courage, Safeguard, Granite W, Black Ward and Soul Lantern preserve unrelated shields. Flow and Valor no longer expire twice. Absorbing an item shield does not consume Granite's passive shield.
- Bloodthirster's 15% overheal cap applies to its own shield; it cannot shrink another shield. Lifesteal uses actual health damage and excludes overkill.
- Luden deals a separate magic proc on physical spells. Its item damage no longer counts toward Noctra's spell healing or a hero's spell-hit passive. Blocked and zero-damage hits do not trigger offensive item procs.
- Critical strikes multiply the ordinary attack damage, rather than also multiplying Spellblade, current-health item damage and additional on-hit bonuses.
- Warmog recovery respects healing modifiers. True damage bypasses percent damage reduction while still being absorbed by shields.
- Ignite delivers all ten ticks, including its final half-second; long frames retain accumulated ticks.
- Ember's cone starts at her body and hits enemies immediately in front of her. Her targeted Q rejects empty ground without spending mana or starting cooldown.
- Black Ward and Aurelia R can explicitly target yourself even when an ally is nearby.
- Skadi Q has one attack/on-hit event plus two damage fragments, so a single attack cannot instantly trigger Kraken. Its tooltip now shows the actual rank-scaled total AD damage.
- Solstice's visible Lightslinger second shot applies attack item procs and lifesteal without recursively generating another second shot.
- Kael's zero-damage Flux mark and Shade's ultimate mark are blocked by spell shields. Physical Death Mark damage respects Death's Dance.
- Frozen Heart also reduces nearby minion attack speed; Bami's tooltip states its minion cap.
- Mana items and veteran levels cannot create fake mana on resource-free heroes or raise energy above 200. Archangel converts actual mana only.
- Last-hit prediction includes guaranteed champion bonuses such as runes, third attacks, empowered attacks, charged Flay and learned on-hit passives. Random critical strikes remain excluded from the farming cue.

## Coverage and validation

| Check | Coverage | Result |
| --- | --- | --- |
| AllContentAudit | All 120 skills at ranks 1 and 5 (R capped at 3), 1,800 action-frame mappings, every ordinary item's stats on every hero, all 76 purchases/tooltips/icons, selling removes stats | 10,658 checks, zero failures |
| CombatInteractionAudit | Damage types, stacking shields, partial absorption, expiry, healing, crit/item separation, all Ignite ticks, spell shields, on-hit events, farming predictions and invalid casts | 62 checks, zero failures |
| PassiveVisionTests | All 30 passives, bush visibility, resource rules and recasts | 176 checks, zero failures |
| ItemBuildTests | Tank/AD item procs, shared cooldowns, cleave/aura exclusions, real recipes, selling and builds | 243 checks, zero failures |
| ExpansionTests / KitRemakeTests | Original added hero spells, gear procs, zones and painted skill mappings | 408 / 192 checks, zero failures |
| Roster12Tests / Roster12BattleTests | Twelve added heroes, casts/recasts, scaling, control and AI battle | 1,313 / 214 checks, zero failures |
| BalanceTests / EnemyProgressionTests | Mitigation, N scaling, projectiles, level 100 and resource caps | 800 / 454 checks, zero failures |
| DeathLifecycleTests / ARAMLoopTests / CorePveTests | Death/respawn, buying, cooldowns, XP and repeatable stat consumables | 331 / 45 / 81 checks, zero failures |
| Native LAN co-op | Host and two guests: movement, skills, purchasing, progression, death and disconnect | Zero failures |
| Native PassiveVisionCoopTests | Concealment, temporary reveal, airborne, counters, overlapping shields, absorption and expiry on both guests | Host 3 checks, guests 33 each; zero failures |

Exported release PCK smoke also passes: a real Spacewar lobby, packaged hero/skill assets, independent timed shields, shopping, death/respawn, equipment and progression.

Additional hero, hook, Silver Bolts, attack-move, minion presentation and update regressions pass. Original tests were updated where they still expected 18 heroes, castable Vesper W or mana growth on energy/resource-free heroes.

These checks exercise the game implementation and existing assets. They cannot prove every possible six-item combination, latency condition or future balance change. Multi-account Steam internet co-op still needs testing on separate PCs/accounts. Use v0.5.2 on every co-op PC.
