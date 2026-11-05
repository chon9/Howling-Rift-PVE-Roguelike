# Spacewar testing — Howling Rift

This development build uses Steam AppID **480**, so Steam displays **Spacewar**
while the game is running. Use your own AppID before a public Steam release.

## Play with friends

1. Each player signs into their own Steam account on their own Windows PC.
   All players need the same Howling Rift build; add each other as Steam friends.
2. Start Steam first, then launch Howling Rift. Godot F5 also works after the
   editor has scanned the new `addons/godotsteam` extension; reopen the editor
   if Steam reports that the extension is unavailable.
3. The host selects **HOST STEAM**. The lobby is friends only and accepts three
   players total. Choose N1–N99 before starting.
4. Use **INVITE FRIENDS** to open Steam's invite overlay. The host can also
   **COPY LOBBY CODE**; friends select **JOIN STEAM**, paste the code, and join.
   The Join screen also lists matching lobbies reported by Steam friends.
5. Everyone chooses a hero and two summoners, then presses **Ready**.
   The host selects **START CO-OP MATCH**. Missing players are filled by AI.

No LAN address is needed for Steam sessions. Steam Networking Sockets handles
the P2P connection and can use Steam relays. LAN remains available as a separate
option. The host runs combat; menus do not pause a co-op match. Guests who leave
are replaced by AI. The session ends when the host leaves; host migration and
joining an already-started match are not supported.

The whole exported folder is required, including the PCK and DLLs. Extract the
ZIP before running the executable. `steam_appid.txt` stays alongside the EXE
for development testing. Friends-only visibility requires a Steam friendship
with the host; the lobby code does not override that restriction.

## Validation

- `tests/SteamSessionTests.tscn -- --no-steam`: deterministic cancellation,
  incompatible build/game, full lobby, host changes, and active-match safeguards.
- `tests/SteamSmokeTests.tscn -- --steam-test`: real Steam initialization, lobby
  creation, metadata, membership limit, native peer, leave/rehost and ARAM start.
  This creates temporary friends-only lobbies and leaves them when finished.
- `tests/RunLanTests.ps1 -Native`: existing three-process LAN combat regression.
- `tests/SteamPeerTests.tscn -- --steam-test host` on one PC and
  `tests/SteamPeerTests.tscn -- --steam-test guest LOBBY_CODE` on a second PC
  exercise Steam RPC channels and real guest movement, purchases and skill ranks.

Live validation on the development PC cannot establish a two-account internet
connection by itself. A second Steam account on another PC is still needed for
the final invite, relay and multi-player gameplay test.

## Dependencies

Windows x64: official **GodotSteam 4.23.1**, Steamworks 1.65, GDExtension for
Godot 4.4+. It includes the native `SteamMultiplayerPeer`; a separate peer plugin
or custom Godot editor is not needed. Tested in Godot 4.6.3.
See `addons/godotsteam/license.md` and `tools/steam/DEPENDENCY.json`.

Initialization supplies AppID 480 explicitly and pumps Steam callbacks once per
frame. Headless tests skip Steam unless `--steam-test` is supplied;
`--no-steam` disables integration for LAN tests. Lobbies carry the game key,
network protocol and game version, and all three must match before attaching
the transport. The native peer preserves Godot host ID 1 and RPC channels 0–2.
