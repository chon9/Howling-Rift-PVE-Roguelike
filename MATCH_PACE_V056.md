# v0.5.6 — Restore gradual match progression

The v0.5.4 income increases made matches escalate too quickly. Gold and combat XP now return to their pre-v0.5.4 values. Passive XP remains as a small supplementary source.

| Reward | v0.5.4–0.5.5 | v0.5.6 |
|---|---:|---:|
| Passive gold | 12/sec | 2/sec |
| Passive XP while alive | 35/sec | 2/sec |
| Hero kill gold | 1,000 | 300 |
| Hero kill XP | 1,600 + 60 × victim level | 160 |
| Assist gold | 150 | 75 |
| Assist XP while alive | 600 + 20 × victim level | 40 |
| Minion soak XP | Base × 4.8 | Base × 1.2 |
| Minion last-hit gold | Base × 3 | Base |

Last hitting retains 25% extra minion XP. Starting gold, XP level costs, level 100, items, hero abilities, permanent progression and higher-N enemy scaling stay unchanged. Passive XP is not awarded while dead, paused, after the match, or to inactive allied bots. The host remains authoritative for co-op rewards.

Two idle minutes now give 240 XP and 240 gold, insufficient to level from the starting level 3 or buy a major item. This is an income budget, not a guarantee of match duration. Farming, kills, difficulty and existing permanent equipment still affect how quickly a real match ends.

HUD income tooltips now read the shared balance constants to avoid stale reward descriptions.

The same deterministic ten-minute farming budget now reaches level 18 and 7,490 gold (121 CS), compared with level 52 and 25,022 gold before. Balance tests pass: 29 pace checks, 454 enemy progression checks, and 39 assist/bot/graphics checks.
