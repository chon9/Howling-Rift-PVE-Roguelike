# v0.5.7 — Lower passive income, higher kill rewards

As requested, passive income is one-tenth of v0.5.6 and both hero and minion kill rewards double.

| Reward | v0.5.6 | v0.5.7 |
|---|---:|---:|
| Passive gold | 2/sec | 0.2/sec |
| Passive XP while alive | 2/sec | 0.2/sec |
| Hero kill gold | 300 | 600 |
| Hero kill XP | 160 | 320 |
| Minion last-hit gold | Base | Base × 2 |
| Minion soak XP | Base × 1.2 | Base × 2.4 |

Last hits still gain 25% extra minion XP. Assists, tower rewards, difficulty scaling, prices and permanent progression remain unchanged.

Gold wallets and shop costs remain whole numbers. Each active hero's host-side fractional balance accumulates 0.2 gold each second and pays one whole gold every five seconds. The carry survives respawn but starts fresh in a new match. Pause, inactive allied slots, match end and clients do not generate income. Dead heroes still earn passive gold but do not gain passive XP. Guests receive the host's integer gold and XP through existing snapshots.

Two idle minutes now give 24 gold and 24 XP. Active farming and takedowns remain the main progression sources. HUD tooltips display decimal income rates accurately.

The same deterministic ten-minute farming scenario now reaches level 25 and 11,730 gold (121 CS). This measures income under a fixed farming/kill scenario, not real match duration. Native three-player co-op verifies both fractional payouts and doubled hero-kill rewards.
