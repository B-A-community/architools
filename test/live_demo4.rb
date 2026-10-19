# frozen_string_literal: true
#
# Демо-сцена «Моделирование» (функции JHS Powerbar): FFD-деформация
# коробки, Split Up + FFD «подушка», трубы по линиям с шарами, зеркало,
# случайный масштаб и поворот «деревьев», сетка на грани, «бусы» по дуге,
# сглаживание. Снимок — в PNG, песочница удаляется.
# Запуск: python test/bridge.py test/live_demo4.rb

module ATDemo4
  AT = BACommunity::ArchiTools
  extend self

  OX = 180_000
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

  def box(x, y, w, d, h)
    g = ents.add_group
    f = g.entities.add_face(pt(x, y), pt(x + w, y), pt(x + w, y + d), pt(x, y + d))
    f.reverse! if f.normal.z.negative?
    f.pushpull(h.mm)
    g
  end

  def build
    # FFD: коробка, верх решётки закручен и раздут.
    g = box(0, 0, 2000, 2000, 2000)
    sel(g)
    split_faces = g.entities.grep(Sketchup::Face)
    model.active_path = [@sandbox, g]
    sel(model.active_entities.grep(Sketchup::Face))
    run(:split_up, divisions: 8)
    model.active_path = [@sandbox]
    sel(g)
    run(:ffd, mode: :create, lattice: :g3)
    lat = ents.grep(Sketchup::Group).find { |x| x.name == AT.t(:name_ffd_lattice) }
    st = AT::FFD.find_state(lat)
    st[:ctrl].each do |(i, j, k), c|
      if k == 2
        ang = 0.6
        cx = (0 + OX).mm + 1000.mm
        cy = 1000.mm
        p = c.position
        x = cx + (p.x - cx) * Math.cos(ang) - (p.y - cy) * Math.sin(ang)
        y = cy + (p.x - cx) * Math.sin(ang) + (p.y - cy) * Math.cos(ang)
        lat.entities.transform_entities(Geom::Transformation.translation(Geom::Point3d.new(x, y, p.z) - p), c)
      elsif k == 1 && i == 1 && j == 1
        next
      elsif k == 1
        p = c.position
        v = Geom::Vector3d.new(p.x - (OX + 1000).mm, p.y - 1000.mm, 0)
        lat.entities.transform_entities(Geom::Transformation.translation(Geom3Scale.scale(v, 0.5)), c) if v.length.to_f > 0
      end
    end
    AT::FFD.update(lat)
    sel(g)
    run(:soften_edges, mode: :angle, angle: 35.0, soft: true, smooth: true, nested: true)
    sel(lat)
    run(:ffd, mode: :finish)

    # Трубы по линиям — «рама» с шарами в узлах.
    pts = [[4000, 0, 0], [6000, 0, 0], [6000, 2000, 0], [4000, 2000, 0]]
    top = pts.map { |x, y, _| [x, y, 2000] }
    lines = []
    pts.each_with_index { |a, i| lines << ents.add_line(pt(*a), pt(*pts[(i + 1) % 4])); lines << ents.add_line(pt(*top[i]), pt(*top[(i + 1) % 4])); lines << ents.add_line(pt(*a), pt(*top[i])) }
    lines << ents.add_line(pt(*pts[0]), pt(*top[2]))
    sel(lines)
    run(:lines_to_tubes, diameter: 80.mm.to_f, segments: 16, joints: true, erase_lines: true)

    # Деревья: конус на стволе, рассыпаны по сетке и случайно масштабированы.
    tree = ents.add_group
    t = tree.entities
    c = t.add_circle(pt(8500, 300, 0), Z_AXIS, 60.mm, 12)
    f = t.add_face(c); f.reverse! if f.normal.z.negative?; f.pushpull(600.mm)
    c2 = t.add_circle(pt(8500, 300, 600), Z_AXIS, 400.mm, 16)
    f2 = t.add_face(c2); f2.reverse! if f2.normal.z.negative?
    f2.pushpull(100.mm)
    apex = pt(8500, 300, 2200)
    rim = c2.map { |e| e.start.position.offset(Z_AXIS, 100.mm) }
    rim.each_with_index { |a, i| t.add_face(a, rim[(i + 1) % rim.size], apex) }
    sel(tree)
    run(:rectangular_array, cols: 4, rows: 3, levels: 1, dx: 900.mm.to_f, dy: 900.mm.to_f, pattern: :staggered)
    trees = ents.grep(Sketchup::Group).select { |x| (x.bounds.center.x.to_mm - OX).between?(8000, 12_500) }
    sel(trees)
    run(:random_transform, mode: :both, scale_min: 60.0, scale_max: 140.0, angle_max: 180.0, seed: 3)

    # Зеркало: Г-образная стенка и её отражение.
    w = box(13_500, 0, 200, 2000, 1200)
    w2 = box(13_500, 0, 1500, 200, 1200)
    sel(w, w2)
    run(:mirror, copy: true, points: [pt(15_500, -100), pt(15_500, 100)])

    # Сетка на наклонной грани и «бусы» по дуге.
    slab = ents.add_face(pt(0, 4000, 0), pt(6000, 4000, 0), pt(6000, 7000, 1500), pt(0, 7000, 1500))
    sel(slab)
    run(:mesh_maker, by: :cell, cell: 500.mm.to_f, angle: 30.0, output: :split)
    bead = ents.add_group
    s = bead.entities.add_circle(pt(8000, 4000, 0), Z_AXIS, 120.mm, 12)
    fb = bead.entities.add_face(s); fb.reverse! if fb.normal.z.negative?; fb.pushpull(240.mm)
    arc = ents.add_arc(pt(11_000, 6500, 0), Geom::Vector3d.new(-1, -1, 0).normalize, Z_AXIS, 3500.mm, 0, Math::PI * 1.2, 72)
    sel(bead, arc)
    run(:path_array, mode: :chord, spacing: 500.mm.to_f, follow: false)
  end

  module Geom3Scale
    def self.scale(v, k) = Geom::Vector3d.new(v.x * k, v.y * k, v.z * k)
  end

  def shot(path)
    view = model.active_view
    cam = view.camera
    saved = [cam.eye, cam.target, cam.up, cam.perspective?, cam.fov]
    view.camera = Sketchup::Camera.new(pt(-6000, -14_000, 11_000), pt(8000, 3500, 600), Z_AXIS, true, 40)
    view.write_image(filename: path, width: 1800, height: 1100, antialias: true, transparent: false)
  ensure
    view.camera = Sketchup::Camera.new(*saved) if saved
  end

  def go
    @log = []
    @sandbox = model.entities.add_group
    @sandbox.name = 'ArchiTools demo modeling'
    @sandbox.entities.add_cline(pt(0, 0), X_AXIS)
    model.active_path = [@sandbox]
    build
    model.active_path = nil
    path = ENV['ARCHITOOLS_SHOT'] || File.join(ENV['TEMP'], 'architools_demo4.png')
    shot(path)
    @log << path
  ensure
    model.active_path = nil
    @sandbox.erase! if @sandbox&.valid? && !ENV['ARCHITOOLS_KEEP']
  end
end

ATDemo4.go
