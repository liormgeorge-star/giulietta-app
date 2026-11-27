"""Generates www/themes.css and www/themes.js from one table, so the 30 designs stay in sync.
Run: python3 tools/gen_themes.py   (from the pc-remote folder)"""
import json, os

D = {  # display / body / data font stacks
 'rubik': "'Rubik','Heebo',system-ui,sans-serif", 'heebo': "'Heebo',system-ui,sans-serif",
 'assistant': "'Assistant',system-ui,sans-serif", 'secular': "'Secular One','Rubik',sans-serif",
 'suez': "'Suez One','Rubik',serif", 'varela': "'Varela Round','Assistant',sans-serif",
 'karantina': "'Karantina','Heebo',sans-serif", 'plex': "'IBM Plex Sans Hebrew','Heebo',sans-serif",
 'press': "'Press Start 2P',ui-monospace,monospace", 'silk': "'Silkscreen',ui-monospace,monospace",
 'vt': "'VT323',ui-monospace,monospace", 'orbitron': "'Orbitron',sans-serif", 'rajdhani': "'Rajdhani',sans-serif",
 'stm': "'Share Tech Mono',ui-monospace,monospace", 'chakra': "'Chakra Petch',sans-serif", 'bebas': "'Bebas Neue',sans-serif",
 'exo': "'Exo 2',sans-serif", 'michroma': "'Michroma',sans-serif", 'saira': "'Saira Condensed',sans-serif",
 'spacemono': "'Space Mono',ui-monospace,monospace", 'pixel': "'Pixelify Sans',ui-monospace,monospace",
 'plexmono': "'IBM Plex Mono',ui-monospace,monospace",
}

