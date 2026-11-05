# Dedicated permanent equipment art — v0.4.2

The stash and equipped slots now use a dedicated transparent painted spritesheet with 19 distinct equipment objects. Helmets and hoods depict headgear; breastplates and robes depict body armor. Weapons, shields, orbs, boots, rings, necklaces and gloves use their own silhouettes. Item names identify the depicted object, including Iron Helm, Rift Breastplate, Frost Sword, Ruby Ring, Dawn Necklace and Duelist Gloves.

Every relic has a stable `base_id`. Loading an existing profile migrates legacy shop icon references and names to the matching equipment identity inside its actual slot. This preserves item IDs, rolled stats, modifiers, rarity, level and equipped positions. No item reroll is required. The two ring positions remain independent.

Art was created using built-in image generation followed by a transparent-background padding edit. Asset: `assets/ui/permanent-equipment-v1.png`. Exact generation prompt and source path: `assets/ui/PERMANENT_EQUIPMENT_V1_PROMPT.json`. Exact refinement prompt: `assets/ui/PERMANENT_EQUIPMENT_V1_PADDING_PROMPT.txt`. The generated rows have uneven spacing, so `scripts/GearArt.gd` uses individually measured square crops with transparent padding rather than assuming uniform cells. Atlas filtering is clipped to each region.

Validation: 203 native presentation and legacy-profile migration checks passed, including every icon crop, correct slot/name mapping, preserved stats and equipped positions, save/reload and malformed cross-slot references. The existing 7,267 equipment progression checks also passed. Native screenshots: `tests/equipment-art-v042.png` and `tests/equipment-icon-gallery-v042.png`.

Release validation: the actual exported Steam/AppID 480 PCK smoke test passed with zero failures, including all 19 dedicated equipment icons, correct generated names, equipment, co-op match startup and daily rewards. The release executable boots cleanly. All co-op players should update to v0.4.2.
