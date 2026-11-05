# Howling Rift 0.2.5

- Shop categories now match item stats, including hybrid old/new items. The active category is gold highlighted; Consumables has its own filter. Price cards update when an authoritative co-op purchase arrives.
- Enemy structure health scales by 1 + 0.16(N-1) + 0.004(N-1)^2; tower attack scales by 1 + 0.065(N-1) + 0.0008(N-1)^2. N1 stays at baseline. N10 outer tower: 8,292 HP / 264 attack; N50: 55,332 HP / 977 attack; N99: 162,288 HP / 2,409 attack. Repeat hits still ramp up to 50% extra. Allied structures retain their existing stats.
- Own fountain instantly restores HP and mana when no living enemy hero or minion is within 550 world units. Contested fountains retain 120 HP/s and 80 mana/s. Dead units do not contest; fountain recovery also works while stunned.
- Recall takes one second, keeps its progress animation, and still cancels on damage or movement. A clear fountain refills the player on arrival.
- Six stat consumables: War +25 AD, Arcane +40 AP, Vitality +400 HP, Iron +20 armor, Warding +20 magic resist, Fury +15% attack speed. Each starts at 8,000 gold; next purchases cost 10,800, 14,580, etc. Prices grow by 35% for the first twenty purchases, then linearly to avoid overflow. Purchase counts are independent. Bonuses stack through death for this match, need shop access, and never occupy a slot. They cannot be sold. Existing painted stat-item icons identify each training type.
- Completed AI builds spend excess gold on match training too. Bots use finishable targets, ramped tower shots, escape distance, nearby defenders and a health reserve to decide dives. A committed dive cannot renew its two-second deadline; kill, danger or expiry triggers retreat. Enemy fountains remain off limits.
- Match training counts and bonuses replicate over LAN/Steam. All co-op players must use v0.2.5.

Validation: CorePveTests covers actual purchases, full inventory, escalating prices, combat stats, profile isolation, death/new-match reset, fountain contesting, recall cancellation, actual tower scaling, and dive/retreat decisions. Existing combat, presentation, balance, lane and three-peer co-op tests are run alongside it.
