# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Правка: выдавливание граней, сдвиг по нормали, оболочка, профиль по
    # пути без закручивания, круговой и линейный массивы.
    module ModifyTools
      G = Geom3

      module_function

      def key(pt)
        format('%.4f,%.4f,%.4f', pt.x, pt.y, pt.z)
      end

      # Оболочка из многоугольников: исходные (развёрнутые) + смещённые по
      # нормали в вершинах + боковые грани по свободным рёбрам.
      def shell_polygons(polys, thickness)
        normals = Hash.new { |h, k| h[k] = [] }
        polys.each do |poly|
          n = G.newell_normal(poly)
          next unless n

          poly.each { |pt| normals[key(pt)] << n }
        end
        offset = {}
        normals.each do |k, list|
          sum = list.inject(Geom::Vector3d.new(0, 0, 0)) { |a, b| a + b }
          next if sum.length.to_f < 1.0e-9

          avg = sum.normalize
          cos = list.map { |n| avg.dot(n) }.min
          cos = 0.2 if cos < 0.2
          offset[k] = G.scale(avg, thickness / cos)
        end
        shifted = ->(pt) { pt.offset(offset[key(pt)] || Geom::Vector3d.new(0, 0, 0)) }

        out = []
        edge_count = Hash.new(0)
        polys.each do |poly|
          out << poly.reverse
          out << poly.map(&shifted)
          poly.each_with_index do |a, i|
            b = poly[(i + 1) % poly.size]
            edge_count[[key(a), key(b)].sort] += 1
          end
        end
        polys.each do |poly|
          poly.each_with_index do |a, i|
            b = poly[(i + 1) % poly.size]
            next unless edge_count[[key(a), key(b)].sort] == 1

            out << [a, b, shifted.call(b), shifted.call(a)]
          end
        end
        out = out.map(&:reverse) if thickness.negative?
        out
      end

      # Многоугольники грани (с дырами — треугольниками).
      def face_polygons(face, transform = nil)
        if face.loops.size == 1
          pts = face.outer_loop.vertices.map(&:position)
          return [transform ? pts.map { |p| p.transform(transform) } : pts]
        end
        mesh = face.mesh(0)
        mesh.polygons.map do |poly|
          pts = poly.map { |i| mesh.point_at(i.abs) }
          pts = pts.reverse if G.newell_normal(pts)&.dot(face.normal)&.negative?
          transform ? pts.map { |p| p.transform(transform) } : pts
        end
      end

      # Сливает соседние треугольники одной плоскости — после fill_from_mesh.
      def merge_coplanar(entities)
        entities.grep(Sketchup::Edge).each do |e|
          next unless e.valid?

          fs = e.faces
          next unless fs.size == 2
          next unless fs[0].normal.samedirection?(fs[1].normal)
          next unless fs[0].plane.zip(fs[1].plane).all? { |a, b| (a - b).abs < 1.0e-6 }

          e.erase!
        end
        # После слияния часть рёбер остаётся висеть без граней — убираем.
        stray = entities.grep(Sketchup::Edge).select { |e| e.valid? && e.faces.empty? }
        entities.erase_entities(stray) unless stray.empty?
      end

      # Знаковый объём по граням: отрицательный — нормали смотрят внутрь.
      def signed_volume(entities)
        entities.grep(Sketchup::Face).sum do |f|
          mesh = f.mesh(0)
          mesh.polygons.sum do |poly|
            a, b, c = poly.map { |i| mesh.point_at(i.abs) }
            Geom::Vector3d.new(a.x, a.y, a.z).dot(Geom::Vector3d.new(b.x, b.y, b.z).cross(Geom::Vector3d.new(c.x, c.y, c.z))) / 6.0
          end
        end
      end

      def orient_outward(entities)
        entities.grep(Sketchup::Face).each(&:reverse!) if signed_volume(entities).negative?
      end

      def soften_smooth(entities, angle_deg)
        limit = Math.cos(G.deg(angle_deg))
        entities.grep(Sketchup::Edge).each do |e|
          fs = e.faces
          next unless fs.size == 2

          if fs[0].normal.dot(fs[1].normal) > limit
            e.soft = true
            e.smooth = true
          end
        end
      end

      def copy_object(entities, obj, transform)
        if obj.is_a?(Sketchup::ComponentInstance)
          inst = entities.add_instance(obj.definition, transform * obj.transformation)
          inst.material = obj.material
          inst.layer = obj.layer
          inst
        else
          g = obj.copy
          g.transform!(transform)
          g
        end
      end

      # --- профиль по пути --------------------------------------------------

      # Оси сечения на каждом участке пути. vertical — сечение стоит
      # отвесно (b по мировой Z) и на уклоне: стены, пандусы, ленты; иначе
      # оно перпендикулярно пути: балки, трубы, поручни.
      def path_frames(points, vertical = false)
        points.each_cons(2).map do |a, b|
          t = (b - a).normalize
          if vertical && !t.parallel?(G::Z)
            next { t: t, up: G::Z.clone, side: t.cross(G::Z).normalize }
          end

          up = G::Z - G.scale(t, G::Z.dot(t))
          up = (t.parallel?(G::X) ? Geom::Vector3d.new(0, 1, 0) : G::X) if up.length.to_f < 1.0e-6
          up = up.normalize
          side = t.cross(up).normalize
          up = side.cross(t).normalize
          { t: t, up: up, side: side }
        end
      end

      def sweep(points, closed, loops2d, cap_polys2d, vertical: false)
        pts = closed ? points + [points.first] : points
        frames = path_frames(pts, vertical)
        n = pts.size
        ring_at = lambda do |i, a, b|
          if i.zero? && !closed
            f = frames[0]
            pts[0].offset(f[:side], a).offset(f[:up], b)
          elsif i == n - 1 && !closed
            f = frames[-1]
            pts[-1].offset(f[:side], a).offset(f[:up], b)
          else
            fin = frames[(i - 1) % frames.size]
            fout = frames[i % frames.size]
            base = pts[i - 1]
            start = base.offset(fin[:side], a).offset(fin[:up], b)
            miter = fin[:t] + fout[:t]
            miter = fin[:t] if miter.length.to_f < 1.0e-6
            hit = Geom.intersect_line_plane([start, fin[:t]], [pts[i], miter.normalize])
            hit || pts[i].offset(fin[:side], a).offset(fin[:up], b)
          end
        end
        ring_count = closed ? n - 1 : n
        rings = loops2d.map do |loop|
          (0...ring_count).map do |i|
            idx = closed && i.zero? ? n - 1 : i
            loop.map { |a, b| ring_at.call(idx, a, b) }
          end
        end
        polys = []
        rings.each do |loop_rings|
          seq = closed ? loop_rings + [loop_rings.first] : loop_rings
          seq.each_cons(2) do |r1, r2|
            m = r1.size
            m.times do |j|
              k = (j + 1) % m
              polys << [r1[j], r1[k], r2[k], r2[j]]
            end
          end
        end
        unless closed
          cap_polys2d.each do |poly|
            polys << poly.map { |a, b| ring_at.call(0, a, b) }.reverse
            polys << poly.map { |a, b| ring_at.call(n - 1, a, b) }
          end
        end
        polys
      end
    end

    Registry.define(:extrude_faces, :modify) do |p|
      p.length :distance, 500
      p.bool :copy, false
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      d = ctx.p[:distance]
      ctx.need(d.abs > Geom3.tol, :err_distance)
      done = 0
      faces.each do |f|
        next unless f.valid?

        f.pushpull(d, ctx.p[:copy])
        done += 1
      end
      ArchiTools.t(:ok_extrude, n: done)
    end

    Registry.define(:shift_faces, :modify) do |p|
      p.length :distance, 100
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      d = ctx.p[:distance]
      sums = {}
      faces.each do |f|
        f.vertices.each do |v|
          sums[v] = (sums[v] || Geom::Vector3d.new(0, 0, 0)) + f.normal
        end
      end
      verts = sums.keys
      vectors = verts.map do |v|
        s = sums[v]
        s.length.to_f < 1.0e-9 ? Geom::Vector3d.new(0, 0, 0) : Geom3.scale(s.normalize, d)
      end
      Geom3.move_vertices(ctx.entities, verts, vectors)
      ArchiTools.t(:ok_shift, n: faces.size)
    end

    Registry.define(:shell, :modify) do |p|
      p.length :thickness, 200
      p.bool :erase_source, false
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      t = ctx.p[:thickness]
      ctx.need(t.abs > Geom3.tol, :err_distance)
      polys = faces.flat_map { |f| ModifyTools.face_polygons(f) }
      g = Geom3.mesh_group(ctx.entities, ModifyTools.shell_polygons(polys, t), ctx.name(:shell))
      ModifyTools.merge_coplanar(g.entities)
      ModifyTools.orient_outward(g.entities)
      ModifyTools.soften_smooth(g.entities, 20)
      ctx.entities.erase_entities(faces) if ctx.p[:erase_source]
      ctx.made(g)
      ArchiTools.t(:ok_shell, n: faces.size)
    end

    Registry.define(:extrude_path, :modify) do |p|
      p.bool :smooth, true
      p.bool :erase_profile, false
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(faces.size == 1, :need_profile_path)
      face = faces.first
      profile_edges = face.edges
      path_edges = ctx.edges - profile_edges
      chains = Geom3.chains(path_edges)
      ctx.need(chains.size == 1 && chains.first[:points].size >= 2, :need_profile_path)
      chain = chains.first
      pts = chain[:points]
      center = face.bounds.center
      pts = pts.reverse if !chain[:closed] && center.distance(pts.last).to_f < center.distance(pts.first).to_f
      if chain[:closed]
        # На замкнутом пути начинаем с вершины, ближайшей к профилю.
        i = pts.each_with_index.min_by { |pt, _| pt.distance(center).to_f }.last
        pts = pts.rotate(i)
      end
      frame0 = ModifyTools.path_frames(pts.first(2), true).first
      to2d = lambda do |q|
        d = q - pts.first
        [d.dot(frame0[:side]), d.dot(frame0[:up])]
      end
      loops2d = face.loops.map { |l| l.vertices.map { |v| to2d.call(v.position) } }
      caps2d = ModifyTools.face_polygons(face).map { |poly| poly.map { |q| to2d.call(q) } }
      polys = ModifyTools.sweep(pts, chain[:closed], loops2d, caps2d, vertical: true)
      g = Geom3.mesh_group(ctx.entities, polys, ctx.name(:sweep))
      ModifyTools.merge_coplanar(g.entities)
      ModifyTools.soften_smooth(g.entities, 30) if ctx.p[:smooth]
      ModifyTools.orient_outward(g.entities)
      face.erase! if ctx.p[:erase_profile] && face.valid?
      ctx.made(g)
      ArchiTools.t(:ok_sweep)
    end

    Registry.define(:polar_array, :modify) do |p|
      p.int :count, 6, min: 2
      p.angle :angle, 360, min: -3600, max: 3600
      p.choice :axis, :z, %i[z x y]
      p.bool :rotate_copies, true
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      center = ctx.cpoints.first&.position || ORIGIN
      axis = { z: Geom3::Z, x: Geom3::X, y: Geom::Vector3d.new(0, 1, 0) }[ctx.p[:axis]]
      n = ctx.p[:count]
      total = Geom3.deg(ctx.p[:angle])
      full = (ctx.p[:angle].abs - 360).abs < 1.0e-6
      step = full ? total / n : total / (n - 1)
      raise UserError, ArchiTools.t(:err_too_many) if n * objects.size > MAX_ITEMS

      objects.each do |obj|
        pc = obj.bounds.center
        (1...n).each do |i|
          rot = Geom::Transformation.rotation(center, axis, step * i)
          tr = ctx.p[:rotate_copies] ? rot : Geom::Transformation.translation(pc.transform(rot) - pc)
          ctx.made(ModifyTools.copy_object(ctx.entities, obj, tr))
        end
      end
      ArchiTools.t(:ok_array, n: (n - 1) * objects.size)
    end

    Registry.define(:linear_array, :modify) do |p|
      p.int :count, 5, min: 2
      p.length :dx, 1000
      p.length :dy, 0
      p.length :dz, 0
      p.choice :mode, :step, %i[step total]
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      n = ctx.p[:count]
      v = Geom::Vector3d.new(ctx.p[:dx], ctx.p[:dy], ctx.p[:dz])
      ctx.need(v.length.to_f > Geom3.tol, :err_distance)
      v = Geom3.scale(v, 1.0 / (n - 1)) if ctx.p[:mode] == :total
      raise UserError, ArchiTools.t(:err_too_many) if n * objects.size > MAX_ITEMS

      objects.each do |obj|
        (1...n).each do |i|
          ctx.made(ModifyTools.copy_object(ctx.entities, obj, Geom::Transformation.translation(Geom3.scale(v, i))))
        end
      end
      ArchiTools.t(:ok_array, n: (n - 1) * objects.size)
    end

    Registry.define(:align_objects, :modify) do |p|
      p.choice :axis, :x, %i[x y z]
      p.choice :mode, :min, %i[min center max distribute]
      p.choice :reference, :extreme, %i[extreme largest], show: { mode: %i[min center max] }
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(objects.size >= 2, :need_two_objects)
      i = { x: 0, y: 1, z: 2 }[ctx.p[:axis]]
      lo = ->(o) { o.bounds.min.to_a[i].to_f }
      hi = ->(o) { o.bounds.max.to_a[i].to_f }
      mid = ->(o) { (lo.call(o) + hi.call(o)) / 2.0 }
      move = lambda do |o, d|
        v = [0.0, 0.0, 0.0]
        v[i] = d
        o.transform!(Geom::Transformation.translation(Geom::Vector3d.new(*v))) if d.abs > Geom3.tol
      end
      mode = ctx.p[:mode]
      if mode == :distribute
        ctx.need(objects.size >= 3, :need_three_objects)
        sorted = objects.sort_by { |o| mid.call(o) }
        a = mid.call(sorted.first)
        b = mid.call(sorted.last)
        sorted.each_with_index { |o, k| move.call(o, a + (b - a) * k / (sorted.size - 1) - mid.call(o)) }
      else
        pick = { min: lo, center: mid, max: hi }[mode]
        target =
          if ctx.p[:reference] == :largest then pick.call(objects.max_by { |o| o.bounds.diagonal.to_f })
          elsif mode == :min then objects.map(&lo).min
          elsif mode == :max then objects.map(&hi).max
          else objects.map(&mid).sum / objects.size
          end
        objects.each { |o| move.call(o, target - pick.call(o)) }
      end
      ctx.made(objects)
      ArchiTools.t(:ok_align, n: objects.size)
    end
  end
end
