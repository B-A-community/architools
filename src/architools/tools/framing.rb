# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Каркас: балки перекрытия, стропила, прогоны, кровля по прямоугольнику,
    # колонны, балки по рёбрам.
    module FrameTools
      G = Geom3

      module_function

      # Направление вдоль грани по выбору: самое длинное ребро, поперёк него,
      # мировые X / Y.
      def direction(face, mode)
        n = face.normal
        u =
          case mode
          when :long, :short
            longest = face.outer_loop.edges.max_by(&:length)
            d = longest.line[1]
            mode == :short ? n.cross(d) : d
          when :x then G::X
          else Geom::Vector3d.new(0, 1, 0)
          end
        u = u - G.scale(n, u.dot(n))
        u = n.cross(G::X) if u.length.to_f < 1.0e-6
        u.normalize
      end

      # Точки установки: выделенные точки-направляющие или вершины рёбер.
      def insertion_points(ctx)
        points = ctx.cpoints.map(&:position)
        return points unless points.empty?

        ctx.edges.flat_map { |e| e.vertices.map(&:position) }.uniq { |pt| pt.to_a.map { |c| c.to_f.round(4) } }
      end

      def place_definition(ctx, defn, points, ok_key, place_key)
        if points.empty?
          inst = ctx.entities.add_instance(defn, Geom::Transformation.new)
          ctx.made(inst)
          ctx.placing = inst
          return ArchiTools.t(place_key)
        end
        raise UserError, ArchiTools.t(:err_too_many) if points.size > MAX_ITEMS

        points.each { |pt| ctx.made(ctx.entities.add_instance(defn, Geom::Transformation.translation(pt))) }
        ArchiTools.t(ok_key, n: points.size)
      end

      # Тело вращения по профилю [[радиус, z], ...] — кольца из seg
      # сторон; square — квадратные кольца по осям (для квадратных деталей).
      def lathe(entities, profile, seg, square: false)
        rings = profile.map do |r, z|
          n = square ? 4 : seg
          (0...n).map do |i|
            a = 2 * Math::PI * i / n + (square ? Math::PI / 4 : 0)
            rr = square ? r * Math.sqrt(2) : r
            Geom::Point3d.new(rr * Math.cos(a), rr * Math.sin(a), z)
          end
        end
        polys = []
        rings.each_cons(2) do |r1, r2|
          r1.each_index { |i| j = (i + 1) % r1.size; polys << [r1[i], r1[j], r2[j], r2[i]] }
        end
        polys << rings.first.reverse
        polys << rings.last
        g = G.mesh_group(entities, polys)
        ModifyTools.merge_coplanar(g.entities)
        ModifyTools.orient_outward(g.entities)
        ModifyTools.soften_smooth(g.entities, 20) unless square
        g
      end

      # Колонна в начале координат, низ на z = 0.
      def column(e, prm)
        sx = prm[:size_x]
        sy = prm[:size_y]
        h = prm[:height]
        case prm[:shape]
        when :round
          f = e.add_face(e.add_circle(ORIGIN, G::Z, sx / 2.0, 24))
          f.reverse! if f.normal.z.negative?
          f.pushpull(h)
        when :ellipse
          pts = (0...32).map { |i| a = 2 * Math::PI * i / 32; Geom::Point3d.new(sx / 2.0 * Math.cos(a), sy / 2.0 * Math.sin(a), 0) }
          f = e.add_face(pts)
          f.reverse! if f.normal.z.negative?
          f.pushpull(h)
          e.grep(Sketchup::Edge).each { |ed| ed.soft = ed.smooth = true if ed.faces.size == 2 && ed.line[1].parallel?(G::Z) }
        when :capital
          # Прямоугольная с базой и капителью: плиты на 30 % шире ствола.
          bh = [h * 0.06, sx * 0.3].min
          k = 1.3
          G.box(e, Geom::Point3d.new(-sx * k / 2, -sy * k / 2, 0), Geom::Vector3d.new(sx * k, 0, 0),
                Geom::Vector3d.new(0, sy * k, 0), Geom::Vector3d.new(0, 0, bh), ArchiTools.t(:name_base))
          G.box(e, Geom::Point3d.new(-sx / 2, -sy / 2, bh), Geom::Vector3d.new(sx, 0, 0), Geom::Vector3d.new(0, sy, 0),
                Geom::Vector3d.new(0, 0, h - 2 * bh), ArchiTools.t(:name_shaft))
          G.box(e, Geom::Point3d.new(-sx * k / 2, -sy * k / 2, h - bh), Geom::Vector3d.new(sx * k, 0, 0),
                Geom::Vector3d.new(0, sy * k, 0), Geom::Vector3d.new(0, 0, bh), ArchiTools.t(:name_capital))
        when :tuscan, :tuscan_round
          # Тосканский ордер (пропорции упрощённо по Виньоле): квадратный
          # плинт и абака, база-вал, ствол с утонением к верху, эхин.
          d = sx
          square = prm[:shape] == :tuscan
          plinth = 0.07 * h
          abacus = 0.05 * h
          G.box(e, Geom::Point3d.new(-0.68 * d, -0.68 * d, 0), Geom::Vector3d.new(1.36 * d, 0, 0),
                Geom::Vector3d.new(0, 1.36 * d, 0), Geom::Vector3d.new(0, 0, plinth), ArchiTools.t(:name_base))
          prof = [[0.62 * d, plinth], [0.62 * d, plinth + 0.03 * h], [0.5 * d, plinth + 0.04 * h],
                  [0.42 * d, 0.86 * h], [0.47 * d, 0.86 * h], [0.47 * d, 0.88 * h], [0.42 * d, 0.88 * h],
                  [0.42 * d, 0.90 * h], [0.6 * d, h - abacus]]
          lathe(e, prof, 24, square: square)
          G.box(e, Geom::Point3d.new(-0.68 * d, -0.68 * d, h - abacus), Geom::Vector3d.new(1.36 * d, 0, 0),
                Geom::Vector3d.new(0, 1.36 * d, 0), Geom::Vector3d.new(0, 0, abacus), ArchiTools.t(:name_capital))
        else
          G.box(e, Geom::Point3d.new(-sx / 2.0, -sy / 2.0, 0), Geom::Vector3d.new(sx, 0, 0),
                Geom::Vector3d.new(0, sy, 0), Geom::Vector3d.new(0, 0, h))
        end
      end

      # Сечение брусьев каркаса из параметров (nil — обычный прямоугольный брус).
      def section(prm)
        return nil if prm[:profile].nil? || prm[:profile] == :rect

        d = %i[round chs].include?(prm[:profile]) ? prm[:width] : prm[:depth]
        Profiles.loops(prm[:profile], prm[:width], d, prm[:web], prm[:flange])
      end

      def section_params(p, rect_only: false)
        p.choice :profile, :rect, Profiles::KINDS
        p.length :web, 6, show: { profile: Profiles::WALLED }
        p.length :flange, 8, show: { profile: %i[i_beam channel angle tee] }
      end

      # Лобовая доска по карнизу ската: нижние горизонтальные рёбра грани.
      def fascia(entities, face, height, thickness, name)
        zmin = face.vertices.map { |v| v.position.z.to_f }.min
        eaves = face.outer_loop.edges.select do |e|
          (e.start.position.z.to_f - zmin).abs < G.tol && (e.end.position.z.to_f - zmin).abs < G.tol
        end
        center = face.bounds.center
        eaves.map do |e|
          a = e.start.position
          b = e.end.position
          dir = b - a
          inward = G::Z.cross(dir).normalize
          inward = inward.reverse if inward.dot(center - a).negative?
          G.box(entities, a.offset(G::Z, -height), dir, G.scale(inward, thickness), G.scale(G::Z, height), name)
        end.compact
      end

      # Ряд брусьев сечением width × depth вдоль axis, с шагом поперёк.
      # Брусья обрезаются контуром грани; below — под гранью, иначе над ней.
      def members(entities, face, axis, spacing, width, depth, edge_members, below, name, section = nil)
        n = face.normal
        across = n.cross(axis).normalize
        o = face.outer_loop.vertices.first.position
        loops = face.loops.map { |l| l.vertices.map { |v| G.to_uv(v.position, o, axis, across) } }
        _, _, cmin, cmax = G.bounds_uv(loops)
        stations =
          if edge_members
            list = G.stations(cmin + width / 2.0, cmax - width / 2.0, spacing)
            list << cmax - width / 2.0 if list.empty? || (cmax - width / 2.0) - list.last > width
            list
          else
            G.stations(cmin, cmax, spacing, spacing)
          end
        group = entities.add_group
        group.name = name
        shift = below ? -depth : 0.0
        count = 0
        stations.each do |c|
          # Брус шириной width: берём пересечение по его двум кромкам, чтобы
          # не вылезать за наклонный край грани.
          spans = [c - width / 2.0 + G.tol, c + width / 2.0 - G.tol].map { |cc| G.scan_intervals(loops, cc) }
          spans.first.each do |a, b|
            other = spans.last.find { |x, y| x < b && y > a }
            next unless other

            a2 = [a, other[0]].max
            b2 = [b, other[1]].min
            next if b2 - a2 < G::MIN_SIZE * 10

            if section
              # Сечение из библиотеки: ось бруса посередине высоты.
              p0 = G.from_uv(a2, c, o, axis, across, shift + depth / 2.0, n)
              p1 = G.from_uv(b2, c, o, axis, across, shift + depth / 2.0, n)
              Profiles.bar(group.entities, p0, p1, n, section)
            else
              origin = G.from_uv(a2, c - width / 2.0, o, axis, across, shift, n)
              next unless G.box(group.entities, origin, G.scale(axis, b2 - a2), G.scale(across, width), G.scale(n, depth))
            end

            count += 1
            raise UserError, ArchiTools.t(:err_too_many) if count > MAX_ITEMS
          end
        end
        [group, count]
      end

      # Вальма по контуру любой формы, в том числе с дворами, — через прямой
      # скелет. Внешний контур ведём против часовой, дворы — по часовой.
      def skeleton_roof(face, prm)
        z0 = face.vertices.first.position.z.to_f
        clean = lambda do |pts|
          # Лишние вершины на прямой мешают скелету — убираем.
          pts.each_with_index.reject do |pt, i|
            a = pts[i - 1]
            b = pts[(i + 1) % pts.size]
            (pt - a).cross(b - pt).length.to_f < 1.0e-6 * (pt - a).length.to_f * (b - pt).length.to_f
          end.map(&:first)
        end
        loops = face.loops.map do |loop|
          pts = clean.call(loop.vertices.map { |v| q = v.position; Geom::Point3d.new(q.x, q.y, z0) })
          ccw = WallTools.signed_area_xy(pts).positive?
          pts = pts.reverse if ccw != loop.outer?
          # Свес: карниз наружу от стен, у двора — внутрь двора.
          pts = G.offset_polyline(pts, -prm[:overhang], G::Z, true) if prm[:overhang] > G.tol
          pts
        end
        tan = Math.tan(G.deg(prm[:pitch]))
        faces = Skeleton.faces(loops.map { |l| l.map { |pt| [pt.x.to_f, pt.y.to_f] } })
        slopes = faces.map { |poly| poly.map { |x, y, t| Geom::Point3d.new(x, y, z0 + t * tan) } }
        hgt = faces.flatten(1).map { |q| q[2] }.max * tan
        [slopes, [], hgt]
      end

      def roof_polygons(face, prm)
        n = face.normal
        raise UserError, ArchiTools.t(:need_horizontal_face) unless n.parallel?(G::Z)
        return skeleton_roof(face, prm) if prm[:type] == :hip && !WallTools.rectangular?(face)
        raise UserError, ArchiTools.t(:need_horizontal_rect) unless WallTools.rectangular?(face)

        o, u, v, _n, w, h = WallTools.rect_of(face)
        # Прямоугольник = o + s·u + t·v, поэтому смена ролей осей угол не двигает.
        a, b, len, wid = w >= h ? [u, v, w, h] : [v, u, h, w]
        oh = prm[:overhang]
        o = o.offset(a, -oh).offset(b, -oh)
        len += 2 * oh
        wid += 2 * oh
        tan = Math.tan(G.deg(prm[:pitch]))
        z = G::Z
        pa = o
        pb = o.offset(a, len)
        pc = pb.offset(b, wid)
        pd = o.offset(b, wid)
        slopes = []
        walls = []
        case prm[:type]
        when :hip
          hgt = wid / 2.0 * tan
          r1 = o.offset(a, wid / 2.0).offset(b, wid / 2.0).offset(z, hgt)
          r2 = o.offset(a, len - wid / 2.0).offset(b, wid / 2.0).offset(z, hgt)
          if r1.distance(r2).to_f < G.tol
            slopes += [[pa, pb, r1], [pb, pc, r1], [pc, pd, r1], [pd, pa, r1]]
          else
            slopes += [[pa, pb, r2, r1], [pc, pd, r1, r2], [pb, pc, r2], [pd, pa, r1]]
          end
        when :gable
          hgt = wid / 2.0 * tan
          r1 = o.offset(b, wid / 2.0).offset(z, hgt)
          r2 = r1.offset(a, len)
          slopes += [[pa, pb, r2, r1], [pc, pd, r1, r2]]
          walls += [[pd, pa, r1], [pb, pc, r2]]
        else # :shed
          hgt = wid * tan
          pc2 = pc.offset(z, hgt)
          pd2 = pd.offset(z, hgt)
          slopes << [pa, pb, pc2, pd2]
          walls += [[pa, pd2, pd], [pb, pc, pc2], [pd, pd2, pc2, pc]]
        end
        fix = ->(poly) { (G.newell_normal(poly)&.z || 0).negative? ? poly.reverse : poly }
        [slopes.map(&fix), walls, hgt]
      end
    end

    Registry.define(:joists, :framing) do |p|
      p.choice :direction, :short, %i[short long x y]
      p.length :spacing, 600
      p.length :width, 50
      p.length :depth, 200
      p.bool :edge_members, true
      p.choice :side, :below, %i[below above]
      FrameTools.section_params(p)
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      total = 0
      sec = FrameTools.section(ctx.p)
      faces.each do |f|
        axis = FrameTools.direction(f, ctx.p[:direction])
        g, c = FrameTools.members(ctx.entities, f, axis, ctx.p[:spacing], ctx.p[:width], ctx.p[:depth],
                                  ctx.p[:edge_members], ctx.p[:side] == :below, ctx.name(:joists), sec)
        ctx.made(g)
        total += c
      end
      ArchiTools.t(:ok_members, n: total)
    end

    Registry.define(:rafters, :framing) do |p|
      p.length :spacing, 600
      p.length :width, 50
      p.length :depth, 200
      p.bool :edge_members, true
      FrameTools.section_params(p)
      p.bool :fascia, false
      p.length :fascia_height, 250, show: { fascia: true }
      p.length :fascia_thickness, 25, show: { fascia: true }
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      total = 0
      sec = FrameTools.section(ctx.p)
      faces.each do |f|
        ctx.need(!f.normal.parallel?(Geom3::Z), :need_sloped_face)
        _o, _u, v, = Geom3.face_frame(f)
        g, c = FrameTools.members(ctx.entities, f, v, ctx.p[:spacing], ctx.p[:width], ctx.p[:depth],
                                  ctx.p[:edge_members], true, ctx.name(:rafters), sec)
        if ctx.p[:fascia]
          boards = FrameTools.fascia(g.entities, f, ctx.p[:fascia_height], ctx.p[:fascia_thickness], ctx.name(:fascia))
          boards.each { |b| b.material = WallTools.material(ctx.model, :frame) }
        end
        ctx.made(g)
        total += c
      end
      ArchiTools.t(:ok_members, n: total)
    end

    Registry.define(:purlins, :framing) do |p|
      p.length :spacing, 900
      p.length :width, 50
      p.length :depth, 50
      p.bool :edge_members, true
      p.choice :side, :above, %i[above below]
      FrameTools.section_params(p)
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      total = 0
      sec = FrameTools.section(ctx.p)
      faces.each do |f|
        _o, u, = Geom3.face_frame(f)
        g, c = FrameTools.members(ctx.entities, f, u, ctx.p[:spacing], ctx.p[:width], ctx.p[:depth],
                                  ctx.p[:edge_members], ctx.p[:side] == :below, ctx.name(:purlins), sec)
        ctx.made(g)
        total += c
      end
      ArchiTools.t(:ok_members, n: total)
    end

    Registry.define(:roof, :framing) do |p|
      p.choice :type, :hip, %i[hip gable shed]
      p.angle :pitch, 30, min: 1, max: 80
      p.length :overhang, 500
      p.length :thickness, 0
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(faces.size == 1, :need_horizontal_face)
      slopes, walls, hgt = FrameTools.roof_polygons(faces.first, ctx.p)
      group = ctx.entities.add_group
      group.name = ctx.name(:roof)
      t = ctx.p[:thickness]
      if t > Geom3.tol
        shell = Geom3.mesh_group(group.entities, ModifyTools.shell_polygons(slopes, t))
        ModifyTools.merge_coplanar(shell.entities)
        ModifyTools.orient_outward(shell.entities)
      else
        slopes.each { |poly| group.entities.add_face(poly) }
      end
      walls.each { |poly| group.entities.add_face(poly) }
      ctx.made(group)
      ArchiTools.t(:ok_roof, h: Sketchup.format_length(hgt))
    end

    Registry.define(:columns, :framing) do |p|
      p.choice :shape, :rect, %i[rect round ellipse capital tuscan tuscan_round]
      p.length :size_x, 400
      p.length :size_y, 400, show: { shape: %i[rect ellipse capital] }
      p.length :height, 3000
      p.bool :footing, false
      p.length :footing_size, 1200, show: { footing: true }
      p.length :footing_depth, 500, show: { footing: true }
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:size_x] > Geom3.tol && prm[:height] > Geom3.tol, :err_distance)
      points = FrameTools.insertion_points(ctx)
      label = %i[rect ellipse capital].include?(prm[:shape]) ?
                "#{Sketchup.format_length(prm[:size_x])}×#{Sketchup.format_length(prm[:size_y])}" :
                "Ø#{Sketchup.format_length(prm[:size_x])}"
      defn = ctx.model.definitions.add("#{ctx.name(:column)} #{ArchiTools.label(:c, :columns, prm[:shape])} #{label}")
      FrameTools.column(defn.entities, prm)
      if prm[:footing]
        fs = prm[:footing_size]
        Geom3.box(defn.entities, Geom::Point3d.new(-fs / 2.0, -fs / 2.0, -prm[:footing_depth]), Geom::Vector3d.new(fs, 0, 0),
                  Geom::Vector3d.new(0, fs, 0), Geom::Vector3d.new(0, 0, prm[:footing_depth]))
      end
      FrameTools.place_definition(ctx, defn, points, :ok_columns, :ok_column_place)
    end

    Registry.define(:pad_footing, :framing) do |p|
      p.length :pad_x, 1500
      p.length :pad_y, 1500
      p.length :pad_depth, 400
      p.length :stump, 400
      p.length :stump_height, 600
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:pad_x] > Geom3.tol && prm[:pad_y] > Geom3.tol && prm[:pad_depth] > Geom3.tol, :err_distance)
      ctx.need(prm[:stump] < [prm[:pad_x], prm[:pad_y]].min, :err_stump_big)
      points = FrameTools.insertion_points(ctx)
      defn = ctx.model.definitions.add("#{ctx.name(:pad_footing)} #{Sketchup.format_length(prm[:pad_x])}×#{Sketchup.format_length(prm[:pad_y])}")
      e = defn.entities
      sh = prm[:stump_height]
      s = prm[:stump]
      # Точка вставки — центр верха подколонника, как в оригинале.
      if sh > Geom3.tol && s > Geom3.tol
        Geom3.box(e, Geom::Point3d.new(-s / 2.0, -s / 2.0, -sh), Geom::Vector3d.new(s, 0, 0), Geom::Vector3d.new(0, s, 0),
                  Geom::Vector3d.new(0, 0, sh), ctx.name(:stump))
      end
      Geom3.box(e, Geom::Point3d.new(-prm[:pad_x] / 2.0, -prm[:pad_y] / 2.0, -sh - prm[:pad_depth]),
                Geom::Vector3d.new(prm[:pad_x], 0, 0), Geom::Vector3d.new(0, prm[:pad_y], 0),
                Geom::Vector3d.new(0, 0, prm[:pad_depth]), ctx.name(:pad))
      FrameTools.place_definition(ctx, defn, points, :ok_footings, :ok_footing_place)
    end

    Registry.define(:strip_footing, :framing) do |p|
      p.length :footing_width, 600
      p.length :footing_depth, 300
      p.length :wall_width, 300
      p.length :wall_height, 600
      p.choice :align, :center, %i[center left right]
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges)
      ctx.need(!chains.empty?, :need_edges)
      prm = ctx.p
      fw = prm[:footing_width]
      fd = prm[:footing_depth]
      ww = prm[:wall_width]
      wh = prm[:wall_height]
      ctx.need(fw > Geom3.tol && fd > Geom3.tol && ww > Geom3.tol, :err_distance)
      ctx.need(fw >= ww, :err_stump_big)
      s0 = { center: -ww / 2.0, left: -ww, right: 0.0 }[prm[:align]]
      s1 = s0 + ww
      cs = (s0 + s1) / 2.0
      hh = wh + fd
      section =
        if wh > Geom3.tol
          [[cs - fw / 2.0, -hh], [cs + fw / 2.0, -hh], [cs + fw / 2.0, -wh], [s1, -wh], [s1, 0.0], [s0, 0.0], [s0, -wh],
           [cs - fw / 2.0, -wh]]
        else
          [[cs - fw / 2.0, -fd], [cs + fw / 2.0, -fd], [cs + fw / 2.0, 0.0], [cs - fw / 2.0, 0.0]]
        end
      section = section.each_with_object([]) { |q, acc| acc << q unless acc.last && (acc.last[0] - q[0]).abs < 1.0e-9 && (acc.last[1] - q[1]).abs < 1.0e-9 }
      chains.each do |chain|
        pts = chain[:points]
        pts = pts.reverse if chain[:closed] && WallTools.signed_area_xy(pts).negative?
        pts = Geom3.canonical(pts) unless chain[:closed]
        ctx.made(Profiles.sweep_group(ctx.entities, pts, chain[:closed], [section], ctx.name(:strip_footing), smooth: false,
                                                                                             vertical: true))
      end
      ArchiTools.t(:ok_strip, n: chains.size)
    end

    Registry.define(:beams, :framing) do |p|
      p.choice :profile, :rect, Profiles::KINDS
      p.length :width, 200
      p.length :depth, 400, show: { profile: %i[rect i_beam channel angle tee rhs] }
      p.length :web, 10, show: { profile: Profiles::WALLED }
      p.length :flange, 15, show: { profile: %i[i_beam channel angle tee] }
      p.choice :align, :top, %i[top center bottom]
    end.run do |ctx|
      edges = ctx.edges
      ctx.need(!edges.empty?, :need_edges)
      prm = ctx.p
      w = prm[:width]
      d = %i[round chs].include?(prm[:profile]) ? w : prm[:depth]
      ctx.need(w > Geom3.tol && d > Geom3.tol, :err_distance)
      loops = Profiles.aligned(Profiles.loops(prm[:profile], w, d, prm[:web], prm[:flange]), d, prm[:align])
      edges.each do |e|
        pts = [e.start.position, e.end.position]
        ctx.made(Profiles.sweep_group(ctx.entities, pts, false, loops, ctx.name(:beam)))
      end
      ArchiTools.t(:ok_beams, n: edges.size)
    end

    Registry.define(:profile_sweep, :modify) do |p|
      p.choice :profile, :round, Profiles::KINDS
      p.length :width, 50
      p.length :depth, 50, show: { profile: %i[rect i_beam channel angle tee rhs] }
      p.length :web, 4, show: { profile: Profiles::WALLED }
      p.length :flange, 6, show: { profile: %i[i_beam channel angle tee] }
      p.choice :align, :center, %i[center top bottom]
      p.int :segments, 16, min: 6, max: 96, show: { profile: %i[round chs] }
      p.bool :vertical, false
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges)
      ctx.need(!chains.empty?, :need_edges)
      prm = ctx.p
      w = prm[:width]
      d = %i[round chs].include?(prm[:profile]) ? w : prm[:depth]
      ctx.need(w > Geom3.tol && d > Geom3.tol, :err_distance)
      loops = Profiles.aligned(Profiles.loops(prm[:profile], w, d, prm[:web], prm[:flange], prm[:segments]),
                               d, prm[:align])
      chains.each do |chain|
        ctx.made(Profiles.sweep_group(ctx.entities, chain[:points], chain[:closed], loops, ctx.name(:sweep),
                                      vertical: prm[:vertical]))
      end
      ArchiTools.t(:ok_profile_sweep, n: chains.size)
    end
  end
end
