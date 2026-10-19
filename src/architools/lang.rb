# Copyright 2026 B&A community
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Язык Ruby-части (меню, панель, сообщения, имена в модели) — как в RALNCS,
# area counter и PathCopy Advanced. tools\build_rbz.ps1 -Lang en подменяет
# строку LANG; оболочка окна берёт язык из html/i18n.js (там та же подмена).
# Подписи инструментов, параметров и режимов приходят в окно отсюда.

module BACommunity
  module ArchiTools
    LANG = 'ru'

    STRINGS = {
      'ru' => {
        ext_description: 'Архитектурные инструменты по мотивам 1001bit Tools: скругление и фаска рёбер, ' \
                         'продление, деление, уклон, оболочка, профиль по пути, массивы, стены, проёмы, ' \
                         'окна, двери, ламели, лестницы, эскалатор, ограждения, балки, стропила, кровля, колонны.',

        menu_panel: 'Панель ArchiTools',
        tip_panel:  'Панель ArchiTools',
        st_panel:   'Открыть панель инструментов ArchiTools',
        menu_about: 'О плагине…',
        title_about: 'О плагине ArchiTools',
        st_place:   'Кликните, чтобы поставить. Tab или ←/→ — поворот на 90°, Esc — отменить.',
        op_place:   'Расстановка',

        cat_edges:   'Рёбра',
        cat_modify:  'Правка',
        cat_walls:   'Стены и проёмы',
        cat_facade:  'Фасад',
        cat_stairs:  'Лестницы',
        cat_framing: 'Каркас и кровля',

        # --- инструменты: название и что выделить ---
        tool_fillet: 'Скругление',
        hint_fillet: 'Два ребра в одной плоскости — скругление угла между ними (радиус 0 — просто угол). ' \
                     'Цепочка из трёх и более рёбер — скругляются все её углы.',
        tool_chamfer: 'Фаска',
        hint_chamfer: 'Два ребра или цепочка рёбер. Второе расстояние 0 — фаска равносторонняя.',
        tool_extend_edges: 'Продлить до пересечения',
        hint_extend_edges: 'Два ребра — продлить или обрезать оба до точки пересечения. ' \
                           'Рёбра и одна грань — продлить рёбра до плоскости грани.',
        tool_divide: 'Деление ребра',
        hint_divide: 'Рёбра — разделить на равные части или по длине: разбить ребро или поставить точки.',
        tool_center_point: 'Точка центра',
        hint_center_point: 'Дуги и окружности — точка в центре; грани — точка в центре тяжести.',
        tool_offset_edges: 'Смещение рёбер',
        hint_offset_edges: 'Цепочки рёбер (не только контур грани). Замкнутый контур смещается наружу, ' \
                           '«в другую сторону» — внутрь.',
        tool_slope_edges: 'Уклон рёбер',
        hint_slope_edges: 'Открытая цепочка рёбер — поднять по уклону от нижнего конца: угол, 1:N или перепад высоты.',
        tool_normal_line: 'Перпендикуляр к грани',
        hint_normal_line: 'Грани — линия или направляющая по нормали из центра грани.',

        tool_extrude_faces: 'Выдавить грани',
        hint_extrude_faces: 'Несколько граней сразу — каждая выдавливается по своей нормали на одно расстояние.',
        tool_shift_faces: 'Сдвиг по нормали',
        hint_shift_faces: 'Грани — сдвинуть вершины по нормалям (вершины общих граней — по средней нормали).',
        tool_shell: 'Оболочка (толщина)',
        hint_shell: 'Грани поверхности — придать толщину: новая группа-тело со смещённой копией и торцами.',
        tool_extrude_path: 'Профиль по пути',
        hint_extrude_path: 'Одна грань-профиль и цепочка рёбер-путь. В отличие от Ведения профиль не ' \
                           'закручивается на наклонных участках — остаётся вертикальным.',
        tool_polar_array: 'Круговой массив',
        hint_polar_array: 'Группы или компоненты. Центр — выделенная точка-направляющая, иначе начало координат.',
        tool_linear_array: 'Линейный массив',
        hint_linear_array: 'Группы или компоненты — копии с шагом или на общую длину.',

        tool_wall: 'Стена по линиям',
        hint_wall: 'Рёбра плана (цепочки или замкнутые контуры) — стена заданной толщины и высоты.',
        tool_opening: 'Проём в стене',
        hint_opening: '«По размерам»: одна грань стены, проём прямоугольный, арочный или круглый. ' \
                      '«Выделенная грань»: прямоугольники, нарисованные на стене, — пробиваются насквозь.',
        tool_window: 'Окно',
        hint_window: 'Прямоугольная грань в проёме — или грань стены с прямоугольными проёмами-дырами: ' \
                     'окна встанут во все. Рама, импосты и стекло.',
        tool_door: 'Дверь',
        hint_door: 'Прямоугольная грань в проёме — или грань стены с проёмами-дырами. ' \
                   'Коробка и одно- или двупольное полотно.',

        tool_louvres: 'Ламели (жалюзи)',
        hint_louvres: 'Грань — горизонтальные или вертикальные ламели с шагом и наклоном, по контуру грани.',
        tool_panel_divider: 'Разбивка на панели',
        hint_panel_divider: 'Грань — сетка рамы рядов × столбцов, грань по желанию делится на панели.',

        tool_straight_stairs: 'Прямая лестница',
        hint_straight_stairs: 'Ничего выделять не нужно: марш строится и ставится кликом.',
        tool_spiral_stairs: 'Винтовая лестница',
        hint_spiral_stairs: 'Ничего выделять не нужно: лестница строится и ставится кликом.',

        tool_joists: 'Балки перекрытия',
        hint_joists: 'Грань перекрытия — ряд балок с шагом, обрезанных по контуру.',
        tool_rafters: 'Стропила',
        hint_rafters: 'Скат кровли (наклонная грань) — стропила вдоль ската под гранью.',
        tool_purlins: 'Прогоны / обрешётка',
        hint_purlins: 'Грань (обычно скат) — горизонтальные бруски с шагом.',
        tool_roof: 'Кровля',
        hint_roof: 'Одна горизонтальная грань. Прямоугольник — вальмовая, двускатная или односкатная; ' \
                   'любой выпуклый контур — вальмовая по прямому скелету.',
        tool_columns: 'Колонны',
        hint_columns: 'Точки-направляющие или рёбра (колонны в их вершинах). Без выделения — одна колонна кликом.',
        tool_beams: 'Балки по рёбрам',
        hint_beams: 'Рёбра — балка по каждому ребру: брус, круг, двутавр, швеллер, уголок, тавр, трубы.',

        # --- параметры ---
        p_radius: 'Радиус', p_segments: 'Сегментов дуги',
        p_distance1: 'Расстояние 1', p_distance2: 'Расстояние 2',
        p_by: 'Задать', p_divide_by: 'Делить', p_count: 'Частей', p_seg_length: 'Длина части', p_output: 'Результат',
        p_axis: 'Ось через центр', p_polar_array_axis: 'Ось вращения',
        p_distance: 'Расстояние', p_both_sides: 'в обе стороны', p_flip: 'в другую сторону',
        p_angle: 'Угол', p_slope_edges_angle: 'Уклон', p_louvres_angle: 'Наклон ламелей',
        p_spiral_stairs_angle: 'Угол поворота',
        p_gradient: 'Уклон 1 :', p_height: 'Высота', p_slope_edges_height: 'Перепад', p_reverse: 'начать с другого конца',
        p_length: 'Длина', p_copy: 'оставить исходную грань', p_thickness: 'Толщина',
        p_erase_source: 'удалить исходные грани', p_smooth: 'сгладить рёбра', p_erase_profile: 'удалить профиль',
        p_rotate_copies: 'поворачивать копии',
        p_dx: 'Шаг X', p_dy: 'Шаг Y', p_dz: 'Шаг Z', p_mode: 'Смещение задано',
        p_align: 'Привязка', p_source: 'Проём', p_width: 'Ширина', p_sill: 'Низ от края грани',
        p_position: 'По горизонтали', p_offset: 'Отступ', p_opening_offset: 'Отступ слева', p_louvres_offset: 'От грани',
        p_frame: 'коробка по откосам', p_frame_width: 'Ширина рамы', p_cols: 'Столбцов', p_rows: 'Рядов',
        p_frame_depth: 'Глубина рамы', p_mullion: 'Импост', p_inset: 'Утопить в проём', p_glass: 'стекло',
        p_leaves: 'Полотна', p_leaf_thickness: 'Толщина полотна', p_gap: 'Зазор',
        p_direction: 'Направление', p_blade_depth: 'Ширина ламели', p_blade_thickness: 'Толщина ламели',
        p_split_face: 'разделить грань на панели',
        p_type: 'Тип', p_rise: 'Высота подъёма', p_risers: 'Подступёнков', p_going: 'Проступь',
        p_waist: 'Толщина плиты', p_tread_thickness: 'Толщина ступени', p_nosing: 'Свес ступени',
        p_stringers: 'косоуры (для ступеней)', p_stringer_width: 'Ширина косоура', p_stringer_depth: 'Высота косоура',
        p_outer_radius: 'Наружный радиус', p_inner_radius: 'Радиус стойки', p_column: 'центральная стойка',
        p_spacing: 'Шаг', p_depth: 'Высота сечения', p_edge_members: 'крайние по контуру', p_side: 'Положение',
        p_joists_direction: 'Балки вдоль',
        p_pitch: 'Уклон', p_overhang: 'Свес', p_roof_thickness: 'Толщина (0 — без)',
        p_shape: 'Сечение', p_size_x: 'Размер X / Ø', p_size_y: 'Размер Y', p_columns_height: 'Высота',
        p_footing: 'фундамент под колонной', p_footing_size: 'Размер фундамента', p_footing_depth: 'Высота фундамента',

        # --- режимы ---
        c_count: 'на части', c_length: 'по длине', c_split: 'разбить ребро', c_points: 'поставить точки',
        c_angle: 'углом', c_gradient: '1 : N', c_height: 'перепадом',
        c_z: 'Z (вертикаль)', c_x: 'X', c_y: 'Y', c_step: 'шаг', c_total: 'на всю длину',
        c_center: 'по оси', c_left: 'слева / внутрь', c_right: 'справа / наружу',
        c_opening_center: 'по центру грани', c_offset: 'с отступом',
        c_size: 'по размерам', c_face: 'выделенная грань',
        c_single: 'одно', c_double: 'два',
        c_horizontal: 'горизонтальные', c_vertical: 'вертикальные',
        c_slab: 'по плите', c_solid: 'сплошная', c_treads: 'ступени на косоурах',
        c_ccw: 'против часовой', c_cw: 'по часовой',
        c_short: 'короткой стороны', c_long: 'длинной стороны',
        c_below: 'под гранью', c_above: 'над гранью',
        c_hip: 'вальмовая', c_gable: 'двускатная', c_shed: 'односкатная',
        c_rect: 'прямоугольное', c_round: 'круглое',
        c_top: 'верх по ребру', c_bottom: 'низ по ребру', c_beams_center: 'центр по ребру',
        c_edge: 'ребро', c_guide: 'направляющая',

        # --- выделение не подходит ---
        need_two_edges: 'Выделите два ребра (или цепочку рёбер).',
        need_chain: 'Нужна цепочка хотя бы из двух соединённых рёбер.',
        need_extend: 'Выделите два ребра — или рёбра и одну грань.',
        need_edges: 'Выделите рёбра.',
        need_arcs: 'Выделите дуги, окружности или грани.',
        need_open_chain: 'Выделите открытую цепочку рёбер.',
        need_faces: 'Выделите грани.',
        need_profile_path: 'Выделите одну грань-профиль и одну цепочку рёбер-путь.',
        need_objects: 'Выделите группы или компоненты.',
        need_wall_face: 'Выделите грань стены.',
        need_rect_face: 'Выделите прямоугольную грань проёма или грань стены с прямоугольными проёмами.',
        need_horizontal_rect: 'Нужна одна горизонтальная прямоугольная грань.',
        need_sloped_face: 'Стропила ставятся на наклонный скат — горизонтальная грань не подходит.',

        # --- ошибки ---
        err_spacing: 'Шаг должен быть больше нуля.',
        err_too_many: 'Получается слишком много элементов — проверьте шаг и количество.',
        err_face_failed: 'SketchUp не смог построить грань — проверьте, что контур плоский и не самопересекается.',
        err_internal: 'Не получилось:',
        err_parallel: 'Рёбра параллельны — угла между ними нет.',
        err_not_coplanar: 'Рёбра не лежат в одной плоскости.',
        err_radius_too_big: 'Радиус не помещается на рёбрах; наибольший — %{max}.',
        err_chamfer_too_big: 'Фаска длиннее ребра.',
        err_distance: 'Размер должен быть больше нуля.',
        err_no_hits: 'Ни одно ребро не пересекает плоскость грани.',
        err_vertical_chain: 'Цепочка вертикальная — уклон в плане задать не к чему.',
        err_no_back_face: 'Не нашлась задняя поверхность стены напротив грани — стена должна быть телом ' \
                          'с параллельными сторонами в том же контексте.',
        err_opening_outside: 'Проём не помещается в грань стены.',
        err_window_small: 'Рамы и импосты не помещаются в проём.',
        err_radius_order: 'Наружный радиус должен быть больше радиуса стойки.',

        # --- результат ---
        ok_fillet: 'Скруглено.', ok_fillet_chain: 'Скруглены углы цепочек: %{n}.',
        ok_chamfer: 'Фаска готова.', ok_extend: 'Рёбра сведены в угол.',
        ok_extend_face: 'Продлено рёбер: %{n}.', ok_divide: 'Разделено рёбер: %{n}.',
        ok_center: 'Поставлено точек: %{n}.', ok_offset: 'Смещено цепочек: %{n}.',
        ok_slope: 'Уклон задан цепочкам: %{n}.', ok_normal: 'Построено перпендикуляров: %{n}.',
        ok_extrude: 'Выдавлено граней: %{n}.', ok_shift: 'Сдвинуто граней: %{n}.',
        ok_shell: 'Оболочка построена из граней: %{n}.', ok_sweep: 'Профиль проведён по пути.',
        ok_array: 'Создано копий: %{n}.', ok_wall: 'Построено стен: %{n}.',
        ok_opening: 'Пробито проёмов: %{n}.', ok_window: 'Построено окон: %{n}.', ok_door: 'Построено дверей: %{n}.',
        ok_louvres: 'Ламелей: %{n}.', ok_panels: 'Разбито граней: %{n}.',
        ok_stairs: 'Подступёнок %{riser}, проступь %{going}, длина марша %{run}; 2h + b = %{rule} мм. ' \
                   'Кликните, чтобы поставить.',
        ok_spiral: 'Подступёнок %{riser}. Кликните, чтобы поставить.',
        ok_members: 'Элементов: %{n}.', ok_roof: 'Кровля построена, высота конька %{h}.',
        ok_column_place: 'Кликните, чтобы поставить колонну.', ok_columns: 'Поставлено колонн: %{n}.',
        ok_beams: 'Построено балок: %{n}.',

        # --- имена в модели ---
        name_shell: 'Оболочка', name_sweep: 'Профиль по пути', name_wall: 'Стена', name_lining: 'Коробка проёма',
        name_window: 'Окно', name_frame: 'Рама', name_mullion: 'Импост', name_glass: 'Стекло',
        name_door: 'Дверь', name_leaf: 'Полотно', name_louvres: 'Ламели', name_panels: 'Панели',
        name_stairs: 'Лестница', name_spiral: 'Винтовая лестница', name_tread: 'ступень', name_column: 'Колонна',
        name_joists: 'Балки перекрытия', name_rafters: 'Стропила', name_purlins: 'Прогоны', name_roof: 'Кровля',
        name_beam: 'Балка',

        # --- 0.2 ---
        tool_profile_sweep: 'Сечение по пути',
        hint_profile_sweep: 'Цепочки рёбер — провести по ним сечение из библиотеки: круг, труба, двутавр, ' \
                            'швеллер, уголок, тавр. Поручни, трубы, молдинги, металлокаркас.',
        tool_align_objects: 'Выровнять объекты',
        hint_align_objects: 'Несколько групп или компонентов — выровнять по краю или центру вдоль оси ' \
                            'либо распределить равномерно (крайние остаются на месте).',
        tool_railing: 'Ограждение по рёбрам',
        hint_railing: 'Цепочка рёбер по низу ограждения (по полу, по носкам ступеней) — стойки, поручень, ' \
                      'балясины, ригели или стекло.',
        tool_landing_stairs: 'Лестница с площадкой',
        hint_landing_stairs: 'Ничего выделять не нужно: два марша с площадкой, поворот 90° (Г) или 180° (П), ' \
                             'с ограждением. Ставится кликом.',
        tool_escalator: 'Эскалатор',
        hint_escalator: 'Ничего выделять не нужно: ступени 30° или 35°, площадки, фартуки, стеклянные ' \
                        'балюстрады и поручни. Ставится кликом.',

        p_profile: 'Сечение', p_web: 'Стенка', p_flange: 'Полка', p_opening_shape: 'Форма',
        p_beams_width: 'Ширина / Ø', p_profile_sweep_width: 'Ширина / Ø', p_opening_segments: 'Сегментов дуги',
        p_rail_height: 'Высота ограждения', p_post_spacing: 'Шаг стоек', p_post_size: 'Сечение стойки',
        p_handrail: 'Поручень Ø', p_infill: 'Заполнение', p_baluster_spacing: 'Шаг балясин', p_rails_count: 'Ригелей',
        p_lift: 'Поднять линию на', p_railing: 'ограждение', p_turn: 'Поворот', p_first_flight: 'Подступёнков в 1-м марше',
        p_landing_stairs_gap: 'Зазор между маршами', p_landing: 'Площадка', p_balustrade: 'Высота балюстрады',
        p_truss_depth: 'Высота фермы', p_reference: 'Относительно',
        p_align_objects_axis: 'Ось', p_align_objects_mode: 'Действие', p_escalator_angle: 'Угол',

        c_i_beam: 'двутавр', c_channel: 'швеллер', c_beams_angle: 'уголок', c_profile_sweep_angle: 'уголок',
        c_tee: 'тавр', c_rhs: 'труба прямоугольная', c_chs: 'труба круглая',
        c_profile_sweep_center: 'центр по линии', c_profile_sweep_top: 'верх по линии',
        c_profile_sweep_bottom: 'низ по линии',
        c_opening_rect: 'прямоугольный', c_arch: 'арочный', c_opening_round: 'круглый',
        c_balusters: 'балясины', c_rails: 'ригели', c_glass: 'стекло', c_none: 'без заполнения',
        c_l_left: 'Г, налево', c_l_right: 'Г, направо', c_u_left: 'П, налево', c_u_right: 'П, направо',
        c_a30: '30°', c_a35: '35°',
        c_min: 'по минимуму', c_max: 'по максимуму', c_align_objects_center: 'по центру',
        c_distribute: 'распределить равномерно', c_extreme: 'крайнего объекта', c_largest: 'самого большого',

        need_horizontal_face: 'Нужна одна горизонтальная грань.',
        need_two_objects: 'Выделите хотя бы две группы или компонента.',
        need_three_objects: 'Для распределения нужно хотя бы три объекта.',
        err_wall_thick: 'Стенка трубы толще половины сечения.',
        err_arch_low: 'Арка не помещается: высота проёма меньше половины ширины.',
        err_flight_short: 'В каждом марше должно быть хотя бы два подступёнка.',
        err_roof_concave: 'Контур невыпуклый. Вальма строится по выпуклому контуру; разбейте здание ' \
                          'на выпуклые части.',

        ok_profile_sweep: 'Сечение проведено по цепочкам: %{n}.',
        ok_railing: 'Ограждений: %{n}.',
        ok_landing: 'Подступёнок %{riser}, марши %{a} + %{b}. Кликните, чтобы поставить.',
        ok_escalator: 'Длина в плане %{run}. Кликните, чтобы поставить.',
        ok_align: 'Выровнено объектов: %{n}.',

        name_handrail: 'Поручень', name_railing: 'Ограждение', name_flight: 'Марш', name_landing: 'Площадка',
        name_steps: 'Ступени', name_landing_stairs: 'Лестница с площадкой', name_escalator: 'Эскалатор',

        # --- выделение в статусе панели ---
        sel_empty: 'Ничего не выделено',
        sel_edges: 'рёбер', sel_faces: 'граней', sel_objects: 'групп/компонентов', sel_cpoints: 'точек',
        sel_other: 'прочего'
      },

      'en' => {
        ext_description: 'Architectural toolkit inspired by 1001bit Tools: edge fillet and chamfer, extend, ' \
                         'divide, slope, shell, profile along path, arrays, walls, openings, windows, doors, ' \
                         'louvres, stairs, escalator, railings, joists, rafters, roofs, columns.',

        menu_panel: 'ArchiTools panel',
        tip_panel:  'ArchiTools panel',
        st_panel:   'Open the ArchiTools panel',
        menu_about: 'About…',
        title_about: 'About ArchiTools',
        st_place:   'Click to place. Tab or ←/→ rotates by 90°, Esc cancels.',
        op_place:   'Place',

        cat_edges:   'Edges',
        cat_modify:  'Modify',
        cat_walls:   'Walls & openings',
        cat_facade:  'Facade',
        cat_stairs:  'Stairs',
        cat_framing: 'Framing & roof',

        tool_fillet: 'Fillet',
        hint_fillet: 'Two coplanar edges — round the corner between them (radius 0 makes a sharp corner). ' \
                     'A chain of three or more edges — all its corners are rounded.',
        tool_chamfer: 'Chamfer',
        hint_chamfer: 'Two edges or a chain. Second distance 0 means an equal chamfer.',
        tool_extend_edges: 'Extend to intersection',
        hint_extend_edges: 'Two edges — extend or trim both to their intersection. ' \
                           'Edges plus one face — extend the edges to the face plane.',
        tool_divide: 'Divide edge',
        hint_divide: 'Edges — divide into equal parts or by length: split the edge or place points.',
        tool_center_point: 'Center point',
        hint_center_point: 'Arcs and circles — a point at the center; faces — a point at the centroid.',
        tool_offset_edges: 'Offset edges',
        hint_offset_edges: 'Edge chains (not just face loops). A closed loop is offset outward, ' \
                           '“other side” — inward.',
        tool_slope_edges: 'Slope edges',
        hint_slope_edges: 'An open edge chain — raise along a slope from its lower end: angle, 1:N or height difference.',
        tool_normal_line: 'Face normal',
        hint_normal_line: 'Faces — a line or guide along the normal from the face center.',

        tool_extrude_faces: 'Extrude faces',
        hint_extrude_faces: 'Several faces at once — each is pushed along its own normal by one distance.',
        tool_shift_faces: 'Shift along normal',
        hint_shift_faces: 'Faces — move vertices along normals (shared vertices use the average normal).',
        tool_shell: 'Shell (thicken)',
        hint_shell: 'Surface faces — give them thickness: a new solid group with an offset copy and side faces.',
        tool_extrude_path: 'Profile along path',
        hint_extrude_path: 'One profile face and one edge chain as the path. Unlike Follow Me the profile does ' \
                           'not twist on sloped segments — it stays upright.',
        tool_polar_array: 'Polar array',
        hint_polar_array: 'Groups or components. Center — a selected guide point, otherwise the origin.',
        tool_linear_array: 'Linear array',
        hint_linear_array: 'Groups or components — copies by step or over a total distance.',

        tool_wall: 'Wall from lines',
        hint_wall: 'Plan edges (chains or closed loops) — a wall of given thickness and height.',
        tool_opening: 'Wall opening',
        hint_opening: '“By size”: one wall face, a rectangular, arched or round opening. ' \
                      '“Selected face”: rectangles drawn on the wall are punched through.',
        tool_window: 'Window',
        hint_window: 'A rectangular face in the opening — or a wall face with rectangular holes: ' \
                     'a window goes into each. Frame, mullions and glass.',
        tool_door: 'Door',
        hint_door: 'A rectangular face in the opening — or a wall face with holes. ' \
                   'Frame and a single or double leaf.',

        tool_louvres: 'Louvres',
        hint_louvres: 'A face — horizontal or vertical blades with spacing and tilt, clipped to the face outline.',
        tool_panel_divider: 'Panel divider',
        hint_panel_divider: 'A face — a rows × columns frame grid, optionally splitting the face into panels.',

        tool_straight_stairs: 'Straight stairs',
        hint_straight_stairs: 'No selection needed: the flight is built and placed with a click.',
        tool_spiral_stairs: 'Spiral stairs',
        hint_spiral_stairs: 'No selection needed: the stair is built and placed with a click.',

        tool_joists: 'Floor joists',
        hint_joists: 'A floor face — a row of joists at a spacing, clipped to the outline.',
        tool_rafters: 'Rafters',
        hint_rafters: 'A roof slope (sloped face) — rafters down the slope under the face.',
        tool_purlins: 'Purlins / battens',
        hint_purlins: 'A face (usually a slope) — horizontal members at a spacing.',
        tool_roof: 'Roof',
        hint_roof: 'One horizontal face. A rectangle — hip, gable or shed; ' \
                   'any convex outline — a hip roof by straight skeleton.',
        tool_columns: 'Columns',
        hint_columns: 'Guide points or edges (columns at their vertices). Nothing selected — one column by click.',
        tool_beams: 'Beams on edges',
        hint_beams: 'Edges — a beam along each edge: rectangle, round, I-beam, channel, angle, tee, tubes.',

        p_radius: 'Radius', p_segments: 'Arc segments',
        p_distance1: 'Distance 1', p_distance2: 'Distance 2',
        p_by: 'Set by', p_divide_by: 'Divide', p_count: 'Parts', p_seg_length: 'Part length', p_output: 'Result',
        p_axis: 'axis through center', p_polar_array_axis: 'Rotation axis',
        p_distance: 'Distance', p_both_sides: 'both sides', p_flip: 'other side',
        p_angle: 'Angle', p_slope_edges_angle: 'Slope', p_louvres_angle: 'Blade tilt',
        p_spiral_stairs_angle: 'Turn angle',
        p_gradient: 'Gradient 1 :', p_height: 'Height', p_slope_edges_height: 'Rise', p_reverse: 'start from the other end',
        p_length: 'Length', p_copy: 'keep the original face', p_thickness: 'Thickness',
        p_erase_source: 'erase source faces', p_smooth: 'smooth edges', p_erase_profile: 'erase the profile',
        p_rotate_copies: 'rotate copies',
        p_dx: 'Step X', p_dy: 'Step Y', p_dz: 'Step Z', p_mode: 'Offset is',
        p_align: 'Alignment', p_source: 'Opening', p_width: 'Width', p_sill: 'Bottom from face edge',
        p_position: 'Horizontally', p_offset: 'Offset', p_opening_offset: 'Offset from left', p_louvres_offset: 'From face',
        p_frame: 'lining in reveals', p_frame_width: 'Frame width', p_cols: 'Columns', p_rows: 'Rows',
        p_frame_depth: 'Frame depth', p_mullion: 'Mullion', p_inset: 'Inset into opening', p_glass: 'glass',
        p_leaves: 'Leaves', p_leaf_thickness: 'Leaf thickness', p_gap: 'Gap',
        p_direction: 'Direction', p_blade_depth: 'Blade width', p_blade_thickness: 'Blade thickness',
        p_split_face: 'split the face into panels',
        p_type: 'Type', p_rise: 'Total rise', p_risers: 'Risers', p_going: 'Going',
        p_waist: 'Waist', p_tread_thickness: 'Tread thickness', p_nosing: 'Nosing',
        p_stringers: 'stringers (for treads)', p_stringer_width: 'Stringer width', p_stringer_depth: 'Stringer depth',
        p_outer_radius: 'Outer radius', p_inner_radius: 'Column radius', p_column: 'center column',
        p_spacing: 'Spacing', p_depth: 'Section depth', p_edge_members: 'members on the outline', p_side: 'Position',
        p_joists_direction: 'Joists along',
        p_pitch: 'Pitch', p_overhang: 'Overhang', p_roof_thickness: 'Thickness (0 — none)',
        p_shape: 'Section', p_size_x: 'Size X / Ø', p_size_y: 'Size Y', p_columns_height: 'Height',
        p_footing: 'footing under column', p_footing_size: 'Footing size', p_footing_depth: 'Footing depth',

        c_count: 'into parts', c_length: 'by length', c_split: 'split the edge', c_points: 'place points',
        c_angle: 'angle', c_gradient: '1 : N', c_height: 'height',
        c_z: 'Z (vertical)', c_x: 'X', c_y: 'Y', c_step: 'step', c_total: 'total',
        c_center: 'centered', c_left: 'left / inside', c_right: 'right / outside',
        c_opening_center: 'face center', c_offset: 'with offset',
        c_size: 'by size', c_face: 'selected face',
        c_single: 'single', c_double: 'double',
        c_horizontal: 'horizontal', c_vertical: 'vertical',
        c_slab: 'slab', c_solid: 'solid', c_treads: 'treads on stringers',
        c_ccw: 'counter-clockwise', c_cw: 'clockwise',
        c_short: 'short side', c_long: 'long side',
        c_below: 'below face', c_above: 'above face',
        c_hip: 'hip', c_gable: 'gable', c_shed: 'shed',
        c_rect: 'rectangular', c_round: 'round',
        c_top: 'top on edge', c_bottom: 'bottom on edge', c_beams_center: 'center on edge',
        c_edge: 'edge', c_guide: 'guide',

        need_two_edges: 'Select two edges (or an edge chain).',
        need_chain: 'Needs a chain of at least two connected edges.',
        need_extend: 'Select two edges — or edges and one face.',
        need_edges: 'Select edges.',
        need_arcs: 'Select arcs, circles or faces.',
        need_open_chain: 'Select an open edge chain.',
        need_faces: 'Select faces.',
        need_profile_path: 'Select one profile face and one edge chain as the path.',
        need_objects: 'Select groups or components.',
        need_wall_face: 'Select a wall face.',
        need_rect_face: 'Select a rectangular opening face or a wall face with rectangular openings.',
        need_horizontal_rect: 'Needs one horizontal rectangular face.',
        need_sloped_face: 'Rafters go on a sloped face — a horizontal face will not do.',

        err_spacing: 'Spacing must be greater than zero.',
        err_too_many: 'Too many elements — check the spacing and count.',
        err_face_failed: 'SketchUp could not build a face — check that the outline is planar and not self-intersecting.',
        err_internal: 'Failed:',
        err_parallel: 'The edges are parallel — there is no corner.',
        err_not_coplanar: 'The edges are not in one plane.',
        err_radius_too_big: 'The radius does not fit on the edges; the largest is %{max}.',
        err_chamfer_too_big: 'The chamfer is longer than the edge.',
        err_distance: 'Size must be greater than zero.',
        err_no_hits: 'No edge crosses the face plane.',
        err_vertical_chain: 'The chain is vertical — there is no plan length to slope.',
        err_no_back_face: 'No back face of the wall was found opposite the face — the wall must be a solid ' \
                          'with parallel sides in the same context.',
        err_opening_outside: 'The opening does not fit in the wall face.',
        err_window_small: 'Frames and mullions do not fit in the opening.',
        err_radius_order: 'The outer radius must be larger than the column radius.',

        ok_fillet: 'Filleted.', ok_fillet_chain: 'Chains filleted: %{n}.',
        ok_chamfer: 'Chamfer done.', ok_extend: 'Edges joined at the corner.',
        ok_extend_face: 'Edges extended: %{n}.', ok_divide: 'Edges divided: %{n}.',
        ok_center: 'Points placed: %{n}.', ok_offset: 'Chains offset: %{n}.',
        ok_slope: 'Chains sloped: %{n}.', ok_normal: 'Normals drawn: %{n}.',
        ok_extrude: 'Faces extruded: %{n}.', ok_shift: 'Faces shifted: %{n}.',
        ok_shell: 'Shell built from faces: %{n}.', ok_sweep: 'Profile swept along the path.',
        ok_array: 'Copies created: %{n}.', ok_wall: 'Walls built: %{n}.',
        ok_opening: 'Openings punched: %{n}.', ok_window: 'Windows built: %{n}.', ok_door: 'Doors built: %{n}.',
        ok_louvres: 'Blades: %{n}.', ok_panels: 'Faces divided: %{n}.',
        ok_stairs: 'Riser %{riser}, going %{going}, flight length %{run}; 2R + G = %{rule} mm. Click to place.',
        ok_spiral: 'Riser %{riser}. Click to place.',
        ok_members: 'Members: %{n}.', ok_roof: 'Roof built, ridge height %{h}.',
        ok_column_place: 'Click to place the column.', ok_columns: 'Columns placed: %{n}.',
        ok_beams: 'Beams built: %{n}.',

        name_shell: 'Shell', name_sweep: 'Profile along path', name_wall: 'Wall', name_lining: 'Opening lining',
        name_window: 'Window', name_frame: 'Frame', name_mullion: 'Mullion', name_glass: 'Glass',
        name_door: 'Door', name_leaf: 'Leaf', name_louvres: 'Louvres', name_panels: 'Panels',
        name_stairs: 'Stairs', name_spiral: 'Spiral stairs', name_tread: 'tread', name_column: 'Column',
        name_joists: 'Floor joists', name_rafters: 'Rafters', name_purlins: 'Purlins', name_roof: 'Roof',
        name_beam: 'Beam',

        tool_profile_sweep: 'Section along path',
        hint_profile_sweep: 'Edge chains — sweep a library section along them: round, tube, I-beam, channel, ' \
                            'angle, tee. Handrails, pipes, mouldings, steel framing.',
        tool_align_objects: 'Align objects',
        hint_align_objects: 'Several groups or components — align by edge or center along an axis, ' \
                            'or distribute evenly (the outermost stay in place).',
        tool_railing: 'Railing along edges',
        hint_railing: 'An edge chain along the bottom of the railing (floor, stair nosings) — posts, handrail, ' \
                      'balusters, rails or glass.',
        tool_landing_stairs: 'Stairs with landing',
        hint_landing_stairs: 'No selection needed: two flights with a landing, 90° (L) or 180° (U) turn, ' \
                             'with railings. Placed with a click.',
        tool_escalator: 'Escalator',
        hint_escalator: 'No selection needed: 30° or 35° steps, landings, skirts, glass balustrades and ' \
                        'handrails. Placed with a click.',

        p_profile: 'Section', p_web: 'Web', p_flange: 'Flange', p_opening_shape: 'Shape',
        p_beams_width: 'Width / Ø', p_profile_sweep_width: 'Width / Ø', p_opening_segments: 'Arc segments',
        p_rail_height: 'Railing height', p_post_spacing: 'Post spacing', p_post_size: 'Post size',
        p_handrail: 'Handrail Ø', p_infill: 'Infill', p_baluster_spacing: 'Baluster spacing', p_rails_count: 'Rails',
        p_lift: 'Lift the line by', p_railing: 'railing', p_turn: 'Turn', p_first_flight: 'Risers in 1st flight',
        p_landing_stairs_gap: 'Gap between flights', p_landing: 'Landing', p_balustrade: 'Balustrade height',
        p_truss_depth: 'Truss depth', p_reference: 'Relative to',
        p_align_objects_axis: 'Axis', p_align_objects_mode: 'Action', p_escalator_angle: 'Angle',

        c_i_beam: 'I-beam', c_channel: 'channel', c_beams_angle: 'angle', c_profile_sweep_angle: 'angle',
        c_tee: 'tee', c_rhs: 'rectangular tube', c_chs: 'round tube',
        c_profile_sweep_center: 'center on line', c_profile_sweep_top: 'top on line',
        c_profile_sweep_bottom: 'bottom on line',
        c_opening_rect: 'rectangular', c_arch: 'arched', c_opening_round: 'round',
        c_balusters: 'balusters', c_rails: 'rails', c_glass: 'glass', c_none: 'no infill',
        c_l_left: 'L, left', c_l_right: 'L, right', c_u_left: 'U, left', c_u_right: 'U, right',
        c_a30: '30°', c_a35: '35°',
        c_min: 'minimum', c_max: 'maximum', c_align_objects_center: 'center',
        c_distribute: 'distribute evenly', c_extreme: 'outermost object', c_largest: 'largest object',

        need_horizontal_face: 'Needs one horizontal face.',
        need_two_objects: 'Select at least two groups or components.',
        need_three_objects: 'Distributing needs at least three objects.',
        err_wall_thick: 'The tube wall is thicker than half the section.',
        err_arch_low: 'The arch does not fit: the opening is lower than half its width.',
        err_flight_short: 'Each flight needs at least two risers.',
        err_roof_concave: 'The outline is concave. A hip roof is built over a convex outline; split the ' \
                          'building into convex parts.',

        ok_profile_sweep: 'Section swept along chains: %{n}.',
        ok_railing: 'Railings: %{n}.',
        ok_landing: 'Riser %{riser}, flights %{a} + %{b}. Click to place.',
        ok_escalator: 'Plan length %{run}. Click to place.',
        ok_align: 'Objects aligned: %{n}.',

        name_handrail: 'Handrail', name_railing: 'Railing', name_flight: 'Flight', name_landing: 'Landing',
        name_steps: 'Steps', name_landing_stairs: 'Stairs with landing', name_escalator: 'Escalator',

        sel_empty: 'Nothing selected',
        sel_edges: 'edges', sel_faces: 'faces', sel_objects: 'groups/components', sel_cpoints: 'points',
        sel_other: 'other'
      }
    }.freeze

    def self.t(key, **vars)
      table = STRINGS[LANG] || STRINGS['ru']
      text = table[key] || STRINGS['ru'][key] || key.to_s
      vars.empty? ? text : format(text, **vars)
    end

    # Подпись параметра или режима: сначала своя у инструмента, потом общая.
    def self.label(prefix, tool_id, key)
      table = STRINGS[LANG] || STRINGS['ru']
      table[:"#{prefix}_#{tool_id}_#{key}"] || table[:"#{prefix}_#{key}"] || key.to_s
    end
  end
end
