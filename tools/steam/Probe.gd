extends SceneTree
func _initialize() -> void:
 print("Steam singleton: ",Engine.has_singleton("Steam")," peer: ",ClassDB.class_exists("SteamMultiplayerPeer"))
 if Engine.has_singleton("Steam"):
  var api=Engine.get_singleton("Steam")
  print("INIT: ",api.steamInitEx(480,false))
  if api.isSteamRunning(): print("Steam logged on: ",api.loggedOn())
 quit()
