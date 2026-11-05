# Combat audio and female announcer

Combat effects remain the original procedural v2 effects from tools/create_combat_audio.py. Minion hit sounds remain muted.

All eleven announcer lines now use installed Microsoft Zira Desktop (female, en-US), speaking the project's own short text at normal rate. Unlike the previous David arrangement, no pitch lowering is applied. Source recordings and VOICE_INFO.json are stored in voice-source/. The voice is locally synthesized speech, not a professional voice recording or external neural service.

Processing: 80 Hz high-pass, 8.5 kHz low-pass, FFmpeg loudness normalization targeting -18 LUFS / -2 dBTP. No heavy distortion, widened pitch or monster effect. ANNOUNCER_REPORT.txt records measured WAV durations and RMS. Runtime retains multikill priority and combat/music ducking.

Regenerate announcer only: powershell -File tools/create_announcer.ps1, then python tools/create_combat_audio.py --announcer-only. Without the flag the Python tool regenerates effects too. female-announcer-preview.wav contains first blood, double/triple kill, killing spree, victory and defeat. moba-audio-preview.wav combines existing combat cues with the new female multikill voice.
