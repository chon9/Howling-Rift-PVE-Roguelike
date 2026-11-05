class_name WorldTextFont
extends RefCounted
# Shared scalable glyphs for text enlarged by the battlefield camera.
# HUD fonts retain Godot's native viewport oversampling.
static var face: FontFile
static func get_font() -> FontFile:
 if face==null:
  face=ThemeDB.fallback_font.duplicate()
  face.multichannel_signed_distance_field=true
  face.msdf_size=64
  face.msdf_pixel_range=32
 return face
