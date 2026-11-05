class_name SteamLobbyMenu
extends RefCounted
static func show_browser(game) -> void:
 var root=RiftMenus.backdrop(game,"steam")
 var panel=RiftMenus.centered(root,95)
 panel.add_child(RiftMenus.label("STEAM MULTIPLAYER",46))
 panel.add_child(RiftMenus.label("Join a friend's Howling Rift lobby",22))
 var status=RiftMenus.label(SteamSession.status,20)
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 panel.add_child(status)
 var code=LineEdit.new();code.name="SteamLobbyCode"
 code.placeholder_text="Paste lobby code from your host"
 code.custom_minimum_size=Vector2(520,52)
 code.add_theme_font_size_override("font_size",22)
 panel.add_child(code)
 var join=func():
  var error=SteamSession.join_game(code.text)
  if error!=OK:status.text=SteamSession.status if error==ERR_UNAVAILABLE else "Could not join: "+error_string(error)
 panel.add_child(RiftMenus.button("JOIN BY LOBBY CODE",join))
 code.text_submitted.connect(func(_text):join.call())
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(520,230)
 panel.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.add_child(list)
 var refresh=func():
  if not is_instance_valid(list):return
  for child in list.get_children():list.remove_child(child);child.queue_free()
  if SteamSession.friends.is_empty():
   list.add_child(RiftMenus.label("No matching friend lobbies found.\nAsk your host for an invite or lobby code.",20))
  for entry in SteamSession.friends:
   var id=int(entry.id)
   var row=RiftMenus.button("%s • %s • %d/%d • JOIN" % [entry.name,"PVP" if entry.get("mode","pve")=="pvp" else "PVE",entry.members,entry.get("capacity",3)],func():
    var error=SteamSession.join_game(str(id))
    if error!=OK:status.text="Could not join: "+error_string(error))
   row.add_theme_font_size_override("font_size",20)
   list.add_child(row)
 var update=func():
  if is_instance_valid(status):status.text=SteamSession.status
 SteamSession.changed.connect(update)
 SteamSession.friends_changed.connect(refresh)
 root.tree_exiting.connect(func():
  SteamSession.changed.disconnect(update)
  SteamSession.friends_changed.disconnect(refresh))
 panel.add_child(RiftMenus.button("REFRESH FRIEND LOBBIES",func():SteamSession.refresh_friends()))
 panel.add_child(RiftMenus.button("BACK TO MAIN MENU",func():LanSession.leave();game._show_main_menu()))
 refresh.call();SteamSession.refresh_friends()
