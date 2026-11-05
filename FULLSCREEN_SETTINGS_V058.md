# v0.5.8 — Remember fullscreen across launches

Fullscreen/windowed mode now persists in the local progression profile and is applied when the main scene starts. The settings checkbox, F11 and Alt+Enter all update the same saved preference. Settings panels stay synchronized with the selected mode.

Existing profiles that do not yet contain a fullscreen preference continue to start windowed. Turn fullscreen on once through the settings or F11; subsequent launches restore it. Startup applies the preference without unnecessarily saving the profile again. Display preferences remain local to each player in co-op.

Validation uses an isolated save and the real main startup scene, including fullscreen save/reload, restored native window mode, F11 returning to windowed mode, Alt+Enter persistence, checkbox synchronization and legacy-profile defaults. Player progression is preserved.
