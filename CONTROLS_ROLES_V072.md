# v0.7.2: Mayhem upgrades, MOBA controls and role balance

This release changes how matches play, how your hero responds and which heroes are worth picking.

## Controls

- A click on a unit now targets exactly that unit. A click on the ground is always a move, so it can no longer turn into an attack on a nearby minion.
- Hold right-click to keep walking toward the cursor.
- Heroes plan a route around buildings before walking, so they curve past towers instead of sticking to them.
- Minions step aside and heroes curve around them. A crowd no longer cancels your order.
- Heroes are easier to click and win over minions when they overlap. Hold Alt to ignore heroes when you want to last-hit a minion next to one.
- An idle hero attacks enemies that come into range, enemy heroes first.
- A spell pressed up to 0.3 seconds before it is ready still fires. This does not apply to LAN guests yet.
- Your hero has a thick green ring. Health bars are green for you, blue for allies and red for enemies.
- Clicks show green arrows for a move and red for an attack. Your target has a bold red ring.
- The cursor is larger, has a dark outline, and stays inside the game window during play.

## Role balance

Before this release, armor was 0 for every hero at every level, so physical damage had nothing to get through. That is why ranged AD heroes dominated. Each role now has its own frame:

| Role | Armor at level 1, plus per level | Health | Damage to heroes |
|---|---|---|---|
| Tank | 40 + 5 | +20% | Normal, plus 2% of max health per hit |
| Bruiser | 30 + 3.8 | +10% | +12% |
| Support | 20 + 3 | Normal | Normal |
| Caster | 18 + 2.5 | -5% | Normal |
| Marksman | 16 + 2.6 | -8% | -12% |

- Tanks and bruisers also get extra magic resist.
- Melee heroes move 18 faster, and their attacks slow enemy heroes by 15% for 1.2 seconds, so they can catch ranged heroes.
- Allies within 320 range of a tank take 10% less damage.
- Jinx deals a further 10% less damage to heroes.

In 40 to 50 bot-played matches before and after this change:

| Role | Share of hero damage, before | After | Kills per minute, before | After |
|---|---|---|---|---|
| Marksman | 33% | 25% | 3.84 | 2.11 |
| Caster | 24% | 25% | 1.56 | 1.72 |
| Bruiser | 24% | 22% | 1.68 | 1.52 |
| Tank | 13% | 18% | 0.74 | 1.24 |
| Support | 6% | 10% | 0.43 | 1.07 |

## Mayhem upgrades

Pick 1 of 3 upgrades at the start of a match and at levels 7, 11 and 15, using the mouse or keys 1, 2 and 3. There are 22 upgrades, such as chain lightning, exploding kills, raising dead minions and growing to giant size. Bots pick them too.

## Match pace and comebacks

- Heroes have 1.35x health, and with armor, fights last longer.
- After the first minute, the team behind on levels deals more damage, takes less and levels faster.
- Kill gold is still 600 at equal levels. After the first minute it ranges from 35% to 175% of that, depending on the level difference, and ending a kill streak pays extra.
- Enemy bonus gold for dying is now capped at 1,500 per death.
- Towers hit heroes harder. Buildings take less damage overall, and less again from heroes with no attacking minions nearby.
- From minute 10, buildings and towers gradually weaken so matches end.

## Feel and flow

- Kills trigger short slow motion in solo play, with a stronger screen shake and a camera push. Units squash when hit, numbers pop, and sounds vary slightly.
- The result screen offers NEXT or TRY AGAIN with the same hero. Win streaks pay up to 50% more credits.

## Known limits

- The numbers above come from bot-played matches, which do not play like people.
- In those matches the enemy team wins far more often than yours, mostly because a bot playing your slot kills less than the other bots. Your own win rate is untested.
- Some matches are still one-sided, and bots can be slow to finish a match they are winning.

## Multiplayer

The network protocol is now 14, so everyone in a room must update to v0.7.2. Existing progression is preserved.
