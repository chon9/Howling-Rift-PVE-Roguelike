# Vesper projectile visibility — v0.4.3

Vesper basic attacks now use her existing bright silver arrow animation instead of the dark red expansion missile. The bolt is 28 x 9 world units, with a compact dark rim, cyan trail and white core to remain readable on snow and dark stones. Condemn uses its existing gold arrow animation at 34 x 12 units with a warm trail. Torso altitude remains stable when travelling in any direction. No new generated artwork is needed.

Presentation is selected by effect ID, which already replicates through LAN/Steam snapshots. Source-free client projectile replicas therefore render the same visible arrows. Damage, projectile speed, hitboxes, target homing, knockback and flight timing are unchanged.

Validation: 12 dedicated native checks passed, including a real basic attack landing, Condemn, direction-independent altitude and source-free co-op presentation. Existing 800 balance and 1,296 action animation checks passed. Native screenshot: tests/vesper-projectiles-v043.png.

The exported v0.4.3 Steam/AppID 480 smoke test also passed with zero failures.
