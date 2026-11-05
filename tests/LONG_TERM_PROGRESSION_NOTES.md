# Long-term ARAM progression

N1–N99 is selected on the title screen, hero selection, or host lobby before launching. A run captures its stage for enemy stats, AI and completion rewards. Pause settings display the stage, but cannot alter it. Permanent purchases are between runs and become starting stats on every player-controlled hero. LAN starting configurations preserve movement bonuses; mid-match permanent-stat commands are rejected.

Existing credit balances and upgrade ranks are preserved. No save reset or conversion is performed. The six existing per-rank stat benefits are unchanged. Stride adds 0.5% movement speed per rank, up to 49.5% at rank 99. Movement uses the champion's existing percentage movement formula alongside boots and run augments.

## Economy

Next purchase cost = ceil(base cost × (1 + 0.22 × owned ranks)^2 × (1 + 0.015 × owned ranks)). Each of seven upgrades has 99 ranks.

| Upgrade | First rank | Rank 11 | Rank 51 | Final rank (99) |
| --- | ---: | ---: | ---: | ---: |
| Vitality (HP) | 500 | 5,889 | 126,000 | 628,558 |
| Might (AD) | 600 | 7,066 | 151,200 | 754,270 |
| Sorcery (AP) | 600 | 7,066 | 151,200 | 754,270 |
| Guard (armor) | 500 | 5,889 | 126,000 | 628,558 |
| Recovery (HP/sec) | 450 | 5,300 | 113,400 | 565,702 |
| Haste (attack speed) | 650 | 7,655 | 163,800 | 817,126 |
| Stride (movement speed) | 750 | 8,833 | 189,000 | 942,837 |

Reward multiplier = 1 + 0.08 × (N−1) + 0.0004 × (N−1)^2.
Completion credits = round((30 + 70 for a win + min(floor(seconds/30),40) + min(kills,30)×3) × multiplier).
Negative time/kills are clamped to zero; N is clamped to 1–99. Unfinished abandoned runs do not pay. Each completion pays once. Defeats still pay.

Example: a 10-minute, 10-kill win pays 150 at N1 and 1,902 at N99. A first AD rank costs 600 (four such N1 wins); rank 51 costs 151,200 (roughly 80 such N99 wins). These are initial balance targets for a long grind, not measured session-length or difficulty-clearance guarantees.

Available level-up choices receive an amber badge with a gentle pulsing outline/glow and a clickable center-top prompt. The prompt hides while choosing, shopping or paused; resumes while choices remain; only level milestones grant drafts. No combat pause is introduced by a draft.

Reference: Windy's published Workshop description describes battle points earned in roguelike PvE to enhance attributes in future games: https://steamcommunity.com/sharedfiles/filedetails/?id=2307479570 . This game uses its own cost curve and rewards, not an asserted reproduction of Windy's exact balance.

Validation: LongTermProgressionTests checks pre-game selection, all 99 reward multipliers, high-rank costs for all seven stats, movement purchase/application/LAN serialization, stage locking, build alert lifecycle, duplicate-choice prevention, completion rewards and saved account preservation. Native captures 51–54 verify title, upgrade page, ready prompt and draft layout. ProgressionTests verifies disk persistence; InGameMenuTests verifies the now-read-only match settings; ARAMLoopTests verifies XP, level milestones and menu interactions.
