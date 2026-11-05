"""Generate original, local SVG artwork. No downloads or runtime dependencies."""
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets'
(ART / 'champions').mkdir(parents=True, exist_ok=True)
(ART / 'structures').mkdir(exist_ok=True)
(ART / 'minions').mkdir(exist_ok=True)

def svg(body, width=80, height=110, color='#69c9fa'):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs><linearGradient id="cloth" x2=".7" y2="1"><stop stop-color="{color}"/><stop offset="1" stop-color="#172a46"/></linearGradient>
<linearGradient id="steel" x2=".8" y2="1"><stop stop-color="#f0f6ff"/><stop offset=".5" stop-color="#8fa9c2"/><stop offset="1" stop-color="#304b69"/></linearGradient>
<radialGradient id="glow"><stop stop-color="{color}" stop-opacity=".65"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient></defs>{body}</svg>'''

base = '<ellipse cx="40" cy="100" rx="24" ry="6" fill="#060c19" opacity=".45"/>'
head = '<path d="M29 24Q29 13 40 13Q53 13 51 28L47 36H34Z" fill="#efc3a1" stroke="#644b51" stroke-width="1.2"/><path d="M33 26l5 1m5 0 5-1" stroke="#283650" stroke-width="2"/><path d="M38 32h5" stroke="#a76561"/>'
legs = '<path d="M30 76L29 94L23 99L38 100L39 76M43 76L43 98L58 99L52 94L51 76" fill="#23354d" stroke="#657792" stroke-width="1.3"/>'
bodies = {
 'ashe': ('#68c9ef', base + '<path d="M30 32L50 32L64 93L42 85L16 94Z" fill="url(#cloth)" stroke="#8ac9e7" stroke-width="1.8"/>' + legs + '<path d="M30 38L50 38L54 73L26 73Z" fill="#254d70"/><path d="M30 40L49 66M28 73H54" stroke="#d2ba79" stroke-width="3"/>' + head + '<path d="M26 30Q23 5 39 7Q61 6 54 34L47 18L33 17Z" fill="#ddeaf0"/><path d="M24 18Q38 0 55 17L52 10Q37 0 26 12Z" fill="#355c87"/>' + '<path d="M20 42L13 61M53 43L60 59" stroke="#c1ccd4" stroke-width="7" stroke-linecap="round"/><path d="M65 28Q85 57 65 88M65 28L65 88" fill="none" stroke="#9eeaff" stroke-width="3"/><path d="M53 58H77L70 53M77 58L70 63" stroke="#e7f8ff" stroke-width="2" fill="none"/>'),
 'annie': ('#ef785c', base + '<circle cx="24" cy="23" r="12" fill="#a64346"/><circle cx="56" cy="23" r="12" fill="#a64346"/>' + legs + '<path d="M28 38Q40 32 52 38L59 80L21 80Z" fill="url(#cloth)" stroke="#ffa68c" stroke-width="2"/><path d="M25 68H55L59 80H21Z" fill="#b55579"/><path d="M36 42L40 49L44 42" fill="#ffe3d1"/>' + head + '<path d="M28 26Q20 5 40 6Q61 5 52 26L43 15L32 21Z" fill="#ba504a"/><path d="M28 44L19 63M52 44L60 58" stroke="#eebaa0" stroke-width="6" stroke-linecap="round"/><circle cx="13" cy="57" r="16" fill="url(#glow)"/><path d="M11 39Q2 49 7 60Q21 65 24 55Q25 48 17 44L14 52Z" fill="#ffb13b"/><circle cx="64" cy="63" r="9" fill="#694439"/><circle cx="58" cy="54" r="4" fill="#694439"/><circle cx="69" cy="54" r="4" fill="#694439"/><circle cx="61" cy="61" r="1.7" fill="#ffb252"/><circle cx="67" cy="61" r="1.7" fill="#ffb252"/>'),
 'garen': ('#769ac4', base + '<path d="M22 32H57L64 92L40 83L16 93Z" fill="#284f97" stroke="#8dace1" stroke-width="1.5"/>' + legs + '<path d="M25 40L55 40L54 72L27 72Z" fill="url(#steel)" stroke="#dbc583" stroke-width="2"/><path d="M29 50L40 60L51 50M28 72H53" stroke="#eac982" stroke-width="3" fill="none"/>' + head + '<path d="M27 23Q23 5 40 6Q57 4 54 23L44 17L32 20Z" fill="#5b453b"/><path d="M18 35L30 33L31 49L16 51L12 43ZM50 33L63 35L68 43L64 51L49 49Z" fill="url(#steel)" stroke="#e8ce89" stroke-width="2"/><path d="M19 50L18 68M59 49L62 64" stroke="#536c93" stroke-width="8"/><path d="M62 70L69 13L76 7L80 17L71 72Z" fill="url(#steel)" stroke="#dceaff"/><path d="M57 70L77 73" stroke="#f0ca67" stroke-width="4"/><path d="M65 74L64 85" stroke="#66523b" stroke-width="5"/>'),
 'lux': ('#edcb75', base + '<path d="M28 35H51L60 92L40 83L20 92Z" fill="#374d8e" stroke="#7c9ddb"/>' + legs + '<path d="M29 38L51 38L55 74L25 74Z" fill="url(#steel)" stroke="#dcc681" stroke-width="2"/><path d="M25 69H55L57 79H24Z" fill="#e4d8bf"/><path d="M34 47L40 54L47 47" stroke="#d9b454" stroke-width="3" fill="none"/>' + head + '<path d="M27 32Q23 5 40 7Q61 7 54 36L47 18L36 21L30 44Z" fill="#ead092"/><path d="M28 42L20 64M52 42L62 56" stroke="#bacada" stroke-width="7" stroke-linecap="round"/><path d="M64 22L68 96" stroke="#d4b76c" stroke-width="4"/><circle cx="64" cy="19" r="18" fill="url(#glow)"/><path d="M64 6L72 18L64 29L56 18Z" fill="#fff2ba" stroke="#d7b968" stroke-width="2"/><path d="M55 17H74" stroke="#e4d7a7" stroke-width="2"/>'),
 'ahri': ('#db78be', base + '<path d="M32 63Q-5 34 7 83Q11 101 37 85M34 70Q9 51 16 94Q22 104 40 83M46 69Q77 34 75 78Q72 99 44 86M46 73Q75 64 64 98L40 86" fill="#ede5ee" stroke="#a78aab" stroke-width="1.5"/>' + legs + '<path d="M30 35L50 35L56 76L24 76Z" fill="#a53d6d" stroke="#efb0c7" stroke-width="2"/><path d="M31 36L40 56L50 36M27 62H54" stroke="#f1dec3" stroke-width="4" fill="none"/>' + head + '<path d="M25 31Q19 5 40 9Q60 4 57 36L45 18L31 25L28 53Z" fill="#252638"/><path d="M25 17L24 1L34 12M46 12L58 1L57 21" fill="#f2d7df" stroke="#38283f" stroke-width="3"/><path d="M29 44L18 65M52 43L62 57" stroke="#f2c5ae" stroke-width="6" stroke-linecap="round"/><circle cx="65" cy="55" r="16" fill="url(#glow)"/><circle cx="65" cy="55" r="8" fill="#81f0fa" stroke="#ddfcff" stroke-width="2"/><path d="M31 30l5 2m10-2-4 2" stroke="#b25476"/>'),
 'ezreal': ('#65c7d0', base + '<path d="M28 34L52 35L60 78L21 78Z" fill="#754d3d" stroke="#c79d6b" stroke-width="2"/>' + legs + '<path d="M31 40L48 40L50 73L29 73Z" fill="#d2c5b0"/><path d="M27 41L52 66M26 72H53" stroke="#aa864d" stroke-width="4"/>' + head + '<path d="M25 25Q20 8 35 7L29 2L45 6L55 2L53 13L59 14L51 24L43 17L33 21Z" fill="#dfc679"/><path d="M28 15H52" stroke="#553a37" stroke-width="4"/><path d="M31 15h6m6 0h6" stroke="#6bacc5" stroke-width="3"/><path d="M27 45L18 64M53 43L65 56" stroke="#98755d" stroke-width="7"/><path d="M11 57L22 54L26 71L13 75Z" fill="#ab8e4e" stroke="#e8dba1" stroke-width="2"/><circle cx="16" cy="65" r="15" fill="url(#glow)"/><path d="M17 58L23 65L17 71L12 65Z" fill="#80f3ff" stroke="#ddfaff"/>' )
}
for key, (color, body) in bodies.items():
    (ART / 'champions' / f'{key}.svg').write_text(svg(body, color=color), encoding='utf-8')

for team, color in [('blue', '#58b6f2'), ('red', '#ef697e')]:
    tower = '<ellipse cx="40" cy="97" rx="34" ry="9" fill="#101b2b" opacity=".6"/><path d="M9 91L40 104L71 91L64 78H16Z" fill="#344a62" stroke="#87a0ae" stroke-width="2"/><path d="M20 36L59 36L65 86L40 96L15 86Z" fill="url(#steel)" stroke="#9cacbb" stroke-width="2"/><path d="M23 48L40 55L57 48M20 71L40 79L60 71" stroke="#c1b590" stroke-width="4" fill="none"/><path d="M31 50L40 59L49 50L47 77L40 83L33 77Z" fill="#243652"/><circle cx="40" cy="29" r="29" fill="url(#glow)"/><path d="M40 3L55 25L40 47L25 25Z" fill="url(#cloth)" stroke="#ddf8ff" stroke-width="2"/><path d="M40 3L40 47L55 25Z" fill="white" opacity=".3"/><path d="M25 25H55" stroke="white" opacity=".7"/><path d="M17 43L10 35L8 58L21 64M62 43L71 35L73 58L60 64" fill="#5b718a" stroke="#b5bfd0"/>'
    (ART / 'structures' / f'tower_{team}.svg').write_text(svg(tower, color=color), encoding='utf-8')

# Illustrated battlefield: stone paving, cliffs, crystal lamps, forest silhouettes.
rng = random.Random(1703)
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="2800" height="540"><defs><linearGradient id="ground" x2="0" y2="1"><stop stop-color="#142b36"/><stop offset="1" stop-color="#091822"/></linearGradient><linearGradient id="stone" x2="0" y2="1"><stop stop-color="#42505a"/><stop offset="1" stop-color="#293b48"/></linearGradient></defs><rect width="2800" height="540" fill="url(#ground)"/>']
for x in range(0, 2800, 68):
    for edge in [0, 540]:
        y = edge + (25 if edge == 0 else -25)
        parts.append(f'<path d="M{x-38} {y}L{x} {y-60}L{x+38} {y}L{x+24} {y+13}L{x-25} {y+13}Z" fill="#183b43" stroke="#244b53" stroke-width="2"/>')
parts.append('<path d="M0 70H2800V470H0Z" fill="#152733" stroke="#69828c" stroke-width="4"/>')
for row in range(6):
    y = 87 + row * 60
    for x in range(-60 + (row % 2) * 55, 2800, 110):
        tint = rng.choice(['#354752','#3a4b56','#30424e','#3d4d57'])
        parts.append(f'<path d="M{x+4} {y+4}L{x+101} {y+2}L{x+107} {y+51}L{x+12} {y+56}L{x+2} {y+32}Z" fill="{tint}" stroke="#213640" stroke-width="2"/><path d="M{x+15} {y+8}L{x+90} {y+6}" stroke="#64727b" stroke-opacity=".28" stroke-width="2"/>')
for edge in [74, 461]:
    parts.append(f'<rect y="{edge}" width="2800" height="7" fill="#789aa8"/><rect y="{edge+7}" width="2800" height="4" fill="#1b323f"/>')
    for x in range(30, 2800, 100):
        parts.append(f'<path d="M{x} {edge}l15 -16h40l15 16Z" fill="#445e6c" stroke="#8aa5ae"/><path d="M{x+12} {edge-7}h45" stroke="#c1d8da" stroke-width="2"/>')
for x in range(110, 2800, 240):
    for y in [55, 490]:
        parts.append(f'<ellipse cx="{x}" cy="{y}" rx="28" ry="12" fill="#65d8f4" opacity=".08"/><path d="M{x-9} {y+5}L{x} {y-20}L{x+9} {y+5}Z" fill="#79c6d9" stroke="#c7edf2"/><path d="M{x-14} {y+7}h28l-5 7h-18Z" fill="#4a6272"/>')
parts.append('<circle cx="1400" cy="270" r="115" fill="none" stroke="#8b9d9f" stroke-opacity=".28" stroke-width="4"/><path d="M1400 180L1455 270L1400 360L1345 270Z" fill="none" stroke="#8b9d9f" stroke-opacity=".22" stroke-width="3"/></svg>')
(ART / 'battlefield.svg').write_text(''.join(parts), encoding='utf-8')
for team, color in [('blue', '#619fee'), ('red', '#dc6b7a')]:
    soldier = '<ellipse cx="40" cy="99" rx="23" ry="5" fill="#07111e" opacity=".5"/><path d="M25 72L24 93L17 99H35L36 72M44 72L45 99H63L56 93L55 72" fill="#24354d"/><path d="M24 44L55 44L60 78L20 78Z" fill="url(#cloth)" stroke="#a7bdd4" stroke-width="2"/><path d="M23 63H57" stroke="#d4ba76" stroke-width="4"/><path d="M27 42Q19 12 40 12Q62 12 54 42Z" fill="url(#steel)" stroke="#b8ccdc" stroke-width="2"/><path d="M26 29H55L51 43H30Z" fill="#172c40"/><path d="M32 33H48" stroke="'+color+'" stroke-width="3"/>'
    weapons = {'melee':'<path d="M62 72L69 30L74 26L76 33L68 73Z" fill="url(#steel)"/><path d="M59 71L75 75" stroke="#ceb974" stroke-width="3"/><path d="M15 51L29 55L26 78L13 74Z" fill="#546f90" stroke="#b9cadc" stroke-width="2"/>', 'caster':'<path d="M64 28L67 98" stroke="#957759" stroke-width="4"/><circle cx="64" cy="24" r="13" fill="url(#glow)"/><path d="M64 15L71 24L64 32L57 24Z" fill="'+color+'" stroke="#d0f5ff"/>', 'super':'<path d="M12 41L26 37L29 54L11 58M52 37L68 41L69 58L52 54" fill="url(#steel)" stroke="#dfc57b" stroke-width="3"/><path d="M65 61L75 16" stroke="#a5b9cd" stroke-width="7"/><path d="M70 15L63 23L69 39L80 27Z" fill="#c2d3df" stroke="#dccb91"/>'}
    for kind, weapon in weapons.items():
        (ART / 'minions' / f'{kind}_{team}.svg').write_text(svg(soldier + weapon, color=color), encoding='utf-8')
    cannon = '<ellipse cx="40" cy="94" rx="33" ry="10" fill="#07111e"/><circle cx="19" cy="80" r="15" fill="#24354a" stroke="#8da4bc" stroke-width="3"/><circle cx="59" cy="80" r="15" fill="#24354a" stroke="#8da4bc" stroke-width="3"/><path d="M12 62L62 57L70 80H12Z" fill="url(#cloth)" stroke="#a5bcd1" stroke-width="2"/><path d="M31 57L64 31L75 42L43 70Z" fill="url(#steel)" stroke="#253c4e" stroke-width="2"/><path d="M61 30L76 41L73 47L58 36Z" fill="#132532"/><path d="M22 55L25 37L40 39L45 56Z" fill="#71869d"/>'
    (ART / 'minions' / f'siege_{team}.svg').write_text(svg(cannon, color=color), encoding='utf-8')
    bear = '<ellipse cx="40" cy="101" rx="29" ry="6" fill="#090d14"/><path d="M19 67L13 98H32L40 75L49 98H69L62 64Z" fill="#6b4131"/><ellipse cx="40" cy="60" rx="28" ry="32" fill="#8b533b" stroke="#cc8c56" stroke-width="2"/><circle cx="17" cy="24" r="11" fill="#7b4636"/><circle cx="62" cy="24" r="11" fill="#7b4636"/><circle cx="40" cy="34" r="23" fill="#92563e"/><ellipse cx="40" cy="46" rx="12" ry="9" fill="#c89460"/><circle cx="31" cy="32" r="4" fill="#ffc157"/><circle cx="49" cy="32" r="4" fill="#ffc157"/><path d="M35 42L45 42L40 47Z" fill="#402b27"/>'
    (ART / 'minions' / f'tibbers_{team}.svg').write_text(svg(bear, color=color), encoding='utf-8')
print('Generated champion, tower, minion and battlefield artwork.')
