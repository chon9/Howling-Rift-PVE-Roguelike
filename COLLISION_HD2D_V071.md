# v0.7.1 — solid buildings, unit collision and an HD-2D look

## Collision

- **Buildings are solid.** Turrets, inhibitors and Thrones block heroes and minions. Walkers steer around them, and a destroyed building stops blocking.
- **Heroes and minions keep apart.** Heroes path around minions and can be body-blocked by a crowd, like LoL. A hero who is completely walled in stops instead of walking on the spot. Minions go around a standing hero and never shove it. Minions do not block minions, and heroes do not block heroes.
- **Dashes and blinks pass through** units and buildings, but always land outside a building. Ghost walks through minions.
- **Melee can always hit a building it is touching.** Ranged attack ranges are unchanged.

## Base layout

The fountain moved back from the Throne, so the spawn and heal area no longer overlaps it. The two Throne turrets moved outward and forward, so heroes can walk between a turret and the Throne, and melee can reach the Throne's front. Inhibitors and lane turrets did not move.

## Grounded buildings

A building's position is now the centre of its painted stone base instead of its front tip. Range rings, shadows, hover rings, hits and collision all sit under the middle of the building. A soft contact shadow and a shaded lower edge settle the art onto the floor. Classic 2D uses the same centre point, so buildings there sit slightly lower than before.

## HD-2D lighting

- A low, warm sun over cool ambient light.
- Sun shadows are the actual silhouette of each unit's current animation frame.
- Pools of coloured light around crystals and fountains, and soft sunbeams across the lane.
- A screen finish over the 3D world: gentle blur at the top and bottom edges, warm and cool colour grading, a soft bloom and a vignette. The HUD and health bars stay sharp.

Set **3D QUALITY** to Low on slower PCs. It turns off the shadows, the screen finish, the sunbeams and the glow.

## Result screen

Victory and defeat now show an animated crest over the dimmed battlefield, your hero card and stats, both teams, the match rewards and a clear button.

## Multiplayer

Collision runs on the host, and guests predict their own movement with the same rules. Steam protocol is **13**. Everyone in a room must use **v0.7.1**. Extract the full Windows release ZIP or use the verified in-game updater. Existing progression is kept.

## Validation

- New collision suite: buildings, minions, heroes, landing points and Ghost.
- Headless suites in 3D and classic 2D show no new failures against the known-failure list.
- LAN co-op in 3D: three-peer co-op, hooks and skill footprints pass.
- Windowed captures of the arena, base, teamfight and result screens.
- The base layout and result screen were checked by hand in a played match, along with Steam.

The frame rate was fine in a played match, but frame times were not re-measured. The new shadows, screen finish and collision checks add some cost compared with v0.7.0.
