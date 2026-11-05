# Howling Rift 0.2.2

- Rook/Darius and Granite/Malphite now have mana, growth and regeneration rather
  than inheriting Garen's empty resource pool. All six expansion kits now specify
  their own mana stats; costs, regeneration, level growth and item mana work.
- Battlefield camera zoom rises from 1.3 to 1.7: heroes, minions, structures and
  terrain appear 31% larger together. Hero/minion body proportions are unchanged.
  Projectiles additionally have wider, clearer silhouettes; collision radii and
  attack/skill ranges are unchanged.
- Legacy spell hits no longer gain 100% AP on every channel tick or repeated
  bolt. Lux/Annie use 60%, Ahri 35%, Katarina 15%, Kayle 50%, Ezreal 30%; physical
  legacy kits receive no generic AP addition. Already-scaled expansion spells
  retain their own formulas. Live tooltip coefficients match actual damage.
- Heroes gain innate MR (30 ranged / 35 melee, with expansion tank exceptions)
  plus 1.25 per level. MR items and Void Staff apply to that total. Ignite deals
  its stated true damage without accidentally gaining repeated AP/item procs.
- Six new hero projectile identities use 48 generated flight frames: crimson
  axe fragment, granite shard, dark comet, shadow binding, silver bolt and
  spectral hook. Animation and identity replicate to co-op clients. Condemn now
  travels before applying damage and knockback, respecting spell/CC guards.
- Higher N boosts enemy health, damage, armor, MR, attack speed, reactions and
  pursuit. Enemy structures gain progressively more HP and towers gain damage;
  allied structures retain baseline stats. No increase to tower attack range.
  Selection is still locked when the match starts. The selector previews scaling.
- New hero AI now includes expansion damage abilities in kill estimates and
  checks the victim's actual resistance; existing tower safety stays active.
- The previous match's throne-break camera-shake reset is preserved.

For n = N - 1, enemy structure HP multiplier is 1 + 0.05n + 0.0008n².
N1/N10/N50/N99 give 1.00 / 1.51 / 5.37 / 13.58 times base structure HP.
Enemy hero HP uses 1 + 0.045n + 0.0009n²; damage uses
1 + 0.03n + 0.00045n². N1 preserves original base HP/damage.

Artwork used built-in image_gen, preserving generated PNG transparency.
Asset: `assets/vfx/expansion-projectiles-v1.png`.
Exact prompt: `assets/vfx/EXPANSION_PROJECTILE_PROMPT.json`.

Validation: BalanceTests (800), ExpansionTests (291), ActionAnimationTests
(1,296), GroundScalingTests (141), ARAMLoopTests (45), PvePresentationTests (52),
CameraShakeTests (14), MenuInputTests (10), native visual inspection, and a LAN
host plus two clients. Steam lobby/rehost/start (18 checks), export and release
boot also passed. Two-account internet play needs a second PC.

All co-op players must use version 0.2.2.
