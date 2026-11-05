class_name MatchRules
extends RefCounted
const PVE="pve"
const PVP="pvp"
static func settings(mode: String=PVE,size: int=3,bots: bool=true) -> Dictionary:
 return {"mode":PVP if mode==PVP else PVE,"team_size":clampi(size,1,3) if mode==PVP else 3,"fill_bots":bots}
static func capacity(rules: Dictionary) -> int:
 return int(rules.team_size)*2 if rules.mode==PVP else 3
static func count_team(players: Dictionary,team: int,except_peer: int=0) -> int:
 var count=0
 for peer in players:
  if peer!=except_peer and int(players[peer].get("team",0))==team:count+=1
 return count
static func open_team(players: Dictionary,rules: Dictionary) -> int:
 if rules.mode!=PVP:return 0 if players.size()<3 else -1
 var blue=count_team(players,0);var red=count_team(players,1)
 if mini(blue,red)>=int(rules.team_size):return -1
 return 0 if blue<=red else 1
static func start_error(players: Dictionary,rules: Dictionary) -> String:
 if players.is_empty():return "Choose a hero and press Ready."
 for entry in players.values():
  if not entry.get("ready",false):return "Waiting for every player to press Ready."
 if rules.mode==PVP:
  var blue=count_team(players,0);var red=count_team(players,1);var size=int(rules.team_size)
  if blue==0 or red==0:return "PvP needs at least one human on each team."
  if blue>size or red>size:return "A team has too many players for this room size."
  if not rules.fill_bots and (blue!=size or red!=size):return "Fill both %d-player teams, or enable AI for empty slots." % size
 return ""
static func build_config(players: Dictionary,rules: Dictionary,stage: int,pve_bots: bool) -> Dictionary:
 var configs: Array=[];var peers=players.keys();peers.sort()
 var picks: Array=[[],[]]
 for team in range(2):
  var slot=0
  for peer in peers:
   var entry=players[peer]
   if int(entry.get("team",0))!=team:continue
   var config=entry.duplicate(true);config.team=team;config.slot=team*3+slot
   if rules.mode==PVP:config.bonuses={}
   configs.append(config);picks[team].append(config.hero);slot+=1
 var pool=ChampionData.CHAMPIONS.keys();pool.shuffle()
 for team in range(2):
  for hero in pool:
   if picks[team].size()>=3:break
   if not picks[0].has(hero) and not picks[1].has(hero):picks[team].append(hero)
 if rules.mode==PVE:picks[1]=MatchRoster.enemy_team(picks[0])
 return {"mode":rules.mode,"team_size":rules.team_size,"fill_bots":rules.fill_bots,"players":configs,"blue":picks[0],"red":picks[1],"stage":1 if rules.mode==PVP else stage,"allied_bots":rules.fill_bots if rules.mode==PVP else pve_bots}
