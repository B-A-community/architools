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

      # Ряд брусьев сечением width × depth вдоль axis, с шагом поперёк.
      # Брусья обрезаются контуром грани; below — под гранью, иначе над ней.
      def members(entities, face, axis, spacing, width, depth, edge_members, below, name)
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

            origin = G.from_uv(a2, c - width / 2.0, o, axis, across, shift, n)
            next unless G.box(group.entities, origin, G.scale(axis, b2 - a2), G.scale(across, width), G.scale(n, depth))

            count += 1
            raise UserError, ArchiTools.t(:err_too_many) if count > MAX_ITEMS
          end
        end
        [group, count]
      end

      # Вальма по любому выпуклому контуру — через прямой скелет.
      def skeleton_roof(face, prm)
        z0 = face.vertices.first.position.z.to_f
        pts = face.outer_loop.vertices.map { |v| p = v.position; Geom::Point3d.new(p.x, p.y, z0) }
        pts = pts.reverse if WallTools.signed_area_xy(pts).negative?
        # Лишние вершины на прямой мешают скелету — убираем.
        pts = pts.each_with_index.reject do |pt, i|
          a = pts[i - 1]
          b = pts[(i + 1) % pts.size]
          (pt - a).cross(b - pt).length.to_f < 1.0e-6 * (pt - a).length.to_f * (b - pt).length.to_f
        end.map(&:first)
        convex = pts.each_with_index.all? do |pt, i|
          ((pt - pts[i - 1]).cross(pts[(i + 1) % pts.size] - pt)).z >= -1.0e-9
        end
        raise UserError, ArchiTools.t(:err_roof_concave) unless convex

        pts = G.offset_polyline(pts, -prm[:overhang], G::Z, true) if prm[:overhang] > G.tol
        tan = Math.tan(G.deg(prm[:pitch]))
        faces = Skeleton.faces(pts.map { |pt| [pt.x.to_f, pt.y.to_f] })
        slopes = faces.map { |poly| poly.map { |x, y, t| Geom::Point3d.new(x, y, z0 + t * tan) } }
        hgt = faces.flatten(1).map { |q| q[2] }.max * tan
        [slopes, [], hgt]
      end

      def roof_polygons(face, prm)
        n = face.normal
        raise UserError, ArchiTools.t(:need_horizontal_face) unless n.parallel?(G::Z)
        unless WallTools.rectangular?(face)
          raise UserError, ArchiTools.t(:need_horizontal_rect) unless prm[:type] == :hip

          return skeleton_roof(face, prm)
        end

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
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      total = 0
      faces.each do |f|
        axis = FrameTools.direction(f, ctx.p[:direction])
        g, c = FrameTools.members(ctx.entities, f, axis, ctx.p[:spacing], ctx.p[:width], ctx.p[:depth],
                                  ctx.p[:edge_members], ctx.p[:side] == :below, ctx.name(:joists))
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
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      total = 0
      faces.each do |f|
        ctx.need(!f.normal.parallel?(Geom3::Z), :need_sloped_face)
        _o, _u, v, = Geom3.face_frame(f)
        g, c = FrameTools.members(ctx.entities, f, v, ctx.p[:spacing], ctx.p[:width], ctx.p[:depth],
                                  ctx.p[:edge_members], true, ctx.name(:rafters))
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
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      total = 0
      faces.each do |f|
        _o, u, = Geom3.face_frame(f)
        g, c = FrameTools.members(ctx.entities, f, u, ctx.p[:spacing], ctx.p[:width], ctx.p[:depth],
                                  ctx.p[:edge_members], ctx.p[:side] == :below, ctx.name(:purlins))
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
      p.choice :shape, :rect, %i[rect round]
      p.length :size_x, 400
      p.length :size_y, 400, show: { shape: :rect }
      p.length :height, 3000
      p.bool :footing, false
      p.length :footing_size, 1200, show: { footing: true }
      p.length :footing_depth, 500, show: { footing: true }
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:size_x] > Geom3.tol && prm[:height] > Geom3.tol, :err_distance)
      points = ctx.cpoints.map(&:position)
      if points.empty?
        points = ctx.edges.flat_map { |e| e.vertices.map(&:position) }
                    .uniq { |pt| [pt.x.round(4), pt.y.round(4), pt.z.round(4)] }
      end
      label = prm[:shape] == :round ? "Ø#{Sketchup.format_length(prm[:size_x])}" :
                "#{Sketchup.format_length(prm[:size_x])}×#{Sketchup.format_length(prm[:size_y])}"
      defn = ctx.model.definitions.add("#{ctx.name(:column)} #{label}")
      e = defn.entities
      sx = prm[:size_x]
      sy = prm[:shape] == :round ? sx : prm[:size_y]
      if prm[:shape] == :round
        f = e.add_face(e.add_circle(ORIGIN, Geom3::Z, sx / 2.0, 24))
        f.reverse! if f.normal.z.negative?
        f.pushpull(prm[:height])
      else
        Geom3.box(e, Geom::Point3d.new(-sx / 2.0, -sy / 2.0, 0), Geom::Vector3d.new(sx, 0, 0),
                  Geom::Vector3d.new(0, sy, 0), Geom::Vector3d.new(0, 0, prm[:height]))
      end
      if prm[:footing]
        fs = prm[:footing_size]
        Geom3.box(e, Geom::Point3d.new(-fs / 2.0, -fs / 2.0, -prm[:footing_depth]), Geom::Vector3d.new(fs, 0, 0),
                  Geom::Vector3d.new(0, fs, 0), Geom::Vector3d.new(0, 0, prm[:footing_depth]))
      end
      if points.empty?
        inst = ctx.entities.add_instance(defn, Geom::Transformation.new)
        ctx.made(inst)
        ctx.placing = inst
        next ArchiTools.t(:ok_column_place)
      end
      raise UserError, ArchiTools.t(:err_too_many) if points.size > MAX_ITEMS

      points.each { |pt| ctx.made(ctx.entities.add_instance(defn, Geom::Transformation.translation(pt))) }
      ArchiTools.t(:ok_columns, n: points.size)
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
        ctx.made(Profiles.sweep_group(ctx.entities, chain[:points], chain[:closed], loops, ctx.name(:sweep)))
      end
      ArchiTools.t(:ok_profile_sweep, n: chains.size)
    end
  end
end
