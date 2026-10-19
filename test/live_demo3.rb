# frozen_string_literal: true
#
# Демо-сцена 0.3: колонны всех типов, окна всех типов, забежная лестница,
# кровля по Г-контуру и с двором, перфорированный экран, профнастил,
# тело вращения, рельеф с площадкой и горизонталями. Снимок — в PNG.
# Запуск: python test/bridge.py test/live_demo3.rb

module ATDemo3
  AT = BACommunity::ArchiTools
  extend self

  OX = 120_000
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

  def isolated
    holder = ents.add_group
    holder.entities.add_cline(pt(0, 0), X_AXIS)
    path = model.active_path || []
    model.active_path = path + [holder]
    yield
  ensure
    model.active_path = path
  end

  def build
    # Колонны всех типов в ряд.
    %i[rect round ellipse capital tuscan tuscan_round].each_with_index do |shape, i|
      cp = ents.add_cpoint(pt(i * 1500, 0))
      sel(cp)
      run(:columns, shape: shape, size_x: 450.mm.to_f, size_y: 300.mm.to_f, height: 3200.mm.to_f, footing: false)
      cp.erase!
    end
    # Стена с тремя окнами разных типов.
    isolated do
      ents.add_line(pt(0, 3000), pt(9000, 3000)).tap { |e| sel(e) }
      run(:wall, kind: :cavity, height: 3000.mm.to_f, align: :left, leaf: 120.mm.to_f, leaf_inner: 120.mm.to_f,
                 cavity: 60.mm.to_f, follow_slope: false)
      ents.erase_entities(ents.grep(Sketchup::Edge))
      [[1000, :fixed, :casing], [4000, :casement, :rebated], [7000, :sliding, :flat]].each do |x, type, profile|
        f = ents.add_face(pt(x, 2990, 900), pt(x + 1600, 2990, 900), pt(x + 1600, 2990, 2400), pt(x, 2990, 2400))
        f.reverse! if f.normal.y.positive?
        sel(f)
        run(:window, type: type, cols: 2, rows: 2, profile: profile, position: :front, frame_width: 60.mm.to_f,
                     frame_depth: 70.mm.to_f, mullion: 50.mm.to_f, sash_width: 50.mm.to_f, inset: 0.0, glass: true)
        f.erase! if f.valid?
      end
    end
    # Забежная лестница.
    model.selection.clear
    run(:winder_stairs, turn: :left, type: :solid, width: 1000.mm.to_f, rise: 2800.mm.to_f, risers: 16,
                        first_flight: 6, winders: 3, going: 270.mm.to_f)
    place(model.selection.first, 11_000, 0)
    # Кровли: Г-образная и с двором.
    isolated do
      f = ents.add_face(pt(0, 8000, 3000), pt(10_000, 8000, 3000), pt(10_000, 12_000, 3000), pt(4000, 12_000, 3000),
                        pt(4000, 18_000, 3000), pt(0, 18_000, 3000))
      sel(f)
      run(:roof, type: :hip, pitch: 30.0, overhang: 400.mm.to_f, thickness: 150.mm.to_f)
      f.erase! if f.valid?
    end
    isolated do
      outer = ents.add_face(pt(12_000, 8000, 3000), pt(24_000, 8000, 3000), pt(24_000, 18_000, 3000), pt(12_000, 18_000, 3000))
      ents.add_face(pt(16_000, 11_000, 3000), pt(20_000, 11_000, 3000), pt(20_000, 15_000, 3000), pt(16_000, 15_000, 3000)).erase!
      outer = ents.grep(Sketchup::Face).first
      sel(outer)
      run(:roof, type: :hip, pitch: 30.0, overhang: 300.mm.to_f, thickness: 150.mm.to_f)
      outer.erase! if outer.valid?
    end
    # Экран и профнастил.
    isolated do
      f = ents.add_face(pt(14_000, 0, 0), pt(17_000, 0, 0), pt(17_000, 0, 2500), pt(14_000, 0, 2500))
      sel(f)
      run(:perforated_screen, hole_shape: :round, hole_width: 120.mm.to_f, hole_height: 120.mm.to_f, spacing_x: 200.mm.to_f,
                              spacing_y: 180.mm.to_f, angle: 15.0, margin: 80.mm.to_f, thickness: 20.mm.to_f, erase_source: true)
    end
    isolated do
      f = ents.add_face(pt(18_000, 0, 2000), pt(22_000, 0, 2000), pt(22_000, 3000, 2600), pt(18_000, 3000, 2600))
      sel(f)
      run(:metal_deck, deck: :trapezoid, direction: :short, pitch: 250.mm.to_f, rib_height: 60.mm.to_f, top_ratio: 0.35,
                       thickness: 1.mm.to_f)
      f.erase! if f.valid?
    end
    # Тело вращения: ваза.
    isolated do
      prof = ents.add_curve(pt(24_000, 0, 0), pt(24_400, 0, 100), pt(24_250, 0, 700), pt(24_450, 0, 1200), pt(24_350, 0, 1400))
      sel(prof)
      run(:revolve, angle: 360.0, segments: 32, scale: 1.0, rise: 0.0, points: [pt(23_800, 0, 0), pt(23_800, 0, 1000)])
      ents.erase_entities(prof.select(&:valid?))
    end
    # Рельеф: холм, площадка, горизонтали.
    isolated do
      hill = ents.add_group
      mesh = Geom::PolygonMesh.new
      n = 30
      h = ->(x, y) { 2500 * Math.exp(-(((x - 7500)**2) + ((y - 7500)**2)) / 1.8e7) }
      (0...n).each do |i|
        (0...n).each do |j|
          q = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]].map { |a, b| x = a * 500; y = b * 500; pt(x, y - 22_000, h.call(x, y)) }
          mesh.add_polygon(q[0], q[1], q[2])
          mesh.add_polygon(q[0], q[2], q[3])
        end
      end
      hill.entities.fill_from_mesh(mesh, true, 0)
      pad = ents.add_face(pt(5500, -16_500, 1500), pt(9500, -16_500, 1500), pt(9500, -12_500, 1500), pt(5500, -12_500, 1500))
      sel(hill, pad)
      run(:cut_fill, level_from: :face, batter: 35.0, step: 250.mm.to_f, hide_source: true)
      pad.erase! if pad.valid?
      graded = ents.grep(Sketchup::Group).find { |g| g.name == AT.t(:name_graded) }
      sel(graded)
      run(:contour_lines, start: 0.0, interval: 250.mm.to_f)
    end
  end

  def shot(path)
    view = model.active_view
    cam = view.camera
    saved = [cam.eye, cam.target, cam.up, cam.perspective?, cam.fov]
    eye, target = [pt(-12_000, -38_000, 26_000), pt(11_000, -2000, 0)]
    if ENV['ARCHITOOLS_CAM']
      v = ENV['ARCHITOOLS_CAM'].split(',').map(&:to_f)
      eye = pt(v[0], v[1], v[2])
      target = pt(v[3], v[4], v[5])
    end
    view.camera = Sketchup::Camera.new(eye, target, Z_AXIS, true, 40)
    view.write_image(filename: path, width: 1800, height: 1100, antialias: true, transparent: false)
  ensure
    view.camera = Sketchup::Camera.new(*saved) if saved
  end

  def go
    @log = []
    @sandbox = model.entities.add_group
    @sandbox.name = 'ArchiTools demo 0.3'
    @sandbox.entities.add_cline(pt(0, 0), X_AXIS)
    model.active_path = [@sandbox]
    build
    model.active_path = nil
    path = ENV['ARCHITOOLS_SHOT'] || File.join(ENV['TEMP'], 'architools_demo3.png')
    shot(path)
    @log << path
  ensure
    model.active_path = nil
    @sandbox.erase! if @sandbox&.valid? && !ENV['ARCHITOOLS_KEEP']
  end
end

ATDemo3.go
