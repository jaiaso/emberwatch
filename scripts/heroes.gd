extends RefCounted
## Original interpretations of six historical and legendary commanders.
const XP = [0, 60, 160, 300, 480, 700]
const DATA = {
	"arthur": {"name":"アーサー王", "role":"soldier", "color":"ead179", "title":"聖剣の王", "passive":"自分の剣士の攻撃 +20%（Lv毎+4%）", "unlocks":"Lv3：自身の与ダメージ20%回復\nLv5：自分の剣士の軽減 +10pt"},
	"joan": {"name":"ジャンヌダルク", "role":"soldier", "color":"a9dcec", "title":"祈りの旗手", "passive":"自分の剣士の軽減 +8pt（Lv毎+1pt）\n周囲7マスの味方を毎秒2HP回復（Lv毎+0.5）", "unlocks":"Lv3：回復範囲10マス\nLv5：自分の剣士は遠方でも毎秒1HP回復"},
	"iskandar": {"name":"イスカンダル", "role":"cavalry", "color":"d99163", "title":"征服の覇王", "passive":"自分の騎兵が重装騎兵に変化\n高攻撃・高防御、速度4.0（通常4.5）", "unlocks":"Lv3：重装騎兵の軽減 +8pt\nLv5：重装騎兵の攻撃 +25%"},
	"kenshin": {"name":"上杉謙信", "role":"cavalry", "color":"ced5ed", "title":"疾風の軍神", "passive":"自分の騎兵の攻撃 +15%・速度 +12%\nLv毎：攻撃+3%・速度+2%", "unlocks":"Lv3：自身の攻撃間隔を短縮\nLv5：自分の騎兵の軽減 +8pt"},
	"yoichi": {"name":"那須与一", "role":"archer", "color":"94d29f", "title":"遠矢の名手", "passive":"自分の弓兵の射程 +2（Lv毎+0.4）\n英雄自身の基本射程13", "unlocks":"Lv3：自身の攻撃 +30%\nLv5：自分の弓兵の攻撃 +15%"},
	"himiko": {"name":"卑弥呼", "role":"mage", "color":"e5a0d6", "title":"炎を詠む女王", "passive":"自分の弓兵が炎の魔法使いに変化\n低防御・低速、高威力の炎弾", "unlocks":"Lv3：自身の炎弾が範囲攻撃\nLv5：自分の魔法使いの炎弾も範囲攻撃"},
}

static func is_hero(kind: String) -> bool:
	return DATA.has(kind)

static func role(kind: String) -> String:
	return DATA.get(kind,{}).get("role", "cavalry" if kind=="heavy_cavalry" else kind)

static func mounted(kind: String) -> bool:
	return role(kind)=="cavalry"

static func unit_name(kind: String) -> String:
	return DATA[kind].name if is_hero(kind) else {"worker":"村人","soldier":"剣士","archer":"弓兵","cavalry":"騎兵","heavy_cavalry":"重装騎兵","mage":"魔法使い"}.get(kind,kind)

static func next_xp(level: int) -> int:
	return XP[level] if level<XP.size() else XP[-1]
