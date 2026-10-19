# Проверка инструментов

Протокол живого прогона `python test/bridge.py test/live_tools.rb` в SketchUp 2024 (24.0.484). Пересобирается командой `python test/make_report.py <вывод прогона>`.

Дата: 2026-10-19 · проверок: **142 из 142** · функций 1001bit: **40 из 40**

## 40 функций 1001bit Tools

Список — из оглавления руководства автора ([1001bit Pro User Guide, ред. 9-Jul-10](https://www.1001bit.com/pro/1001bit_pro_user_guide.pdf)). Функция зелёная, только если прошли все её проверки.

| № | 1001bit | ArchiTools | Проверок | |
|---|---|---|---|---|
| 1 | Point on face | Точка на грани | 1 | ✅ |
| 2 | Divide | Деление ребра | 2 | ✅ |
| 3 | Align selected entities | Выровнять по 3 точкам | 2 | ✅ |
| 4 | Perpendicular line | Перпендикуляр; Перпендикуляр к грани | 2 | ✅ |
| 5 | Face on plane | Грань на плоскости | 1 | ✅ |
| 6 | Best fit face | Грань по неплоским точкам | 2 | ✅ |
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
| ✅ | one undo step per run | [[:wall, 3, 4, 3], [:louvres, 6, 7, 6], [:straight_stairs, 1, 2, 1]] |
| ✅ | refusals are clean | Выделите два ребра (или цепочку рёбер). |
| ✅ | every tool has a live check | 53 tools |
