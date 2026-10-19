# Проверка инструментов

Протокол живого прогона `python test/bridge.py test/live_tools.rb` в SketchUp 2024 (24.0.484). Пересобирается командой `python test/make_report.py <вывод прогона>`.

Дата: 2026-10-19 · проверок: **183 из 183** · функций 1001bit: **40 из 40** · команд JHS Powerbar: **47 из 47**

## 40 функций 1001bit Tools

Список — из оглавления руководства автора ([1001bit Pro User Guide, ред. 9-Jul-10](https://www.1001bit.com/pro/1001bit_pro_user_guide.pdf)). Функция зелёная, только если прошли все её проверки.

| № | 1001bit | ArchiTools | Проверок | |
|---|---|---|---|---|
| 1 | Point on face | Точка на грани | 1 | ✅ |
| 2 | Divide | Деление ребра | 2 | ✅ |
| 3 | Align selected entities | Выровнять по 3 точкам | 3 | ✅ |
| 4 | Perpendicular line | Перпендикуляр; Перпендикуляр к грани | 2 | ✅ |
| 5 | Face on plane | Грань на плоскости | 1 | ✅ |
| 6 | Best fit face | Грань по неплоским точкам | 3 | ✅ |
| 7 | Extrude along sloping curve path | Профиль по пути | 1 | ✅ |
| 8 | Extrude maintaining taper | Выдавить с сужением | 1 | ✅ |
| 9 | Revolved surface | Тело вращения | 2 | ✅ |
| 10 | Move vertex | Переместить вершину | 1 | ✅ |
| 11 | Fillet | Скругление | 3 | ✅ |
| 12 | Chamfer | Фаска | 1 | ✅ |
| 13 | Extend | Продлить до пересечения | 2 | ✅ |
| 14 | Offset | Смещение рёбер | 2 | ✅ |
| 15 | Horizontal slice selected face | Горизонтальный разрез | 1 | ✅ |
| 16 | Slope selected edges | Уклон рёбер | 3 | ✅ |
| 17 | Linear array | Линейный массив | 1 | ✅ |
| 18 | Rectangular array | Прямоугольный массив | 1 | ✅ |
| 19 | Polar array | Круговой массив | 1 | ✅ |
| 20 | Path array | Массив по пути | 2 | ✅ |
| 21 | Vertical walls (1, 2 cavity, 3 studs, profile, slope) | Стена по линиям | 4 | ✅ |
| 22 | Opening on wall (incl. custom profile) | Проём в стене | 5 | ✅ |
| 23 | Horizontal grooves | Горизонтальные бороздки | 1 | ✅ |
| 24 | Columns (5 types) | Колонны | 2 | ✅ |
| 25 | Foundations (pad, strip) | Столбчатый и ленточный фундамент | 1 | ✅ |
| 26 | Staircases | Прямая, с площадкой, с забежными, винтовая лестница; ограждение | 12 | ✅ |
| 27 | Escalator | Эскалатор | 1 | ✅ |
| 28 | Window frame | Окно | 2 | ✅ |
| 29 | Door frame | Дверь | 1 | ✅ |
| 30 | Divided panels | Разбивка на панели | 1 | ✅ |
| 31 | Perforated screens | Перфорированный экран | 2 | ✅ |
| 32 | Louvers (7 profiles) | Ламели | 3 | ✅ |
| 33 | Profiles on plane | Балки по рёбрам; Сечение по пути | 10 | ✅ |
| 34 | Joists | Балки перекрытия | 2 | ✅ |
| 35 | Roof rafters, battens/purlins, fascia | Стропила; Прогоны / обрешётка | 2 | ✅ |
| 36 | Hip roof (any shape, holes) | Кровля | 5 | ✅ |
| 37 | Metal deck | Профнастил | 1 | ✅ |
| 38 | Cut and fill site | Площадка: срезка и подсыпка | 1 | ✅ |
| 39 | Trace boundaries | Граница на рельефе | 1 | ✅ |
| 40 | Contour lines | Горизонтали | 1 | ✅ |

## 47 команд JHS Powerbar

Список и авторы — из файлов самого плагина JHS Powerbar 2020.1 (`jhs_pb.strings`, сборка CadFather). Код не копировался: поведение написано заново. Команда зелёная, только если прошли все её проверки.

| Код | JHS Powerbar | Автор | ArchiTools | Проверок | |
|---|---|---|---|---|---|
| pb00 | AMS Smooth Dialog | A. Synytsia | Сглаживание рёбер — по углу | 1 | ✅ |
| pb01 | AMS Smooth Run | A. Synytsia | Сглаживание рёбер — последние настройки | 1 | ✅ |
| pb02 | Smooze Lite | M. Noblet | Сглаживание рёбер — по углу | 1 | ✅ |
| pb03 | Smooze Hard | M. Noblet | Сглаживание рёбер — сгладить все | 1 | ✅ |
| pb04 | UnSmooze | M. Noblet | Сглаживание рёбер — снять | 1 | ✅ |
| pb05 | AMS Smooth to Quadrants | A. Synytsia | Сглаживание рёбер — четырёхугольники | 1 | ✅ |
| pb06 | Upright Extruder | J. Eneroth | Профиль по пути (отвесно) | 2 | ✅ |
| pb07 | Upright Extruder Input | J. Eneroth | Профиль по пути — вертикаль по вектору | 1 | ✅ |
| pb08 | Upright Extruder Edge | J. Eneroth | Профиль по пути — вертикаль по ребру | 1 | ✅ |
| pb09 | Face Finder | Ithil | Найти грани | 1 | ✅ |
| pb10 | Offset Edge | SD Mitch | Смещение рёбер — направляющими | 1 | ✅ |
| pb11 | Extrude Lines | D. Bur | Выдавить линии | 1 | ✅ |
| pb12 | Extrude Along Path | R. Wilson | Профиль по пути | 1 | ✅ |
| pb13 | Pipe Along Path | TIG | Сечение по пути (труба) | 1 | ✅ |
| pb14 | Lines to Tube | D. Bur | Линии в трубы | 1 | ✅ |
| pb15 | Copy Along Path | R. Wilson | Массив по пути | 2 | ✅ |
| pb16 | Copy Comps Path | SD Mitch | Массив по пути — бусы | 1 | ✅ |
| pb17 | Center on Red | Pixero | Выровнять объекты — к общему центру по X | 1 | ✅ |
| pb18 | Center on Green | Pixero | Выровнять объекты — к общему центру по Y | 2 | ✅ |
| pb19 | Center on Blue | Pixero | Выровнять объекты — к общему центру по Z | 2 | ✅ |
| pb20 | Comps to Grid Array | SD Mitch | Прямоугольный массив — сетка и шахматный | 2 | ✅ |
| pb21 | Drop at Intersection | R. Wilson | Опустить — на поверхность | 1 | ✅ |
| pb22 | Drop at Level | R. Wilson | Опустить — на отметку | 1 | ✅ |
| pb23 | Mirror | TIG | Зеркало | 2 | ✅ |
| pb24 | SuperWeld | TIG | Сварить рёбра | 1 | ✅ |
| pb25 | Explode All Curves | CadFather | Распустить кривые | 1 | ✅ |
| pb26 | Equalise Curve Segments | SD Mitch | Равные сегменты | 1 | ✅ |
| pb27 | JS Mover | Pixero | Сдвинуть на вектор | 1 | ✅ |
| pb28 | Align Tool | D. Bur | Выровнять по 3 точкам | 1 | ✅ |
| pb29 | 3D Rotate | J. Eneroth | Поворот вокруг оси | 1 | ✅ |
| pb30 | Rotix | TBD | Rotix — поворот стрелками | 1 | ✅ |
| pb31 | Random Scale | TBD | Случайный масштаб и поворот | 1 | ✅ |
| pb32 | Random Rotate | TBD | Случайный масштаб и поворот | 1 | ✅ |
| pb33 | Random Scale & Rotate | TBD | Случайный масштаб и поворот | 1 | ✅ |
| pb34 | Proxify Components | SD Mitch | Прокси компонентов | 1 | ✅ |
| pb35 | Composwapper | R. Wilson | Заменить компоненты | 1 | ✅ |
| pb36 | SketchyFFD 3x3x3 | mindsightstudios | FFD — решётка 3×3×3 | 1 | ✅ |
| pb36b | SketchyFFD 4x4x4 | mindsightstudios | FFD — решётка 4×4×4 | 1 | ✅ |
| pb37 | SketchyFFD Input Box | mindsightstudios | FFD — своя решётка | 1 | ✅ |
| pb38 | SketchyFFD Lock Edges | mindsightstudios | FFD — зафиксировать рёбра | 2 | ✅ |
| pb39 | SketchyFFD Unlock Edges | mindsightstudios | FFD — снять фиксацию | 1 | ✅ |
| pb40 | Mesh Maker | SD Mitch | Сетка на грани — по ячейке | 1 | ✅ |
| pb41 | SubDivide Face | SD Mitch | Сетка на грани — по делениям | 1 | ✅ |
| pb42 | Split Up | TIG | Split Up | 1 | ✅ |
| pb43 | C-Points at Vertex | TIG | Точки в вершины | 1 | ✅ |
| pb44 | Connect Cpoints with Line | SD Mitch | Соединить точки | 1 | ✅ |
| pb45 | Comps to C-Points | ThomThom | Компонент в точки | 1 | ✅ |

## Что проверяется

- функциональные проверки — инструмент строит то, что должен: объёмы, размеры, число элементов, замкнутость тел, плоскость граней;
- отказ на пустом выделении — инструмент, которому нужно выделение, отказывает с понятной причиной и ничего не создаёт;
- одна отмена — применение снимается одним Ctrl+Z;
- однозначность — результат не зависит от того, в каком порядке SketchUp хранит рёбра цепочки;
- клики — инструменты с указанием точек проверяются тем же путём, по которому идут клики;
- покрытие — тест падает, если у какого-то инструмента нет функциональной проверки.

Офлайн: `ruby test/check_lang.rb` (словари ru = en, у всего есть подписи) и `ruby test/check_skeleton.rb` (прямой скелет кровли на 16 контурах, включая Г, Т, П, крест, звезду и дворы: площадь скатов и плоскость каждого ската).

## Все проверки

| | Проверка | Результат |
|---|---|---|
| ✅ | fillet two edges r200 | Скруглено. |
| ✅ | fillet keeps face | Скруглено. faces=1 area=794970 |
| ✅ | fillet chain 2 corners | Скруглены углы цепочек: 1. curves=2 |
| ✅ | chamfer 100 | [141.4, 900.0, 900.0] |
| ✅ | extend two edges to corner | Рёбра сведены в угол. |
| ✅ | extend edges to face | Продлено рёбер: 1. |
| ✅ | divide split/points | edges=4 cpoints=3 |
| ✅ | center point of circle | Поставлено точек: 1. |
| ✅ | offset closed loop outward | Смещено цепочек: 1. x=[-100, 1100] |
| ✅ | slope 45 deg | Уклон задан цепочкам: 1. z=[0, 2000] |
| ✅ | normal line | Построено перпендикуляров: 1. |
| ✅ | extrude two faces | Выдавлено граней: 2. z=[-300, 0] |
| ✅ | shift faces | Сдвинуто граней: 1. |
| ✅ | shell 100 on plate | Оболочка построена из граней: 1. vol=100000000 |
| ✅ | shell on bent surface (two faces) | Оболочка построена из граней: 2. manifold=true |
| ✅ | extrude profile along sloped path | Профиль проведён по пути. manifold=true zmax=1200 |
| ✅ | polar array 6 around cpoint | Создано копий: 5. y=[-866, -866, 0, 0, 866, 866] |
| ✅ | linear array total | [0, 1000, 2000, 3000, 4000] |
| ✅ | wall open L | vol=3.75 m3 |
| ✅ | wall closed loop | vol=10.5 m3 |
| ✅ | opening by size + lining | Пробито проёмов: 1. dv=0.4725 |
| ✅ | opening from drawn rectangle | Пробито проёмов: 1. v=1.512 |
| ✅ | window 2x2 | Построено окон: 1. |
| ✅ | door double | Построено дверей: 1. |
| ✅ | louvres horizontal | Ламелей: 10. |
| ✅ | louvres vertical on triangle | Ламелей: 8. |
| ✅ | panel divider 3x2 | Разбито граней: 1. faces=6 |
| ✅ | straight stairs slab | Подступёнок ~ 176 mm, проступь 280 mm, длина марша 4480 mm; 2h + b = 633 мм. Кликните, чтобы поставить. 4480x1200x3000 |
| ✅ | straight stairs solid | Подступёнок ~ 176 mm, проступь 280 mm, длина марша 4480 mm; 2h + b = 633 мм. Кликните, чтобы поставить. 4480x1200x3000 |
| ✅ | straight stairs treads | Подступёнок ~ 176 mm, проступь 280 mm, длина марша 4480 mm; 2h + b = 633 мм. Кликните, чтобы поставить. 4500x1200x2960 |
| ✅ | spiral stairs | Подступёнок ~ 188 mm. Кликните, чтобы поставить. |
| ✅ | joists 4000x3000 @600 | Элементов: 8. n=8 lens=[3000] |
| ✅ | roof hip + rafters + purlins | Кровля построена, высота конька ~ 2021 mm. / Элементов: 18. / Элементов: 6. |
| ✅ | roof gable with thickness | Кровля построена, высота конька ~ 2311 mm. |
| ✅ | roof shed | Кровля построена, высота конька ~ 529 mm. |
| ✅ | columns at cpoints + footing | Поставлено колонн: 3. |
| ✅ | beams on edges | Построено балок: 1. |
| ✅ | beam profile rect | Построено балок: 1. vol=240.0 exp=240.0 дм³ |
| ✅ | beam profile round | Построено балок: 1. vol=124.23 exp=124.23 дм³ |
| ✅ | beam profile i_beam | Построено балок: 1. vol=34.8 exp=34.8 дм³ |
| ✅ | beam profile channel | Построено балок: 1. vol=34.8 exp=34.8 дм³ |
| ✅ | beam profile angle | Построено балок: 1. vol=23.4 exp=23.4 дм³ |
| ✅ | beam profile tee | Построено балок: 1. vol=23.4 exp=23.4 дм³ |
| ✅ | beam profile rhs | Построено балок: 1. vol=38.4 exp=38.4 дм³ |
| ✅ | beam profile chs | Построено балок: 1. vol=23.6 exp=23.6 дм³ |
| ✅ | profile sweep: tube along L path and closed loop | Сечение проведено по цепочкам: 2. manifold=[true, true] |
| ✅ | profile sweep refuses wall thicker than tube | Стенка трубы толще половины сечения. |
| ✅ | opening arch + lining | Пробито проёмов: 1. dv=0.4505 exp=0.4505 м³ |
| ✅ | opening round + lining | Пробито проёмов: 1. dv=0.1242 exp=0.1242 м³ |
| ✅ | opening arch refuses when too low | Арка не помещается: высота проёма меньше половины ширины. |
| ✅ | railing infill balusters | Ограждений: 1. posts=6 top=900 |
| ✅ | railing infill rails | Ограждений: 1. posts=6 top=900 |
| ✅ | railing infill glass | Ограждений: 1. posts=6 top=900 |
| ✅ | railing infill none | Ограждений: 1. posts=6 top=900 |
| ✅ | straight stairs with railings | Подступёнок ~ 176 mm, проступь 280 mm, длина марша 4480 mm; 2h + b = 633 мм. Кликните, чтобы поставить. railings=2 |
| ✅ | landing stairs l_left | Подступёнок ~ 167 mm, марши 9 + 9. Кликните, чтобы поставить. plan=3365x3365 exp≈3340x3340 top=3000 |
| ✅ | landing stairs l_right | Подступёнок ~ 167 mm, марши 9 + 9. Кликните, чтобы поставить. plan=3365x3365 exp≈3340x3340 top=3000 |
| ✅ | landing stairs u_left | Подступёнок ~ 167 mm, марши 9 + 9. Кликните, чтобы поставить. plan=3365x2300 exp≈3340x2300 top=3000 |
| ✅ | landing stairs u_right | Подступёнок ~ 167 mm, марши 9 + 9. Кликните, чтобы поставить. plan=3365x2300 exp≈3340x2300 top=3000 |
| ✅ | landing stairs refuses short flight | В каждом марше должно быть хотя бы два подступёнка. |
| ✅ | escalator | Длина в плане ~ 9855 mm. Кликните, чтобы поставить. run=9855 exp≈9855 top=5520 |
| ✅ | roof hip over hexagon | Кровля построена, высота конька 2500 mm. h=2500 exp=2500 faces=6 |
| ✅ | roof hip over trapezoid with overhang and thickness | Кровля построена, высота конька ~ 1352 mm. manifold=true |
| ✅ | align objects: min, center, distribute | y=[0, 0, 0] x=[100, 1600, 3100] |
| ✅ | divide: from middle, max length, midpoints | mid=[200, 500, 800] max=[250, 250, 250, 250] midpoints=[125, 375, 625, 875] |
| ✅ | point on face: wall light 600 / 1800 | Точка поставлена. [2400, 0, 1800] |
| ✅ | perpendicular to edge and to face | Перпендикуляр длиной 800 mm. / Перпендикуляр длиной 2000 mm. [[[500, 0, 0], [2000, 0, 0]], [[500, 0, 0], [500, 800, 0]], [[700, 700, 1000], [700, 700, 3000]]] |
| ✅ | face on plane: outline projected onto tilted plane | Грань построена, вершин: 4. |
| ✅ | best fit face from non-coplanar points | Грань построена, наибольшее отклонение точки ~ 8 mm. |
| ✅ | move vertex stretches the box | Вершина сдвинута на ~ 866 mm. |
| ✅ | align by 3 points onto a slope | x=4900 z=1000 |
| ✅ | extrude keeping taper (frustum) | Выдавлено граней: 1. z=1500 top=500 |
| ✅ | revolve: cylinder surface and closed torus | area=3132629 exp=3132629 torus=true |
| ✅ | revolve with scale and rise (horn) | Тело вращения: 48 граней. |
| ✅ | horizontal slice: 3 cuts on a wall | Разрезов: 2. faces=3 |
| ✅ | horizontal grooves recess and ribs | Бороздок: 5. dv=3000000 exp=3000000 |
| ✅ | rectangular array 3×2×2 | Создано копий: 11. last=[2000, 500, 3000] |
| ✅ | path array: count along L path, turned | Создано копий: 5. [[0, 0, 200], [1000, 0, 200], [2000, 0, 200], [2000, 1000, 40], [2000, 2000, 40]] |
| ✅ | path array: max spacing on closed loop | Создано копий: 11. groups=12 |
| ✅ | window: casement, sliding, rebated, casing, positions | [[:casement, true], [:sliding, true], [:rebated, true], [:casing, true], [:back, true], [:middle, true], [:front, true]] |
| ✅ | wall kinds: cavity and stud partition | cavity vol=2.64 studs=8 |
| ✅ | wall: own section from face and follow slope | top=2100 |
| ✅ | columns: all six types | [[:rect, true], [:round, true], [:ellipse, true], [:capital, true], [:tuscan, true], [:tuscan_round, true]] |
| ✅ | pad footing at points, strip footing along L | pad=true strip v=3.6 exp=3.6 |
| ✅ | joists with I-beam profile, rafters with fascia | joists=true fascia=1 |
| ✅ | winder stairs left/right and mono stringer | [[:left, true], [:right, true], [:mono, true]] |
| ✅ | roof hip over L-shape and courtyard | L: faces=6 h=1155 exp=1155; двор: Кровля построена, высота конька ~ 1328 mm. manifold=true |
| ✅ | roof gable refuses non-rectangle | Нужна одна горизонтальная прямоугольная грань. |
| ✅ | perforated screen: 27 round holes | Отверстий: 27. v=35867019 exp=35867019 |
| ✅ | perforated screen: rotated rect holes in a triangle | Отверстий: 77. |
| ✅ | metal deck: trapezoid, corrugated, box | [[:trapezoid, true], [:corrugated, true], [:box, true]] |
| ✅ | cut and fill platform on a slope | Площадка на отметке 1000 mm: срезка 3.2 м³, подсыпка 3.2 м³. zc=1000 far=1900 |
| ✅ | trace boundary onto terrain | Граница перенесена, точек: 23. points=22 |
| ✅ | contour lines on plane and closed loops on a hill | plane=[20000, 20000, 20000, 20000] hill=Горизонталей: 2 (отметок 3). closed=true |
| ✅ | pick tool: clicks lead to the same run | prompt=куда встанет точка 2 start=Выделите группы или компоненты. |
| ✅ | open chain direction is fixed: slope and offset | z={[2000, 500]=>250, [2000, 0]=>200, [0, 0]=>0} y=[0, 100] |
| ✅ | louvres: all seven blade profiles, positions, erase face | [[:flat, true], [:sheet, true], [:oval, true], [:round, true], [:rhs, true], [:channel, true], [:airfoil, true], [:middle, true], [:back, true]] |
| ✅ | slope edges: keep original, slope a copy | edges=4 flat=2 top=600 |
| ✅ | jhs soften: angle, all, none, quadrants | angle=16 none=0 all=48 quads=2 |
| ✅ | jhs weld, explode, equal segments | welded=1 lens=[500] |
| ✅ | jhs face finder in group and loose | Найдено граней: 2. |
| ✅ | jhs extrude lines and lines to tubes | area=7500000 parts=5 |
| ✅ | jhs drop below and to level | a=867 b=1200 |
| ✅ | jhs c-points at vertices, connect, component to points | cps=4 line=4 [[0, 0, 0], [0, 1000, 0], [2000, 0, 0], [2000, 1000, 0]] |
| ✅ | jhs mirror: 2-point plan plane, 3-point plane, copy, loose geometry | xs=[[-1500, -1000], [1000, 1500]] z=[1800, 2000] edges=[-500, -100, 100, 500] |
| ✅ | jhs rotate about axis and move by vector | c=[-250, 1250] |
| ✅ | jhs random scale and rotate is reproducible | heights=[173, 282, 443, 300, 231, 354] |
| ✅ | jhs rotix: arrow keys rotate, axis change, flip | after right=[200, 1000] axis=1 |
| ✅ | jhs proxify toggle and restore all | proxy=Proxy · ATLive heavy#5 both=["Proxy · ATLive heavy#5", "Proxy · ATLive heavy#5"] back=["ATLive heavy#5", "ATLive heavy#5"] |
| ✅ | jhs composwapper: one sample replaces many | Заменено экземпляров: 3 → ATLive chair B#5. |
| ✅ | jhs mesh maker: cells, rotated guides, divisions | cells=32 guides=13 div=15 |
| ✅ | jhs split up: 4×4 and 3×3 | n=16 box=96 manifold=true |
| ✅ | jhs FFD: lattice moves the shape, lock keeps edges, finish bakes | moved=true low=0 n=1 |
| ✅ | jhs ffd lock/unlock refusal and 4x4x4 | Откройте группу и выделите рёбра, которые нужно зафиксировать или освободить. |
| ✅ | jhs upright extruder: vector and by edge | Профиль проведён по пути. / Профиль проведён по пути. |
| ✅ | jhs offset as guides, chord string, bounds align, staggered grid | guides=2 chords=[500] xs=[1600] row2=[500, 1500, 2500] |
| ✅ | jhs pick tool: mirror finishes by Enter after 2 points | x=[-900, -500] |
| ✅ | jhs ffd custom lattice, lock and unlock by the tool | points=12 locked=true |
| ✅ | empty selection refused: fillet | Выделите два ребра (или цепочку рёбер). |
| ✅ | empty selection refused: chamfer | Выделите два ребра (или цепочку рёбер). |
| ✅ | empty selection refused: extend_edges | Выделите два ребра — или рёбра и одну грань. |
| ✅ | empty selection refused: divide | Выделите рёбра. |
| ✅ | empty selection refused: center_point | Выделите дуги, окружности или грани. |
| ✅ | empty selection refused: offset_edges | Выделите рёбра. |
| ✅ | empty selection refused: slope_edges | Выделите открытую цепочку рёбер. |
| ✅ | empty selection refused: normal_line | Выделите грани. |
| ✅ | empty selection refused: point_on_face | Выделите одну грань. |
| ✅ | empty selection refused: align_3pt | Выделите группы или компоненты. |
| ✅ | empty selection refused: extrude_faces | Выделите грани. |
| ✅ | empty selection refused: shift_faces | Выделите грани. |
| ✅ | empty selection refused: shell | Выделите грани. |
| ✅ | empty selection refused: extrude_path | Выделите одну грань-профиль и одну цепочку рёбер-путь. |
| ✅ | empty selection refused: polar_array | Выделите группы или компоненты. |
| ✅ | empty selection refused: linear_array | Выделите группы или компоненты. |
| ✅ | empty selection refused: align_objects | Выделите хотя бы две группы или компонента. |
| ✅ | empty selection refused: extrude_taper | Выделите грани. |
| ✅ | empty selection refused: revolve | Выделите одну цепочку рёбер — профиль. |
| ✅ | empty selection refused: horizontal_slice | Выделите негоризонтальные грани. |
| ✅ | empty selection refused: horizontal_grooves | Выделите негоризонтальные грани. |
| ✅ | empty selection refused: rectangular_array | Выделите группы или компоненты. |
| ✅ | empty selection refused: path_array | Выделите группы или компоненты и одну цепочку рёбер — путь. |
| ✅ | empty selection refused: wall | Выделите рёбра. |
| ✅ | empty selection refused: opening | Выделите грань стены. |
| ✅ | empty selection refused: window | Выделите прямоугольную грань проёма или грань стены с прямоугольными проёмами. |
| ✅ | empty selection refused: door | Выделите прямоугольную грань проёма или грань стены с прямоугольными проёмами. |
| ✅ | empty selection refused: louvres | Выделите грани. |
| ✅ | empty selection refused: panel_divider | Выделите грани. |
| ✅ | empty selection refused: perforated_screen | Выделите грани. |
| ✅ | empty selection refused: metal_deck | Выделите грани. |
| ✅ | empty selection refused: railing | Выделите рёбра. |
| ✅ | empty selection refused: joists | Выделите грани. |
| ✅ | empty selection refused: rafters | Выделите грани. |
| ✅ | empty selection refused: purlins | Выделите грани. |
| ✅ | empty selection refused: roof | Нужна одна горизонтальная грань. |
| ✅ | empty selection refused: strip_footing | Выделите рёбра. |
| ✅ | empty selection refused: beams | Выделите рёбра. |
| ✅ | empty selection refused: profile_sweep | Выделите рёбра. |
| ✅ | empty selection refused: cut_fill | Выделите рельеф — группу или компонент с поверхностью. |
| ✅ | empty selection refused: trace_boundary | Выделите рельеф — группу или компонент с поверхностью. |
| ✅ | empty selection refused: soften_edges | Выделите рёбра, грани, группы или компоненты. |
| ✅ | empty selection refused: weld_edges | Нужна цепочка хотя бы из двух соединённых рёбер. |
| ✅ | empty selection refused: explode_curves | В выделении нет кривых. |
| ✅ | empty selection refused: equalize_curve | Выделите рёбра. |
| ✅ | empty selection refused: face_finder | Выделите рёбра, грани, группы или компоненты. |
| ✅ | empty selection refused: extrude_lines | Выделите рёбра. |
| ✅ | empty selection refused: lines_to_tubes | Выделите рёбра. |
| ✅ | empty selection refused: drop | Выделите группы или компоненты. |
| ✅ | empty selection refused: cpoints_at_vertices | Выделите рёбра. |
| ✅ | empty selection refused: connect_cpoints | Выделите хотя бы две точки-направляющие. |
| ✅ | empty selection refused: comps_to_cpoints | Выделите одну группу или компонент и точки-направляющие. |
| ✅ | empty selection refused: mirror | Выделите объекты или геометрию. |
| ✅ | empty selection refused: rotate_3d | Выделите объекты или геометрию. |
| ✅ | empty selection refused: random_transform | Выделите группы или компоненты. |
| ✅ | empty selection refused: move_by | Выделите объекты или геометрию. |
| ✅ | empty selection refused: rotix | Выделите группы или компоненты. |
| ✅ | empty selection refused: proxify | Выделите компоненты. |
| ✅ | empty selection refused: composwapper | Выделите экземпляр-образец и экземпляры другого компонента. |
| ✅ | empty selection refused: mesh_maker | Выделите грани. |
| ✅ | empty selection refused: split_up | Выделите четырёхугольные грани (без дыр). |
| ✅ | empty selection refused: ffd | Выделите одну группу или компонент. |
| ✅ | one undo step per run | [[:wall, 3, 4, 3], [:louvres, 6, 7, 6], [:straight_stairs, 1, 2, 1]] |
| ✅ | refusals are clean | Выделите два ребра (или цепочку рёбер). |
| ✅ | every tool has a live check | 74 tools |
