# Проверка инструментов

Протокол живого прогона `python test/bridge.py test/live_tools.rb` в SketchUp 2024 (24.0.484). Пересобирается командой `python test/make_report.py <вывод прогона>`.

Дата: 2026-10-19 · итог: **96 из 96**

Что проверяется:

- функциональные проверки — каждый из 33 инструментов строит то, что должен (объёмы, размеры, число элементов, замкнутость тел);
- отказ на пустом выделении — каждый инструмент, которому нужно выделение, отказывает с понятной причиной и ничего не создаёт;
- одна отмена — применение инструмента целиком снимается одним Ctrl+Z;
- покрытие — тест падает, если у какого-то инструмента нет функциональной проверки.

Офлайн: `ruby test/check_lang.rb` (словари ru = en, у всего есть подписи) и `ruby test/check_skeleton.rb` (прямой скелет кровли на шести контурах).

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
| ✅ | extrude profile along sloped path | Профиль проведён по пути. manifold=true zmax=1201 |
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
| ✅ | roof refuses concave outline | Контур невыпуклый. Вальма строится по выпуклому контуру; разбейте здание на выпуклые части. |
| ✅ | align objects: min, center, distribute | y=[0, 0, 0] x=[100, 1600, 3100] |
| ✅ | empty selection refused: fillet | Выделите два ребра (или цепочку рёбер). |
| ✅ | empty selection refused: chamfer | Выделите два ребра (или цепочку рёбер). |
| ✅ | empty selection refused: extend_edges | Выделите два ребра — или рёбра и одну грань. |
| ✅ | empty selection refused: divide | Выделите рёбра. |
| ✅ | empty selection refused: center_point | Выделите дуги, окружности или грани. |
| ✅ | empty selection refused: offset_edges | Выделите рёбра. |
| ✅ | empty selection refused: slope_edges | Выделите открытую цепочку рёбер. |
| ✅ | empty selection refused: normal_line | Выделите грани. |
| ✅ | empty selection refused: extrude_faces | Выделите грани. |
| ✅ | empty selection refused: shift_faces | Выделите грани. |
| ✅ | empty selection refused: shell | Выделите грани. |
| ✅ | empty selection refused: extrude_path | Выделите одну грань-профиль и одну цепочку рёбер-путь. |
| ✅ | empty selection refused: polar_array | Выделите группы или компоненты. |
| ✅ | empty selection refused: linear_array | Выделите группы или компоненты. |
| ✅ | empty selection refused: align_objects | Выделите хотя бы две группы или компонента. |
| ✅ | empty selection refused: wall | Выделите рёбра. |
| ✅ | empty selection refused: opening | Выделите грань стены. |
| ✅ | empty selection refused: window | Выделите прямоугольную грань проёма или грань стены с прямоугольными проёмами. |
| ✅ | empty selection refused: door | Выделите прямоугольную грань проёма или грань стены с прямоугольными проёмами. |
| ✅ | empty selection refused: louvres | Выделите грани. |
| ✅ | empty selection refused: panel_divider | Выделите грани. |
| ✅ | empty selection refused: railing | Выделите рёбра. |
| ✅ | empty selection refused: joists | Выделите грани. |
| ✅ | empty selection refused: rafters | Выделите грани. |
| ✅ | empty selection refused: purlins | Выделите грани. |
| ✅ | empty selection refused: roof | Нужна одна горизонтальная грань. |
| ✅ | empty selection refused: beams | Выделите рёбра. |
| ✅ | empty selection refused: profile_sweep | Выделите рёбра. |
| ✅ | one undo step per run | [[:wall, 3, 4, 3], [:louvres, 6, 7, 6], [:straight_stairs, 1, 2, 1]] |
| ✅ | refusals are clean | Выделите два ребра (или цепочку рёбер). |
| ✅ | every tool has a live check | 33 tools |