# id, Hebrew name, group, scheme, display, body, data, radius, colors:
# bg surface sunken line ink muted accent accentInk on busy off danger
T = [
 ('studio','סטודיו','יומיומי','light','rubik','heebo','plexmono',20,'#eef0f5 #ffffff #e4e7ee #d5d9e3 #141722 #5c6376 #2f55e4 #ffffff #13865a #b0730f #8b92a5 #c3343c'),
 ('midnight','חצות','יומיומי','dark','assistant','assistant','plexmono',24,'#0a0c12 #12151f #1a1e2b #1f2433 #e8eaf2 #8a91a6 #8fa6ff #0a0c12 #3fd08e #f2b54d #697086 #ff8a92'),
 ('hardware','חומרה','יומיומי','light','heebo','heebo','stm',16,'#cfd2d8 #e7e9ec #c3c8cf #aeb3bb #23262c #4a4f58 #2c5d8a #ffffff #1f9a55 #a8741a #7d828b #b53a2e'),
 ('brutal','ברוטליסטי','יומיומי','light','heebo','heebo','spacemono',0,'#ffffff #ffffff #ffe600 #000000 #000000 #333333 #000000 #ffffff #000000 #000000 #666666 #000000'),
 ('soft','רך','יומיומי','light','varela','assistant','assistant',30,'#fbf6f1 #dff3ea #ffffff #e8e1d8 #2d2a32 #6d6673 #2f7d6b #ffffff #2f7d6b #c07a2c #a19aa6 #c2546b'),
 ('rgb','RGB Rig','גיימינג','dark','rubik','rubik','rajdhani',20,'#06070b #0d0f17 #141725 #262a3d #eef1ff #9aa1c4 #38e8ff #06070b #3dff9c #ffcf4a #6b7290 #ff6b96'),
 ('arcade','ארקייד','גיימינג','dark','secular','secular','press',4,'#1a0b2e #0b0418 #2a1450 #6ff2ff #f6f0ff #8d7bb3 #ff3e8a #ffffff #7dff6a #ffd23f #8d7bb3 #ff3e8a'),
 ('hud','HUD טקטי','גיימינג','dark','plex','plex','stm',0,'#0e0f0b #14150f #1c1d15 #5a4415 #ffb020 #a8761a #ffb020 #0e0f0b #d8ff3a #ffb020 #7a5a1a #ff7a5c'),
 ('console','מסך בית של קונסולה','גיימינג','dark','rubik','rubik','rubik',18,'#071a45 #0f2d6e #0b2358 #24499a #ffffff #9fb7e8 #2a7bff #ffffff #5bff9a #ffd166 #8fa3cc #ff7a8a'),
 ('esports','ספורט אלקטרוני','גיימינג','dark','heebo','heebo','saira',0,'#111215 #1b1c21 #23252b #34363e #f4f4f6 #a3a6b0 #ff2d3d #ffffff #ffffff #ffb020 #7c808c #ff4a58'),
 ('grey80','אפור שנות ה-80','רטרו','light','rubik','rubik','vt',6,'#c9c7c2 #d8d6d1 #bdbbb6 #8d8b86 #1d1d1d #555555 #c8102e #ffffff #1d1d1d #c8102e #6e6c68 #c8102e'),
 ('blackred','שחור-אדום 8-ביט','רטרו','dark','heebo','heebo','silk',10,'#121214 #26262a #18181b #3a3a40 #f1f1f1 #9a9aa3 #e3262f #ffffff #f1f1f1 #ffb020 #6e6e76 #e3262f'),
 ('cream','קרם ובורדו','רטרו','light','suez','assistant','assistant',6,'#efe6d2 #f8f2e4 #e9dfc9 #d9cdb2 #3b2a22 #8a7663 #8b1e2b #f6eedb #2f7a3a #c9a24a #a6967f #d23a3a'),
 ('wood','עץ שנות ה-70','רטרו','dark','secular','heebo','heebo',6,'#141210 #1e1a16 #0c0b0a #4a2a12 #f2e6d4 #a8957c #e0742b #1a120b #ff9a3c #f2c14e #7a6a56 #c0261b'),
 ('lcd','כף יד ירוק','רטרו','light','secular','secular','silk',12,'#c4c2b8 #9bbc0f #8bac0f #306230 #0f380f #306230 #8b1e52 #ffffff #0f380f #306230 #5a6a3a #8b1e52'),
 ('lilac','16-ביט לילך','רטרו','light','rubik','rubik','pixel',22,'#d4d3d9 #e9e8ee #b9b6c7 #b5b3c0 #2e2b3a #6f6a85 #5a4a9c #ffffff #3aa35a #e6b43a #8d89a3 #d6453d'),
 ('ribbed','16-ביט שחור מחורץ','רטרו','dark','heebo','heebo','orbitron',8,'#121212 #1c1c1c #2b2b2b #333333 #ececec #a5a5a5 #d9b25a #121212 #ffffff #d9b25a #6a6a6a #c4302b'),
 ('disc','עידן הדיסק האפור','רטרו','light','assistant','assistant','michroma',8,'#c3c4c8 #e4e5e9 #b5b6bb #9fa0a6 #232428 #4a4c55 #2f4a8a #ffffff #1f8a55 #b07a1a #7e7f86 #b5343a'),
 ('clear','פלסטיק שקוף','רטרו','light','varela','rubik','rubik',26,'#ece9f4 #d9cff0 #ffffff #c8bce6 #2a2140 #5f5480 #5b2ea6 #ffffff #1f8a4c #d9821a #8f86a8 #d63c50'),
 ('pocket','כף יד צבעוני','רטרו','dark','rubik','rubik','pixel',22,'#4b2c8f #2a1a52 #5fc4d6 #6a4bb0 #ffffff #c9b8f2 #ffd94a #12324a #5bff7a #ffd94a #9d8bd0 #ff4f7a'),
 ('white','לבן עם מסך זיכרון','רטרו','light','assistant','assistant','silk',20,'#f4f3ef #ffffff #e9e7e0 #e3e1da #2b2b2e #6f6d68 #e8641e #ffffff #2f8a4f #e8641e #9a978f #d0432b'),
 ('cube','קוביה סגולה','רטרו','dark','rubik','rubik','rubik',24,'#2b2466 #463ba6 #3a3092 #5b50c4 #f1efff #c9c3ff #2fae5a #ffffff #7cff9a #f2c94c #8f86d6 #ff6b6b'),
 ('jewel','שחור וירוק אבן חן','רטרו','dark','heebo','heebo','exo',14,'#0c0d0c #151714 #1d201c #2a2f28 #e6ebe4 #8a9487 #5fbf3f #0b2205 #7ae35a #e6c84a #555c52 #ff6b5a'),
 ('channels','ערוצים לבנים','רטרו','light','varela','assistant','varela',18,'#eef1f4 #ffffff #e3e8ed #c9d1d9 #3a4048 #6b737d #2aa3d9 #ffffff #2aa3d9 #e0a030 #9aa2ac #e0566a'),
 ('piano','שחור פסנתר וגל','רטרו','dark','assistant','assistant','assistant',6,'#0a0a0c #141418 #1c1c22 #26262c #f2f2f5 #8b8b95 #a8b6e0 #0a0a0c #ffffff #e6c06a #5c5c66 #ff7b7b'),
 ('wheel','גלגל פקודות','חדשני','dark','rubik','rubik','chakra',16,'#070a14 #0b1324 #101a2e #24395c #e9f3ff #8ea3c2 #3ef0ff #04131a #45ffa0 #ffcf4a #5a6f90 #ff6b85'),
 ('holo','קלף הולוגרפי','חדשני','dark','secular','heebo','orbitron',18,'#0d0b16 #1c1638 #1a1534 #3a2f6e #f4f1ff #a79bd6 #ff7ad9 #1c1638 #b1ff7a #ffd76a #7f74ad #ff8aa0'),
 ('radar','רדאר רשת','חדשני','dark','assistant','assistant','rajdhani',12,'#04100f #08201d #072623 #145a50 #dcfff7 #6fbfaf #39e6c4 #04100f #39e6c4 #ffb547 #2d7c70 #ff7a6b'),
 ('loadout','מסך בחירת דמות','חדשני','dark','karantina','heebo','bebas',4,'#170f2e #24163f #2a1d55 #3a2c6e #fff6ee #b9a8ff #ff6a2b #170f2e #4dffb0 #ffd25e #8e80c4 #ff8a8a'),
 ('core','ליבת אנרגיה','חדשני','dark','rubik','rubik','exo',22,'#05060c #0f1c4a #0a1230 #2d4aa8 #eaf0ff #7f8fb8 #7fb0ff #071030 #a8c6ff #ff8a3d #4a5a88 #ff8a3d'),
]
KEYS = 'bg surface sunken line ink muted accent accent-ink on busy off danger'.split()

