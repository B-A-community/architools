# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Поверхности и массивы: выдавливание с сохранением сужения, тело
    # вращения (с масштабом и подъёмом), горизонтальный разрез граней,
    # горизонтальные бороздки, прямоугольный массив, массив по пути.
    module SurfaceTools
      G = Geom3

      module_function

      # Отрезки пересечения грани с плоскостью z = level (внутри грани).
      def slice_segments(face, level)
        n = face.normal
        return [] if n.parallel?(G::Z)

        dir = n.cross(G::Z).normalize
        pts = []
        face.loops.each do |loop|
          vs = loop.vertices.map(&:position)
          vs.each_with_index do |a, i|
            b = vs[(i + 1) % vs.size]
            za = a.z.to_f
            zb = b.z.to_f
            next if (za - zb).abs < 1.0e-12
            next unless level >= [za, zb].min && level < [za, zb].max

            t = (level - za) / (zb - za)
            pts << Geom.linear_combination(1.0 - t, a, t, b)
          end
        end
        o = pts.first
        return [] unless o

        pts = pts.sort_by { |pt| (pt - o).dot(dir) }
        pts.each_slice(2).select do |pair|
          next false unless pair.size == 2 && pair[0].distance(pair[1]).to_f > G::MIN_SIZE

          mid = Geom.linear_combination(0.5, pair[0], 0.5, pair[1])
          [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge].include?(face.classify_point(mid))
        end
      end

      def slice(entities, faces, levels)
        cuts = faces.flat_map { |f| levels.flat_map { |z| slice_segments(f, z) } }
        cuts.each { |a, b| entities.add_line(a, b) }
        cuts.size
      end

      # Станции вдоль полилинии: [точка, направление] на расстояниях dists.
      def along(points, dists)
        segs = points.each_cons(2).map { |a, b| [a, b, a.distance(b).to_f] }
        dists.map do |d|
          acc = 0.0
          hit = segs.find { |_, _, len| (acc += len) >= d - 1.0e-9 } || segs.last
          a, b, len = hit
          start = acc - len
          f = len.positive? ? [[(d - start) / len, 0.0].max, 1.0].min : 0.0
          [Geom.linear_combination(1.0 - f, a, f, b), (b - a).normalize]
        end
      end

      def heading(vec)
        Math.atan2(vec.y, vec.x)
      end
    end

    Registry.define(:extrude_taper, :modify) do |p|
      p.length :distance, 500
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      d = ctx.p[:distance]
      ctx.need(d.abs > Geom3.tol, :err_distance)
      faces.each do |face|
        next unless face.valid?

        n = face.normal
        own = face.edges
        # Сужение задают рёбра, подходящие к вершине грани сзади: их
        # продолжение и есть направление сдвига вершины.
        moved = {}
        face.vertices.each do |v|
          side = (v.edges - own).map { |e| v.position - e.other_vertex(v).position }
                                .select { |vec| vec.length.to_f > Geom3.tol && vec.normalize.dot(n) > 0.05 }
                                .max_by { |vec| vec.normalize.dot(n) }
          step = side ? Geom3.scale(side.normalize, d / side.normalize.dot(n)) : Geom3.scale(n, d)
          moved[v] = v.position.offset(step)
        end
        solid = own.any? { |e| e.faces.size > 1 }
        ents = face.parent.entities
        polys = face.loops.flat_map do |loop|
          vs = loop.vertices
          vs.each_index.map { |i| [vs[i], vs[(i + 1) % vs.size]] }.map do |a, b|
            [a.position, b.position, moved[b], moved[a]]
          end
        end
        top_loops = face.loops.map { |loop| loop.vertices.map { |v| moved[v] } }
        old_edges = own.dup
        face.erase! if solid
        polys.each do |q|
          if Geom3.planar?(q)
            ents.add_face(q)
          else
            ents.add_face(q[0], q[1], q[2])
            ents.add_face(q[0], q[2], q[3])
          end
        end
        top = ents.add_face(top_loops.first)
        top_loops.drop(1).each { |l| ents.add_face(l)&.erase! }
        ctx.made(top)
        # Старые рёбра между гранями одной плоскости больше не нужны.
        old_edges.select(&:valid?).each do |e|
          fs = e.faces
          e.erase! if fs.size == 2 && fs[0].normal.samedirection?(fs[1].normal) &&
                      e.start.position.distance_to_plane(fs[1].plane).to_f < Geom3.tol
        end
      end
      ArchiTools.t(:ok_extrude, n: faces.size)
    end

    Registry.define(:revolve, :modify) do |p|
      p.angle :angle, 360, min: -7200, max: 7200
      p.int :segments, 24, min: 3, max: 720
      p.float :scale, 1.0, min: 0.0
      p.length :rise, 0
    end.picks(count: 2, prompts: %i[pk_axis1 pk_axis2],
              check: ->(ctx) { ctx.need(!ctx.edges.empty?, :need_profile_edges) }).run do |ctx|
      chains = Geom3.chains(ctx.edges)
      ctx.need(chains.size == 1, :need_profile_edges)
      ctx.need(ctx.points.size >= 2, :need_points, n: 2)
      a0, a1 = ctx.points
      axis = a1 - a0
      ctx.need(axis.length.to_f > Geom3::MIN_SIZE, :err_points_same)
      axis = axis.normalize
      chain = chains.first
      prof = chain[:points]
      prof += [prof.first] if chain[:closed]
      n = ctx.p[:segments]
      total = Geom3.deg(ctx.p[:angle])
      k = ctx.p[:scale]
      rise = ctx.p[:rise]
      full = (ctx.p[:angle].abs - 360).abs < 1.0e-6 && (k - 1).abs < 1.0e-9 && rise.abs < Geom3.tol
      rings = (0..n).map do |i|
        f = i.to_f / n
        rot = Geom::Transformation.rotation(a0, axis, total * f)
        s = 1.0 + (k - 1.0) * f
        prof.map do |pt|
          foot = pt.project_to_line([a0, axis])
          radial = Geom3.scale(pt - foot, s)
          foot.offset(radial).transform(rot).offset(axis, rise * f)
        end
      end
      rings[-1] = rings[0] if full
      polys = []
      rings.each_cons(2) do |r1, r2|
        (0...prof.size - 1).each { |j| polys << [r1[j], r1[j + 1], r2[j + 1], r2[j]] }
      end
      g = Geom3.mesh_group(ctx.entities, polys, ctx.name(:revolved))
      ModifyTools.soften_smooth(g.entities, 30)
      ctx.made(g)
      ArchiTools.t(:ok_revolve, n: polys.size)
    end

    Registry.define(:horizontal_slice, :modify) do |p|
      p.length :base, 0
      p.length :height, 1000
      p.int :count, 1, min: 1, max: 1000
      p.length :interval, 1000, show: { count: '!1' }
    end.run do |ctx|
      faces = ctx.faces.reject { |f| f.normal.parallel?(Geom3::Z) }
      ctx.need(!faces.empty?, :need_sloped_faces)
      levels = (0...ctx.p[:count]).map { |i| ctx.p[:base] + ctx.p[:height] + i * ctx.p[:interval] }
      cuts = SurfaceTools.slice(ctx.entities, faces, levels)
      ctx.need(cuts.positive?, :err_no_hits)
      ArchiTools.t(:ok_slice, n: cuts)
    end

    Registry.define(:horizontal_grooves, :modify) do |p|
      p.length :start, 300
      p.length :interval, 300
      p.length :groove, 20
      p.length :depth, 10
    end.run do |ctx|
      faces = ctx.faces.reject { |f| f.normal.parallel?(Geom3::Z) }
      ctx.need(!faces.empty?, :need_sloped_faces)
      gh = ctx.p[:groove]
      ctx.need(gh > Geom3::MIN_SIZE && ctx.p[:interval] > gh && ctx.p[:depth].abs > Geom3::MIN_SIZE, :err_distance)
      planes = faces.map { |f| [f.plane, f.normal, f.parent.entities, f.bounds.min.z.to_f, f.bounds.max.z.to_f] }
      count = 0
      planes.each do |plane, normal, ents, zmin, zmax|
        z = ctx.p[:start]
        z += ctx.p[:interval] while z < zmin + Geom3.tol
        levels = []
        while z + gh < zmax - Geom3.tol
          levels << z
          z += ctx.p[:interval]
          raise UserError, ArchiTools.t(:err_too_many) if levels.size > MAX_ITEMS
        end
        on_plane = lambda do
          ents.grep(Sketchup::Face).select do |f|
            f.normal.samedirection?(normal) && f.vertices.first.position.distance_to_plane(plane).to_f < Geom3.tol
          end
        end
        levels.each do |lv|
          SurfaceTools.slice(ents, on_plane.call, [lv, lv + gh])
          band = on_plane.call.select do |f|
            f.bounds.min.z.to_f > lv - Geom3.tol && f.bounds.max.z.to_f < lv + gh + Geom3.tol
          end
          band.each do |f|
            f.pushpull(-ctx.p[:depth])
            count += 1
          end
        end
      end
      ArchiTools.t(:ok_grooves, n: count)
    end

    Registry.define(:rectangular_array, :modify) do |p|
      p.int :cols, 4, min: 1
      p.int :rows, 3, min: 1
      p.int :levels, 1, min: 1
      p.length :dx, 1000
      p.length :dy, 1000
      p.length :dz, 3000, show: { levels: '!1' }
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      c, r, l = ctx.p.values_at(:cols, :rows, :levels)
      ctx.need(c * r * l > 1, :err_array_one)
      raise UserError, ArchiTools.t(:err_too_many) if c * r * l * objects.size > MAX_ITEMS

      made = 0
      objects.each do |obj|
        l.times do |k|
          r.times do |j|
            c.times do |i|
              next if i.zero? && j.zero? && k.zero?

              v = Geom::Vector3d.new(i * ctx.p[:dx], j * ctx.p[:dy], k * ctx.p[:dz])
              ctx.made(ModifyTools.copy_object(ctx.entities, obj, Geom::Transformation.translation(v)))
              made += 1
            end
          end
        end
      end
      ArchiTools.t(:ok_array, n: made)
    end

    Registry.define(:path_array, :modify) do |p|
      p.choice :mode, :count, %i[count spacing max_spacing]
      p.int :count, 10, min: 2, show: { mode: :count }
      p.length :spacing, 1000, show: { mode: %i[spacing max_spacing] }
      p.bool :follow, true
    end.run do |ctx|
      objects = ctx.objects
      chains = Geom3.chains(ctx.edges)
      ctx.need(!objects.empty? && chains.size == 1, :need_objects_path)
      chain = chains.first
      pts = chain[:points]
      # Начало пути — у объекта: ближайший конец (на замкнутом — вершина).
      ob = objects.first.bounds
      ref0 = Geom::Point3d.new(ob.center.x, ob.center.y, ob.min.z)
      if chain[:closed]
        pts = pts.rotate(pts.each_index.min_by { |i| pts[i].distance(ref0).to_f })
      elsif pts.last.distance(ref0).to_f < pts.first.distance(ref0).to_f
        pts = pts.reverse
      end
      pts += [pts.first] if chain[:closed]
      len = Geom3.polyline_length(pts)
      ctx.need(len > Geom3::MIN_SIZE, :err_distance)
      s = ctx.p[:spacing]
      dists =
        case ctx.p[:mode]
        when :count
          n = ctx.p[:count]
          last = chain[:closed] ? n : n - 1
          (0...n).map { |i| len * i / last }
        when :spacing
          ctx.need(s > Geom3::MIN_SIZE, :err_spacing)
          (0..(len / s + 1.0e-9).floor).map { |i| i * s }
        else
          ctx.need(s > Geom3::MIN_SIZE, :err_spacing)
          n = [(len / s - 1.0e-9).ceil, 1].max
          (0..n).map { |i| len * i / n }.then { |list| chain[:closed] ? list[0...-1] : list }
        end
      raise UserError, ArchiTools.t(:err_too_many) if dists.size * objects.size > MAX_ITEMS

      stations = SurfaceTools.along(pts, dists)
      h0 = SurfaceTools.heading(stations.first[1])
      objects.each do |obj|
        b = obj.bounds
        ref = Geom::Point3d.new(b.center.x, b.center.y, b.min.z)
        stations.each do |pt, dir|
          rot = ctx.p[:follow] ? SurfaceTools.heading(dir) - h0 : 0.0
          t = Geom::Transformation.translation(pt - ORIGIN) * Geom::Transformation.rotation(ORIGIN, Geom3::Z, rot) *
              Geom::Transformation.translation(ORIGIN - ref)
          ctx.made(ModifyTools.copy_object(ctx.entities, obj, t))
        end
      end
      ArchiTools.t(:ok_array, n: stations.size * objects.size)
    end
  end
end
