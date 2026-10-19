# frozen_string_literal: true
#
# Демо-сцена для визуальной проверки: домик из инструментов ArchiTools,
# снимок вида в PNG, затем камера возвращается и песочница удаляется.
# Запуск: python test/bridge.py test/live_demo.rb
# Путь снимка — ENV['ARCHITOOLS_SHOT'] или %TEMP%/architools_demo.png.

module ATDemo
  AT = BACommunity::ArchiTools
  extend self

  def model = Sketchup.active_model
  def ents = model.active_entities
  # Сцена строится в 60 м от начала координат, чтобы не пересекаться с моделью.
  # Внутри открытой группы координаты мировые, поэтому сдвигаем сами точки.
  OX = 60_000
  def pt(x, y, z = 0) = Geom::Point3d.new((x + OX).mm, y.mm, z.mm)

  def sel(*list)
    model.selection.clear
    model.selection.add(list.flatten)
  end

  def run(id, **over)
    res = AT::Registry.run(id, { place: false }.merge(over))
    @log << "#{id}: #{res[:ok] ? 'ok' : 'FAIL'} #{res[:message]}"
    res
  end

  def build
    # Стены по контуру 8×6 м.
    loop_edges = ents.add_curve(pt(0, 0), pt(8000, 0), pt(8000, 6000), pt(0, 6000), pt(0, 0))
    sel(loop_edges)
    run(:wall, thickness: 300.mm.to_f, height: 3000.mm.to_f, align: :left)
    ents.erase_entities(loop_edges.select(&:valid?))
    wall = ents.grep(Sketchup::Group).first
    wall.explode
    front = ents.grep(Sketchup::Face).find { |f| f.normal.y < -0.99 && f.bounds.min.y.abs < 1 }
    # Дверь и два окна в фасаде.
    sel(front)
    run(:opening, source: :size, width: 1000.mm.to_f, height: 2100.mm.to_f, sill: 0.0, position: :offset,
                  offset: 1000.mm.to_f, frame: false)
    front = ents.grep(Sketchup::Face).find { |f| f.normal.y < -0.99 && f.bounds.min.y.abs < 1 && f.area > 1000 }
    sel(front)
    run(:opening, source: :size, width: 1800.mm.to_f, height: 1500.mm.to_f, sill: 900.0.mm.to_f, position: :offset,
                  offset: 4500.mm.to_f, frame: false)
    # Окно и дверь в проёмы: грани-заглушки в плоскости фасада.
    # Окно — по выделенной грани фасада: встаёт в её прямоугольную дыру.
    front = ents.grep(Sketchup::Face).find { |f| f.normal.y < -0.99 && f.bounds.min.y.abs < 1 && f.loops.size > 1 }
    sel(front)
    run(:window, cols: 3, rows: 2, frame_width: 60.mm.to_f, frame_depth: 70.mm.to_f, mullion: 50.mm.to_f,
                 inset: 100.mm.to_f, glass: true)
    door = ents.add_face(pt(1000, 0, 0), pt(2000, 0, 0), pt(2000, 0, 2100), pt(1000, 0, 2100))
    sel(door)
    run(:door, leaves: :single, frame_width: 50.mm.to_f, frame_depth: 100.mm.to_f, leaf_thickness: 40.mm.to_f,
               gap: 3.mm.to_f, inset: 100.mm.to_f)
    # Только грань: её рёбра общие с проёмом, без них пропал бы фасад.
    door.erase! if door.valid?

    # Кровля с толщиной по верху стен.
    # Основание кровли — в своей группе, иначе грань слипнется с верхом стен.
    holder = ents.add_group
    holder.entities.add_cline(pt(0, 0, 3000), X_AXIS)
    model.active_path = [@sandbox, holder]
    top = ents.add_face(pt(0, 0, 3000), pt(8000, 0, 3000), pt(8000, 6000, 3000), pt(0, 6000, 3000))
    sel(top)
    run(:roof, type: :hip, pitch: 30.0, overhang: 600.mm.to_f, thickness: 150.mm.to_f)
    ents.erase_entities(top.edges.select(&:valid?)) if top.valid?
    model.active_path = [@sandbox]

    # Ламели на боковом фасаде.
    side = ents.add_face(pt(-300, 1000, 300), pt(-300, 5000, 300), pt(-300, 5000, 2700), pt(-300, 1000, 2700))
    sel(side)
    run(:louvres, direction: :vertical, blade_depth: 200.mm.to_f, blade_thickness: 30.mm.to_f, spacing: 300.mm.to_f,
                  angle: 35.0, offset: 0.0)
    ents.erase_entities(side.edges.select(&:valid?)) if side.valid?

    # Крыльцо: прямая лестница на террасу и колонны.
    model.selection.clear
    res = run(:straight_stairs, type: :treads, width: 1200.mm.to_f, rise: 900.mm.to_f, risers: 5, going: 300.mm.to_f,
                                tread_thickness: 40.mm.to_f, nosing: 20.mm.to_f, stringers: true,
                                stringer_width: 50.mm.to_f, stringer_depth: 200.mm.to_f)
    stairs = model.selection.first
    stairs.transform!(Geom::Transformation.new(pt(9800, -2500, 0)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, Math::PI / 2)) if res[:ok] && stairs
    model.selection.clear
    run(:spiral_stairs, outer_radius: 900.mm.to_f, inner_radius: 80.mm.to_f, rise: 3000.mm.to_f, risers: 15,
                        angle: 330.0, direction: :ccw, tread_thickness: 50.mm.to_f, column: true)
    spiral = model.selection.first
    spiral&.transform!(Geom::Transformation.translation(pt(-2500, 3000, 0) - ORIGIN))

    cps = [[9000, -500], [11_000, -500]].map { |x, y| ents.add_cpoint(pt(x, y)) }
    sel(cps)
    run(:columns, shape: :round, size_x: 250.mm.to_f, height: 2700.mm.to_f, footing: false)
    ents.erase_entities(cps)
  end

  def shot(path)
    view = model.active_view
    cam = view.camera
    saved = [cam.eye, cam.target, cam.up, cam.perspective?, cam.fov]
    # Песочница сдвинута на 60 м по X — камера смотрит туда, чужое не трогаем.
    eye = pt(-9000, -16_000, 11_000)
    target = pt(4500, 2500, 1500)
    view.camera = Sketchup::Camera.new(eye, target, Z_AXIS, true, 35)
    view.write_image(filename: path, width: 1400, height: 900, antialias: true, transparent: false)
  ensure
    view.camera = Sketchup::Camera.new(saved[0], saved[1], saved[2], saved[3], saved[4]) if saved
  end

  def go
    @log = []
    @sandbox = model.entities.add_group
    @sandbox.name = 'ArchiTools demo'
    @sandbox.entities.add_cline(ORIGIN, X_AXIS)
    model.active_path = [@sandbox]
    build
    model.active_path = nil
    path = ENV['ARCHITOOLS_SHOT'] || File.join(ENV['TEMP'], 'architools_demo.png')
    shot(path)
    @log << path
    @log
  ensure
    model.active_path = nil
    @sandbox.erase! if @sandbox&.valid? && !ENV['ARCHITOOLS_KEEP']
  end
end

ATDemo.go
