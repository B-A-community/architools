"""Builds docs/TESTING.md from a live test run.

Usage: python test/bridge.py test/live_tools.rb > run.txt
       python test/make_report.py run.txt
"""
import io, sys, datetime

lines = [l.rstrip('\n') for l in io.open(sys.argv[1], encoding='utf-8')]
rows = []
for l in lines:
    if l[:4] in ('PASS', 'FAIL', 'ERR '):
        status, rest = l[:4].strip(), l[5:]
        name, _, info = rest.partition(' — ')
        rows.append((status, name.strip(), info.strip().replace('|', '/')))
total = len(rows)
passed = sum(1 for r in rows if r[0] == 'PASS')
out = ['# Проверка инструментов', '',
       'Протокол живого прогона `python test/bridge.py test/live_tools.rb` в SketchUp 2024 (24.0.484). '
       'Пересобирается командой `python test/make_report.py <вывод прогона>`.', '',
       f'Дата: {datetime.date.today().isoformat()} · итог: **{passed} из {total}**', '',
       'Что проверяется:', '',
       '- функциональные проверки — каждый из 33 инструментов строит то, что должен '
       '(объёмы, размеры, число элементов, замкнутость тел);',
       '- отказ на пустом выделении — каждый инструмент, которому нужно выделение, отказывает с '
       'понятной причиной и ничего не создаёт;',
       '- одна отмена — применение инструмента целиком снимается одним Ctrl+Z;',
       '- покрытие — тест падает, если у какого-то инструмента нет функциональной проверки.', '',
       'Офлайн: `ruby test/check_lang.rb` (словари ru = en, у всего есть подписи) и '
       '`ruby test/check_skeleton.rb` (прямой скелет кровли на шести контурах).', '',
       '| | Проверка | Результат |', '|---|---|---|']
for st, name, info in rows:
    mark = '✅' if st == 'PASS' else '❌'
    out.append(f'| {mark} | {name} | {info} |')
io.open('docs/TESTING.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f'{passed}/{total} -> docs/TESTING.md')
