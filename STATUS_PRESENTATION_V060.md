# v0.6.0 — Buff and debuff presentation

Bastion’s Q already applied a 1.5-second silence on its empowered basic attack and prevented skill casts. The silence had no visual indicator. It now shows a violet animated silence rune and a named remaining-duration badge. Casting Q alone arms the attack; silence starts on the hit. Movement and basic attacks remain available during silence. Tenacity and CC immunity retain their existing gameplay behavior.

Three newly generated transparent atlases provide four animation frames for sixteen status families: silence, stun, airborne, binding, slow, burn, shield, healing, haste, empowered attack, protection, target mark, bleeding, reduced healing, armor shred, and reduced attack speed. Gameplay buffs share family artwork but keep their own names, timers and stack counts. Existing directional vitals, recast windows, channel cues and Deadeye aiming lines remain specialized. Internal cooldown/contribution records are not presented as buffs.

Primary crowd control has a named countdown; secondary effects use a compact icon row above it. Shield/protection rings and restrained edge flames follow the body. Body interiors remain transparent. Actual shield absorption still appears above the HP bar. The HUD adds active-status icons with hover descriptions, values and durations; learned active skill buttons show when death, stun or silence blocks casting. A brief healing cue observes health recovery without modifying gameplay or adding network packets.

Presentation reads the same authoritative buffs already carried by co-op snapshots. Hidden enemies do not leak status effects through bushes. Expiry and death remove cues; pause freezes animations. Atlases and HUD controls are shared/reused rather than allocated on each application.

Validation: real Bastion cast/hit, movement/auto/cast restrictions, expiry, tenacity, immunity/parry, simultaneous statuses, transparent atlas frames, HUD hover details/control reuse, healing and bush visibility. Native three-peer co-op checks verify silence countdown, slow/shield presentation and expiry on host and both clients. Existing hero/item, status, shield, Deadeye and repeated-match memory tests are also run.

Exact generation prompts and runtime cell-layout notes: [STATUS_ART_PROMPTS_V060.md](STATUS_ART_PROMPTS_V060.md).
