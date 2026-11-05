# Howling Rift 0.2.3 — casting options

Open Permanent Upgrades / Settings from the title screen, or Esc → Settings
during a match. Switch **SMART CAST Q / W / E / R** off for normal casting.

- On (default): Q/W/E/R immediately cast at your cursor.
- Off: directional, location and target abilities enter targeting mode. Move the
  cursor to aim, then left-click the battlefield to cast. Right-click or Esc
  cancels without moving or spending mana. Esc again opens the pause menu.
- Self buffs/shields and fixed-target recasts (Lee Q2, Zed W2) remain instant.
  D/F summoner spells retain their existing immediate casting behavior.
- HUD ability clicks also obey normal cast. Hovering another ability does not
  erase an active targeting indicator. Pressing another ready ability switches
  targeting. Unlearned, unaffordable or cooling-down skills do not start aiming.
- Attack move, stop, recall, shop, augments, summoners, menus, death and match
  transitions clear pending targeting. Clicking UI does not confirm a spell.
- The preference saves in the existing profile and applies only to your input;
  AI casting and host-authoritative co-op combat stay unchanged.

CastModeTests passed 25 checks including real keyboard/mouse confirmation and
cancellation, settings clicks, saved preference reload, HUD behavior, death,
menu transitions and Lee Q2. ARAMLoopTests (45) and MenuInputTests (10) passed.
Both settings layouts were visually checked in the native game.

All co-op players must use version 0.2.3.
