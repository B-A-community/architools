# frozen_string_literal: true
#
# Демо-сцена 0.2: П-образная лестница с ограждением, эскалатор, беседка
# на шестиугольнике с вальмой по прямому скелету, пергола из двутавров,
# арочный и круглый проёмы. Снимок вида — в PNG, песочница удаляется.
# Запуск: python test/bridge.py test/live_demo2.rb

module ATDemo2
  AT = BACommunity::ArchiTools
  extend self

  OX = 60_000
  def model = Sketchup.active_model
  def ents = model.active_entities
  def pt(x, y, z = 0) = Geom::Point3d.new((x + OX).mm, y.mm, z.mm)

  def sel(*list)
    model.selection.clear
    model.selection.add(list.flatten.compact)
  end

  def run(id, **over)
    res = AT::Registry.run(id, { place: false }.merge(over))
    @log << "#{id}: #{res[:ok] ? 'ok' : 'FAIL'} #{res[:message]}"
    res
  end

  def place(entity, x, y, angle = 0)
    entity&.transform!(Geom::Transformation.translation(pt(x, y) - ORIGIN) *
                       Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle * Math::PI / 180))
  end

  def build
    # Стена с арочным и круглым проёмами.
    ents.add_line(pt(-9000, 0), pt(-1000, 0)).tap { |e| sel(e) }
    run(:wall, thickness: 300.mm.to_f, height: 3500.mm.to_f, align: :left)
    ents.erase_entities(ents.grep(Sketchup::Edge))
    ents.grep(Sketchup::Group).first.explode
    front = -> { ents.grep(Sketchup::Face).select { |f| f.normal.y < -0.99 && f.bounds.min.y.abs < 1 }.max_by(&:area) }
    sel(front.call)
    run(:opening, source: :size, shape: :arch, width: 1400.mm.to_f, height: 2600.mm.to_f, sill: 0.0,
                  position: :offset, offset: 1500.mm.to_f, segments: 24, frame: true, frame_width: 80.mm.to_f)
    sel(front.call)
    run(:opening, source: :size, shape: :round, width: 1200.mm.to_f, sill: 1300.mm.to_f, position: :offset,
                  offset: 5000.mm.to_f, segments: 32, frame: true, frame_width: 80.mm.to_f)

    # П-образная лестница с ограждением.
    model.selection.clear
    run(:landing_stairs, turn: :u_left, type: :slab, width: 1100.mm.to_f, rise: 3000.mm.to_f, risers: 18,
                         first_flight: 9, going: 280.mm.to_f, gap: 150.mm.to_f, waist: 150.mm.to_f, railing: true,
                         rail_height: 900.mm.to_f, post_spacing: 1000.mm.to_f, post_size: 50.mm.to_f,
                         handrail: 50.mm.to_f, infill: :balusters, baluster_spacing: 120.mm.to_f)
    place(model.selection.first, 1000, -6000)

    # Эскалатор.
    model.selection.clear
    run(:escalator, width: 1000.mm.to_f, rise: 3000.mm.to_f, angle: :a30, landing: 1200.mm.to_f,
                    balustrade: 1000.mm.to_f, truss_depth: 1000.mm.to_f)
    place(model.selection.first, 7000, -6500)

    # Беседка: колонны по вершинам шестиугольника, вальма по скелету.
    c = [-4000, -9000]
    hex = (0...6).map { |i| a = Math::PI / 3 * i; [c[0] + 2500 * Math.cos(a), c[1] + 2500 * Math.sin(a)] }
    cps = hex.map { |x, y| ents.add_cpoint(pt(x, y)) }
    sel(cps)
    run(:columns, shape: :round, size_x: 200.mm.to_f, height: 2700.mm.to_f, footing: false)
    ents.erase_entities(cps)
    holder = ents.add_group
    holder.entities.add_cline(pt(0, 0, 2700), X_AXIS)
    model.active_path = [@sandbox, holder]
    base = ents.add_face(hex.map { |x, y| pt(x, y, 2700) })
    sel(base)
    run(:roof, type: :hip, pitch: 30.0, overhang: 400.mm.to_f, thickness: 120.mm.to_f)
    base.erase! if base.valid?
    model.active_path = [@sandbox]

    # Пергола: двутавры по рёбрам, трубы-прогоны сечением по пути.
    lines = [[0, 0], [0, 4000]].map { |dx, dy| ents.add_line(pt(6000 + dx, dy - 15_000, 3000), pt(12_000 + dx, dy - 15_000, 3000)) }
    sel(lines)
    run(:beams, profile: :i_beam, width: 150.mm.to_f, depth: 300.mm.to_f, web: 8.mm.to_f, flange: 12.mm.to_f,
                align: :top)
    ents.erase_entities(lines)
    cross = (0..6).map { |i| ents.add_line(pt(6000 + i * 1000, -15_200, 3050), pt(6000 + i * 1000, -10_800, 3050)) }
    sel(cross)
    run(:profile_sweep, profile: :chs, width: 80.mm.to_f, web: 5.mm.to_f, align: :center, segments: 16)
    ents.erase_entities(cross)
    cps = [[6000, -15_000], [12_000, -15_000], [6000, -11_000], [12_000, -11_000]].map { |x, y| ents.add_cpoint(pt(x, y)) }
    sel(cps)
    run(:columns, shape: :rect, size_x: 200.mm.to_f, size_y: 200.mm.to_f, height: 2700.mm.to_f, footing: false)
    ents.erase_entities(cps)
  end

  def shot(path)
    view = model.active_view
    cam = view.camera
    saved = [cam.eye, cam.target, cam.up, cam.perspective?, cam.fov]
    # ARCHITOOLS_CAM="ex,ey,ez,tx,ty,tz" (мм, без сдвига сцены) — свой ракурс.
    eye, target = [pt(-16_000, -30_000, 15_000), pt(2000, -7000, 1000)]
    if ENV['ARCHITOOLS_CAM']
      v = ENV['ARCHITOOLS_CAM'].split(',').map(&:to_f)
      eye = pt(v[0], v[1], v[2])
      target = pt(v[3], v[4], v[5])
    end
    view.camera = Sketchup::Camera.new(eye, target, Z_AXIS, true, 40)
    view.write_image(filename: path, width: 1600, height: 1000, antialias: true, transparent: false)
  ensure
    view.camera = Sketchup::Camera.new(*saved) if saved
  end

  def go
    @log = []
    @sandbox = model.entities.add_group
    @sandbox.name = 'ArchiTools demo 0.2'
    @sandbox.entities.add_cline(pt(0, 0), X_AXIS)
    model.active_path = [@sandbox]
    build
    model.active_path = nil
    path = ENV['ARCHITOOLS_SHOT'] || File.join(ENV['TEMP'], 'architools_demo2.png')
    shot(path)
    @log << path
  ensure
    model.active_path = nil
    @sandbox.erase! if @sandbox&.valid? && !ENV['ARCHITOOLS_KEEP']
  end
end

ATDemo2.go
