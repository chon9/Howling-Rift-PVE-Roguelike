# v0.5.3 — Assists, human-only teams and graphics options

## Assist gold

Hero takedowns award **75 gold** and one assist to each qualifying teammate. Damage within the previous **10 seconds** counts even if the helper moves away or dies before the takedown. Damage absorbed by a shield counts; zero, blocked and friendly damage do not. Recent allied heal/shield support can qualify through the beneficiary's participation. The killer retains the existing 300g kill reward and cannot also claim an assist. Contributors who are alive receive the existing 40 assist XP. Standing near a kill without contributing no longer grants an assist.

An immediate **+75g ASSIST** popup makes the award visible. Gold and K/D/A remain host authoritative and replicate to guests. Repeated death notifications cannot duplicate rewards. Participation resets on respawn and across matches.

## Turn off allied bots

**Fill allied slots with AI** is on the title screen, in the host's co-op lobby, and in Settings. Choose before starting; it is locked during the match. Off means one human hero in solo, or only connected human heroes in co-op, against three enemy AI heroes. Allied minions still spawn. Enemy AI, difficulty and rewards are unchanged.

With filling off, a disconnected human's hero is removed from play instead of converted to an active bot. Inactive slots remain internally so projectile/skill and network references stay stable, but cannot fight, farm, respawn, be targeted or appear on the team HUD/scoreboard/minimap. With filling on, the existing bot replacement behavior remains.

The host's rule overrides guests' solo preferences for that match. The preference is saved locally. Steam lobby protocol is now **6**; all peers must use v0.5.3.

## Graphics and FPS

Settings now include **World edge smoothing (FXAA)**, **V-sync**, and a **60 / 120 / 144 / 240 / unlimited** frame limiter. These preferences persist. Smoothing defaults on, V-sync on, and the limiter to 120 FPS. HUD, menus and cursor render after the smoothing pass, preserving crisp text and UI. The graphics overlay ignores mouse input.

This is a single native-resolution 2D post-process. It avoids switching renderers or requiring newer GPUs. FXAA costs an extra screen copy/pass; turn it off for maximum FPS. A frame limiter reduces wasted CPU/GPU work; it does not make a slow PC faster. V-sync can limit FPS to the monitor's refresh rate. Disable it for higher FPS/lower latency if screen tearing is acceptable.

FSR/DLSS are not implemented: this game uses Godot's 2D Compatibility renderer. Godot's built-in FSR is for the 3D RenderingDevice pipeline, and 2D MSAA is unavailable in Compatibility. FXAA cannot recover details missing from the original sprite artwork.

Account/settings content now scrolls so additional controls remain accessible rather than extending beyond the screen.

## Verification

- Assist/bot/graphics checks cover gold, timeout, support, dead contributors, absorbed/blocked damage, duplicate death, inactive slots, two-player roster configuration, saved preferences and UI visibility.
- Native NVIDIA RTX 3080 checks verify a rendered diagonal edge changes under FXAA while the HUD comparison region remains byte-identical; inspect title/settings layouts and click-through overlay behavior.
- Three native LAN processes verify host rule propagation, exact assist gold/KDA on guests, disconnected slot removal, and guest scoreboard visibility.
- Full content, combat interaction, passive/vision and update/network regression suites pass.
- Native static-scene render checks at 1280x720, uncapped/V-sync off, measured roughly 2–2.5 ms per frame with both FXAA settings. This is a renderer smoke measurement, not a full-match performance guarantee or evidence of a speedup from FXAA.

The native co-op regression previously asserted W on one frame after waiting for the cooldown; that could miss a correctly rendered short cast. It now records actual observed W frames and accepts either the observed animation or the current W pose.
