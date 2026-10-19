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

  # ARCHITOOLS_ONLY=regexp — гонять только подходящие проверки (отладка).
  def check(name)
    return if ENV['ARCHITOOLS_ONLY'] && name !~ Regexp.new(ENV['ARCHITOOLS_ONLY'])

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


    # --- 0.3: точки и грани по кликам (точки передаются как после кликов) ---
    check('divide: from middle, max length, midpoints') do
      e = ents.add_line(pt(0, 0), pt(1000, 0))
      sel(e)
      r1 = run(:divide, by: :from_middle, seg_length: 300.mm.to_f, output: :points)
      xs1 = ents.grep(Sketchup::ConstructionPoint).map { |c| mm(c.position.x).round }.sort
      wipe
      e = ents.add_line(pt(0, 0), pt(1000, 0))
      sel(e)
      r2 = run(:divide, by: :max_length, seg_length: 300.mm.to_f, output: :split)
      lens = ents.grep(Sketchup::Edge).map { |x| mm(x.length).round }.sort
      wipe
      e = ents.add_line(pt(0, 0), pt(1000, 0))
      sel(e)
      r3 = run(:divide, by: :count, count: 4, output: :midpoints)
      xs3 = ents.grep(Sketchup::ConstructionPoint).map { |c| mm(c.position.x).round }.sort
      [r1[:ok] && r2[:ok] && r3[:ok] && xs1 == [200, 500, 800] && lens == [250, 250, 250, 250] &&
        xs3 == [125, 375, 625, 875], "mid=#{xs1} max=#{lens} midpoints=#{xs3}"]
    end

    check('point on face: wall light 600 / 1800') do
      f = vrect(0, 0, 3000, 3000)
      sel(f)
      r = run(:point_on_face, dist_h: 600.mm.to_f, dist_v: 1800.mm.to_f,
                              points: [pt(3000, 0, 0), pt(2000, 0, 0)])
      c = ents.grep(Sketchup::ConstructionPoint).first
      p = c && [mm(c.position.x).round, mm(c.position.y).round, mm(c.position.z).round]
      [r[:ok] && p == [2400, 0, 1800], "#{r[:message]} #{p.inspect}"]
    end

    check('perpendicular to edge and to face') do
      e = ents.add_line(pt(0, 0), pt(2000, 0))
      f = ents.add_face(pt(0, 0, 3000), pt(2000, 0, 3000), pt(2000, 2000, 3000), pt(0, 2000, 3000))
      model.selection.clear
      r1 = run(:perpendicular, output: :edge, points: [pt(500, 800), pt(0, 0)],
                               picked: [{}, { edge_line: [pt(0, 0), Geom::Vector3d.new(1, 0, 0)] }])
      r2 = run(:perpendicular, output: :edge, points: [pt(700, 700, 1000), pt(0, 0, 3000)],
                               picked: [{}, { face_plane: [pt(0, 0, 3000), Geom::Vector3d.new(0, 0, 1)] }])
      lines = ents.grep(Sketchup::Edge).reject { |x| x == e || f.edges.include?(x) }
      ends = lines.map { |x| x.vertices.map { |v| v.position.to_a.map { |c| mm(c).round } }.sort }
      [r1[:ok] && r2[:ok] && ends.include?([[500, 0, 0], [500, 800, 0]]) && ends.include?([[700, 700, 1000], [700, 700, 3000]]),
       "#{r1[:message]} / #{r2[:message]} #{ends.inspect}"]
    end

    check('face on plane: outline projected onto tilted plane') do
      model.selection.clear
      plane = [pt(0, 0, 0), pt(1000, 0, 0), pt(0, 1000, 1000)]
      outline = [pt(0, 0, 500), pt(1000, 0, -300), pt(1000, 1000, 77), pt(0, 1000, 2000)]
      r = run(:face_on_plane, points: plane + outline)
      f = ents.grep(Sketchup::Face).first
      ok = f && f.vertices.all? { |v| (mm(v.position.z) - mm(v.position.y)).abs < 0.01 }
      [r[:ok] && ok && f.vertices.size == 4, r[:message]]
    end

    check('best fit face from non-coplanar points') do
      model.selection.clear
      r = run(:best_fit_face, points: [pt(0, 0, 0), pt(2000, 0, 15), pt(2000, 2000, -10), pt(0, 2000, 8)])
      f = ents.grep(Sketchup::Face).first
      [r[:ok] && f && f.vertices.size == 4 && (f.area * 645.16 - 4.0e6).abs < 1.0e4, r[:message]]
    end

    check('move vertex stretches the box') do
      g = ents.add_face(pt(0, 0), pt(1000, 0), pt(1000, 1000), pt(0, 1000))
      g.pushpull(-1000.mm)
      model.selection.clear
      r = run(:move_vertex, points: [pt(1000, 1000, 1000), pt(1500, 1500, 1500)],
                            picked: [{ vertex_position: pt(1000, 1000, 1000) }, {}])
      top = ents.grep(Sketchup::Edge).flat_map(&:vertices).uniq.map { |v| v.position.to_a.map { |c| mm(c).round } }
      [r[:ok] && top.include?([1500, 1500, 1500]) && !top.include?([1000, 1000, 1000]), r[:message]]
    end

    check('align by 3 points onto a slope') do
      g = ents.add_group
      g.entities.add_face(pt(0, 0), pt(1000, 0), pt(1000, 500), pt(0, 500)).pushpull(-200.mm)
      sel(g)
      a = Math::PI / 6
      t = ->(x, y) { pt(5000 + x * Math.cos(a), y, 1000 + x * Math.sin(a)) }
      r = run(:align_3pt, scale: false, points: [pt(0, 0), pt(1000, 0), pt(0, 500), t[0, 0], t[1000, 0], t[0, 500]])
      b = g.bounds
      zmin = mm(b.min.z)
      xmin = mm(b.min.x)
      [r[:ok] && near(xmin, 5000 - 200 * Math.sin(a), 1) && near(zmin, 1000, 1), "x=#{xmin.round} z=#{zmin.round}"]
    end

    check('extrude keeping taper (frustum)') do
      base = ents.add_face(pt(0, 0), pt(2000, 0), pt(2000, 2000), pt(0, 2000))
      base.reverse! if base.normal.z.positive?
      top = [pt(500, 500, 1000), pt(1500, 500, 1000), pt(1500, 1500, 1000), pt(500, 1500, 1000)]
      bot = [pt(0, 0), pt(2000, 0), pt(2000, 2000), pt(0, 2000)]
      4.times { |i| ents.add_face(bot[i], bot[(i + 1) % 4], top[(i + 1) % 4], top[i]) }
      tf = ents.add_face(top)
      tf.reverse! if tf.normal.z.negative?
      sel(tf)
      r = run(:extrude_taper, distance: 500.mm.to_f)
      g = ents.add_group(ents.grep(Sketchup::Face) + ents.grep(Sketchup::Edge))
      zmax = mm(g.bounds.max.z)
      topf = g.entities.grep(Sketchup::Face).select { |f| f.normal.parallel?(Geom::Vector3d.new(0, 0, 1)) }.max_by { |f| f.bounds.max.z }
      side = mm(topf.bounds.width)
      [r[:ok] && g.manifold? && near(zmax, 1500, 0.5) && near(side, 500, 0.5), "#{r[:message]} z=#{zmax.round} top=#{side.round}"]
    end

    check('revolve: cylinder surface and closed torus') do
      line = ents.add_line(pt(500, 0, 0), pt(500, 0, 1000))
      sel(line)
      r1 = run(:revolve, angle: 360.0, segments: 24, scale: 1.0, rise: 0.0, points: [pt(0, 0, 0), pt(0, 0, 1000)])
      cyl = groups.first
      area = cyl.entities.grep(Sketchup::Face).sum(&:area) * 645.16
      exp = 24 * 2 * 500 * Math.sin(Math::PI / 24) * 1000
      wipe
      ring = ents.add_circle(pt(1000, 0, 0), Geom::Vector3d.new(0, 1, 0), 200.mm, 12)
      sel(ring)
      r2 = run(:revolve, angle: 360.0, segments: 24, scale: 1.0, rise: 0.0, points: [pt(0, 0, 0), pt(0, 0, 1000)])
      torus = groups.first
      [r1[:ok] && r2[:ok] && (area - exp).abs / exp < 0.001 && torus.manifold?, "area=#{area.round} exp=#{exp.round} torus=#{torus.manifold?}"]
    end

    check('revolve with scale and rise (horn)') do
      line = ents.add_line(pt(500, 0, 0), pt(600, 0, 0))
      sel(line)
      r = run(:revolve, angle: 720.0, segments: 48, scale: 0.2, rise: 2000.mm.to_f, points: [pt(0, 0, 0), pt(0, 0, 1000)])
      g = groups.first
      [r[:ok] && near(mm(g.bounds.max.z), 2000, 1) && g.entities.grep(Sketchup::Face).size > 40, r[:message]]
    end

    check('horizontal slice: 3 cuts on a wall') do
      f = vrect(0, 0, 3000, 3000)
      sel(f)
      r = run(:horizontal_slice, base: 0.0, height: 1000.mm.to_f, count: 2, interval: 1000.mm.to_f)
      [r[:ok] && ents.grep(Sketchup::Face).size == 3, "#{r[:message]} faces=#{ents.grep(Sketchup::Face).size}"]
    end

    check('horizontal grooves recess and ribs') do
      ents.add_line(pt(0, 0), pt(3000, 0)).tap { |e| sel(e) }
      run(:wall, thickness: 200.mm.to_f, height: 2000.mm.to_f, align: :left)
      ents.erase_entities(ents.grep(Sketchup::Edge))
      w = groups.first
      v0 = mm3(w.volume)
      w.explode
      f = ents.grep(Sketchup::Face).find { |x| x.normal.y < -0.99 }
      sel(f)
      r = run(:horizontal_grooves, start: 300.mm.to_f, interval: 400.mm.to_f, groove: 20.mm.to_f, depth: 10.mm.to_f)
      g = ents.add_group(ents.grep(Sketchup::Face) + ents.grep(Sketchup::Edge))
      dv = v0 - mm3(g.volume)
      n = 5 # 300, 700, 1100, 1500, 1900 — последняя упирается в верх (1920 < 2000)
      exp = n * 20 * 10 * 3000.0
      [r[:ok] && g.manifold? && (dv - exp).abs / exp < 0.001, "#{r[:message]} dv=#{dv.round} exp=#{exp.round}"]
    end

    check('rectangular array 3×2×2') do
      g = ents.add_group
      g.entities.add_face(pt(0, 0), pt(100, 0), pt(100, 100), pt(0, 100))
      sel(g)
      r = run(:rectangular_array, cols: 3, rows: 2, levels: 2, dx: 1000.mm.to_f, dy: 500.mm.to_f, dz: 3000.mm.to_f)
      ps = groups.map { |x| [mm(x.bounds.min.x).round, mm(x.bounds.min.y).round, mm(x.bounds.min.z).round] }.sort
      [r[:ok] && ps.size == 12 && ps.last == [2000, 500, 3000], "#{r[:message]} last=#{ps.last}"]
    end

    check('path array: count along L path, turned') do
      g = ents.add_group
      g.entities.add_face(pt(-100, -20), pt(100, -20), pt(100, 20), pt(-100, 20))
      ents.add_curve(pt(0, 0), pt(2000, 0), pt(2000, 2000))
      sel(g, ents.grep(Sketchup::Edge))
      r = run(:path_array, mode: :count, count: 5, follow: true)
      cs = groups.drop(1).map { |x| [mm(x.bounds.center.x).round, mm(x.bounds.center.y).round, mm(x.bounds.width).round] }
      last = cs.max_by { |x, y, _| y }
      [r[:ok] && cs.size == 5 && last[0] == 2000 && last[1] == 2000 && last[2] == 40, "#{r[:message]} #{cs.inspect}"]
    end

    check('path array: max spacing on closed loop') do
      g = ents.add_group
      g.entities.add_face(pt(-50, -50), pt(50, -50), pt(50, 50), pt(-50, 50))
      ents.add_curve(pt(0, 0), pt(3000, 0), pt(3000, 3000), pt(0, 3000), pt(0, 0))
      sel(g, ents.grep(Sketchup::Edge))
      r = run(:path_array, mode: :max_spacing, spacing: 1100.mm.to_f, follow: false)
      [r[:ok] && groups.size == 1 + 11, "#{r[:message]} groups=#{groups.size}"]
    end


    # --- 0.3: окна, стены, колонны, фундаменты ---
    check('window: casement, sliding, rebated, casing, positions') do
      res = []
      { casement: [2, 2], sliding: [2, 2] }.each do |type, (sashes, panes)|
        wipe
        sel(vrect(0, 0, 1800, 1500))
        r = run(:window, type: type, cols: 2, rows: 1, profile: :flat, position: :back, frame_width: 60.mm.to_f,
                         frame_depth: 70.mm.to_f, mullion: 50.mm.to_f, sash_width: 50.mm.to_f, inset: 0.0, glass: true)
        w = groups.first
        s = named(w.entities, :name_sash).size
        g = named(w.entities, :name_glass).first
        res << [type, r[:ok] && s == sashes && g && g.entities.grep(Sketchup::Face).size == panes]
      end
      { rebated: 2, casing: 2 }.each do |profile, frames|
        wipe
        sel(vrect(0, 0, 1800, 1500))
        r = run(:window, type: :fixed, cols: 1, rows: 1, profile: profile, position: :back, frame_width: 60.mm.to_f,
                         frame_depth: 70.mm.to_f, mullion: 50.mm.to_f, sash_width: 50.mm.to_f, inset: 0.0, glass: true)
        w = groups.first
        n = named(w.entities, :name_frame).size + named(w.entities, :name_casing).size
        res << [profile, r[:ok] && n == frames]
      end
      { back: [0, 70], middle: [-35, 35], front: [-70, 0] }.each do |pos, (y0, y1)|
        wipe
        f = vrect(0, 0, 1800, 1500) # грань в плоскости y = 0, нормаль −Y (наружу)
        f.reverse! if f.normal.y.positive?
        sel(f)
        r = run(:window, type: :fixed, cols: 1, rows: 1, profile: :flat, position: pos, frame_width: 60.mm.to_f,
                         frame_depth: 70.mm.to_f, mullion: 50.mm.to_f, sash_width: 50.mm.to_f, inset: 0.0, glass: false)
        b = groups.first.bounds
        res << [pos, r[:ok] && near(mm(b.min.y), y0, 0.5) && near(mm(b.max.y), y1, 0.5)]
      end
      [res.all? { |x| x[1] == true }, res.inspect]
    end

    check('wall kinds: cavity and stud partition') do
      ents.add_line(pt(0, 0), pt(4000, 0)).tap { |e| sel(e) }
      r1 = run(:wall, kind: :cavity, height: 3000.mm.to_f, align: :center, leaf: 120.mm.to_f, leaf_inner: 100.mm.to_f,
                      cavity: 60.mm.to_f, follow_slope: false)
      w = groups.first
      layers = w.entities.grep(Sketchup::Group)
      vol = layers.sum { |l| mm3(l.volume) }
      ok1 = r1[:ok] && layers.size == 2 && layers.all?(&:manifold?) && (vol - 4000 * 3000 * 220.0).abs < 1.0e5 &&
            near(mm(w.bounds.height), 280, 0.5)
      wipe
      ents.add_line(pt(0, 0), pt(4000, 0)).tap { |e| sel(e) }
      r2 = run(:wall, kind: :stud, height: 2700.mm.to_f, align: :left, leaf: 12.5.mm.to_f, cavity: 75.mm.to_f,
                      stud_spacing: 600.mm.to_f, stud_width: 50.mm.to_f, follow_slope: false)
      w = groups.first
      studs = named(w.entities, :name_stud).size
      [ok1 && r2[:ok] && studs == 8, "cavity vol=#{(vol / 1e9).round(3)} studs=#{studs}"]
    end

    check('wall: own section from face and follow slope') do
      sec = ents.add_face(pt(-150, -2000), pt(150, -2000), pt(150, -1000), pt(250, -1000), pt(250, -900), pt(-250, -900),
                          pt(-250, -1000), pt(-150, -1000))
      line = ents.add_curve(pt(0, 0, 0), pt(3000, 0, 0), pt(6000, 0, 1000))
      sel(sec, line)
      r = run(:wall, kind: :solid, thickness: 250.mm.to_f, height: 3000.mm.to_f, align: :center, follow_slope: true)
      w = groups.find { |g| g.name == AT.t(:name_wall) }
      top = mm(w.bounds.max.z)
      # Сечение 300×1000 + полка 500×100; высота сечения 1100.
      [r[:ok] && w.manifold? && near(top, 2100, 1) && near(mm(w.bounds.height), 500, 1), "top=#{top.round}"]
    end

    check('columns: all six types') do
      res = []
      %i[rect round ellipse capital tuscan tuscan_round].each_with_index do |shape, i|
        cp = ents.add_cpoint(pt(i * 2000, 0))
        sel(cp)
        r = run(:columns, shape: shape, size_x: 400.mm.to_f, size_y: 300.mm.to_f, height: 3000.mm.to_f, footing: false)
        inst = ents.grep(Sketchup::ComponentInstance).last
        b = inst.bounds
        solids = inst.definition.entities.grep(Sketchup::Group)
        loose_ok = inst.definition.entities.grep(Sketchup::Face).empty? || inst.definition.entities.grep(Sketchup::Face).size > 2
        res << [shape, r[:ok] && near(mm(b.max.z), 3000, 0.5) && near(mm(b.min.z), 0, 0.5) && loose_ok &&
                       solids.all?(&:manifold?)]
      end
      [res.all? { |x| x[1] == true }, res.inspect]
    end

    check('pad footing at points, strip footing along L') do
      cps = [[0, 0], [5000, 0]].map { |x, y| ents.add_cpoint(pt(x, y)) }
      sel(cps)
      r1 = run(:pad_footing, pad_x: 1500.mm.to_f, pad_y: 1200.mm.to_f, pad_depth: 400.mm.to_f, stump: 400.mm.to_f,
                             stump_height: 600.mm.to_f)
      inst = ents.grep(Sketchup::ComponentInstance)
      b = inst.first.bounds
      ok1 = r1[:ok] && inst.size == 2 && near(mm(b.min.z), -1000, 0.5) && near(mm(b.width), 1500, 0.5)
      wipe
      ents.add_curve(pt(0, 0), pt(6000, 0), pt(6000, 4000)).tap { |c| sel(c) }
      r2 = run(:strip_footing, footing_width: 600.mm.to_f, footing_depth: 300.mm.to_f, wall_width: 300.mm.to_f,
                               wall_height: 600.mm.to_f, align: :center)
      g = groups.first
      area = 600 * 300 + 300 * 600
      exp = area * 10_000.0 # прямой угол «в ус» сохраняет объём по осевой линии
      v = mm3(g.volume)
      [ok1 && r2[:ok] && g.manifold? && (v - exp).abs / exp < 0.002, "pad=#{ok1} strip v=#{(v / 1e9).round(3)} exp=#{(exp / 1e9).round(3)}"]
    end

    check('joists with I-beam profile, rafters with fascia') do
      f = rect(0, 0, 4000, 3000, 3000)
      sel(f)
      r1 = run(:joists, direction: :short, spacing: 600.mm.to_f, width: 100.mm.to_f, depth: 200.mm.to_f,
                        edge_members: true, side: :below, profile: :i_beam, web: 6.mm.to_f, flange: 8.mm.to_f)
      g = groups.first
      bars = g.entities.grep(Sketchup::Group)
      ok1 = r1[:ok] && bars.size == 8 && bars.all?(&:manifold?) && near(mm(g.bounds.min.z), 2800, 0.5)
      wipe
      slope = ents.add_face(pt(0, 0, 3000), pt(6000, 0, 3000), pt(6000, 3000, 4500), pt(0, 3000, 4500))
      sel(slope)
      r2 = run(:rafters, spacing: 600.mm.to_f, width: 50.mm.to_f, depth: 200.mm.to_f, edge_members: true,
                         profile: :rect, fascia: true, fascia_height: 250.mm.to_f, fascia_thickness: 25.mm.to_f)
      g = groups.first
      fascia = named(g.entities, :name_fascia).size
      [ok1 && r2[:ok] && fascia == 1, "joists=#{ok1} fascia=#{fascia}"]
    end

    check('winder stairs left/right and mono stringer') do
      res = []
      %i[left right].each do |turn|
        wipe
        model.selection.clear
        r = run(:winder_stairs, turn: turn, type: :solid, width: 1000.mm.to_f, rise: 2800.mm.to_f, risers: 16,
                                first_flight: 6, winders: 3, going: 270.mm.to_f, tread_thickness: 40.mm.to_f)
        g = groups.first
        b = g.bounds
        steps = g.entities.grep(Sketchup::Group).size
        n2 = 16 - 1 - 6 - 3
        ylen = 1000 + n2 * 270
        res << [turn, r[:ok] && steps == 15 && near(mm(b.max.z), 15 * 175, 0.5) && near(mm(b.height), ylen, 0.5) &&
                      near(mm(b.width), 6 * 270 + 1000, 0.5) && (turn == :left ? near(mm(b.min.y), 0, 0.5) : near(mm(b.max.y), 1000, 0.5))]
      end
      wipe
      model.selection.clear
      r = run(:straight_stairs, type: :mono, width: 1000.mm.to_f, rise: 3000.mm.to_f, risers: 17, going: 280.mm.to_f,
                                tread_thickness: 40.mm.to_f, nosing: 20.mm.to_f, stringer_width: 120.mm.to_f,
                                stringer_depth: 250.mm.to_f, railing: false)
      g = groups.first
      parts = g.entities.grep(Sketchup::Group)
      stringer = parts.select { |x| near(mm(x.bounds.height), 120, 0.5) }
      res << [:mono, r[:ok] && parts.size == 17 && stringer.size == 1]
      [res.all? { |x| x[1] == true }, res.inspect]
    end

    # --- 0.3: кровля по любому контуру ---
    check('roof hip over L-shape and courtyard') do
      f = ents.add_face(pt(0, 0, 3000), pt(10_000, 0, 3000), pt(10_000, 4000, 3000), pt(4000, 4000, 3000),
                        pt(4000, 10_000, 3000), pt(0, 10_000, 3000))
      sel(f)
      r1 = run(:roof, type: :hip, pitch: 30.0, overhang: 0.0, thickness: 0.0)
      g = groups.first
      h1 = mm(g.bounds.max.z) - 3000
      n1 = g.entities.grep(Sketchup::Face).size
      wipe
      outer = ents.add_face(pt(0, 0, 3000), pt(12_000, 0, 3000), pt(12_000, 10_000, 3000), pt(0, 10_000, 3000))
      hole = ents.add_face(pt(4000, 3000, 3000), pt(8000, 3000, 3000), pt(8000, 7000, 3000), pt(4000, 7000, 3000))
      hole.erase!
      outer = ents.grep(Sketchup::Face).first
      sel(outer)
      r2 = run(:roof, type: :hip, pitch: 30.0, overhang: 300.mm.to_f, thickness: 150.mm.to_f)
      g2 = groups.first
      shell = g2.entities.grep(Sketchup::Group).first
      exp = 2000 * Math.tan(30 * Math::PI / 180)
      [r1[:ok] && r2[:ok] && n1 == 6 && near(h1, exp, 1) && shell&.manifold?,
       "L: faces=#{n1} h=#{h1.round} exp=#{exp.round}; двор: #{r2[:message]} manifold=#{shell&.manifold?}"]
    end

    check('roof gable refuses non-rectangle') do
      f = ents.add_face(pt(0, 0), pt(6000, 0), pt(6000, 3000), pt(3000, 3000), pt(3000, 6000), pt(0, 6000))
      sel(f)
      r = run(:roof, type: :gable, pitch: 30.0, overhang: 0.0, thickness: 0.0)
      [!r[:ok] && r[:message] == AT.t(:need_horizontal_rect) && groups.empty?, r[:message]]
    end

    # --- 0.3: фасад ---
    check('perforated screen: 27 round holes') do
      f = vrect(0, 0, 2000, 1000)
      sel(f)
      r = run(:perforated_screen, hole_shape: :round, hole_width: 100.mm.to_f, hole_height: 100.mm.to_f,
                                  spacing_x: 200.mm.to_f, spacing_y: 200.mm.to_f, angle: 0.0, margin: 100.mm.to_f,
                                  thickness: 20.mm.to_f, erase_source: true)
      g = groups.first
      hole = 16 * 0.5 * 50 * 50 * Math.sin(2 * Math::PI / 16)
      exp = (2000 * 1000 - 27 * hole) * 20
      v = mm3(g.volume)
      [r[:ok] && r[:message] == AT.t(:ok_screen, n: 27) && g.manifold? && (v - exp).abs / exp < 0.001,
       "#{r[:message]} v=#{v.round} exp=#{exp.round}"]
    end

    check('perforated screen: rotated rect holes in a triangle') do
      f = ents.add_face(pt(0, 0, 0), pt(3000, 0, 0), pt(1500, 0, 2500))
      sel(f)
      r = run(:perforated_screen, hole_shape: :rect, hole_width: 150.mm.to_f, hole_height: 60.mm.to_f,
                                  spacing_x: 250.mm.to_f, spacing_y: 150.mm.to_f, angle: 30.0, margin: 50.mm.to_f,
                                  thickness: 10.mm.to_f, erase_source: false)
      g = groups.first
      [r[:ok] && g.manifold? && ents.grep(Sketchup::Face).size == 1, r[:message]]
    end

    check('metal deck: trapezoid, corrugated, box') do
      res = []
      %i[trapezoid corrugated box].each do |deck|
        wipe
        f = rect(0, 0, 3000, 2000, 3000)
        sel(f)
        r = run(:metal_deck, deck: deck, direction: :short, pitch: 200.mm.to_f, rib_height: 40.mm.to_f,
                             top_ratio: 0.35, thickness: deck == :box ? 1.mm.to_f : 0.0)
        g = groups.first
        next res << [deck, false, r[:message]] unless g

        b = g.bounds
        area = g.entities.grep(Sketchup::Face).sum(&:area) * 645.16
        res << [deck, r[:ok] && near(mm(b.width), 3000, 1) && near(mm(b.height), 2000, 1) &&
                      near(mm(b.max.z) - mm(b.min.z), deck == :box ? 41 : 40, 1) && area > 6.0e6 &&
                      (deck != :box || g.manifold?)]
      end
      [res.all? { |x| x[1] == true }, res.inspect]
    end

    # --- 0.3: рельеф ---
    terrain = lambda do |&height|
      g = ents.add_group
      mesh = Geom::PolygonMesh.new
      n = 20
      (0...n).each do |i|
        (0...n).each do |j|
          q = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]].map { |a, b| x = a * 1000; y = b * 1000; pt(x, y, height.call(x, y)) }
          mesh.add_polygon(q[0], q[1], q[2])
          mesh.add_polygon(q[0], q[2], q[3])
        end
      end
      g.entities.fill_from_mesh(mesh, true, 0)
      g
    end

    check('cut and fill platform on a slope') do
      t = terrain.call { |x, _y| x * 0.1 }
      pad = ents.add_face(pt(7000, 7000, 1000), pt(13_000, 7000, 1000), pt(13_000, 13_000, 1000), pt(7000, 13_000, 1000))
      sel(t, pad)
      r = run(:cut_fill, level_from: :face, level: 0.0, batter: 45.0, step: 250.mm.to_f, hide_source: true)
      g = groups.find { |x| x.name == AT.t(:name_graded) }
      mesh = AT::Terrain.from([g])
      zc = mm(mesh.height_at(10_000.mm.to_f, 10_000.mm.to_f))
      ze = mm(mesh.height_at(12_900.mm.to_f, 10_000.mm.to_f))
      far = mm(mesh.height_at(19_000.mm.to_f, 1000.mm.to_f))
      cut, fill = r[:message].scan(/(\d+(?:\.\d+))/).flatten.last(2).map(&:to_f)
      [r[:ok] && t.hidden? && near(zc, 1000, 0.5) && near(ze, 1000, 0.5) && near(far, 1900, 1) &&
        cut.positive? && fill.positive? && (cut - fill).abs / cut < 0.15, "#{r[:message]} zc=#{zc.round} far=#{far.round}"]
    end

    check('trace boundary onto terrain') do
      t = terrain.call { |x, y| 500 + 0.05 * x + 0.02 * y }
      out = ents.add_face(pt(3000, 3000, 5000), pt(9000, 3000, 5000), pt(9000, 8000, 5000), pt(3000, 8000, 5000))
      sel(t, out)
      r = run(:trace_boundary)
      g = groups.find { |x| x.name == AT.t(:name_boundary) }
      pts = g.entities.grep(Sketchup::Edge).flat_map(&:vertices).uniq.map(&:position)
      ok = pts.all? { |q| near(mm(q.z), 500 + 0.05 * mm(q.x) + 0.02 * mm(q.y), 0.5) }
      [r[:ok] && ok && pts.size >= 4, "#{r[:message]} points=#{pts.size}"]
    end

    check('contour lines on plane and closed loops on a hill') do
      terrain.call { |x, _y| x * 0.1 }
      model.selection.clear
      r1 = run(:contour_lines, start: 250.mm.to_f, interval: 500.mm.to_f)
      g = groups.find { |x| x.name == AT.t(:name_contours) }
      curves = g.entities.grep(Sketchup::Edge).map(&:curve).compact.uniq
      lens = curves.map { |c| mm(c.edges.sum(&:length)).round }
      wipe
      hill = terrain.call { |x, y| 3000 * Math.exp(-(((x - 10_000)**2) + ((y - 10_000)**2)) / 2.0e7) }
      sel(hill)
      r2 = run(:contour_lines, start: 0.0, interval: 1000.mm.to_f)
      g2 = groups.find { |x| x.name == AT.t(:name_contours) }
      loops = g2.entities.grep(Sketchup::Edge).map(&:curve).compact.uniq
      closed = loops.all? { |c| c.vertices.first.position.distance(c.vertices.last.position).to_f < 0.01 || c.edges.first.start == c.edges.last.end }
      [r1[:ok] && r2[:ok] && lens.size == 4 && lens.uniq == [20_000] && loops.size >= 2 && closed,
       "plane=#{lens} hill=#{r2[:message]} closed=#{closed}"]
    end


    check('pick tool: clicks lead to the same run') do
      model.selection.clear
      tool = AT::PickTool.new(AT::Registry[:best_fit_face], AT::Prefs.values(AT::Registry[:best_fit_face]).merge(place: false))
      tool.instance_variable_set(:@points, [pt(0, 0, 0), pt(1000, 0, 0), pt(1000, 1000, 5), pt(0, 1000, 0)])
      tool.instance_variable_set(:@picked, [{}, {}, {}, {}])
      prompt = AT::PickTool.prompt(AT::Registry[:align_3pt], 4)
      tool.send(:finish)
      f = ents.grep(Sketchup::Face).first
      start = run(:align_3pt, place: false)
      [f && f.vertices.size == 4 && prompt == AT.t(:pk_target2) && !start[:ok], "prompt=#{prompt} start=#{start[:message]}"]
    end


    check('open chain direction is fixed: slope and offset') do
      ents.add_curve(pt(2000, 500), pt(2000, 0), pt(0, 0))
      sel(ents.grep(Sketchup::Edge))
      r1 = run(:slope_edges, by: :gradient, gradient: 10.0, reverse: false)
      zs = ents.grep(Sketchup::Edge).flat_map(&:vertices).uniq.to_h { |v| [[mm(v.position.x).round, mm(v.position.y).round], mm(v.position.z).round] }
      wipe
      e = ents.add_line(pt(1000, 0), pt(0, 0))
      sel(e)
      r2 = run(:offset_edges, distance: 100.mm.to_f, both_sides: false, flip: false)
      ys = ents.grep(Sketchup::Edge).map { |x| mm(x.start.position.y).round }.sort
      [r1[:ok] && r2[:ok] && zs[[0, 0]] == 0 && zs[[2000, 500]] == 250 && ys == [0, 100], "z=#{zs} y=#{ys}"]
    end


    check('louvres: all seven blade profiles, positions, erase face') do
      res = []
      AT::FacadeTools::BLADES.each do |blade|
        wipe
        f = vrect(0, 0, 2000, 2000)
        f.reverse! if f.normal.y.positive?
        sel(f)
        r = run(:louvres, direction: :horizontal, blade: blade, blade_depth: 150.mm.to_f, blade_thickness: 30.mm.to_f,
                          spacing: 250.mm.to_f, angle: 20.0, position: :front, offset: 50.mm.to_f, erase_source: true)
        g = groups.first
        n = blade == :sheet ? g.entities.grep(Sketchup::Face).size : g.entities.grep(Sketchup::Group).size
        solid = %i[sheet].include?(blade) || g.entities.grep(Sketchup::Group).all?(&:manifold?)
        res << [blade, r[:ok] && n == 8 && solid && ents.grep(Sketchup::Face).empty? && mm(g.bounds.max.y) < -40]
      end
      { middle: [-80, 80], back: [49, 260] }.each do |pos, (lo, hi)|
        wipe
        f = vrect(0, 0, 2000, 2000)
        f.reverse! if f.normal.y.positive?
        sel(f)
        r = run(:louvres, direction: :vertical, blade: :flat, blade_depth: 150.mm.to_f, blade_thickness: 20.mm.to_f,
                          spacing: 250.mm.to_f, angle: 0.0, position: pos, offset: 50.mm.to_f, erase_source: false)
        b = groups.first.bounds
        res << [pos, r[:ok] && mm(b.min.y) > lo && mm(b.max.y) < hi]
      end
      [res.all? { |x| x[1] == true }, res.inspect]
    end

    check('slope edges: keep original, slope a copy') do
      ents.add_curve(pt(0, 0), pt(2000, 0), pt(2000, 1000))
      sel(ents.grep(Sketchup::Edge))
      r = run(:slope_edges, by: :height, height: 600.mm.to_f, reverse: false, keep_original: true)
      edges = ents.grep(Sketchup::Edge)
      flat = edges.count { |e| e.start.position.z.to_f.abs < 1e-6 && e.end.position.z.to_f.abs < 1e-6 }
      top = edges.flat_map(&:vertices).map { |v| mm(v.position.z).round }.max
      [r[:ok] && edges.size == 4 && flat == 2 && top == 600, "edges=#{edges.size} flat=#{flat} top=#{top}"]
    end

    # Покрытие считаем по функциональным проверкам — до проверок отказа.
    @functional = @tested.keys

    # --- каждый инструмент: отказ на пустом выделении и одна отмена ---
    no_selection = %i[straight_stairs spiral_stairs landing_stairs escalator winder_stairs columns pad_footing
                      perpendicular face_on_plane best_fit_face move_vertex contour_lines]
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
    return @results if ENV['ARCHITOOLS_ONLY']

    missed = AT::Registry.all.map(&:id) - @functional
    @results << [missed.empty? ? 'PASS' : 'FAIL', 'every tool has a live check', missed.empty? ? "#{@functional.size} tools" : "missed: #{missed.join(', ')}"]
    @results
  end
end

res = ATLive.all
res.each { |s, n, i| puts "#{s.ljust(4)} #{n} — #{i}" }
"#{res.count { |r| r[0] == 'PASS' }}/#{res.size} passed"
