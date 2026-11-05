# Howling Rift 0.2.8

The saved runtime log showed repeated `Parent node is busy setting up children, add_child() failed` errors from scene startup. ItemSlot and ItemButton tried to create the shared item-hover manager under the viewport root while the main scene was being attached. The failed attachment left hover callbacks bound to a manager whose CanvasLayer had never initialized. Runtime UI operations could consequently call into an uninitialized manager.

Tooltip handlers now attach through a deferred call, after startup completes. Deferred attachment also rejects deleted, queued-for-deletion or detached controls, including catalog cards rebuilt before the call runs. One initialized manager is shared by all item controls.

Validation: DeathLifecycleTests instantiates the actual main scene during scene startup, checks its hover manager, then exercises all 18 heroes with lethal damage, native-rendered corpse frames, death UI refresh, item hovering while dead, cooldown progression, actual-loop respawns and enemy deaths. It also kills every supported minion/summon type. 199 checks passed on the native Godot 4.7.2 renderer with no runtime errors. Three-peer LAN checks cover replicated guest deaths and corpse rendering. Default main-scene boot and existing tactics/item hover checks also pass.

The log did not include a separate death-specific native crash backtrace; this patch addresses the concrete initialization failure found and the tested death/hover path. All co-op players need v0.2.8.
