# v0.5.1 — Passive identities, Lancer combat and co-op concealment

All thirty heroes now have explicit passive mechanics. Hover the hero portrait during a match for its description and current counters, or hover the passive name in hero selection. These are LoL-inspired adaptations for the PvE game: the linked official champion pages establish each identity, but numbers, distances and timing below describe this game's implementation rather than exact live LoL patch parity.

## Lancer

Determination counts successful basic attacks independently of Q: every third attack heals and deals bonus damage. Q empowers three attacks; only its third hit knocks the enemy airborne, with a lifted sprite and an AIRBORNE badge. Remaining Q attacks and duration are visible above Lancer.

E is a homing charge toward the selected enemy. Its directional spear trail follows the charge; magic damage, the short slow and impact effect happen on arrival. It grants an attack-speed window. The old large circular cast effect is replaced by a narrow trail and compact arrival effect.

## Portraits and co-op

All thirty selection portraits use square clipped crops inside the same gold frame. Original sprite files remain intact. Bush visibility is calculated by the host for each team and replicated; guest interpolation no longer reveals a hidden hero. Entering brush and temporary attack reveals work on both guests. Passive counters, proc buffs and airborne state also replicate.

Vesper's W is a learned passive rather than a five-second activation. It displays P and can be ranked normally. Mana-free heroes no longer have fake mana costs; Rokan and Shade use energy. Persistent AP, armor, souls and splinter gains survive respawn within a match and reset at the next match; they are separate from saved account upgrades.

## Hero passives

