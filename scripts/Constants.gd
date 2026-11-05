extends Node
# Autoload: Constants — accessible from anywhere as `Constants.BLUE` etc.

const BLUE: int = 0
const RED: int = 1

const WORLD_W: float = 2800.0
const WORLD_H: float = 540.0
const LANE_Y: float = 270.0
const LANE_HALF: float = 180.0
const FOUNT_B: Vector2 = Vector2(110, 270)
const FOUNT_R: Vector2 = Vector2(2690, 270)
const BASE_B_X: float = 180.0
const BASE_R_X: float = 2620.0

const CHAMP_RADIUS: float = 24.0
# Increase the entire battlefield together, preserving hero/minion/terrain ratios.
const BATTLE_CAMERA_ZOOM: float = 1.7
# Visual proportions: ordinary minions are 40.5-43.2px tall.
const CHAMP_ART_HEIGHT: float = 56.0
const CHAMP_ART_SCALE: float = CHAMP_ART_HEIGHT / 108.0
const CHAMP_RUN_STRIDE: float = 162.0
const CHAMP_BAR_WIDTH: float = 46.0
const CHAMP_GROUND_MARK_SCALE: float = 0.7

const WAVE_INTERVAL: float = 16.0
const FIRST_WAVE_AT: float = 3.0

# Match currency/XP: source rewards are scaled once, before enemy difficulty XP.
const PASSIVE_GOLD: float = 0.2
const PASSIVE_XP: float = 0.2
const HERO_KILL_GOLD: int = 600
const HERO_KILL_XP: float = 320.0
const HERO_KILL_XP_PER_LEVEL: float = 0.0
const ASSIST_XP: float = 40.0
const ASSIST_XP_PER_LEVEL: float = 0.0
const MINION_GOLD_MULTIPLIER: int = 2
const MINION_SOAK_XP_MULTIPLIER: float = 2.4
const LAST_HIT_XP_MULTIPLIER: float = 1.25

const TEAM_COLOR = {
	0: Color(0.29, 0.52, 1.0),
	1: Color(1.0, 0.35, 0.35)
}
const TEAM_FILL = {
	0: Color(0.1, 0.17, 0.4),
	1: Color(0.4, 0.1, 0.1)
}
const TEAM_HP = {
	0: Color(0.27, 1.0, 0.4),
	1: Color(1.0, 0.27, 0.4)
}

# Depth / Z-index layering
const Z_GROUND  : int = 0
const Z_AOE     : int = 10
const Z_UNITS   : int = 20
const Z_PROJ    : int = 30
const Z_FX      : int = 40
const Z_FLOAT   : int = 50

# Early XP curve stays unchanged; veteran levels continue to 100.
const MAX_LEVEL: int = 100
const VETERAN_STATS = {"bonus_ad":3.0,"bonus_ap":5.0,"bonus_hp":45.0,"bonus_mp":25.0}
# XP table for levels 1..18
const XP_TABLE = [0, 280, 380, 480, 580, 680, 780, 880, 980,
				  1080, 1180, 1280, 1380, 1480, 1580, 1680, 1780, 1880]

func xp_to_level(lv: int) -> int:
	lv=clampi(lv,1,MAX_LEVEL)
	if lv >= XP_TABLE.size():
		return int(XP_TABLE[-1])+60*(lv-18)
	return XP_TABLE[lv]

func enemy_death_gold(deaths: int) -> int:
	return 0 if deaths<=10 else 600+(deaths-11)*250
