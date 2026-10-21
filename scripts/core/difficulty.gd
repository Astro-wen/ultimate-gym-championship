class_name Difficulty
## Difficulty presets. Chosen in the menu, stored in GameState.difficulty,
## applied to the watchers and the stealth director when a level is built.

enum Level { EASY, NORMAL, HARD }

const NAMES: Array[String] = ["轻松", "普通", "困难"]
const BLURBS: Array[String] = [
	"产品经理慢、跟得松；可以被抓 4 次",
	"标准体验；可以被抓 3 次",
	"更警觉、跟得更久、路线更难猜；只能被抓 2 次",
]
const COLORS: Array[Color] = [Color(0.4, 0.88, 0.5), Color(0.45, 0.75, 0.98), Color(0.96, 0.4, 0.35)]

## rise: awareness rise multiplier; view: view range multiplier;
## pm_speed: PM walking speed multiplier; chase_speed: px/s while following
## (always below the player's 70 px/s walk); chase_time: seconds she keeps
## following after losing sight; follow_at: awareness that makes her follow;
## randomness: chance the PM picks a random next patrol point;
## strikes: detections allowed.
const PARAMS: Array[Dictionary] = [
	{"rise": 0.6, "view": 0.85, "pm_speed": 0.85, "chase_speed": 40.0, "chase_time": 2.5, "follow_at": 0.6, "randomness": 0.3, "strikes": 4},
	{"rise": 1.0, "view": 1.0, "pm_speed": 1.0, "chase_speed": 50.0, "chase_time": 4.0, "follow_at": 0.4, "randomness": 0.6, "strikes": 3},
	{"rise": 1.2, "view": 1.1, "pm_speed": 1.15, "chase_speed": 60.0, "chase_time": 6.0, "follow_at": 0.3, "randomness": 0.9, "strikes": 2},
]


static func params(d: int) -> Dictionary:
	return PARAMS[clampi(d, 0, PARAMS.size() - 1)]


static func name_of(d: int) -> String:
	return NAMES[clampi(d, 0, NAMES.size() - 1)]
