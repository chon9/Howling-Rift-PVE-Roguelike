# Howling Rift 0.2.4 — tank and AD build expansion

The shop now contains **70 items**, with 24 additions, full component recipes,
painted icons, live stats, real combat effects, and the existing 70% sell return.

Tank choices: Sunfire Aegis, Hollow Radiance, Force of Nature, Randuin's Omen,
Dead Man's Plate, Unending Despair, Jak'Sho and Locket of the Iron Solari.
AD choices: Death's Dance, Maw of Malmortius, Ravenous Hydra, Titanic Hydra,
Sundered Sky, Spear of Shojin, Essence Reaver, Kraken Slayer, The Collector and
Mortal Reminder.
Components: Bami's Cinder, Bramble Vest, Tiamat and Hexdrinker.
Defensive boots: Plated Steelcaps and Mercury's Treads.

Use **Tank builds**, **Bruiser builds** or **Marksman builds** in the shop.
Recommended/AI build orders now use these options across eleven tank and AD
heroes. Complete builds fit all six inventory slots. Detailed descriptions
scroll independently so recipes and Buy remain visible above the action bar.

Examples to adapt to the enemy lineup:

- Armor frontline: Steelcaps, Sunfire, Randuin, Frozen Heart, Unending Despair,
  Jak'Sho. Substitute Thornmail when enemy healing is a problem.
- Anti-mage frontline: Mercury Treads, Hollow Radiance, Force of Nature,
  Spirit Visage, Jak'Sho, Warmog. Locket can replace a selfish slot for allies.
- Bruiser: Steelcaps, Black Cleaver, Sundered Sky, Titanic Hydra, Sterak,
  Death's Dance. Maw/Mercury Treads can answer magic-heavy opponents.
- Marksman: Berserker's Greaves, Kraken, Infinity Edge, Phantom Dancer,
  Mortal Reminder, Bloodthirster. Swap penetration/antiheal to match opponents.

These are adapted game items; read their descriptions for exact behavior.
All effects are automatic. Death's Dance reduces physical damage and heals
champion kills; it does not use the PC game's damage-debt mechanic.
Locket automatically shields nearby allies when its owner crosses low health.
Maw/Hexdrinker/Sterak share a cooldown and cannot stack their lifeline shields.
Burn auras, cleave items, armor penetration and Spellblade use their strongest
effect rather than adding duplicate procs. Consumed item shields expire without
removing unrelated shields. Last-hit prediction includes Titanic, Kraken,
charged Momentum, Nashor and the equipped Spellblade coefficient.

Artwork used built-in image_gen. Final atlas:
`assets/ui/tank-ad-item-icons-v1.png` (six columns, four rows; TankADItems.KEYS order).
Exact prompt: `assets/ui/TANK_AD_ITEM_PROMPT.json`.

Passed: ItemBuildTests (243), ExpansionTests (398), BalanceTests (800),
CastModeTests (25), ARAMLoopTests (45), GroundScalingTests (141),
CompactHudTests (28), native shop inspection, three-player LAN, and the full
AI lane simulation (318s, 20 waves, match completed). The exported package also
passed live Steam hosting, a real Sunfire purchase and loading its generated art.

All co-op players need version 0.2.4.
