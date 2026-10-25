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
          # vertical: true — «вверх» по мировой Z; Vector3d — своё «вверх»
          # (Upright Extruder: ввод вектора или по выделенному ребру).
          upv = vertical.is_a?(Geom::Vector3d) ? vertical.normalize : G::Z
          if vertical && !t.parallel?(upv)
            next { t: t, up: upv.clone, side: t.cross(upv).normalize }
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
        # Отвесный профиль (стены, пандусы, Upright Extruder): «план + высота».
        # Смещение точки профиля — точный стык «в ус» в плане (перпендикулярно
        # «вверх»), высота — высота пути в вершине плюс b. Так и излом уклона,
        # и поворот в плане точны, профиль нигде не заваливается.
        upv = vertical.is_a?(Geom::Vector3d) ? vertical.normalize : G::Z
        plan_ok = vertical && pts.each_cons(2).none? { |p0, p1| (p1 - p0).parallel?(upv) }
        if plan_ok
          flat = ->(v) { v - G.scale(upv, v.dot(upv)) }
          sides = pts.each_cons(2).map { |p0, p1| flat.call(p1 - p0).normalize.cross(upv).normalize }
          height = ->(pt) { Geom::Vector3d.new(pt.x, pt.y, pt.z).dot(upv) }
          ring_at = lambda do |i, a, b|
            if !closed && i.zero? then m = sides.first
            elsif !closed && i == n - 1 then m = sides.last
            else
              s_in = sides[(i - 1) % sides.size]
              s_out = sides[i % sides.size]
              k = 1.0 + s_in.dot(s_out)
              # Встречные стороны (разворот на 180°) — без «уса», по исходящей.
              m = k < 1.0e-6 ? s_out : G.scale(s_in + s_out, 1.0 / k)
            end
            base = pts[i]
            base.offset(G.scale(m, a)).offset(upv, b)
          end
        else
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
      p.choice :upright, :z, %i[z vector edge]
      p.float :up_x, 0, show: { upright: :vector }
      p.float :up_y, 0, show: { upright: :vector }
      p.float :up_z, 1, show: { upright: :vector }
      p.choice :anchor, :bottom, %i[bottom center]
      p.bool :smooth, true
      p.bool :erase_profile, false
    end.run do |ctx|
      faces = ctx.faces
      # Выделена группа, а профиль и путь внутри неё — скажем прямо.
      ctx.need(!(faces.empty? && ctx.edges.empty? && !ctx.objects.empty?), :err_sweep_in_group)
      own_edges = faces.flat_map(&:edges)
      path_edges = ctx.edges - own_edges
      chains = Geom3.chains(path_edges)
      path_face = nil
      if faces.size == 2 && chains.empty?
        # Привычка «Ведения»: путь — контур большей грани, профиль — меньшая.
        path_face, face = faces.max_by(&:area), faces.min_by(&:area)
      else
        ctx.need(faces.size == 1, :need_profile_path)
        face = faces.first
      end
      up = Geom3::Z.clone
      case ctx.p[:upright]
      when :vector
        up = Geom::Vector3d.new(ctx.p[:up_x], ctx.p[:up_y], ctx.p[:up_z])
        ctx.need(up.length.to_f > 1.0e-9, :err_up_vector)
      when :edge
        # Отдельное одиночное ребро задаёт «вверх»; путь — другая цепочка.
        single = chains.select { |c| c[:edges].size == 1 }
        ctx.need(chains.size == 2 && !single.empty?, :need_up_edge)
        upc = single.min_by { |c| Geom3.polyline_length(c[:points]) }
        chains -= [upc]
        up = upc[:points][1] - upc[:points][0]
        up = up.reverse if up.z.negative?
      end
      if path_face
        chain = { points: path_face.outer_loop.vertices.map(&:position), closed: true }
      else
        ctx.need(chains.size == 1 && chains.first[:points].size >= 2, :need_profile_path)
        chain = chains.first
      end
      pts = chain[:points]
      center = face.bounds.center
      size = [face.bounds.diagonal.to_f, Geom3::MIN_SIZE].max
      near_path = pts.map { |q| q.distance(center).to_f }.min < size
      if near_path
        pts = pts.reverse if !chain[:closed] && center.distance(pts.last).to_f < center.distance(pts.first).to_f
        if chain[:closed]
          # На замкнутом пути начинаем с вершины, ближайшей к профилю, и
          # обходим так, чтобы профиль стоял поперёк первого ребра.
          pts = pts.rotate(pts.each_with_index.min_by { |pt, _| pt.distance(center).to_f }.last)
          n = face.normal
          t_out = (pts[1] - pts[0]).normalize
          t_in = (pts[0] - pts[-1]).normalize
          pts = [pts[0]] + pts[1..].reverse if n.dot(t_in).abs > n.dot(t_out).abs + 1.0e-9
        end
      else
        pts = Geom3.canonical(pts) unless chain[:closed]
      end
      frame0 = ModifyTools.path_frames(pts.first(2), up).first
      # Профиль стоит поперёк пути у его начала — берём как есть. Иначе это
      # чертёж сечения (как в 1001bit: плашмя на земле, Y — вверх): ставим
      # его в начало пути низом по центру или центром.
      placed = near_path && face.normal.dot(frame0[:t]).abs > Math.cos(Geom3.deg(30))
      to2d =
        if placed
          ->(q) { d = q - pts.first; [d.dot(frame0[:side]), d.dot(frame0[:up])] }
        else
          n = face.normal
          pu, pv = n.parallel?(Geom3::Z) ? [Geom3::X, Geom::Vector3d.new(0, 1, 0)] : Geom3.face_frame(face)[1, 2]
          o = face.vertices.first.position
          uv = face.outer_loop.vertices.map { |v| Geom3.to_uv(v.position, o, pu, pv) }
          us = uv.map(&:first)
          vs = uv.map(&:last)
          ref_u = (us.min + us.max) / 2.0
          ref_v = ctx.p[:anchor] == :center ? (vs.min + vs.max) / 2.0 : vs.min
          ->(q) { a, b = Geom3.to_uv(q, o, pu, pv); [a - ref_u, b - ref_v] }
        end
      loops2d = face.loops.map { |l| l.vertices.map { |v| to2d.call(v.position) } }
      caps2d = ModifyTools.face_polygons(face).map { |poly| poly.map { |q| to2d.call(q) } }
      polys = ModifyTools.sweep(pts, chain[:closed], loops2d, caps2d, vertical: up)
      g = Geom3.mesh_group(ctx.entities, polys, ctx.name(:sweep))
      ModifyTools.merge_coplanar(g.entities)
      # Сечение выродилось (профиль ребром к пути) — честный отказ, а не «готово».
      if !g.valid? || g.entities.grep(Sketchup::Face).size < 3 || g.bounds.diagonal.to_f < Geom3::MIN_SIZE * 10
        g.erase! if g.valid?
        raise UserError, ArchiTools.t(:err_sweep_empty)
      end
      ModifyTools.soften_smooth(g.entities, 30) if ctx.p[:smooth]
      ModifyTools.orient_outward(g.entities)
      face.erase! if ctx.p[:erase_profile] && face.valid?
      ctx.made(g)
      ArchiTools.t(placed ? :ok_sweep : :ok_sweep_drawn)
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
      p.choice :reference, :extreme, %i[extreme largest bounds], show: { mode: %i[min center max] }
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
          elsif ctx.p[:reference] == :bounds
            # Общий габарит выделения, как Center on Red / Green / Blue в JHS.
            all = Geom::BoundingBox.new
            objects.each { |o| all.add(o.bounds) }
            { min: all.min, center: all.center, max: all.max }[mode].to_a[i].to_f
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
