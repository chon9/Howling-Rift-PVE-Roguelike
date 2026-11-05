extends RefCounted
class_name SummonerData
const ORDER = ["flash", "ignite", "heal", "ghost"]
const SPELLS = {
 "flash":{"name":"Flash", "cd":45.0, "desc":"Blink up to 300 units toward your cursor. 45s cooldown.", "art":26},
 "ignite":{"name":"Ignite", "cd":35.0, "desc":"Burn a hero within 300 range for 70 +20 per level over 5s. 35s cooldown.", "art":27},
 "heal":{"name":"Heal", "cd":40.0, "desc":"Restore 100 +25 per level HP to you and the lowest-health nearby ally; gain 25% speed for 2s. 40s cooldown.", "art":28},
 "ghost":{"name":"Ghost", "cd":30.0, "desc":"Gain 40% movement speed for 6s. 30s cooldown.", "art":29}}