css = ["/* Generated by tools/gen_themes.py — edit the table there, not this file. */"]
meta = []
for (tid, name, group, scheme, disp, body, data, radius, cols) in T:
    c = dict(zip(KEYS, cols.split()))
    v = ';'.join(f'--{k}:{c[k]}' for k in KEYS)
    css.append(f":root[data-skin=\"{tid}\"]{{{v};--font-display:{D[disp]};--font-body:{D[body]};--font-data:{D[data]};"
               f"--r-lg:{radius}px;--r-md:{max(0, round(radius*0.7))}px;--r-sm:{max(0, round(radius*0.5))}px;color-scheme:{scheme}}}")
    meta.append({'id': tid, 'name': name, 'group': group, 'scheme': scheme, 'swatch': [c['bg'], c['surface'], c['accent'], c['on']]})

# Studio follows the phone's light/dark setting.
css.append("@media (prefers-color-scheme: dark){:root[data-skin=\"studio\"]{--bg:#0c0e14;--surface:#151924;--sunken:#0f121a;--line:#252a38;"
           "--ink:#eceef5;--muted:#949bb0;--accent:#7d97ff;--accent-ink:#0c0e14;--on:#41d08f;--busy:#f2b54d;--off:#697086;--danger:#f2686f;color-scheme:dark}}")

here = os.path.dirname(os.path.abspath(__file__))
www = os.path.join(here, '..', 'www')
extra = open(os.path.join(here, 'themes-extra.css'), encoding='utf-8').read()
open(os.path.join(www, 'themes.css'), 'w', encoding='utf-8').write('\n'.join(css) + '\n\n' + extra)
open(os.path.join(www, 'themes.js'), 'w', encoding='utf-8').write(
    '/* Generated by tools/gen_themes.py */\nwindow.PCR_THEMES = ' + json.dumps(meta, ensure_ascii=False) + ';\n')
print(len(T), 'themes')
