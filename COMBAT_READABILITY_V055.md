# Combat readability — v0.5.5

Caliber's Deadeye now shows the time until firing above both the caster and the locked target. A filling bar, tightening crosshair, pulsing aiming line and muzzle glow accompany the actual one-second wind-up. The ultimate sprite stays in aiming frames during the charge and switches to firing frames on release.

A new original mechanical charging sound starts once per cast. It stops when the cast is interrupted or released. The rifle ultimate sound plays when the bullet launches, rather than when aiming starts. Late co-op snapshots seek the charge sound to the authoritative elapsed time. Sound settings, visibility, distance, pause and announcer ducking are respected. No TTS is added.

Movement, stun, displacement, target death or becoming untargetable cancel the charge. Homing and enemy-hero interception remain intact. The caster and marked target are revealed briefly while aiming; unrelated concealed heroes remain hidden.

Skill missiles gain short high-contrast trails. Vesper's dedicated bolts and upright tornado art keep their established rendering. Circular damaging/control zones gain blue friendly or orange enemy borders at their actual radius, and delayed zones show an arming progress arc. Decorative effects, utility zones, rectangular attacks and cones do not gain misleading damage circles. Boundary flags are replicated to co-op clients. Existing sprites, hitboxes and impact sizes are retained.

Newer heroes use matching rifle, blade, fire, light, fist and spirit sound families instead of all sharing the generic magic cast sound. Status badge text is clearer with a lighter outline.

Validation: Deadeye's 39 targeted checks; 1,313 roster checks; 10,658 hero/item audit checks; native host plus two clients (14/13/13 checks). Native captures verify the target lock, aim line and delayed zone boundary. Additional regression checks pass: combat interactions (62), passives/vision (176), updater/network (27), and native Deadeye (39). The packaged Windows build initializes Steam, hosts a real Spacewar lobby, loads the charge audio and lock helper, and passes export smoke validation with zero failures.
