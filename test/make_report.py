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

# (команда JHS Powerbar 2020.1 из jhs_pb.strings, автор, ArchiTools, проверки)
JHS = [
    ('pb00', 'AMS Smooth Dialog', 'A. Synytsia', 'Сглаживание рёбер — по углу', ['jhs soften']),
    ('pb01', 'AMS Smooth Run', 'A. Synytsia', 'Сглаживание рёбер — последние настройки', ['jhs soften']),
    ('pb02', 'Smooze Lite', 'M. Noblet', 'Сглаживание рёбер — по углу', ['jhs soften']),
    ('pb03', 'Smooze Hard', 'M. Noblet', 'Сглаживание рёбер — сгладить все', ['jhs soften']),
    ('pb04', 'UnSmooze', 'M. Noblet', 'Сглаживание рёбер — снять', ['jhs soften']),
    ('pb05', 'AMS Smooth to Quadrants', 'A. Synytsia', 'Сглаживание рёбер — четырёхугольники', ['jhs soften']),
    ('pb06', 'Upright Extruder', 'J. Eneroth', 'Профиль по пути (отвесно)', ['extrude profile along sloped path', 'jhs upright']),
    ('pb07', 'Upright Extruder Input', 'J. Eneroth', 'Профиль по пути — вертикаль по вектору', ['jhs upright']),
    ('pb08', 'Upright Extruder Edge', 'J. Eneroth', 'Профиль по пути — вертикаль по ребру', ['jhs upright']),
    ('pb09', 'Face Finder', 'Ithil', 'Найти грани', ['jhs face finder']),
    ('pb10', 'Offset Edge', 'SD Mitch', 'Смещение рёбер — направляющими', ['jhs offset as guides']),
    ('pb11', 'Extrude Lines', 'D. Bur', 'Выдавить линии', ['jhs extrude lines']),
    ('pb12', 'Extrude Along Path', 'R. Wilson', 'Профиль по пути', ['extrude profile along sloped path']),
    ('pb13', 'Pipe Along Path', 'TIG', 'Сечение по пути (труба)', ['profile sweep: tube']),
    ('pb14', 'Lines to Tube', 'D. Bur', 'Линии в трубы', ['jhs extrude lines and lines to tubes']),
    ('pb15', 'Copy Along Path', 'R. Wilson', 'Массив по пути', ['path array: count', 'path array: max spacing']),
    ('pb16', 'Copy Comps Path', 'SD Mitch', 'Массив по пути — бусы', ['chord string']),
    ('pb17', 'Center on Red', 'Pixero', 'Выровнять объекты — к общему центру по X', ['bounds align']),
    ('pb18', 'Center on Green', 'Pixero', 'Выровнять объекты — к общему центру по Y', ['bounds align', 'align objects: min']),
    ('pb19', 'Center on Blue', 'Pixero', 'Выровнять объекты — к общему центру по Z', ['bounds align', 'align objects: min']),
    ('pb20', 'Comps to Grid Array', 'SD Mitch', 'Прямоугольный массив — сетка и шахматный', ['rectangular array', 'staggered grid']),
    ('pb21', 'Drop at Intersection', 'R. Wilson', 'Опустить — на поверхность', ['jhs drop']),
    ('pb22', 'Drop at Level', 'R. Wilson', 'Опустить — на отметку', ['jhs drop']),
    ('pb23', 'Mirror', 'TIG', 'Зеркало', ['jhs mirror', 'mirror finishes by Enter']),
    ('pb24', 'SuperWeld', 'TIG', 'Сварить рёбра', ['jhs weld']),
    ('pb25', 'Explode All Curves', 'CadFather', 'Распустить кривые', ['jhs weld']),
    ('pb26', 'Equalise Curve Segments', 'SD Mitch', 'Равные сегменты', ['jhs weld']),
    ('pb27', 'JS Mover', 'Pixero', 'Сдвинуть на вектор', ['move by vector']),
    ('pb28', 'Align Tool', 'D. Bur', 'Выровнять по 3 точкам', ['align by 3 points']),
    ('pb29', '3D Rotate', 'J. Eneroth', 'Поворот вокруг оси', ['jhs rotate about axis']),
    ('pb30', 'Rotix', 'TBD', 'Rotix — поворот стрелками', ['jhs rotix']),
    ('pb31', 'Random Scale', 'TBD', 'Случайный масштаб и поворот', ['jhs random']),
    ('pb32', 'Random Rotate', 'TBD', 'Случайный масштаб и поворот', ['jhs random']),
    ('pb33', 'Random Scale & Rotate', 'TBD', 'Случайный масштаб и поворот', ['jhs random']),
    ('pb34', 'Proxify Components', 'SD Mitch', 'Прокси компонентов', ['jhs proxify']),
    ('pb35', 'Composwapper', 'R. Wilson', 'Заменить компоненты', ['jhs composwapper']),
    ('pb36', 'SketchyFFD 3x3x3', 'mindsightstudios', 'FFD — решётка 3×3×3', ['jhs FFD: lattice']),
    ('pb36b', 'SketchyFFD 4x4x4', 'mindsightstudios', 'FFD — решётка 4×4×4', ['4x4x4']),
    ('pb37', 'SketchyFFD Input Box', 'mindsightstudios', 'FFD — своя решётка', ['jhs ffd custom lattice']),
    ('pb38', 'SketchyFFD Lock Edges', 'mindsightstudios', 'FFD — зафиксировать рёбра', ['jhs FFD: lattice', 'jhs ffd custom lattice']),
    ('pb39', 'SketchyFFD Unlock Edges', 'mindsightstudios', 'FFD — снять фиксацию', ['jhs ffd custom lattice']),
    ('pb40', 'Mesh Maker', 'SD Mitch', 'Сетка на грани — по ячейке', ['jhs mesh maker']),
    ('pb41', 'SubDivide Face', 'SD Mitch', 'Сетка на грани — по делениям', ['jhs mesh maker']),
    ('pb42', 'Split Up', 'TIG', 'Split Up', ['jhs split up']),
    ('pb43', 'C-Points at Vertex', 'TIG', 'Точки в вершины', ['jhs c-points']),
    ('pb44', 'Connect Cpoints with Line', 'SD Mitch', 'Соединить точки', ['jhs c-points']),
    ('pb45', 'Comps to C-Points', 'ThomThom', 'Компонент в точки', ['jhs c-points']),
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

jhs_rows = []
jhs_ok = 0
for code, name, author, ours, needles in JHS:
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
