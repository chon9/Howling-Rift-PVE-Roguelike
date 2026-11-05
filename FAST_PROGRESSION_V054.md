# v0.5.4 — Faster match progression

| Reward | Before | Now |
|---|---:|---:|
| Passive gold | 2 / sec | 12 / sec |
| Passive XP | None | 35 / sec while alive |
| Hero kill gold | 300 | 1,000 |
| Hero kill XP | 160 | 1,600 + 60 × defeated hero level |
| Assist gold | 75 | 150 |
| Assist XP (alive) | 40 | 600 + 20 × defeated hero level |
| Minion soak XP | Base × 1.2 | Base × 4.8 (4× previous) |
| Minion last-hit gold | Base | Base × 3 |

Last hits retain the additional 25% XP bonus. Soak range remains 650. Gold keeps ticking during respawn; XP does not. Passive rewards stop when paused or finished, and inactive allied slots earn nothing. The host awards multiplayer income/rewards; guests receive the existing replicated gold/XP/levels. Higher-N enemy XP applies once after the source reward, including passive XP. Starting gold, level costs, cap 100, item prices, skill ranks, augment milestones, difficulty, permanent credits and relic progression are unchanged.

A 10-minute deterministic lane budget (actual six-minion waves with siege every third wave, all nearby wave XP, approximately 50% last hits and one hero kill per minute) reaches **level 52**, **25,022 gold** and **121 CS**. This is an income/progression scenario, not a guarantee about a real match's length or outcome. The intent is to reach veteran levels and full builds much sooner, while keeping farming and hero takedowns valuable. Late-game hero kill XP continues to grow instead of becoming negligible.

HUD XP and shop tooltips explain the new base income. Kill rewards display an immediate +1000g KILL popup; assists show +150g ASSIST. Multi-level rewards preserve each crossed augment milestone.

Verified: 27 fast progression checks, 454 enemy progression checks, assist/bot regression checks, three hero kits with 40-second AI battles, and three-process native co-op reward synchronization. Tests account for XP spanning multiple level-ups. Exported build and normal co-op progression are also checked before publishing.

The co-op regression now waits for both guests to finish their casts and draft checks before forcing deaths. Its old fixed-time deaths could interrupt those checks while a guest was still loading. The four-second Q mark is injected at that check phase rather than allowed to expire during unrelated movement checks.
