# v0.6.5 — Support play, bot tactics and responsive combat

The roster has 32 heroes and the shop has 84 items. Windows solo, Steam/LAN co-op and PvP use the same support kits. All multiplayer players need v0.6.5; Steam's protocol identifier is now 9.

## Bot decisions

Bots can initiate favourable trades before a kill is certain. They score visible heroes using missing health, kill potential, nearby allies/enemies, immobilization and allied focus. Target hysteresis discourages rapid switching. Tower/fountain safety still decides whether a pursuit or dive is survivable. Farming favours killable minions, and ranged heroes plant their feet during an attack windup before resuming their kite. Small separation keeps allied bots from occupying exactly the same position. Support bots prioritize endangered allies and use targeted shields/heals appropriately. Each decision releases at most one main skill, including recasts, so combinations have readable timing.

## Controls and combat presentation

Mouse events dispatch without frame accumulation. Slow frames subdivide simulation into steps up to 20ms, retaining up to 150ms of elapsed movement/combat time rather than silently truncating a frame to 50ms. Camera follow responds faster. Attack windup is 70–240ms depending on attack speed. Right-clicking to move cancels an unfinished attack; reissuing the same attack preserves its windup.

Guests predict commanded movement immediately. The host still validates movement orders and owns hits, casts, damage, cooldowns, gold and items. Snapshot acknowledgements retire pending orders, and position corrections reconcile prediction. Stuns, roots, forced movement, death and authoritative dashes suspend prediction. Movement order sequence numbers continue correctly after reconnect. Remote units retain snapshot interpolation. Actual responsiveness still depends on frame rate and connection quality; movement prediction does not remove the round trip for authoritative skill outcomes.

Projectiles check the swept path between frames, preventing a fast missile from skipping a target. Offscreen legacy spells no longer shake the camera; shake amplitude is bounded. Overhead icons show at most two additional status families, with crowd-control labels and timers retained. Full buff/debuff details remain in the player's HUD. Shields and guards use lighter body overlays. Damage and gold numbers are sent to their participating human players; unrelated AI trades no longer fill the battlefield with numbers. Wave dust spawns less often. The existing spell artwork and aim previews remain without added collision circles/boxes.

## Seren — celestial healer

- Passive: move faster toward wounded allies. Q hero hits grant three seconds of Rejuvenation.
- Q Starfall: delayed area damage and slow; restores health over time through the passive.
- W Astral Mend: targeted ally heal, paying 8% maximum health; Rejuvenation halves the health cost and passes healing over time to the ally. Self-targeting is excluded.
- E Equinox: silences enemies inside a field. Remaining inside through its expiry roots them.
- R Celestial Wish: heals all living allies, with a 35% increase for allies below 40% health.

## Galea — shield and disengage support

- Passive: nearby allied movement aura, plus self movement while W is ready.
- Q Howling Gale: charge up to three seconds, then release a piercing tornado. Q again releases early. Charge affects range, damage and airborne time.
- W Zephyr Feather: targeted slowing wind missile.
- E Eye of the Storm: target self or ally with a four-second shield and bonus attack damage while its absorption remains.
- R Monsoon: push enemies away and channel allied healing. Movement, silence, stun or R again cancels it.

Skill descriptions show AP ratios, current damage/heal/shield amounts and outgoing heal/shield power. Hover the HUD's combat stats for healing power and mana regeneration. Healing and shielding contribute to assists and existing ally-support passives.

## Support shop and level-up builds

The new **Support** category contains Faerie Charm, Forbidden Idol, Moonstone Reliquary, Ardent Censer, Staff of Flowing Light, Redemption, Dawn Bell and Guardian's Oath, alongside useful existing support components and defensive items. Recipes use the existing component/upgrade browser, hover tooltips and six inventory slots.

Outgoing heal/shield power applies to actual grants. Healing received bonuses and grievous wounds apply afterward. Moonstone's secondary heal has a shared cooldown; Ardent grants attack speed and magic on-hit; Flowing grants real AP/movement and removes its AP on expiry. Redemption triggers a delayed rescue in combat; Dawn Bell grants a shield and removes slows; Oath shields a wounded nearby ally. Matching item shields refresh rather than stacking, and proc healing cannot recursively trigger itself. Three support augment templates append to existing stable augment indices.

## Artwork

Built-in image generation produced the project assets below. Existing atlases were retained. The action manifest contains all ten actions and six frames per action for each support. Inspected crop/pivot metadata registers the sprites to the ground; Galea's two feather-only cast cells reuse the earlier character cast pose so the hero does not disappear when the projectile is launched.

- `assets/animations/heroes/soraka-actions-v1.png`
- `assets/animations/heroes/janna-actions-v1.png`
- `assets/ui/support-icons-v1.png`
- `assets/ui/support-item-icons-v1.png`
- `assets/vfx/support-skills-v1.png`

The prompts are recorded in [SUPPORT_ART_PROMPTS_V065.md](SUPPORT_ART_PROMPTS_V065.md). Generated images were copied into the repository. No external generation credentials are required at runtime.

## Validation

The support/tactics scenarios cover targeting, passive activation, health costs, root/silence boundaries, charge/recast timing, channel cancellation, actual item stats and procs, non-stacking effects, expiry, client movement acknowledgement and fast projectile collision. Content, existing combat, hero/item/build, skill-footprint, updater, PvP and Steam suites run alongside three-peer co-op tests. Native battle capture and twenty-round memory checks validate rendering/runtime. Native frame-time measurements are machine-specific, not a guaranteed frame rate on other computers.