| Hero | Identity / official reference | Implemented behavior |
| --- | --- | --- |
| Solara | [Illumination](https://www.leagueoflegends.com/en-us/champions/lux/) | Damaging spells mark for 6s. Your next attack or R consumes the mark for level-scaled magic damage, then R refreshes it. |
| Nyra | [Essence Theft](https://www.leagueoflegends.com/en-us/champions/ahri/) | Every 9 minion kills restores health. A champion takedown you contributed to restores more health. |
| Kael | [Rising Spell Force](https://www.leagueoflegends.com/en-us/champions/ezreal/) | Spell hits grant 10% attack speed for 6s, up to 5 stacks. Q also refunds 1.5s from all skill cooldowns. |
| Skadi | [Frost Shot](https://www.leagueoflegends.com/en-us/champions/ashe/) | Attacks slow for 2s and deal increased damage to your frosted targets. Critical chance increases this bonus; critical attacks strengthen the slow instead of multiplying damage. |
| Ember | [Pyromania](https://www.leagueoflegends.com/en-us/champions/annie/) | After 4 casts, the next offensive spell stuns for 1.25s. Begin the match and respawn ready. Shield casts build stacks without consuming readiness. |
| Bastion | [Perseverance](https://www.leagueoflegends.com/en-us/champions/garen/) | After 8s without champion or tower damage, regenerate 1.5–3.5% maximum health per second. Minion damage does not interrupt it. |
| Kaze | [Way of the Wanderer](https://www.leagueoflegends.com/en-us/champions/yasuo/) | Moving builds Flow. At 100 Flow, champion damage triggers a 1s shield. Critical chance is multiplied by 2.5, with reduced critical damage. |
| Rokan | [Flurry](https://www.leagueoflegends.com/en-us/champions/leesin/) | Each successful cast or recast primes two attacks with 40% attack speed; they restore 20/10 energy. Energy is capped at 200 and regenerates 10 per second. |
| Shade | [Contempt for the Weak](https://www.leagueoflegends.com/en-us/champions/zed/) | Attack targets below 50% health for 6–10% maximum-health bonus magic damage. Ten-second cooldown per champion target. |
| Rixa | [Get Excited!](https://www.leagueoflegends.com/en-us/champions/jinx/) | A champion or structure takedown you contributed to grants 60% movement speed and 25% attack speed for 6s. |
| Scarlet | [Voracity](https://www.leagueoflegends.com/en-us/champions/katarina/) | Champion takedowns you damaged within 3s refund 15s of all cooldowns. Pick up Q/W daggers to spin for magic damage and refund most of E's cooldown. |
| Aurelia | [Divine Ascent](https://www.leagueoflegends.com/en-us/champions/kayle/) | Attacks stack attack speed (five stacks). Level 6 grants ranged attacks, level 11 adds fire waves while exalted, and level 16 grants permanent exaltation and more range. Exalted grants 8% movement speed. |
| Rook | [Hemorrhage](https://www.leagueoflegends.com/en-us/champions/darius/) | Attacks and damaging physical abilities apply a 5s bleed, up to five stacks. Five stacks on a hero grant Noxian Might: bonus AD and instant five-stack application. R scales with bleed and a killing R resets its cooldown. |
| Granite | [Granite Shield](https://www.leagueoflegends.com/en-us/champions/malphite/) | Recharge a shield worth 10% maximum health after 8s without taking damage. Shield capacity follows your health upgrades. |
| Vexel | [Phenomenal Evil](https://www.leagueoflegends.com/en-us/champions/veigar/) | Spell hits on champions grant 1 AP. Q last hits grant 1 AP (2 for siege/super minions). Champion takedowns grant 5 AP. Stacks persist through respawns for this match. |
| Noctra | [Soul Siphon](https://www.leagueoflegends.com/en-us/champions/morgana/) | Heal for 20% of actual spell damage to heroes and siege/super minions. Ordinary minions, item damage and blocked hits do not heal. |
| Vesper | [Night Hunter](https://www.leagueoflegends.com/en-us/champions/vayne/) | Gain 12% movement speed when moving toward a visible enemy hero within 600. Triple this bonus during R. Learned W is always active on attacks and Condemn. |
| Warden | [Damnation](https://www.leagueoflegends.com/en-us/champions/thresh/) | Nearby enemy deaths drop souls (heroes and large minions always; every third ordinary minion). Walk within 65 or place W lantern to collect. Each soul grants 0.75 armor and AP this match. |
| Aegis | [Sunlight](https://www.leagueoflegends.com/en-us/champions/leona/) | Spells mark for 1.5s. Only allied champions consume your marks for bonus magic damage; your own damage refreshes them. |
| Bolt | [Mana Barrier](https://www.leagueoflegends.com/en-us/champions/blitzcrank/) | Damage taking you below 30% health triggers a 10s shield worth 30% current mana, before the hit lands. 45s cooldown. |
| Saur | [Reign of Anger](https://www.leagueoflegends.com/en-us/champions/renekton/) | Attacks generate 5 Fury (7.5 below half health). Unempowered Q/E hits also generate Fury. Out of combat Fury decays; 50 Fury empowers the next applicable skill. |
| Lancer | [Determination](https://www.leagueoflegends.com/en-us/champions/xinzhao/) | Every third successful attack deals bonus physical damage and heals, independently of Q. Q empowers three attacks; only the third becomes airborne. |
| Riftblade | [Runic Blade](https://www.leagueoflegends.com/en-us/champions/riven/) | Every cast and recast grants a rune, up to 3 for 6s. Attacks consume one for level-scaled bonus physical damage. |
| Duelia | [Duelist's Dance](https://www.leagueoflegends.com/en-us/champions/fiora/) | Strike a hero from the indicated vital side for maximum-health true damage, healing and movement speed. Each Duelia owns separate directional marks. |
| Caliber | [Headshot](https://www.leagueoflegends.com/en-us/champions/caitlyn/) | Every sixth attack becomes a crit-scaling Headshot. Bush attacks build two stacks. Trap/net marks grant an independent Headshot with double attack range against that target. |
| Solstice | [Lightslinger / Vigilance](https://www.leagueoflegends.com/en-us/champions/lucian/) | Casts prime a second shot. Allied healing/shielding or nearby enemy immobilization primes two bonus-magic attacks. Second shots reduce E cooldown. |
| Zephyr | [Fleet of Foot](https://www.leagueoflegends.com/en-us/champions/sivir/) | Damaging a champion with an attack or ability grants 20% movement speed for 2s. |
| Pyre | [Blaze](https://www.leagueoflegends.com/en-us/champions/brand/) | Spells apply a 4s stacking burn. Three stacks on heroes cause a delayed explosion. Killing a burning unit restores mana. |
| Umbra | [Transcendent](https://www.leagueoflegends.com/en-us/champions/syndra/) | Gain 5 splinters per level, 1 per siege last hit, and 2 after two spells hit the same hero within 4s (8s per-target cooldown). At 40/60/80/100 splinters upgrade Q/W/E/R; at 120 gain 15% AP. |
| Arclight | [Mana Surge](https://www.leagueoflegends.com/en-us/champions/xerath/) | An attack restores mana every 8s, doubled against heroes. Last hits reduce the remaining cooldown by 1s. |

## Validation

- PassiveVisionTests: 176 checks across all 30 heroes, portrait clipping, third-hit airborne, charge arrival, failed casts, shield damage, permanent W, dagger/soul collection and death-time Q recharge.
- Roster12Tests: 1,313 checks; Roster12BattleTests: 214 checks in an AI battle.
- Native three-process PassiveVisionCoopTests: host 3 checks; each guest 21. Tests concealment, reveal expiry, bush entry, airborne presentation and passive counters.
- Native Roster12CoopTests batches 1 and 3 cover Lancer/Riftblade/Duelia and Pyre/Umbra/Arclight.
- Existing hero, Silver Bolts, hook and update/network regression scenes pass.
- Native screenshots checked for portrait framing, Lancer airborne and charge effects.
- Exported release PCK smoke: zero failures; actual Steam lobby creation, complete hero passive metadata and portrait crops, protocol 5, visibility/counter snapshots, skill/action art, shop, respawn and progression.

All co-op players must update to v0.5.1 (network protocol 5). Three-process tests use localhost; multi-account Steam internet co-op still needs a test on separate PCs/accounts.
