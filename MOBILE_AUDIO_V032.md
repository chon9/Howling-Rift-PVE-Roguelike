# Supplied announcer and battle music — v0.3.2

The recordings supplied in `BGM` now drive kill and spree announcements. The original files remain untouched. Godot-compatible mono PCM WAV copies live in `assets/audio/mobile-announcer-v1`; leading/trailing silence was trimmed without pitch changes. `manifest.json` records every source, destination and duration.

| Trigger | Supplied clip / banner |
|---|---|
| First champion kill of the match | FIRST BLOOD |
| Your ordinary champion kill | YOU HAVE SLAIN AN ENEMY |
| 2 rapid kills | DOUBLE KILL |
| 3 rapid kills | TRIPLE KILL |
| 4 rapid kills | MANIAC |
| 5 or more rapid kills | SAVAGE |
| 3 kills without dying | KILLING SPREE |
| 4 kills without dying | MEGA KILL |
| 5 kills without dying | UNSTOPPABLE |
| 6 kills without dying | MONSTER KILL |
| 7 kills without dying | GODLIKE |
| 8 or more kills without dying | LEGENDARY |

Rapid kills retain the game's eight-second window and take precedence over a simultaneous longer spree announcement. Death resets both streak counters. The four/five-kill banner titles now read Maniac/Savage. Spree progression uses the Mobile Legends naming described in [Codashop's MLBB glossary](https://news.codashop.com/my/mlbb-terms-you-need-to-know-first-blood-savage-godlike-and-more/).

Personal-kill audio follows the killer's identity in co-op. A teammate's ordinary kill retains the neutral Enemy Slain voice. Ally deaths, shutdown, victory and defeat retain the existing voices because the supplied folder contains no corresponding replacements.

`BGM/battletheme.mp3` is copied unchanged to `assets/audio/music/battle-theme-v1.mp3` and loops throughout matches. The menu keeps its current track. Music volume, crossfades, pause attenuation and announcer ducking continue to work.

Validation: 68 audio mapping/streak checks, 81 combat-feedback checks, and 16 headless / 19 native music checks passed. Test logs and packaged-build validation are under `tests/v032-*`. All co-op players must use v0.3.2.

The three-player LAN test and native exported Steam AppID 480 smoke test passed with zero failures. Export validation confirmed the supplied Savage recording, matching crest title and looping MP3 stream. Two-account remote Steam play was not exercised.
