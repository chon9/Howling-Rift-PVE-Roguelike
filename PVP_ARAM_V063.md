# v0.6.3 — Custom ARAM PvP

## Playing

Choose **PLAY PVP ARAM** from the main screen. Host a friends-only Steam Spacewar room or a LAN room, choosing **1v1**, **2v2** or **3v3**. Friends join through a Steam invite/lobby code or the LAN host's IP. The Steam browser labels PvP and PvE rooms separately. All players need the same game version.

Choose **BLUE / RED**, then **CHOOSE HERO & SUMMONERS**. All thirty heroes and Flash, Ignite, Heal and Ghost are available. Mirrored hero picks are allowed. Press **READY**; the host's Start button enables when every human is ready and both teams have at least one human.

With **FILL EMPTY SLOTS WITH AI** enabled, bots occupy missing slots within the chosen team size. With it disabled, both human teams must be completely full. Team switches cancel that player's Ready state. Changes to room size or AI fill cancel every Ready state. These rules are locked after starting.

Destroy the opposing throne to win. The existing skill/passive systems, last hits, assists, bushes, shop, respawns, summoners and level-up build choices remain active. Camera, HUD and controls support a local player on either team. Menus do not pause a multiplayer match.

## Fair match rules

- Every hero starts at level 3 with the same normal starting gold, three basic skill ranks and their chosen summoners. Identical heroes on opposing teams have identical starting stats.
- Permanent upgrades and equipped relics do not apply, including bonuses submitted by a client.
- N difficulty is excluded. Both teams' structures and bots use the same base scaling. Enemy experience multipliers and the PvE repeated-death gold cheat are disabled.
- Item purchases, kill/assist rewards, passive income and earned XP use normal game rates on both sides. Level-up build choices remain random, so this is casual roguelike PvP rather than a ranked competitive ruleset.
- PvP does not award permanent credits, daily quest drops or stash items. Existing PvE progression and the saved PvE difficulty are retained.

## Connection loss

If a guest loses connection during a running match, **RECONNECT PVP** appears on the main screen for 60 seconds. It reclaims that player's original team and hero, retaining current health, inventory, gold, cooldowns, level and build choices. The match continues during the interruption. With AI fill enabled a bot controls the hero; without it the hero stops and remains vulnerable. The reconnect token is sent privately and Steam reconnects additionally verify the original Steam identity.

The host must remain connected. There is no host migration, dedicated server, public matchmaking or ranked ladder. Deliberately leaving the match, quitting the application, an expired reconnect window or a finished match cannot resume through this button.

## Networking and validation

The host remains responsible for combat and checks the sending peer's owned champion before executing commands. Only registered players receive snapshots, effects and match results. Guests cannot use normal join to enter a running match. New peers have five seconds to register or authenticate a reconnect. PvP disables unnecessary client-to-client packet relay; state still replicates at 30 Hz with compressed chunks and interpolation. Steam protocol is now **8**.

Validation includes separate-process LAN 1v1, 2v2 and 3v3 sessions; movement, purchases, summoner cooldowns, individual drafts, kills, assists, respawns and results; forced 1v1 disconnect/reconnect; equal-stat and progression isolation checks; native menu/HUD layout captures; live Spacewar lobby creation, capacity and metadata updates; and existing PvE co-op, hero/item, collision, updater and Steam compatibility regressions. Only one Steam account was available: full cross-account Internet PvP latency has not been measured.
