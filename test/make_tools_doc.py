"""Описание всех инструментов из каталога самого плагина.

1. Выгрузить каталог из живого SketchUp (подписи берутся из lang.rb):
   python test/bridge.py test/export_catalog.rb   -> %TEMP%/architools_catalog.json
2. python test/make_tools_doc.py [путь к json]

Пишет docs/TOOLS.md (подробно: что делает, клики, параметры по умолчанию,
варианты, аналоги) и раздел «Все инструменты» в README.md между метками
<!-- tools:begin --> и <!-- tools:end -->.
"""
import io, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from originals import MAP, JHS  # noqa: E402

src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get('TEMP', '.'), 'architools_catalog.json')
catalog = json.load(io.open(src, encoding='utf-8'))
version = '?'
for line in io.open(os.path.join(ROOT, 'src', 'architools', 'constants.rb'), encoding='utf-8'):
    if 'VERSION' in line and "'" in line:
        version = line.split("'")[1]

# Аналоги по id инструмента.
analogs = {}
for no, orig, _ours, ids, _checks in MAP:
    for i in ids:
        analogs.setdefault(i, {'1001bit': [], 'jhs': []})['1001bit'].append(f'№{no} {orig}')
for code, name, _author, _ours, ids, _checks in JHS:
    for i in ids:
        analogs.setdefault(i, {'1001bit': [], 'jhs': []})['jhs'].append(name)


def analog_text(tid):
    a = analogs.get(tid)
    if not a:
        return 'собственный инструмент ArchiTools'
    parts = []
    if a['1001bit']:
        parts.append('1001bit: ' + ', '.join(dict.fromkeys(a['1001bit'])))
    if a['jhs']:
        parts.append('JHS Powerbar: ' + ', '.join(dict.fromkeys(a['jhs'])))
    return '; '.join(parts)


def value_text(p):
    v = p.get('default')
    if p['type'] == 'bool':
        return 'да' if v in (True, 'true') else 'нет'
    if p['type'] == 'choice':
        for key, label in p.get('choices') or []:
            if str(key) == str(v):
                return label
    if p['type'] == 'angle':
        return f'{v}°'
    return str(v).replace('~ ', '')


def param_label(p):
    return p['label'][:1].upper() + p['label'][1:] if p['type'] == 'bool' else p['label']


total = sum(len(c['tools']) for c in catalog)

# --- docs/TOOLS.md ---------------------------------------------------------
out = [f'# Инструменты ArchiTools {version}', '',
       f'Все {total} инструментов в {len(catalog)} категориях — подписи и параметры взяты из самого плагина '
       '(пересобирается `python test/make_tools_doc.py`). Для каждого: что выделить и что он делает, '
       'нужны ли клики в модели, параметры со значениями по умолчанию и аналог в 1001bit Tools или JHS Powerbar.', '',
       'Общее для всех: панель «ArchiTools» → категория → инструмент → параметры → «Применить». Каждое '
       'применение — один шаг отмены (Ctrl+Z). Длины вводятся в единицах модели. Последние значения '
       'параметров запоминаются для каждого инструмента.', '',
       '## Содержание', '']
for c in catalog:
    out.append(f"- [{c['label']}](#{c['id']}) — {len(c['tools'])}: " + ', '.join(t['label'] for t in c['tools']))
out.append('')
for c in catalog:
    out += [f'<a id="{c["id"]}"></a>', '', f"## {c['label']}", '']
    for t in c['tools']:
        out += [f"### {t['label']}", '', t['hint'], '']
        if t.get('picks'):
            out += ['**Клики в модели:** после «Применить» укажите точки (подсказка — в строке состояния). '
                    'Enter или двойной клик — готово, Backspace — убрать точку, Esc — отмена.', '']
        out += [f"**Аналог:** {analog_text(t['id'])}", '']
        if t['params']:
            out += ['| Параметр | По умолчанию | Варианты |', '|---|---|---|']
            for p in t['params']:
                variants = ', '.join(label for _k, label in (p.get('choices') or []))
                out.append(f"| {param_label(p)} | {value_text(p)} | {variants} |")
            out.append('')
        else:
            out += ['Параметров нет — всё решает выделение.', '']
io.open(os.path.join(ROOT, 'docs', 'TOOLS.md'), 'w', encoding='utf-8').write('\n'.join(out).rstrip() + '\n')

# --- README: раздел «Все инструменты» ---------------------------------------
sec = ['<!-- tools:begin -->', f'## Все инструменты ({total})', '',
       'Полный список; параметры каждого инструмента, значения по умолчанию и варианты — в '
       '[docs/TOOLS.md](docs/TOOLS.md). Отметка ⌖ — инструмент работает по кликам в модели.', '']
for c in catalog:
    sec += [f"### {c['label']} ({len(c['tools'])})", '']
    for t in c['tools']:
        mark = ' ⌖' if t.get('picks') else ''
        sec.append(f"- **{t['label']}**{mark} — {t['hint']} *Аналог: {analog_text(t['id'])}.*")
    sec.append('')
sec.append('<!-- tools:end -->')
readme_path = os.path.join(ROOT, 'README.md')
readme = io.open(readme_path, encoding='utf-8').read()
block = '\n'.join(sec)
if '<!-- tools:begin -->' in readme:
    a = readme.index('<!-- tools:begin -->')
    b = readme.index('<!-- tools:end -->') + len('<!-- tools:end -->')
    readme = readme[:a] + block + readme[b:]
else:
    anchor = '## Управление'
    assert anchor in readme
    readme = readme.replace(anchor, block + '\n\n' + anchor, 1)
io.open(readme_path, 'w', encoding='utf-8').write(readme)
print(f'{total} tools, {len(catalog)} categories -> docs/TOOLS.md, README.md')
