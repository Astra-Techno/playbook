"""Regenerates lib/widgets/sport_icon_svgs.g.dart from assets/sports/*.svg.

Run from kocourt_shared:  python tool/gen_sport_icons.py
The SVG files are the source for both the apps and the Vue site.
"""
import pathlib

root = pathlib.Path(__file__).resolve().parents[1]
lines = ['// GENERATED from assets/sports/*.svg. Edit the SVG files, then regenerate.', '',
         '/// Raw Matchday sport icons; colours are var(--tone), var(--tint), var(--surface).',
         'const sportIconSvgs = <String, String>{']
for svg in sorted((root / 'assets' / 'sports').glob('*.svg')):
    lines.append(f"  '{svg.stem}': r'''{svg.read_text(encoding='utf-8').strip()}''',")
lines += ['};', '']
(root / 'lib' / 'widgets' / 'sport_icon_svgs.g.dart').write_text('\n'.join(lines), encoding='utf-8', newline='\n')
print('ok')
