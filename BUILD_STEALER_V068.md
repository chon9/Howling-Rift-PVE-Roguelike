# v0.6.8 — unique archived heroes and enemy teams

The host stores at most **10 different heroes**, with **one best build per hero**. A new qualifying completed run replaces that hero's saved build only when its recalculated score is higher. Different items, rolled upgrades, skill paths or summoners no longer create additional slots for the same hero. Equal or lower scores preserve the existing build.

The existing score remains `round(difficulty_reward_multiplier × (100 × kills + 15 × assists) / max(1, deaths)) + 500 for a victory`. Higher N increases the difficulty multiplier; performance still contributes. Qualification remains **15+ hero kills and K/D ≥ 5**. Only the best ten hero records survive the global ranking. Old archives automatically consolidate duplicate heroes to their highest score on load, preserving credits and other progression.

Every PvE enemy team has **three different heroes**. With two or more archived heroes, two enemies use different saved builds and the third follows normal AI progression. With just one archived hero, only one enemy uses that build and the other two progress normally. With no archive, all three are normal bots. Repeated allied heroes and mirrors across teams remain allowed. Normal opponents still favor fresh heroes between matches.

The host chooses the lineup before loading and sends it to co-op guests. Echoes use the real saved hero, buy their recorded items with earned gold, and unlock saved upgrades at their original level milestones. Source N affects ranking only; current match difficulty supplies enemy stats. Account equipment, permanent upgrades and endgame levels are not copied. PvP does not use or record stolen builds.

The Build Stealer menu now identifies its capacity as ten heroes and explains replacement and unique enemy teams. Match results count only qualifying builds actually retained, including when multiple co-op players used the same hero.

Validation covers different builds of the same hero, score improvement and ties, twenty distinct heroes reduced to ten, legacy profile migration, fifty randomized enemy rotations, one/zero/two-Echo lineups, independent state for repeated allied heroes, and real three-peer co-op with both ordinary and repeated allied rosters. Native rendering/loading and packaged Steam checks verify the shipped build.

Steam protocol is **12**. All players in a room must use **v0.6.8**. Download and extract the full Windows ZIP or use the game's verified updater.
