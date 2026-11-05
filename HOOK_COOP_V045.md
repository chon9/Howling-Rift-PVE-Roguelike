# Multiplayer Thresh chain — v0.4.5

Co-op used the current hook artwork, but guest projectile replicas had no source reference. The chain renderer requires its caster, so guests saw the hook without its connecting line. Snapshots now include a stable caster reference, team and damage type. Clients resolve the reference to their live hero/minion/structure replicas, preserving the hook chain and skill glow. Guest projectile filtering also matches the host.

The chain uses the caster and hook positions currently displayed by the client, so both ends follow movement and interpolation. Invalid or missing owners are handled safely; subsequent valid snapshots restore the line. Combat, damage and hook pull logic remain host authoritative. All co-op players should use v0.4.5.

Validation: 15 native replication checks passed, including matching art, line endpoints, moving casters, all travel directions, invalid-owner recovery and expired-hook cleanup. A real host and two guest processes received the caster and rendered valid chain segments that followed the host hero moving, with zero failures. Existing 38 tactics/skill UX checks passed. Screenshot: tests/thresh-guest-chain-v045.png.

The exported Steam smoke test also passed, including packaged caster references and hook skill presentation. Existing 12 Vesper and 27 updater/network checks passed.
