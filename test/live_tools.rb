# frozen_string_literal: true
#
# Живая проверка всех инструментов ArchiTools в запущенном SketchUp.
# Запуск: python test/bridge.py test/live_tools.rb
# Всё строится во временной группе-песочнице (она открыта на редактирование
# и удаляется в конце) — остальная модель не трогается.

module ATLive
  AT = BACommunity::ArchiTools
  extend self

  def model = Sketchup.active_model
  def ents = model.active_entities
  def pt(x, y, z = 0) = Geom::Point3d.new(x.mm, y.mm, z.mm)
  def mm(v) = (v.to_f * 25.4)
  def mm3(v) = (v.to_f * 25.4**3)

  def sel(*list)
    model.selection.clear
    model.selection.add(list.flatten)
  end

  def run(id, **over)
    (@tested ||= {})[id] = true
    AT::Registry.run(id, { place: false }.merge(over))
  end

  def groups(list = ents) = list.grep(Sketchup::Group)
  def named(list, key) = list.grep(Sketchup::Group).select { |g| g.name == AT.t(key) }

  # Площадь сечения из библиотеки, мм²: внешний контур минус дыры.
  def section_area(loops)
    loops.each_with_index.sum do |l, i|
      a = AT::Profiles.signed_area(l).abs * 25.4**2
      i.zero? ? a : -a
    end
  end

  def near(a, b, tol = 0.5) = (a - b).abs <= tol

  def wipe
    ents.erase_entities(ents.to_a - [@anchor])
  end

  def check(name)
    wipe
    ok, info = yield
    @results << [ok ? 'PASS' : 'FAIL', name, info]
  rescue StandardError => e
    @results << ['ERR', name, "#{e.class}: #{e.message} @ #{e.backtrace.first}"]
  end

  def rect(x, y, w, h, z = 0)
    ents.add_face(pt(x, y, z), pt(x + w, y, z), pt(x + w, y + h, z), pt(x, y + h, z))
  end

  def vrect(x, y, w, h)
    ents.add_face(pt(x, y, 0), pt(x + w, y, 0), pt(x + w, y, h), pt(x, y, h))
  end

  def all
    @results = []
    @sandbox = model.entities.add_group
    @sandbox.name = 'ArchiTools live test'
    @anchor = @sandbox.entities.add_cline(Geom::Point3d.new(0, 0, -100_000.mm), Geom::Vector3d.new(1, 0, 0))
    model.active_path = [@sandbox]
    run_all
  ensure
    model.active_path = nil
    @sandbox.erase! if @sandbox&.valid?
  end

  def run_all

    # --- рёбра ---
    check('fillet two edges r200') do
      a = ents.add_line(pt(0, 0), pt(1000, 0))
      b = ents.add_line(pt(0, 0), pt(0, 1000))
      sel(a, b)
      r = run(:fillet, radius: 200.mm.to_f, segments: 8)
      arcs = ents.grep(Sketchup::Edge).map(&:curve).compact.grep(Sketchup::ArcCurve).uniq
      [r[:ok] && arcs.size == 1 && near(mm(arcs[0].radius), 200), r[:message]]
    end

    check('fillet keeps face') do
      f = rect(0, 0, 1000, 800)
      e = f.edges.select { |x| x.vertices.any? { |v| v.position == pt(0, 0) } }
      sel(e)
      r = run(:fillet, radius: 150.mm.to_f, segments: 6)
      faces = ents.grep(Sketchup::Face)
      expected = 1000 * 800 - (150**2 - Math::PI * 150**2 / 4)
      area = faces.sum { |x| x.area } * 25.4**2
      [r[:ok] && faces.size == 1 && (area - expected).abs / expected < 0.01, "#{r[:message]} faces=#{faces.size} area=#{area.round}"]
    end

    check('fillet chain 2 corners') do
      ents.add_curve(pt(0, 0), pt(1000, 0), pt(1000, 1000), pt(2000, 1000))
      sel(ents.grep(Sketchup::Edge))
      r = run(:fillet, radius: 200.mm.to_f, segments: 6)
      arcs = ents.grep(Sketchup::Edge).map(&:curve).compact.uniq.size
      [r[:ok] && arcs >= 2, "#{r[:message]} curves=#{arcs}"]
    end

    check('chamfer 100') do
      ents.add_line(pt(0, 0), pt(1000, 0))
      ents.add_line(pt(0, 0), pt(0, 1000))
      sel(ents.grep(Sketchup::Edge))
      r = run(:chamfer, distance1: 100.mm.to_f, distance2: 0.0)
      lens = ents.grep(Sketchup::Edge).map { |e| mm(e.length).round(1) }.sort
      [r[:ok] && lens.include?((100 * Math.sqrt(2)).round(1)) && lens.count(900.0) == 2, lens.inspect]
    end

    check('extend two edges to corner') do
      ents.add_line(pt(100, 0), pt(1000, 0))
      ents.add_line(pt(0, 100), pt(0, 1000))
      sel(ents.grep(Sketchup::Edge))
      r = run(:extend_edges)
      verts = ents.grep(Sketchup::Edge).flat_map(&:vertices).uniq
      corner = verts.find { |v| v.position == pt(0, 0) }
      [r[:ok] && corner && corner.edges.size == 2, r[:message]]
    end

    check('extend edges to face') do
      f = ents.add_face(pt(2000, -500, -500), pt(2000, 500, -500), pt(2000, 500, 500), pt(2000, -500, 500))
      e = ents.add_line(pt(0, 0, 0), pt(1000, 0, 0))
      sel(e, f)
      r = run(:extend_edges)
      reach = ents.grep(Sketchup::Edge).any? { |x| x.vertices.any? { |v| v.position == pt(2000, 0, 0) } }
      [r[:ok] && reach, r[:message]]
    end

    check('divide split/points') do
      e = ents.add_line(pt(0, 0), pt(1000, 0))
      sel(e)
      r1 = run(:divide, by: :count, count: 4, output: :split)
      n = ents.grep(Sketchup::Edge).size
      e2 = ents.add_line(pt(0, 500), pt(1000, 500))
      sel(e2)
      r2 = run(:divide, by: :length, seg_length: 250.mm.to_f, output: :points)
      c = ents.grep(Sketchup::ConstructionPoint).size
      [r1[:ok] && r2[:ok] && n == 4 && c == 3, "edges=#{n} cpoints=#{c}"]
    end

    check('center point of circle') do
      circle = ents.add_circle(pt(500, 500), Geom::Vector3d.new(0, 0, 1), 300.mm, 24)
      sel(circle)
      r = run(:center_point, axis: false)
      cp = ents.grep(Sketchup::ConstructionPoint).first
      [r[:ok] && cp && cp.position == pt(500, 500), r[:message]]
    end

    check('offset closed loop outward') do
      ents.add_curve(pt(0, 0), pt(1000, 0), pt(1000, 1000), pt(0, 1000), pt(0, 0))
      sel(ents.grep(Sketchup::Edge))
      r = run(:offset_edges, distance: 100.mm.to_f, both_sides: false, flip: false)
      xs = ents.grep(Sketchup::Edge).flat_map(&:vertices).map { |v| mm(v.position.x).round }
      [r[:ok] && xs.min == -100 && xs.max == 1100, "#{r[:message]} x=#{xs.minmax}"]
    end

    check('slope 45 deg') do
      ents.add_curve(pt(0, 0), pt(1000, 0), pt(1000, 1000))
      sel(ents.grep(Sketchup::Edge))
      r = run(:slope_edges, by: :angle, angle: 45.0, reverse: false)
      zs = ents.grep(Sketchup::Edge).flat_map(&:vertices).map { |v| mm(v.position.z).round }
      [r[:ok] && zs.max == 2000 && zs.min == 0, "#{r[:message]} z=#{zs.minmax}"]
    end

    check('normal line') do
      f = rect(0, 0, 1000, 1000)
      sel(f)
      r = run(:normal_line, length: 500.mm.to_f, output: :edge)
      e = ents.grep(Sketchup::Edge).max_by { |x| (x.end.position.z - x.start.position.z).abs }
      [r[:ok] && near(mm(e.length), 500), r[:message]]
    end

    # --- правка ---
    check('extrude two faces') do
      a = rect(0, 0, 1000, 1000)
      b = rect(2000, 0, 1000, 1000)
      sel(a, b)
      r = run(:extrude_faces, distance: 300.mm.to_f, copy: false)
      # Грань на земле SketchUp разворачивает вниз — выдавливаем по нормали.
      zs = ents.grep(Sketchup::Face).flat_map { |f| [mm(f.bounds.min.z).round, mm(f.bounds.max.z).round] }.uniq.sort
      [r[:ok] && zs.max - zs.min == 300, "#{r[:message]} z=#{zs}"]
    end

    check('shift faces') do
      a = rect(0, 0, 1000, 1000)
      a.reverse! if a.normal.z.negative?
      sel(a)
      r = run(:shift_faces, distance: 250.mm.to_f)
      f = ents.grep(Sketchup::Face).first
      [r[:ok] && f && near(mm(f.bounds.min.z), 250), r[:message]]
    end

    check('shell 100 on plate') do
      a = rect(0, 0, 1000, 1000)
      sel(a)
      r = run(:shell, thickness: 100.mm.to_f, erase_source: true)
      g = ents.grep(Sketchup::Group).first
      v = g && g.volume.positive? ? mm3(g.volume) : -1
      [r[:ok] && g&.manifold? && (v - 1.0e8).abs / 1.0e8 < 0.001, "#{r[:message]} vol=#{v.round}"]
    end

    check('shell on bent surface (two faces)') do
      a = ents.add_face(pt(0, 0, 0), pt(1000, 0, 0), pt(1000, 1000, 0), pt(0, 1000, 0))
      b = ents.add_face(pt(1000, 0, 0), pt(2000, 0, 500), pt(2000, 1000, 500), pt(1000, 1000, 0))
      sel(a, b)
      r = run(:shell, thickness: 50.mm.to_f, erase_source: false)
      g = ents.grep(Sketchup::Group).first
      [r[:ok] && g&.manifold?, "#{r[:message]} manifold=#{g&.manifold?}"]
    end

    check('extrude profile along sloped path') do
      ents.add_curve(pt(0, 0, 0), pt(3000, 0, 0), pt(5000, 0, 1000), pt(5000, 3000, 1000))
      prof = ents.add_face(pt(0, -50, 0), pt(0, 50, 0), pt(0, 50, 200), pt(0, -50, 200))
      sel(ents.grep(Sketchup::Edge).reject { |e| prof.edges.include?(e) }, prof)
      r = run(:extrude_path, smooth: true, erase_profile: false)
      g = ents.grep(Sketchup::Group).first
      # Профиль на наклоне остаётся вертикальным: высота сечения везде 200.
      zmax = g ? mm(g.bounds.max.z).round : 0
      [r[:ok] && g&.manifold? && g.volume.positive? && zmax.between?(1200, 1210), "#{r[:message]} manifold=#{g&.manifold?} zmax=#{zmax}"]
    end

    check('polar array 6 around cpoint') do
      g = ents.add_group
      g.entities.add_face(pt(900, -50), pt(1100, -50), pt(1100, 50), pt(900, 50)).pushpull(-100.mm)
      cp = ents.add_cpoint(pt(0, 0))
      sel(g, cp)
      r = run(:polar_array, count: 6, angle: 360.0, axis: :z, rotate_copies: true)
      groups = ents.grep(Sketchup::Group)
      ys = groups.map { |x| mm(x.bounds.center.y).round }
      [r[:ok] && groups.size == 6 && ys.max.between?(860, 870), "#{r[:message]} y=#{ys.sort}"]
    end

    check('linear array total') do
      g = ents.add_group
      g.entities.add_face(pt(0, 0), pt(100, 0), pt(100, 100), pt(0, 100))
      sel(g)
      r = run(:linear_array, count: 5, dx: 4000.mm.to_f, dy: 0.0, dz: 0.0, mode: :total)
      xs = ents.grep(Sketchup::Group).map { |x| mm(x.bounds.min.x).round }.sort
      [r[:ok] && xs == [0, 1000, 2000, 3000, 4000], xs.inspect]
    end

    # --- стены ---
    check('wall open L') do
      ents.add_curve(pt(0, 0), pt(3000, 0), pt(3000, 2000))
      sel(ents.grep(Sketchup::Edge))
      r = run(:wall, thickness: 250.mm.to_f, height: 3000.mm.to_f, align: :center)
      g = ents.grep(Sketchup::Group).first
      v = mm3(g.volume)
      [r[:ok] && g.manifold? && (v - 5000 * 250 * 3000).abs / v < 0.001, "vol=#{(v / 1e9).round(3)} m3"]
    end

    check('wall closed loop') do
      ents.add_curve(pt(0, 0), pt(4000, 0), pt(4000, 3000), pt(0, 3000), pt(0, 0))
      sel(ents.grep(Sketchup::Edge))
      r = run(:wall, thickness: 250.mm.to_f, height: 3000.mm.to_f, align: :center)
      g = ents.grep(Sketchup::Group).first
      v = mm3(g.volume)
      [r[:ok] && g.manifold? && (v - 14_000 * 250 * 3000).abs / v < 0.001, "vol=#{(v / 1e9).round(3)} m3"]
    end

    check('opening by size + lining') do
      ents.add_line(pt(0, 0), pt(3000, 0))
      sel(ents.grep(Sketchup::Edge))
      run(:wall, thickness: 250.mm.to_f, height: 3000.mm.to_f, align: :center)
      ents.erase_entities(ents.grep(Sketchup::Edge)) # осевая лежала бы внутри стены
      wall = ents.grep(Sketchup::Group).first
      v0 = mm3(wall.volume)
      wall.explode
      face = ents.grep(Sketchup::Face).max_by { |f| f.normal.y.abs * f.area }
      sel(face)
      r = run(:opening, source: :size, width: 900.mm.to_f, height: 2100.mm.to_f, sill: 0.0, position: :center,
                        frame: true, frame_width: 60.mm.to_f)
      g = ents.add_group(ents.grep(Sketchup::Face) + ents.grep(Sketchup::Edge))
      v1 = mm3(g.volume)
      lin = ents.grep(Sketchup::Group).size
      [r[:ok] && (v0 - v1 - 900 * 2100 * 250).abs / v0 < 0.001 && lin == 2, "#{r[:message]} dv=#{((v0 - v1) / 1e9).round(4)}"]
    end

    check('opening from drawn rectangle') do
      ents.add_line(pt(0, 0), pt(3000, 0))
      sel(ents.grep(Sketchup::Edge))
      run(:wall, thickness: 200.mm.to_f, height: 3000.mm.to_f, align: :left)
      ents.grep(Sketchup::Group).first.explode
      face = ents.grep(Sketchup::Face).find { |f| f.normal.y.abs > 0.99 && f.bounds.min.y.abs < 0.01 }
      y = face.bounds.min.y
      ents.add_face(Geom::Point3d.new(1000.mm, y, 900.mm), Geom::Point3d.new(2200.mm, y, 900.mm),
                    Geom::Point3d.new(2200.mm, y, 2100.mm), Geom::Point3d.new(1000.mm, y, 2100.mm))
      hole = ents.grep(Sketchup::Face).find { |f| (mm(mm(f.area)) - 1200 * 1200).abs < 1 }
      sel(hole)
      r = run(:opening, source: :face, frame: false)
      g = ents.add_group(ents.grep(Sketchup::Face) + ents.grep(Sketchup::Edge))
      v = mm3(g.volume)
      [r[:ok] && (v - (3000 * 3000 - 1200 * 1200) * 200.0).abs / v < 0.001, "#{r[:message]} v=#{(v / 1e9).round(4)}"]
    end

    check('window 2x2') do
      f = vrect(0, 0, 1500, 1400)
      sel(f)
      r = run(:window, cols: 2, rows: 2, frame_width: 60.mm.to_f, frame_depth: 70.mm.to_f, mullion: 50.mm.to_f,
                       inset: 0.0, glass: true)
      w = ents.grep(Sketchup::Group).first
      glass = w.entities.grep(Sketchup::Group).find { |x| x.name == AT.t(:name_glass) }
      [r[:ok] && glass && glass.entities.grep(Sketchup::Face).size == 4 &&
        near(mm(w.bounds.width), 1500) && near(mm(w.bounds.depth), 1400), r[:message]]
    end

    check('door double') do
      f = vrect(0, 0, 1600, 2100)
      sel(f)
      r = run(:door, leaves: :double, frame_width: 50.mm.to_f, frame_depth: 100.mm.to_f, leaf_thickness: 40.mm.to_f,
                     gap: 3.mm.to_f, inset: 0.0)
      d = ents.grep(Sketchup::Group).first
      leaves = d.entities.grep(Sketchup::Group).count { |x| x.name == AT.t(:name_leaf) }
      [r[:ok] && leaves == 2, r[:message]]
    end

    # --- фасад ---
    check('louvres horizontal') do
      f = vrect(0, 0, 2000, 2000)
      sel(f)
      r = run(:louvres, direction: :horizontal, blade_depth: 150.mm.to_f, blade_thickness: 20.mm.to_f,
                        spacing: 200.mm.to_f, angle: 30.0, offset: 100.mm.to_f)
      g = ents.grep(Sketchup::Group).first
      [r[:ok] && g.entities.grep(Sketchup::Group).size == 10, r[:message]]
    end

    check('louvres vertical on triangle') do
      f = ents.add_face(pt(0, 0, 0), pt(2000, 0, 0), pt(1000, 0, 2000))
      sel(f)
      r = run(:louvres, direction: :vertical, blade_depth: 100.mm.to_f, blade_thickness: 0.0,
                        spacing: 250.mm.to_f, angle: 0.0, offset: 0.0)
      g = ents.grep(Sketchup::Group).first
      [r[:ok] && g.entities.grep(Sketchup::Face).size == 8, r[:message]]
    end

    check('panel divider 3x2') do
      f = vrect(0, 0, 3000, 2000)
      sel(f)
      r = run(:panel_divider, cols: 3, rows: 2, frame_width: 50.mm.to_f, frame_depth: 100.mm.to_f, split_face: true)
      faces = ents.grep(Sketchup::Face).size
      g = ents.grep(Sketchup::Group).first
      [r[:ok] && faces == 6 && g.entities.grep(Sketchup::Group).size == 7, "#{r[:message]} faces=#{faces}"]
    end

    # --- лестницы ---
    %i[slab solid treads].each do |type|
      check("straight stairs #{type}") do
        model.selection.clear
        r = run(:straight_stairs, type: type, width: 1200.mm.to_f, rise: 3000.mm.to_f, risers: 17,
                                  going: 280.mm.to_f, waist: 150.mm.to_f, tread_thickness: 40.mm.to_f,
                                  nosing: 20.mm.to_f, stringers: true, stringer_width: 50.mm.to_f,
                                  stringer_depth: 250.mm.to_f)
        g = ents.grep(Sketchup::Group).first
        b = g.bounds
        top = type == :treads ? 3000 - 40 : 3000
        [r[:ok] && near(mm(b.max.z), top, 1) && near(mm(b.height.to_f), 1200, 1) && near(mm(b.width.to_f), 16 * 280 + (type == :treads ? 20 : 0), 2),
         "#{r[:message]} #{mm(b.width).round}x#{mm(b.height).round}x#{mm(b.depth).round}"]
      end
    end

    check('spiral stairs') do
      model.selection.clear
      r = run(:spiral_stairs, outer_radius: 1000.mm.to_f, inner_radius: 100.mm.to_f, rise: 3000.mm.to_f, risers: 16,
                              angle: 360.0, direction: :ccw, tread_thickness: 50.mm.to_f, column: true)
      g = ents.grep(Sketchup::Group).first
      inst = g.entities.grep(Sketchup::ComponentInstance).size
      [r[:ok] && inst == 16 && near(mm(g.bounds.max.z), 3000, 1), r[:message]]
    end

    # --- каркас ---
    check('joists 4000x3000 @600') do
      f = rect(0, 0, 4000, 3000, 3000)
      sel(f)
      r = run(:joists, direction: :short, spacing: 600.mm.to_f, width: 50.mm.to_f, depth: 200.mm.to_f,
                       edge_members: true, side: :below)
      g = ents.grep(Sketchup::Group).first
      n = g.entities.grep(Sketchup::Group).size
      lens = g.entities.grep(Sketchup::Group).map { |x| [mm(x.bounds.width), mm(x.bounds.height)].max.round }.uniq
      [r[:ok] && n == 8 && lens == [3000] && near(mm(g.bounds.min.z), 2800), "#{r[:message]} n=#{n} lens=#{lens}"]
    end

    check('roof hip + rafters + purlins') do
      f = rect(0, 0, 10_000, 6000, 3000)
      sel(f)
      r = run(:roof, type: :hip, pitch: 30.0, overhang: 500.mm.to_f, thickness: 0.0)
      roof = ents.grep(Sketchup::Group).first
      h = mm(roof.bounds.max.z) - 3000
      exp = 3500 * Math.tan(30 * Math::PI / 180)
      roof.explode
      slope = ents.grep(Sketchup::Face).select { |x| !x.normal.parallel?(Geom::Vector3d.new(0, 0, 1)) }
                  .max_by(&:area)
      sel(slope)
      r2 = run(:rafters, spacing: 600.mm.to_f, width: 50.mm.to_f, depth: 200.mm.to_f, edge_members: true)
      sel(slope)
      r3 = run(:purlins, spacing: 900.mm.to_f, width: 50.mm.to_f, depth: 50.mm.to_f, edge_members: true, side: :above)
      [r[:ok] && r2[:ok] && r3[:ok] && near(h, exp, 1), "#{r[:message]} | #{r2[:message]} | #{r3[:message]}"]
    end

    check('roof gable with thickness') do
      f = rect(0, 0, 6000, 8000)
      sel(f)
      r = run(:roof, type: :gable, pitch: 35.0, overhang: 300.mm.to_f, thickness: 200.mm.to_f)
      g = ents.grep(Sketchup::Group).first
      shell = g.entities.grep(Sketchup::Group).first
      [r[:ok] && shell&.manifold?, r[:message]]
    end

    check('roof shed') do
      f = rect(0, 0, 4000, 3000)
      sel(f)
      r = run(:roof, type: :shed, pitch: 10.0, overhang: 0.0, thickness: 0.0)
      [r[:ok], r[:message]]
    end

    check('columns at cpoints + footing') do
      cps = [[0, 0], [6000, 0], [6000, 6000]].map { |x, y| ents.add_cpoint(pt(x, y)) }
      sel(cps)
      r = run(:columns, shape: :round, size_x: 400.mm.to_f, size_y: 400.mm.to_f, height: 3000.mm.to_f,
                        footing: true, footing_size: 1200.mm.to_f, footing_depth: 500.mm.to_f)
      inst = ents.grep(Sketchup::ComponentInstance)
      [r[:ok] && inst.size == 3 && near(mm(inst.first.bounds.min.z), -500), r[:message]]
    end

    check('beams on edges') do
      e = ents.add_line(pt(0, 0, 3000), pt(6000, 0, 3000))
      sel(e)
      r = run(:beams, width: 200.mm.to_f, depth: 400.mm.to_f, align: :top)
      g = ents.grep(Sketchup::Group).first
      [r[:ok] && near(mm(g.bounds.min.z), 2600) && near(mm3(g.volume), 6000 * 200 * 400.0, 1e5), r[:message]]
    end


    # --- 0.2: сечения ---
    AT::Profiles::KINDS.each do |kind|
      check("beam profile #{kind}") do
        e = ents.add_line(pt(0, 0, 3000), pt(4000, 0, 3000))
        sel(e)
        r = run(:beams, profile: kind, width: 200.mm.to_f, depth: 300.mm.to_f, web: 10.mm.to_f,
                        flange: 15.mm.to_f, align: :top)
        g = groups.first
        loops = AT::Profiles.loops(kind, 200.mm.to_f, %i[round chs].include?(kind) ? 200.mm.to_f : 300.mm.to_f,
                                   10.mm.to_f, 15.mm.to_f)
        exp = section_area(loops) * 4000
        v = g ? mm3(g.volume) : -1
        [r[:ok] && g.manifold? && (v - exp).abs / exp < 0.002 && near(mm(g.bounds.max.z), 3000, 1),
         "#{r[:message]} vol=#{(v / 1e6).round(2)} exp=#{(exp / 1e6).round(2)} дм³"]
      end
    end

    check('profile sweep: tube along L path and closed loop') do
      ents.add_curve(pt(0, 0, 0), pt(2000, 0, 0), pt(2000, 2000, 1000))
      ents.add_curve(pt(4000, 0, 0), pt(5000, 0, 0), pt(5000, 1000, 0), pt(4000, 1000, 0), pt(4000, 0, 0))
      sel(ents.grep(Sketchup::Edge))
      r = run(:profile_sweep, profile: :chs, width: 50.mm.to_f, web: 4.mm.to_f, align: :center, segments: 16)
      gs = groups
      [r[:ok] && gs.size == 2 && gs.all?(&:manifold?), "#{r[:message]} manifold=#{gs.map(&:manifold?)}"]
    end

    check('profile sweep refuses wall thicker than tube') do
      ents.add_line(pt(0, 0), pt(1000, 0))
      sel(ents.grep(Sketchup::Edge))
      r = run(:profile_sweep, profile: :chs, width: 50.mm.to_f, web: 30.mm.to_f, align: :center, segments: 16)
      [!r[:ok] && r[:message] == AT.t(:err_wall_thick) && groups.empty?, r[:message]]
    end

    # --- 0.2: проёмы ---
    { arch: [900, 2100], round: [800, 800] }.each do |shape, (w, h)|
      check("opening #{shape} + lining") do
        ents.add_line(pt(0, 0), pt(3000, 0))
        sel(ents.grep(Sketchup::Edge))
        run(:wall, thickness: 250.mm.to_f, height: 3000.mm.to_f, align: :center)
        ents.erase_entities(ents.grep(Sketchup::Edge))
        wall = groups.first
        v0 = mm3(wall.volume)
        wall.explode
        face = ents.grep(Sketchup::Face).max_by { |f| f.normal.y.abs * f.area }
        sel(face)
        r = run(:opening, source: :size, shape: shape, width: w.mm.to_f, height: h.mm.to_f, sill: 300.mm.to_f,
                          position: :center, segments: 24, frame: true, frame_width: 50.mm.to_f)
        lining = groups.first
        g = ents.add_group(ents.grep(Sketchup::Face) + ents.grep(Sketchup::Edge))
        uv = AT::WallTools.opening_outline(shape, 0, 0, w.to_f, h.to_f, 24)
        area = AT::WallTools.polygon_area_uv(uv)
        dv = v0 - mm3(g.volume)
        [r[:ok] && g.manifold? && (dv - area * 250).abs / (area * 250) < 0.002 && lining&.manifold?,
         "#{r[:message]} dv=#{(dv / 1e9).round(4)} exp=#{(area * 250 / 1e9).round(4)} м³"]
      end
    end

    check('opening arch refuses when too low') do
      f = vrect(0, 0, 3000, 3000)
      sel(f)
      r = run(:opening, source: :size, shape: :arch, width: 1200.mm.to_f, height: 500.mm.to_f, sill: 0.0,
                        position: :center, segments: 24, frame: false)
      [!r[:ok] && r[:message] == AT.t(:err_arch_low), r[:message]]
    end

    # --- 0.2: ограждения ---
    AT::Railing::INFILL.each do |infill|
      check("railing infill #{infill}") do
        ents.add_curve(pt(0, 0), pt(3000, 0), pt(3000, 2000))
        sel(ents.grep(Sketchup::Edge))
        r = run(:railing, rail_height: 900.mm.to_f, post_spacing: 1200.mm.to_f, post_size: 50.mm.to_f,
                          handrail: 50.mm.to_f, infill: infill, baluster_spacing: 120.mm.to_f, rails_count: 3,
                          lift: 0.0)
        g = groups.first
        # 3000 → 3 доли + 2000 → 2 доли: 6 стоек.
        posts = g.entities.grep(Sketchup::Group).count { |x| near(mm(x.bounds.width), 50, 0.1) && near(mm(x.bounds.height), 50, 0.1) }
        top = mm(g.bounds.max.z)
        [r[:ok] && posts >= 6 && near(top, 900, 1), "#{r[:message]} posts=#{posts} top=#{top.round}"]
      end
    end

    check('straight stairs with railings') do
      model.selection.clear
      r = run(:straight_stairs, type: :slab, width: 1200.mm.to_f, rise: 3000.mm.to_f, risers: 17,
                                going: 280.mm.to_f, waist: 150.mm.to_f, railing: true, rail_height: 900.mm.to_f,
                                post_spacing: 1200.mm.to_f, post_size: 50.mm.to_f, handrail: 50.mm.to_f,
                                infill: :balusters, baluster_spacing: 120.mm.to_f, rails_count: 3)
      g = groups.first
      rails = named(g.entities, :name_railing).size
      [r[:ok] && rails == 2 && near(mm(g.bounds.max.z), 3900, 10), "#{r[:message]} railings=#{rails}"]
    end

    # --- 0.2: лестница с площадкой ---
    %i[l_left l_right u_left u_right].each do |turn|
      check("landing stairs #{turn}") do
        model.selection.clear
        r = run(:landing_stairs, turn: turn, type: :slab, width: 1100.mm.to_f, rise: 3000.mm.to_f, risers: 18,
                                 first_flight: 9, going: 280.mm.to_f, gap: 100.mm.to_f, waist: 150.mm.to_f,
                                 railing: true, rail_height: 900.mm.to_f, post_spacing: 1200.mm.to_f,
                                 post_size: 50.mm.to_f, handrail: 50.mm.to_f, infill: :rails, rails_count: 3)
        g = groups.first
        b = g.bounds
        flights = named(g.entities, :name_flight).size
        rails = named(g.entities, :name_railing).size
        # Площадка на высоте 9 подступёнков, второй марш доходит до 3000.
        land = named(g.entities, :name_landing).first
        dx = mm(b.width).round
        dy = mm(b.height).round
        exp_dx = 8 * 280 + 1100
        exp_dy = turn.to_s.start_with?('l') ? 1100 + 8 * 280 : 2 * 1100 + 100
        stairs_top = g.entities.grep(Sketchup::Group).reject { |x| x.name == AT.t(:name_railing) }.map { |x| mm(x.bounds.max.z) }.max
        [r[:ok] && flights == 2 && rails == 3 && land && near(mm(land.bounds.max.z), 1500, 1) &&
          near(stairs_top, 3000, 1) && (dx - exp_dx).abs <= 60 && (dy - exp_dy).abs <= 60,
         "#{r[:message]} plan=#{dx}x#{dy} exp≈#{exp_dx}x#{exp_dy} top=#{stairs_top.round}"]
      end
    end

    check('landing stairs refuses short flight') do
      model.selection.clear
      r = run(:landing_stairs, turn: :l_left, risers: 10, first_flight: 9)
      [!r[:ok] && r[:message] == AT.t(:err_flight_short) && groups.empty?, r[:message]]
    end

    check('escalator') do
      model.selection.clear
      r = run(:escalator, width: 1000.mm.to_f, rise: 4500.mm.to_f, angle: :a30, landing: 1200.mm.to_f,
                          balustrade: 1000.mm.to_f, truss_depth: 1100.mm.to_f)
      g = groups.first
      b = g.bounds
      run_len = mm(b.width)
      n = (4500 / 200.0).ceil
      exp = (n - 1) * (4500.0 / n) / Math.tan(30 * Math::PI / 180) + 2 * 1200
      handrails = named(g.entities, :name_handrail).size
      [r[:ok] && (run_len - exp).abs < 2 && near(mm(b.max.z), 5520, 2) && handrails == 2,
       "#{r[:message]} run=#{run_len.round} exp≈#{exp.round} top=#{mm(b.max.z).round}"]
    end

    # --- 0.2: кровля по выпуклому контуру ---
    check('roof hip over hexagon') do
      hex = (0...6).map { |i| a = Math::PI / 3 * i; pt(5000 * Math.cos(a), 5000 * Math.sin(a), 3000) }
      f = ents.add_face(hex)
      sel(f)
      r = run(:roof, type: :hip, pitch: 30.0, overhang: 0.0, thickness: 0.0)
      g = groups.first
      h = mm(g.bounds.max.z) - 3000
      exp = 5000 * Math.cos(Math::PI / 6) * Math.tan(30 * Math::PI / 180)
      faces = g.entities.grep(Sketchup::Face).size
      [r[:ok] && near(h, exp, 1) && faces == 6, "#{r[:message]} h=#{h.round} exp=#{exp.round} faces=#{faces}"]
    end

    check('roof hip over trapezoid with overhang and thickness') do
      f = ents.add_face(pt(0, 0, 3000), pt(12_000, 0, 3000), pt(9000, 5000, 3000), pt(3000, 5000, 3000))
      sel(f)
      r = run(:roof, type: :hip, pitch: 25.0, overhang: 400.mm.to_f, thickness: 150.mm.to_f)
      g = groups.first
      shell = g.entities.grep(Sketchup::Group).first
      [r[:ok] && shell&.manifold? && mm(g.bounds.min.x) < -300, "#{r[:message]} manifold=#{shell&.manifold?}"]
    end

    check('roof refuses concave outline') do
      f = ents.add_face(pt(0, 0), pt(6000, 0), pt(6000, 3000), pt(3000, 3000), pt(3000, 6000), pt(0, 6000))
      sel(f)
      r = run(:roof, type: :hip, pitch: 30.0, overhang: 0.0, thickness: 0.0)
      [!r[:ok] && r[:message] == AT.t(:err_roof_concave) && groups.empty?, r[:message]]
    end

    # --- 0.2: выравнивание ---
    check('align objects: min, center, distribute') do
      boxes = [[0, 0], [700, 300], [3000, 900]].map do |x, y|
        g = ents.add_group
        g.entities.add_face(pt(x, y), pt(x + 200, y), pt(x + 200, y + 200), pt(x, y + 200)).pushpull(-200.mm)
        g
      end
      sel(boxes)
      r1 = run(:align_objects, axis: :y, mode: :min, reference: :extreme)
      ys = boxes.map { |g| mm(g.bounds.min.y).round }
      sel(boxes)
      r2 = run(:align_objects, axis: :x, mode: :distribute)
      xs = boxes.map { |g| mm(g.bounds.center.x).round }.sort
      sel(boxes)
      r3 = run(:align_objects, axis: :z, mode: :center, reference: :largest)
      [r1[:ok] && r2[:ok] && r3[:ok] && ys.uniq == [0] && xs == [100, 1600, 3100], "y=#{ys} x=#{xs}"]
    end

    # Покрытие считаем по функциональным проверкам — до проверок отказа.
    @functional = @tested.keys

    # --- каждый инструмент: отказ на пустом выделении и одна отмена ---
    no_selection = %i[straight_stairs spiral_stairs landing_stairs escalator columns]
    AT::Registry.all.each do |tool|
      next if no_selection.include?(tool.id)

      check("empty selection refused: #{tool.id}") do
        model.selection.clear
        r = run(tool.id)
        [!r[:ok] && r[:message].to_s.length > 5 && ents.size == 1, r[:message]]
      end
    end

    check('one undo step per run') do
      results = []
      { wall: -> { ents.add_curve(pt(0, 0), pt(3000, 0), pt(3000, 2000)) },
        louvres: -> { [vrect(0, 0, 2000, 2000)] },
        straight_stairs: -> { [] } }.each do |id, setup|
        wipe
        made = setup.call
        sel(made)
        before = ents.size
        run(id)
        after_run = ents.size
        Sketchup.undo
        results << [id, before, after_run, ents.size]
      end
      [results.all? { |_, b, a, u| a > b && u == b }, results.inspect]
    end

    check('refusals are clean') do
      model.selection.clear
      r = run(:fillet)
      [!r[:ok] && r[:message] == AT.t(:need_two_edges) && ents.size == 1, r[:message]]
    end

    wipe
    missed = AT::Registry.all.map(&:id) - @functional
    @results << [missed.empty? ? 'PASS' : 'FAIL', 'every tool has a live check', missed.empty? ? "#{@functional.size} tools" : "missed: #{missed.join(', ')}"]
    @results
  end
end

res = ATLive.all
res.each { |s, n, i| puts "#{s.ljust(4)} #{n} — #{i}" }
"#{res.count { |r| r[0] == 'PASS' }}/#{res.size} passed"
