# Howling Rift — PvE Roguelike

An ARAM-only, LoL-inspired game built with Godot 4: solo/three-player PvE roguelike and custom 1v1, 2v2 or 3v3 PvP. Arena mode has been removed.


Match startup preloads the selected roster’s actions and effects behind a loading screen; multiplayer starts after all peers finish. See [MATCH_LOADING_V066.md](MATCH_LOADING_V066.md).

Dominant PvE runs teach up to two enemy Echoes your build next match. The host keeps the best ten different heroes, one build per hero; a higher difficulty-weighted score replaces it. Enemy heroes never repeat within their team; allied duplicates and cross-team mirrors are allowed. See [BUILD_STEALER_V068.md](BUILD_STEALER_V068.md).

Echoes continue their hero's original AI item build after finishing saved purchases, then buy late-game stat consumables. Skill ranks and level-up upgrades also continue normally when the saved path ends. See [BUILD_CONTINUATION_V069.md](BUILD_CONTINUATION_V069.md).

Current release: **v0.7.2**. [Download the Windows build](https://github.com/chon9/Howling-Rift-PVE-Roguelike/releases/latest). Extract the entire ZIP and run **Howling Rift.exe**. Start Steam for Spacewar co-op or PvP; solo and LAN play are also available.

The v0.7.2 update adds 22 Mayhem upgrades, MOBA-standard controls and role balance, so tanks and melee heroes are worth picking. See [controls and role notes](CONTROLS_ROLES_V072.md). The v0.7.1 update makes buildings solid, adds hero and minion collision, moves the fountain clear of the Throne, adds HD-2D lighting and a new result screen. See [collision and lighting notes](COLLISION_HD2D_V071.md). The v0.7.0 update draws matches in 3D by default with a League-style camera and a Mobile Legends preset, while classic 2D stays available under VIEW in settings. See [Rift3D notes](VIEW3D_V070.md). An earlier update adds Seren and Galea, eight support items, smarter bot fights, immediate guest movement prediction, swept projectile hits and less combat clutter. The roster now has 32 heroes and 84 items. See [support and combat notes](SUPPORT_COMBAT_V065.md). The v0.6.4 update removes extra circle and box outlines from projectile, AoE, beam, spin and wind-wall effects. Spell artwork, aiming previews and collision geometry remain intact. The v0.6.3 update adds custom PvP rooms with team selection, ready checks, optional AI fill, fair starting stats and a 60-second reconnect window. See [PvP instructions](PVP_ARAM_V063.md). The v0.6.2 update aligns skill previews and ground outlines with collision geometry, stabilizes animation crops, and corrects directional/ground placement. See [skill footprint notes](SKILL_FOOTPRINTS_V062.md). The v0.6.1 update reduces world blur with light edge smoothing, adjustable sharpening, and scalable overhead text. See [fullscreen clarity notes](FULLSCREEN_CLARITY_V061.md). The v0.6.0 update adds a Bastion silence indicator, animated buff/debuff sheets and active-status hover descriptions. See [status presentation notes](STATUS_PRESENTATION_V060.md). The v0.5.9 update bounds retained animation textures, releases unused skill sheets between rosters, clears stale combat/audio timing entries, and avoids redundant shader and display-mode updates. See [memory and rendering notes](MEMORY_RENDERING_V059.md). The previous update remembers fullscreen/windowed mode across launches, including changes using F11 or Alt+Enter. See [display settings notes](FULLSCREEN_SETTINGS_V058.md). The previous update reduces passive gold and XP to 0.2/sec (one-tenth of v0.5.6) and doubles hero and minion kill rewards. Hero kills award 600g and 320 XP; minion last-hit gold and soak XP double, retaining the 25% last-hit XP bonus. Fractional passive gold accumulates into one gold every five seconds. Assists remain 75g and 40 XP. See [active reward notes](ACTIVE_REWARDS_V057.md). Deadeye retains its synchronized countdown, target crosshair, aiming line, charging sound and separate firing animation. Skill missiles and ground telegraphs retain the v0.5.5 readability improvements. See [combat readability notes](COMBAT_READABILITY_V055.md). Includes thirty-two heroes, all hero passives, permanent equipment, daily quests, automatic verified updates, Steam/LAN co-op and world-only FXAA. See [hero/item audit](HERO_ITEM_AUDIT_V052.md), [daily quests and relics](DAILY_RELICS_V040.md), and [enemy progression and level 100](ENEMY_PROGRESSION_V041.md).

Source includes the Windows GodotSteam extension and its license. Install Godot 4.6.3 or newer to edit and run the project; release builds use Godot 4.7.2. Generated caches, personal saves, test captures and local engine binaries are excluded from version control.

## Updates

Download v0.5.9 or newer once if your older updater rejects the renamed repository. Windows releases then check GitHub automatically, download verified updates in the background, and offer **Restart to update** on the main menu. Updates preserve local progression. You can disable automatic downloads or use **Check for updates** and **Release notes**. Source builds opened in Godot check versions manually and do not overwrite the project. All multiplayer players must run the same version. See [update and networking notes](UPDATES_NETWORK_V044.md).

## Play

Open `project.godot` in Godot and press **F5**, or use `Play.cmd` with the installed Godot 4.6.3 engine. The game starts at a title menu. Select **Play Solo ARAM**, choose one of thirty heroes, two different summoner spells, and difficulty **N1–N99**, then press **Play ARAM**.

- **Right-click**: move or attack the clicked enemy. Ground clicks cancel your current attack order.
- **A, then left-click**: attack move. Ground clicks prefer an eligible enemy near the cursor, including a short approach outside attack range. Without a cursor target, attack the enemy nearest your hero already in range; without nearby enemies, walk to the clicked spot and acquire enemies along the route. After a kill, resume that destination. Direct unit clicks lock that unit. **Shift+A** issues attack move immediately. A displays attack range and target feedback.
- **S**: stop movement and cancel an attack before its windup finishes. Once a ranged shot has launched, it continues toward its target.
- **Q/W/E/R**: cast skills toward your cursor. Hover icons for descriptions; use their **+** buttons or **Ctrl+Q/W/E/R** to spend skill points.
- **D/F**: your selected Flash, Ignite, Heal or Ghost.
- **Tab (hold)**: live scoreboard with both teams, K/D/A, CS, level, gold, items and respawn status. Click the team kill count to toggle it; Esc closes it without pausing.
- **P** or click the gold counter: item shop. **B**: one-second recall; press again to cancel.
- **U**: level-up build choices and picked upgrades.
- **Esc**: close the current shop/build panel, cancel attack targeting, or open/close the match menu. The menu includes Resume, permanent upgrades/settings, Return to Main Menu and Quit. Solo matches pause; LAN matches keep running. **M** opens the match menu directly.
- **Y**: unlock camera; arrows or screen edges pan. **Space** resumes following your hero.
- **F11 / Alt+Enter**: fullscreen at native display resolution. The UI uses a 1920×1080 logical canvas and scales with the window.

For PvP, select **Play PvP ARAM**, host a Steam or LAN room, choose **1v1 / 2v2 / 3v3** and optional AI fill, then choose your team, hero and summoners. Every human must be Ready, with at least one human on each side. The host starts the match. Permanent stats, relics, N difficulty and PvE rewards are disabled; the normal shop and level-up builds remain active. See [PvP room rules and reconnects](PVP_ARAM_V063.md).

## Heroes

| Hero | Inspiration | Kit |
| --- | --- | --- |
| Skadi | Ashe | Multishot, volley, dash, stun arrow |
| Ember | Annie | Fire burst, cone, shield, summoned bear |
| Bastion | Garen | Empowered strike, defense, spin, execute |
| Solara | Lux | Binding, allied shield, light field, laser |
| Nyra | Ahri | Returning orb, homing flames, charm, spirit dash |
| Kael | Ezreal | Skillshot, mark, blink, barrage |
| Kaze | Yasuo | Third-Q tornado, wind wall, dash through foes, aerial finisher |
| Rokan | Lee Sin | Sonic Q recast, allied safeguard, slam, knockback kick |
| Shade | Zed | Shuriken from hero and shadow, W swap, slash, delayed death mark |
| Rixa | Jinx | Explosive ranged stance, zap, stun traps, giant rocket |
| Scarlet | Katarina | Cluster daggers, speed spin, targeted blink, dagger storm |
| Aurelia | Kayle | Sword wave, heal, empowered attacks, temporary invulnerability; ranged at level 6 |

The six added heroes use new generated transparent artwork and 24 painted ability icons. Names and balancing are adapted for this game's PvE pacing.

## Three-player LAN co-op

Steam internet co-op is also available for development testing with Spacewar
(AppID 480). Choose **Host Steam** or **Join Steam** on the title screen.
See [Steam multiplayer setup and testing](STEAM_MULTIPLAYER.md).

Run the same game build on all PCs on your local network. One player selects **Host LAN Co-op**. The lobby shows the host's LAN IP. The other two enter that IP on the title screen and select **Join LAN**. Everyone chooses a hero and two summoners, then presses **Ready**. The host starts the match. Up to three humans share the blue team; empty slots are filled by AI when **Fill allied slots with AI** is enabled. Turn it off before starting to play with humans only against three enemy heroes. The host chooses this rule; allied minions remain.

The host controls difficulty and runs combat. Every guest controls their own hero, shops, ranks skills and chooses their own level-earned build upgrades. Camera, inventory and HUD follow the local player. Each player receives permanent completion credits in their own local profile. Returning to the menu during an unfinished match does not grant completion credits.

Menus do not pause LAN combat. If a guest disconnects, AI takes over their hero. If the host leaves, the session ends and guests return to the title screen. New players cannot join after the match starts.

The game uses **UDP port 24567**. If Windows asks, allow Godot/the game on your private network. Development validation used three separate native game processes connected through localhost; physical multi-PC LAN routing and firewall setup still need testing on your network.

Networking uses [Godot ENet multiplayer](https://docs.godotengine.org/en/4.6/tutorials/networking/high_level_multiplayer.html), with commands validated by the host and compressed state updates sent separately from input commands.

## Farming and hero progression

Start at level 3 with Q/W/E learned. Nearby enemy minion deaths grant XP within **650 world units**, including kills by allied minions or towers. Dead heroes and heroes outside this range earn no minion XP. Last hits award creep gold and CS, plus **25% more XP** than soaking. Passive gold is 2 per second; start with 1000 gold.

Basic attacks have a short windup. Time attacks around creep health, cancel with S or a movement order, and watch the gold ring on creeps that can be killed by a normal attack. Ranged attacks also have travel time. Critical strikes are not assumed by the last-hit cue.

Every level grants a skill point. R unlocks at level 6 and ranks again at 11 and 16. Basic ability ranks are limited by hero level. Roguelike build choices are earned **only when reaching levels 4, 6, 8, 10, 12, 14, 16 and 18**. There is no free starting choice or timed reward. The HUD shows the next build level, and each choice names the level that earned it. Reopening a choice cannot reroll it. Drafts keep the lane running.

Death keeps the match and build intact. Respawn takes approximately 4–7 seconds; skills, summoners and item cooldowns continue ticking while dead.

## Shop and builds

The compact bottom HUD puts portrait and stats on the left, Q/W/E/R in the middle, D/F alongside them, and six items in a three-column, two-row grid on the right. Health and mana sit below the actions; XP is a thin strip beneath the portrait. Repeated attack clicks preserve the current swing. Movement before contact cancels it; movement after contact preserves the attack cooldown. Direct attack clicks target the visible unit body, and melee approaches stop at attack range. Click gold to open the shop. The shop opens on the left above the HUD, leaving actions and the minimap visible.

The large shop includes painted item art, search, hero recommendations, item categories, readable passive descriptions, clickable component recipes and six inventory slots. Buy or sell at your fountain or while dead; browse anywhere.

76 items include attack, spell power, health, defense and boots options. Owned recipe components are consumed and credited at their full cost, including partially assembled recipes. Upgrading a component can free inventory space even with all six slots occupied. Selling returns 70%. Only one boots item is allowed. The shop has dedicated Tank, Bruiser and Marksman build filters.

Build decisions include critical strikes with Infinity Edge, lifesteal and an overheal shield with Bloodthirster, current-health on-hit damage with Blade of the Ruined King, empowered attacks after skills with Sheen, periodic spell procs with Luden, mana-to-power scaling with Archangel, Deathcap's AP multiplier, Warmog's out-of-combat recovery and Thornmail's reflected attack damage. These are adapted for this game's PvE pacing.

## Permanent progression and AI

Completed wins and losses grant permanent credits. Buy account-wide health, damage, spell power, armor, regeneration or attack speed upgrades from hero select or the paused match menu. Incremental stat values stay fixed while prices rise quadratically with upgrade level, up to 99. Credits, upgrades and selected difficulty persist in `user://progression.cfg`. Unfinished matches do not pay completion rewards.

N1–N99 increases enemy health, damage, speed, reactions and pursuit. AI evaluates kill opportunities, uses skills, retreats from unsafe towers and buys builds. Changing difficulty in the match menu preserves enemy health percentages; completion rewards use the lowest difficulty played in the match.

## Validation

`tests/GroundAttackMoveTests.tscn` checks actual A + ground-click input, cursor priority, nearest-enemy fallback, empty-ground movement, acquisition along the route, resuming after a kill and cancellation with right-click.

`tests/AttackScoreboardTests.tscn` checks body targeting, repeated-click windup preservation, melee approach distance, cancellation and chase recovery, plus native Tab/click/Esc scoreboard input and fullscreen/windowed captures.

`tests/CompactHudTests.tscn` checks HUD bounds, the item grid, gold-button clicks, shop/Esc routing, tooltips and recall placement, and captures 1080p fullscreen and 720p windowed layouts.

`tests/RosterMenuTests.tscn` checks all eighteen heroes, title-menu transitions and match cleanup; `tests/HeroMechanicTests.tscn` verifies recasts and signature abilities. `tests/LanCoopTests.tscn` runs one host and two clients, checking movement, skills, summoners, independent drafts, purchases, death cooldowns, completion rewards and disconnect takeover. `tests/MenuInputTests.tscn` exercises real mouse/keyboard menu navigation and confirmation dialogs. `tests/NewMenusVisual.tscn` captures title, eighteen-hero selection, pause and upgrade menus. Run `./tests/RunLanTests.ps1 -Native` for the three-process LAN test; pass `-GodotExe` if your Godot executable is elsewhere.

`tests/ARAMLoopTests.tscn` covers level-only rewards, XP soaking and last hits, component synthesis, shop restrictions, combat passives, selected summoners, attack windup cancellation, real Buy clicks and Esc routing. Other regression scenes cover movement, hero skills, permanent progression, fast respawns, graphics and audio. `tests/LaneTests.tscn` runs a complete AI lane simulation. `tests/ARAMVisual.tscn` captures the hero roster, shop and level-up UI in native fullscreen and a 1280×720 window.

Painted equipment and summoner atlas: `assets/ui/item-summoner-icons.png`. Generation prompt: `assets/ui/ITEM_ART.md`.

## Version 0.2.0 expansion

18 heroes, 46 items, new combat item passives and fortified cliff ends at both thrones. See [expansion notes](EXPANSION_V02.md) for the new kits and validation.

## Version 0.2.2 balance and presentation

Real mana for the new heroes, a 31% larger battlefield view, dedicated animated projectiles, corrected repeated-hit AP scaling, innate magic resistance, and tougher enemy heroes and structures at higher N. See [balance notes](BALANCE_V022.md).

## Version 0.2.3 casting options

Turn off **SMART CAST Q / W / E / R** in Settings to aim first and left-click to cast. Right-click or Esc cancels; your preference is saved. See [casting notes](CASTING_V023.md).

## Version 0.2.4 tank and AD builds

24 new items expand armor, anti-mage, team shield, bruiser, cleave, on-hit, crit and antiheal builds. See [item expansion notes](TANK_AD_V024.md) for examples and exact adapted behavior. All co-op players need the same v0.2.4 build.

## Version 0.2.5 core PvE progression
Hybrid items appear in every relevant stat category. Six repeatable stat consumables start at 8,000 gold and increase in price by 35% per purchase, independently per elixir. Their AD, AP, HP, armor, magic resistance and attack-speed bonuses survive death and reset with the match; they consume no inventory slot or permanent credits. See [core PvE notes](CORE_PVE_V025.md).

## Version 0.2.6 mage shop filter
The shop now has a dedicated Mage builds filter containing AP items, magic penetration, mana, antiheal, defensive mage items, boots and components. All twelve shop filters fit the existing panel. All co-op players need v0.2.6.

## Version 0.2.7 tactics and item UX
Hover owned items or shop cards for readable stat/passive tooltips. Left-click an owned item to browse its full upgrade tree, or click a shop item to select it and browse its upgrades. Thirty level-up templates include tank, caster, bruiser and marksman choices with randomized stat magnitudes; reopening cannot reroll them. Six painted frost-brush patches provide concealment and AI ambush routes. Bots dodge visible long-range skillshots after N-dependent reaction time. Projectile animation mapping trims transparent padding, and Warden/Thresh hooks have a visible chain. See [tactics notes](TACTICS_UX_V027.md). All co-op players need v0.2.7.

## Version 0.2.8 tooltip startup fix
Item tooltip handlers now attach after scene startup completes. This prevents failed root-node attachment and callbacks into an uninitialized tooltip manager. Native regression covers deaths, corpse animation frames, cooldowns, respawns and item hovering while dead across all 18 heroes and every minion type. All co-op players need v0.2.8.


## v0.4.0 daily quests and permanent equipment

Open **Daily Quests / Equipment** on the main menu. Five daily objectives award up to five saved relics per day. Equip head, body armor, weapon, sub weapon, shoes, two rings, necklace and gloves between matches. Higher N gives higher item levels, better rarity odds and stronger enemies. Existing permanent credits and upgrades remain available. See [daily relic notes](DAILY_RELICS_V040.md). All co-op players should use v0.4.0.


## v0.4.1 enemy comeback and level 100

Each enemy hero receives 600 bonus gold at death 11, then 250 more per subsequent death. Enemy XP increases with N difficulty. Heroes can level to 100; after earning all eighteen skill points, each further level adds 3 AD, 5 AP, 45 HP and 25 mana. These match bonuses survive death and reset next game. See ENEMY_PROGRESSION_V041.md. All co-op players should use v0.4.1.

## v0.5.0: Twelve more heroes

The roster now has 30 heroes. Aegis, Bolt, Saur, Lancer, Riftblade, Duelia, Caliber, Solstice, Zephyr, Pyre, Umbra and Arclight each have four distinct abilities, complete action animation mappings, dedicated portraits, skill icons and effects. See [roster and co-op validation notes](ROSTER_EXPANSION_V050.md). All co-op players need v0.5.0.

## v0.5.1: Hero passives and co-op visibility

Hover your hero portrait for its passive and live counters. Lancer’s third Q hit is airborne; E uses a directional charge trail and arrival impact. Vesper W is always active once learned. All selection portraits share clipped square framing. Host-authoritative bush concealment and passive counters now replicate to guests. See [all thirty passive mechanics and validation](PASSIVES_V051.md). All co-op players need v0.5.1.

## v0.5.2: Hero and item audit

All thirty heroes, 120 skills and 76 items were audited with a full skill/stat/purchase/animation matrix and targeted combat interaction tests. Fixed damage types, independent timed shields, lifesteal/overheal, crit and on-hit interactions, Ignite ticks, Ember targeting, resource caps and farming predictions. See [coverage, fixes and validation](HERO_ITEM_AUDIT_V052.md). All co-op players should update to v0.5.2.

Status presentation in v0.6.0 adds a visible Bastion silence countdown, generated four-frame buff/debuff atlases, active-status hover descriptions, and blocked-cast labels. See [STATUS_PRESENTATION_V060.md](STATUS_PRESENTATION_V060.md).
