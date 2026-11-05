# Howling Rift 0.2.0

18 heroes and 46 shop items. The six additions are Rook (axe bruiser), Granite
(stone tank), Vexel (scaling mage), Noctra (binding mage), Vesper (crossbow
marksman) and Warden (hook/lantern support). Each has four playable abilities,
painted portraits and skill icons, and six animation frames for each of ten
actions. The complete atlas manifest maps 1,230 hero/minion frames.

Hero selection scrolls to the new row. Enemy drafts exclude allied heroes and
the previous enemy team when the pool permits. Solo and Steam/LAN use the same
expanded roster and host-authoritative combat.

The twenty additions include eight components/intermediates and twelve finished
items. Recipes credit owned components; six slots and one-boots limits remain.
Trinity, Cleaver, Sterak, Nashor, Liandry, Morello, Banshee, Visage and Frozen
Heart have actual combat passives. Percentage penetration uses the highest
owned value, and burn refresh preserves its tick clock. Magic resistance now
counters mage skill damage; armor counters attacks and physical skills. The
HUD displays MR beside armor, and skill descriptions show current AD/AP scaling.
AI recommendations use the new builds.

The throne platforms have painted rounded stone rims and deep cliff foundations
at both lane ends. The generated cap blends into the bridge and keeps the
existing movement boundaries. Native screenshots: `tests/expansion-cliff-0.png`
and `tests/expansion-cliff-1.png`.

Artwork was generated using the built-in image_gen tool. Final saved asset paths
and exact prompts are in `assets/EXPANSION_PROMPTS.json`. Generated PNG alpha is
preserved; the atlas analyzer reads silhouettes without modifying art pixels.

Validation: ExpansionTests (291), ActionAnimationTests (1,296), GroundScalingTests
(141), MenuInputTests (10), RosterMenuTests (75), HeroMechanicTests (24),
PvePresentationTests (52), ARAMLoopTests (45), and native host + two LAN clients.
Steam live lobby/rehost/start (18 checks), exported-package gameplay and release EXE boot also passed.
Two-account internet Steam play still needs a second PC.

All co-op players must use this build: version 0.2.0 / Steam protocol 2.
