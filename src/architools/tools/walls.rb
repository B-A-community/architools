# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Стены по линиям плана, проёмы, окна и двери.
    module WallTools
      G = Geom3

      MATERIALS = {
        glass: ['ArchiTools Glass', [160, 200, 225], 0.35],
        frame: ['ArchiTools Frame', [235, 235, 232], 1.0],
        leaf:  ['ArchiTools Door', [176, 132, 92], 1.0]
      }.freeze

      module_function

      def material(model, kind)
        name, rgb, alpha = MATERIALS[kind]
        m = model.materials[name]
        return m if m

        m = model.materials.add(name)
        m.color = Sketchup::Color.new(*rgb)
        m.alpha = alpha
        m
      end

      def signed_area_xy(points)
        a = 0.0
        points.each_with_index do |p, i|
          q = points[(i + 1) % points.size]
          a += p.x * q.y - q.x * p.y
        end
        a / 2.0
      end

      # Плоская рамка: контур outer с дырой inner, выдавленная на vector.
      def frame_prism(entities, outer, inner, vector, name = nil)
        g = entities.add_group
        g.name = name if name
        face = g.entities.add_face(outer)
        raise UserError, ArchiTools.t(:err_face_failed) unless face

        hole = g.entities.add_face(inner)
        hole&.erase!
        face = g.entities.grep(Sketchup::Face).first
        face.reverse! if face.normal.dot(vector).negative?
        face.pushpull(vector.length.to_f)
        ModifyTools.orient_outward(g.entities)
        g
      end

      # Точка заведомо внутри грани — центр первого треугольника сетки.
      def inner_point(face)
        mesh = face.mesh(0)
        a, b, c = mesh.polygons.first.map { |i| mesh.point_at(i.abs) }
        Geom::Point3d.new((a.x + b.x + c.x) / 3.0, (a.y + b.y + c.y) / 3.0, (a.z + b.z + c.z) / 3.0)
      end

      # Толщина стены за гранью: ближайшая встречная параллельная грань,
      # в которую попадает луч из грани против направления dir.
      def wall_thickness(face, dir)
        c = inner_point(face)
        best = nil
        face.parent.entities.grep(Sketchup::Face).each do |o|
          next if o == face
          next unless o.normal.dot(dir) < -0.999 || o.normal.dot(dir) > 0.999

          hit = Geom.intersect_line_plane([c, dir], o.plane)
          next unless hit

          d = (c - hit).dot(dir)
          next unless d > G.tol

          state = o.classify_point(hit)
          next unless [Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge,
                       Sketchup::Face::PointOnVertex].include?(state)

          best = d if best.nil? || d < best
        end
        best
      end

      # add_face поверх грани стены может развернуть её остаток изнанкой
      # наружу — возвращаем всем граням этой плоскости исходную нормаль.
      def keep_facing(entities, point, normal)
        entities.grep(Sketchup::Face).each do |f|
          next unless f.normal.parallel?(normal) && f.normal.dot(normal).negative?
          next unless point.distance_to_plane(f.plane).to_f < G.tol

          f.reverse!
        end
      end

      # Пробивает грань насквозь до задней поверхности стены.
      def punch(face)
        t = wall_thickness(face, face.normal)
        if t.nil?
          t = wall_thickness(face, face.normal.reverse)
          face.reverse! if t
        end
        raise UserError, ArchiTools.t(:err_no_back_face) unless t

        normal = face.normal
        point = face.vertices.first.position
        ents = face.parent.entities
        face.pushpull(-t)
        keep_facing(ents, point, normal)
        [t, normal]
      end

      # Контур проёма в осях грани (u вправо, v вверх).
      def opening_outline(shape, u0, v0, w, h, segments)
        r = w / 2.0
        case shape
        when :round
          (0...segments).map { |i| a = 2 * Math::PI * i / segments; [u0 + r + r * Math.cos(a), v0 + r + r * Math.sin(a)] }
        when :arch
          spring = v0 + h - r
          arc = (1...segments).map { |i| a = Math::PI * i / segments; [u0 + r + r * Math.cos(a), spring + r * Math.sin(a)] }
          [[u0, v0], [u0 + w, v0], [u0 + w, spring]] + arc + [[u0, spring]]
        else
          [[u0, v0], [u0 + w, v0], [u0 + w, v0 + h], [u0, v0 + h]]
        end
      end

      # Коробка по откосам проёма любой формы: кольцо шириной fw по контуру,
      # вглубь стены на depth (n смотрит наружу).
      def collar(entities, outline, n, fw, depth, name)
        normal = G.newell_normal(outline)
        sign = normal && normal.dot(n).positive? ? 1.0 : -1.0
        inner = G.offset_polyline(outline, fw * sign, n, true)
        frame_prism(entities, outline, inner, G.scale(n, -depth), name)
      end

      # Прямоугольник грани в её осях: origin (левый нижний угол), u, v, n, W, H.
      def rect_of(face)
        o, u, v, n = G.face_frame(face)
        loops = G.face_loops_uv(face, [o, u, v, n])
        umin, umax, vmin, vmax = G.bounds_uv([loops.first])
        [G.from_uv(umin, vmin, o, u, v), u, v, n, umax - umin, vmax - vmin]
      end

      def rectangular?(face)
        return false unless face.loops.size == 1

        _, _, _, _, w, h = rect_of(face)
        (face.area - w * h).abs < [w * h * 1.0e-4, 1.0e-3].max
      end

      def polygon_area_uv(pts)
        pts.each_with_index.sum { |(a, b), i| c, d = pts[(i + 1) % pts.size]; a * d - c * b }.abs / 2.0
      end

      # Прямоугольники, в которые ставится окно или дверь: сама грань, если
      # она прямоугольная, иначе её прямоугольные дыры — так можно выделить
      # стену целиком, и окна встанут во все проёмы.
      def openings_of(face)
        return [rect_of(face)] if rectangular?(face)

        frame = G.face_frame(face)
        o, u, v, n = frame
        face.loops.reject(&:outer?).filter_map do |loop|
          pts = loop.vertices.map { |vx| G.to_uv(vx.position, o, u, v) }
          umin, umax, vmin, vmax = G.bounds_uv([pts])
          w = umax - umin
          h = vmax - vmin
          next unless pts.size == 4 && (polygon_area_uv(pts) - w * h).abs < [w * h * 1.0e-4, 1.0e-3].max

          [G.from_uv(umin, vmin, o, u, v), u, v, n, w, h]
        end
      end

      def rects_for(ctx)
        rects = ctx.faces.flat_map { |f| openings_of(f) }
        ctx.need(!rects.empty?, :need_rect_face)
        rects
      end
    end

    Registry.define(:wall, :walls) do |p|
      p.length :thickness, 250
      p.length :height, 3000
      p.choice :align, :center, %i[center left right]
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges)
      ctx.need(!chains.empty?, :need_edges)
      t = ctx.p[:thickness]
      h = ctx.p[:height]
      ctx.need(t > Geom3.tol && h > Geom3.tol, :err_distance)
      offsets = { center: [t / 2.0, -t / 2.0], left: [t, 0.0], right: [0.0, -t] }[ctx.p[:align]]
      chains.each do |chain|
        z = chain[:points].map(&:z).min
        pts = chain[:points].map { |pt| Geom::Point3d.new(pt.x, pt.y, z) }
        next if pts.size < 2

        # Замкнутый контур ведём против часовой: «слева» — внутрь.
        pts = pts.reverse if chain[:closed] && WallTools.signed_area_xy(pts).negative?
        a = Geom3.offset_polyline(pts, offsets[0], Geom3::Z, chain[:closed])
        b = Geom3.offset_polyline(pts, offsets[1], Geom3::Z, chain[:closed])
        g = ctx.entities.add_group
        g.name = ctx.name(:wall)
        if chain[:closed]
          outer, inner = [a, b].sort_by { |ring| -WallTools.signed_area_xy(ring).abs }
          inner = nil if WallTools.signed_area_xy(inner).abs < 1.0e-6
          face = g.entities.add_face(outer)
          ctx.need(face, :err_face_failed)
          if inner
            hole = g.entities.add_face(inner)
            hole&.erase!
          end
          face = g.entities.grep(Sketchup::Face).first
        else
          face = g.entities.add_face(a + b.reverse)
          ctx.need(face, :err_face_failed)
        end
        face.reverse! if face.normal.z.negative?
        face.pushpull(h)
        ModifyTools.orient_outward(g.entities)
        ctx.made(g)
      end
      ArchiTools.t(:ok_wall, n: chains.size)
    end

    Registry.define(:opening, :walls) do |p|
      p.choice :source, :size, %i[size face]
      p.choice :shape, :rect, %i[rect arch round], show: { source: :size }
      p.length :width, 900, show: { source: :size }
      p.length :height, 2100, show: { source: :size, shape: %i[rect arch] }
      p.length :sill, 0, show: { source: :size }
      p.choice :position, :center, %i[center offset], show: { source: :size }
      p.length :offset, 500, show: { source: :size, position: :offset }
      p.int :segments, 24, min: 6, max: 96, show: { source: :size, shape: %i[arch round] }
      p.bool :frame, false
      p.length :frame_width, 60, show: { frame: true }
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_wall_face)
      count = 0
      if ctx.p[:source] == :face
        faces.each do |f|
          next unless f.valid?

          outline = f.outer_loop.vertices.map(&:position)
          t, n = WallTools.punch(f)
          ctx.made(WallTools.collar(ctx.entities, outline, n, ctx.p[:frame_width], t, ctx.name(:lining))) if ctx.p[:frame]
          count += 1
        end
      else
        ctx.need(faces.size == 1, :need_wall_face)
        wall = faces.first
        shape = ctx.p[:shape]
        w = ctx.p[:width]
        h = shape == :round ? w : ctx.p[:height]
        ctx.need(w > Geom3.tol && h > Geom3.tol, :err_distance)
        ctx.need(shape != :arch || h >= w / 2.0 - Geom3.tol, :err_arch_low)
        o, u, v, n, fw, fh = WallTools.rect_of(wall)
        u0 = ctx.p[:position] == :center ? (fw - w) / 2.0 : ctx.p[:offset]
        v0 = ctx.p[:sill]
        ctx.need(u0 >= -Geom3.tol && u0 + w <= fw + Geom3.tol && v0 >= -Geom3.tol && v0 + h <= fh + Geom3.tol,
                 :err_opening_outside)
        uv = WallTools.opening_outline(shape, u0, v0, w, h, ctx.p[:segments])
        outline = uv.map { |a, b| Geom3.from_uv(a, b, o, u, v) }
        area = WallTools.polygon_area_uv(uv)
        thickness = WallTools.wall_thickness(wall, n)
        ctx.need(thickness, :err_no_back_face)
        wall_plane_entities = wall.parent.entities
        ctx.entities.add_face(outline)
        # Новая грань — та, что легла в контур проёма.
        inside = Geom3.from_uv(u0 + w / 2.0, v0 + [h, w].min / 2.0, o, u, v)
        hole = wall_plane_entities.grep(Sketchup::Face).find do |f|
          f.normal.parallel?(n) && f.classify_point(inside) == Sketchup::Face::PointInside &&
            (f.area - area).abs < [area * 1.0e-3, 1.0e-3].max
        end
        ctx.need(hole, :err_face_failed)
        hole.reverse! if hole.normal.dot(n).negative?
        hole.pushpull(-thickness)
        WallTools.keep_facing(wall_plane_entities, outline[0], n)
        ctx.made(WallTools.collar(ctx.entities, outline, n, ctx.p[:frame_width], thickness, ctx.name(:lining))) if ctx.p[:frame]
        count = 1
      end
      ArchiTools.t(:ok_opening, n: count)
    end

    Registry.define(:window, :walls) do |p|
      p.int :cols, 2, min: 1, max: 50
      p.int :rows, 1, min: 1, max: 50
      p.length :frame_width, 60
      p.length :frame_depth, 70
      p.length :mullion, 50
      p.length :inset, 0
      p.bool :glass, true
    end.run do |ctx|
      rects = WallTools.rects_for(ctx)
      rects.each do |o, u, v, n, w, h|
        fw = ctx.p[:frame_width]
        fd = ctx.p[:frame_depth]
        mw = ctx.p[:mullion]
        cols = ctx.p[:cols]
        rows = ctx.p[:rows]
        iw = w - 2 * fw
        ih = h - 2 * fw
        pw = (iw - (cols - 1) * mw) / cols
        ph = (ih - (rows - 1) * mw) / rows
        ctx.need(pw > Geom3.tol && ph > Geom3.tol, :err_window_small)

        o = o.offset(n, -ctx.p[:inset])
        depth = Geom3.scale(n, -fd)
        win = ctx.entities.add_group
        win.name = ctx.name(:window)
        e = win.entities
        at = ->(a, b) { Geom3.from_uv(a, b, o, u, v) }
        outer = [at[0, 0], at[w, 0], at[w, h], at[0, h]]
        inner = [at[fw, fw], at[w - fw, fw], at[w - fw, h - fw], at[fw, h - fw]]
        frame = WallTools.frame_prism(e, outer, inner, depth, ctx.name(:frame))
        frame.material = WallTools.material(ctx.model, :frame)
        (1...cols).each do |i|
          x = fw + i * pw + (i - 1) * mw
          m = Geom3.box(e, at[x, fw], Geom3.scale(u, mw), Geom3.scale(v, ih), depth, ctx.name(:mullion))
          m.material = frame.material
        end
        (1...rows).each do |j|
          y = fw + j * ph + (j - 1) * mw
          m = Geom3.box(e, at[fw, y], Geom3.scale(u, iw), Geom3.scale(v, mw), depth, ctx.name(:mullion))
          m.material = frame.material
        end
        if ctx.p[:glass]
          glass = e.add_group
          glass.name = ctx.name(:glass)
          shift = Geom3.scale(n, -fd / 2.0)
          cols.times do |i|
            rows.times do |j|
              x = fw + i * (pw + mw)
              y = fw + j * (ph + mw)
              quad = [at[x, y], at[x + pw, y], at[x + pw, y + ph], at[x, y + ph]].map { |pt| pt.offset(shift) }
              glass.entities.add_face(quad)
            end
          end
          glass.material = WallTools.material(ctx.model, :glass)
        end
        ctx.made(win)
      end
      ArchiTools.t(:ok_window, n: rects.size)
    end

    Registry.define(:door, :walls) do |p|
      p.choice :leaves, :single, %i[single double]
      p.length :frame_width, 50
      p.length :frame_depth, 100
      p.length :leaf_thickness, 40
      p.length :gap, 3
      p.length :inset, 0
    end.run do |ctx|
      rects = WallTools.rects_for(ctx)
      rects.each do |o, u, v, n, w, h|
        fw = ctx.p[:frame_width]
        fd = ctx.p[:frame_depth]
        lt = ctx.p[:leaf_thickness]
        gap = ctx.p[:gap]
        ctx.need(w > 2 * fw + 4 * gap && h > fw + 2 * gap, :err_window_small)

        o = o.offset(n, -ctx.p[:inset])
        depth = Geom3.scale(n, -fd)
        door = ctx.entities.add_group
        door.name = ctx.name(:door)
        e = door.entities
        at = ->(a, b, c = 0.0) { Geom3.from_uv(a, b, o, u, v, c, n) }
        frame = e.add_group
        frame.name = ctx.name(:frame)
        Geom3.box(frame.entities, at[0, 0], Geom3.scale(u, fw), Geom3.scale(v, h), depth)
        Geom3.box(frame.entities, at[w - fw, 0], Geom3.scale(u, fw), Geom3.scale(v, h), depth)
        Geom3.box(frame.entities, at[fw, h - fw], Geom3.scale(u, w - 2 * fw), Geom3.scale(v, fw), depth)
        frame.material = WallTools.material(ctx.model, :frame)

        count = ctx.p[:leaves] == :double ? 2 : 1
        clear = w - 2 * fw - (count + 1) * gap
        lw = clear / count
        lh = h - fw - 2 * gap
        count.times do |i|
          x = fw + gap + i * (lw + gap)
          leaf = Geom3.box(e, at[x, gap, -(fd - lt) / 2.0], Geom3.scale(u, lw), Geom3.scale(v, lh),
                           Geom3.scale(n, -lt), ctx.name(:leaf))
          leaf.material = WallTools.material(ctx.model, :leaf)
        end
        ctx.made(door)
      end
      ArchiTools.t(:ok_door, n: rects.size)
    end
  end
end
