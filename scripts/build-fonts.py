"""Static font instances for the app, cut from the website's fonts.

  Inter (variable, opsz 14) -> SKYInter-Regular/Medium/SemiBold/Bold
  Cinzel (variable)         -> SKYCinzel-Bold (hero "SKY" word mark)
  SKY Cormorant             -> copied (Spanish display headings)
  Noto Serif CJK SC/TC      -> subset to the Chinese UI strings (display headings)

  python scripts/build-fonts.py [path/to/apps/web]
"""
import json, os, sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
web = sys.argv[1] if len(sys.argv) > 1 else 'D:/SKY/development/apps/web'
out = os.path.join(root, 'SKY', 'Resources', 'Fonts')
os.makedirs(out, exist_ok=True)


def rename(font, family, style, ps):
    name = font['name']
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25):
            name.removeNames(nameID=rec.nameID)
    full = f'{family} {style}'
    for nid, value in ((1, family), (2, style), (3, ps), (4, full), (6, ps)):
        name.setName(value, nid, 3, 1, 0x409)
        name.setName(value, nid, 1, 0, 0)
    for table in ('STAT',):
        if table in font:
            del font[table]


inter = os.path.join(web, 'public/fonts/Inter-Variable.ttf')
for style, weight in (('Regular', 400), ('Medium', 500), ('SemiBold', 600), ('Bold', 700)):
    f = instancer.instantiateVariableFont(TTFont(inter), {'wght': weight, 'opsz': 14})
    f['OS/2'].usWeightClass = weight
    rename(f, 'SKY Inter', style, f'SKYInter-{style}')
    f.save(os.path.join(out, f'SKYInter-{style}.ttf'))

cinzel = instancer.instantiateVariableFont(TTFont(os.path.join(web, 'public/share-posters/Cinzel.ttf')), {'wght': 700})
cinzel['OS/2'].usWeightClass = 700
rename(cinzel, 'SKY Cinzel', 'Bold', 'SKYCinzel-Bold')
cinzel.save(os.path.join(out, 'SKYCinzel-Bold.ttf'))

cormorant = TTFont(os.path.join(web, 'public/fonts/SKYCormorant-Regular.ttf'))
cormorant.save(os.path.join(out, 'SKYCormorant-Regular.ttf'))

# Chinese display face: only the characters the UI strings use.
data = json.load(open(os.path.join(root, 'SKY/Resources/strings.json'), encoding='utf8'))
for idx, tag in ((3, 'SC'), (4, 'TC')):
    text = ''.join(v[idx] for v in data['strings'].values() if len(v) > idx)
    text += 'SKY0123456789·，。：；！？（）「」VIP%'
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    font = TTFont(os.path.join(web, f'public/fonts/NotoSerifCJK{tag.lower()}-Regular.otf'))
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    rename(font, f'SKY Song {tag}', 'Regular', f'SKYSong{tag}-Regular')
    font.save(os.path.join(out, f'SKYSong{tag}-Regular.otf'))

for f in sorted(os.listdir(out)):
    print(f, os.path.getsize(os.path.join(out, f)))
