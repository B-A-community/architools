"""Builds docs/TESTING.md from a live test run.

Usage: python test/bridge.py test/live_tools.rb > run.txt
       python test/make_report.py run.txt

The first table maps every one of the 40 tools of 1001bit Pro (author's
user guide, revision 9-Jul-10) to ArchiTools tools and to the live checks
that cover it. A function is green only if every listed check passed.
"""
import io, sys, datetime

# (№, функция 1001bit, инструменты ArchiTools, подстроки имён проверок)
MAP = [
    (1, 'Point on face', 'Точка на грани', ['point on face']),
    (2, 'Divide', 'Деление ребра', ['divide split/points', 'divide: from middle']),
    (3, 'Align selected entities', 'Выровнять по 3 точкам', ['align by 3 points', 'pick tool']),
    (4, 'Perpendicular line', 'Перпендикуляр; Перпендикуляр к грани', ['perpendicular to edge and to face', 'normal line']),
    (5, 'Face on plane', 'Грань на плоскости', ['face on plane']),
    (6, 'Best fit face', 'Грань по неплоским точкам', ['best fit face', 'pick tool']),
    (7, 'Extrude along sloping curve path', 'Профиль по пути', ['extrude profile along sloped path']),
    (8, 'Extrude maintaining taper', 'Выдавить с сужением', ['extrude keeping taper']),
    (9, 'Revolved surface', 'Тело вращения', ['revolve: cylinder', 'revolve with scale']),
    (10, 'Move vertex', 'Переместить вершину', ['move vertex']),
    (11, 'Fillet', 'Скругление', ['fillet two edges', 'fillet keeps face', 'fillet chain']),
    (12, 'Chamfer', 'Фаска', ['chamfer 100']),
    (13, 'Extend', 'Продлить до пересечения', ['extend two edges', 'extend edges to face']),
    (14, 'Offset', 'Смещение рёбер', ['offset closed loop', 'open chain direction']),
    (15, 'Horizontal slice selected face', 'Горизонтальный разрез', ['horizontal slice']),
    (16, 'Slope selected edges', 'Уклон рёбер', ['slope 45', 'open chain direction', 'slope edges: keep original']),
    (17, 'Linear array', 'Линейный массив', ['linear array']),
    (18, 'Rectangular array', 'Прямоугольный массив', ['rectangular array']),
    (19, 'Polar array', 'Круговой массив', ['polar array']),
    (20, 'Path array', 'Массив по пути', ['path array: count', 'path array: max spacing']),
    (21, 'Vertical walls (1, 2 cavity, 3 studs, profile, slope)', 'Стена по линиям',
     ['wall open L', 'wall closed loop', 'wall kinds', 'own section']),
    (22, 'Opening on wall (incl. custom profile)', 'Проём в стене',
     ['opening by size', 'opening from drawn', 'opening arch', 'opening round']),
    (23, 'Horizontal grooves', 'Горизонтальные бороздки', ['horizontal grooves']),
    (24, 'Columns (5 types)', 'Колонны', ['columns: all six', 'columns at cpoints']),
    (25, 'Foundations (pad, strip)', 'Столбчатый и ленточный фундамент', ['pad footing at points']),
    (26, 'Staircases', 'Прямая, с площадкой, с забежными, винтовая лестница; ограждение',
     ['straight stairs slab', 'straight stairs solid', 'straight stairs treads', 'straight stairs with railings',
      'landing stairs l_left', 'landing stairs u_right', 'winder stairs', 'spiral stairs', 'railing infill']),
    (27, 'Escalator', 'Эскалатор', ['escalator']),
    (28, 'Window frame', 'Окно', ['window 2x2', 'window: casement']),
    (29, 'Door frame', 'Дверь', ['door double']),
    (30, 'Divided panels', 'Разбивка на панели', ['panel divider']),
    (31, 'Perforated screens', 'Перфорированный экран', ['perforated screen: 27', 'perforated screen: rotated']),
    (32, 'Louvers (7 profiles)', 'Ламели', ['louvres horizontal', 'louvres vertical', 'louvres: all seven']),
    (33, 'Profiles on plane', 'Балки по рёбрам; Сечение по пути', ['beam profile', 'profile sweep: tube']),
    (34, 'Joists', 'Балки перекрытия', ['joists 4000x3000', 'joists with I-beam']),
    (35, 'Roof rafters, battens/purlins, fascia', 'Стропила; Прогоны / обрешётка',
     ['roof hip + rafters', 'rafters with fascia']),
    (36, 'Hip roof (any shape, holes)', 'Кровля',
     ['roof hip over hexagon', 'roof hip over trapezoid', 'roof hip over L-shape', 'roof gable with thickness', 'roof shed']),
    (37, 'Metal deck', 'Профнастил', ['metal deck']),
    (38, 'Cut and fill site', 'Площадка: срезка и подсыпка', ['cut and fill']),
    (39, 'Trace boundaries', 'Граница на рельефе', ['trace boundary']),
    (40, 'Contour lines', 'Горизонтали', ['contour lines']),
]

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
for no, orig, ours, needles in MAP:
    hits = [r for r in rows if any(n in r[1] for n in needles)]
    missing = [n for n in needles if not any(n in r[1] for r in rows)]
    ok = bool(hits) and not missing and all(r[0] == 'PASS' for r in hits)
    func_ok += ok
    func_rows.append(f"| {no} | {orig} | {ours} | {len(hits)} | {'✅' if ok else '❌'} |")

out = ['# Проверка инструментов', '',
       'Протокол живого прогона `python test/bridge.py test/live_tools.rb` в SketchUp 2024 (24.0.484). '
       'Пересобирается командой `python test/make_report.py <вывод прогона>`.', '',
       f'Дата: {datetime.date.today().isoformat()} · проверок: **{passed} из {total}** · '
       f'функций 1001bit: **{func_ok} из {len(MAP)}**', '',
       '## 40 функций 1001bit Tools', '',
       'Список — из оглавления руководства автора ([1001bit Pro User Guide, ред. 9-Jul-10]'
       '(https://www.1001bit.com/pro/1001bit_pro_user_guide.pdf)). Функция зелёная, только если прошли '
       'все её проверки.', '',
       '| № | 1001bit | ArchiTools | Проверок | |', '|---|---|---|---|---|'] + func_rows + [
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
print(f'checks {passed}/{total}, 1001bit functions {func_ok}/{len(MAP)} -> docs/TESTING.md')
