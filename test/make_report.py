"""Builds docs/TESTING.md from a live test run.

Usage: python test/bridge.py test/live_tools.rb > run.txt
       python test/make_report.py run.txt

The first table maps every one of the 40 tools of 1001bit Pro (author's
user guide, revision 9-Jul-10) to ArchiTools tools and to the live checks
that cover it. A function is green only if every listed check passed.
"""
import io, sys, datetime

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from originals import MAP, JHS  # noqa: E402

lines = [l.rstrip('\n') for l in io.open(sys.argv[1], encoding='utf-8')]
rows = []
for l in lines:
    if l[:4] in ('PASS', 'FAIL', 'ERR '):
        status, rest = l[:4].strip(), l[5:]
        name, _, info = rest.partition(' — ')
        rows.append((status, name.strip(), info.strip().replace('|', '/')))
total = len(rows)
passed = sum(1 for r in rows if r[0] == 'PASS')

func_rows = []
func_ok = 0
for no, orig, ours, _ids, needles in MAP:
    hits = [r for r in rows if any(n in r[1] for n in needles)]
    missing = [n for n in needles if not any(n in r[1] for r in rows)]
    ok = bool(hits) and not missing and all(r[0] == 'PASS' for r in hits)
    func_ok += ok
    func_rows.append(f"| {no} | {orig} | {ours} | {len(hits)} | {'✅' if ok else '❌'} |")

jhs_rows = []
jhs_ok = 0
for code, name, author, ours, _ids, needles in JHS:
    hits = [r for r in rows if any(n in r[1] for n in needles)]
    missing = [n for n in needles if not any(n in r[1] for r in rows)]
    ok = bool(hits) and not missing and all(r[0] == 'PASS' for r in hits)
    jhs_ok += ok
    jhs_rows.append(f"| {code} | {name} | {author} | {ours} | {len(hits)} | {'✅' if ok else '❌'} |")

out = ['# Проверка инструментов', '',
       'Протокол живого прогона `python test/bridge.py test/live_tools.rb` в SketchUp 2024 (24.0.484). '
       'Пересобирается командой `python test/make_report.py <вывод прогона>`.', '',
       f'Дата: {datetime.date.today().isoformat()} · проверок: **{passed} из {total}** · '
       f'функций 1001bit: **{func_ok} из {len(MAP)}** · команд JHS Powerbar: **{jhs_ok} из {len(JHS)}**', '',
       '## 40 функций 1001bit Tools', '',
       'Список — из оглавления руководства автора ([1001bit Pro User Guide, ред. 9-Jul-10]'
       '(https://www.1001bit.com/pro/1001bit_pro_user_guide.pdf)). Функция зелёная, только если прошли '
       'все её проверки.', '',
       '| № | 1001bit | ArchiTools | Проверок | |', '|---|---|---|---|---|'] + func_rows + [
       '', '## 47 команд JHS Powerbar', '',
       'Список и авторы — из файлов самого плагина JHS Powerbar 2020.1 (`jhs_pb.strings`, сборка CadFather). '
       'Код не копировался: поведение написано заново. Команда зелёная, только если прошли все её проверки.', '',
       '| Код | JHS Powerbar | Автор | ArchiTools | Проверок | |', '|---|---|---|---|---|---|'] + jhs_rows + [
       '', '## Что проверяется', '',
       '- функциональные проверки — инструмент строит то, что должен: объёмы, размеры, число элементов, '
       'замкнутость тел, плоскость граней;',
       '- отказ на пустом выделении — инструмент, которому нужно выделение, отказывает с понятной причиной '
       'и ничего не создаёт;',
       '- одна отмена — применение снимается одним Ctrl+Z;',
       '- однозначность — результат не зависит от того, в каком порядке SketchUp хранит рёбра цепочки;',
       '- клики — инструменты с указанием точек проверяются тем же путём, по которому идут клики;',
       '- покрытие — тест падает, если у какого-то инструмента нет функциональной проверки.', '',
       'Офлайн: `ruby test/check_lang.rb` (словари ru = en, у всего есть подписи) и '
       '`ruby test/check_skeleton.rb` (прямой скелет кровли на 16 контурах, включая Г, Т, П, крест, '
       'звезду и дворы: площадь скатов и плоскость каждого ската).', '',
       '## Все проверки', '',
       '| | Проверка | Результат |', '|---|---|---|']
for st, name, info in rows:
    mark = '✅' if st == 'PASS' else '❌'
    out.append(f'| {mark} | {name} | {info} |')
io.open('docs/TESTING.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f'checks {passed}/{total}, 1001bit {func_ok}/{len(MAP)}, JHS {jhs_ok}/{len(JHS)} -> docs/TESTING.md')
