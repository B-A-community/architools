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

      # Слои стены в сечении (a — вправо от линии, b — вверх): сплошная,
      # с воздушной прослойкой, перегородка (две обшивки, между ними стойки)
      # или своё сечение по выделенной грани.
      def wall_layers(prm, face = nil)
        h = prm[:height]
        rect = ->(a0, a1) { [[[a0, 0.0], [a1, 0.0], [a1, h], [a0, h]]] }
        if face
          pts = face.outer_loop.vertices.map(&:position)
          cx = (pts.map(&:x).min + pts.map(&:x).max) / 2.0
          y0 = pts.map(&:y).min
          return [[pts.map { |pt| [pt.x - cx, pt.y - y0] }]]
        end

        widths =
          case prm[:kind]
          when :cavity then [prm[:leaf], prm[:cavity], prm[:leaf_inner]]
          when :stud then [prm[:leaf], prm[:cavity], prm[:leaf]]
          else [prm[:thickness]]
          end
        raise UserError, ArchiTools.t(:err_distance) if widths.any? { |w| w <= G.tol } || h <= G.tol

        total = widths.sum
        a0 = { center: -total / 2.0, left: -total, right: 0.0 }[prm[:align]]
        bounds = widths.each_with_object([a0]) { |w, acc| acc << acc.last + w }
        layers = bounds.each_cons(2).map { |x0, x1| rect.call(x0, x1) }
        prm[:kind] == :solid ? layers : [layers[0], layers[2]]
      end

      # Стойки перегородки: в прослойке, с шагом и на каждом изломе.
      def studs(entities, pts, closed, prm, h, name)
        widths = [prm[:leaf], prm[:cavity], prm[:leaf]]
        a0 = { center: -widths.sum / 2.0, left: -widths.sum, right: 0.0 }[prm[:align]] + widths[0]
        sw = prm[:stud_width]
        raise UserError, ArchiTools.t(:err_distance) if sw <= G.tol || prm[:stud_spacing] <= sw

        path = closed ? pts + [pts.first] : pts
        stations = Railing.post_points(path, prm[:stud_spacing])
        stations.pop if closed
        stations.each do |pt|
          seg = path.each_cons(2).find { |a, b| (a.distance(pt).to_f + pt.distance(b).to_f - a.distance(b).to_f).abs < 1.0e-6 }
          dir = (seg[1] - seg[0])
          dir = Geom::Vector3d.new(dir.x, dir.y, 0).normalize
          side = dir.cross(G::Z).normalize
          origin = pt.offset(side, a0).offset(dir, -sw / 2.0)
          G.box(entities, origin, G.scale(dir, sw), G.scale(side, prm[:cavity]), G.scale(G::Z, h), name)
        end
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
      p.choice :kind, :solid, %i[solid cavity stud]
      p.length :thickness, 250, show: { kind: :solid }
      p.length :height, 3000
      p.choice :align, :center, %i[center left right]
      p.length :leaf, 100, show: { kind: %i[cavity stud] }
      p.length :leaf_inner, 100, show: { kind: :cavity }
      p.length :cavity, 50, show: { kind: %i[cavity stud] }
      p.length :stud_spacing, 600, show: { kind: :stud }
      p.length :stud_width, 50, show: { kind: :stud }
      p.bool :follow_slope, false
    end.run do |ctx|
      profile_face = ctx.faces.first if ctx.faces.size == 1
      edges = ctx.edges - (profile_face ? profile_face.edges : [])
      chains = Geom3.chains(edges)
      ctx.need(!chains.empty?, :need_edges)
      prm = ctx.p
      h = prm[:height]
      layers = WallTools.wall_layers(prm, profile_face)
      chains.each do |chain|
        pts = chain[:points]
        next if pts.size < 2

        unless prm[:follow_slope]
          z = pts.map { |pt| pt.z.to_f }.min
          pts = pts.map { |pt| Geom::Point3d.new(pt.x, pt.y, z) }
        end
        # Замкнутый контур ведём против часовой: «слева» — внутрь.
        pts = pts.reverse if chain[:closed] && WallTools.signed_area_xy(pts).negative?
        pts = Geom3.canonical(pts) unless chain[:closed]
        if layers.size == 1 && prm[:kind] != :stud
          ctx.made(Profiles.sweep_group(ctx.entities, pts, chain[:closed], layers.first, ctx.name(:wall), smooth: false,
                                                                                       vertical: true))
          next
        end

        g = ctx.entities.add_group
        g.name = ctx.name(:wall)
        layers.each { |loops| Profiles.sweep_group(g.entities, pts, chain[:closed], loops, ctx.name(:leaf_layer), smooth: false, vertical: true) }
        WallTools.studs(g.entities, pts, chain[:closed], prm, h, ctx.name(:stud)) if prm[:kind] == :stud
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
      p.choice :type, :fixed, %i[fixed casement sliding]
      p.int :cols, 2, min: 1, max: 50, show: { type: %i[fixed casement] }
      p.int :rows, 1, min: 1, max: 50, show: { type: %i[fixed casement] }
      p.choice :profile, :flat, %i[flat rebated casing]
      p.choice :position, :back, %i[back middle front]
      p.length :frame_width, 60
      p.length :frame_depth, 70
      p.length :mullion, 50, show: { type: %i[fixed casement] }
      p.length :sash_width, 50, show: { type: %i[casement sliding] }
      p.length :inset, 0
      p.bool :glass, true
    end.run do |ctx|
      rects = WallTools.rects_for(ctx)
      rects.each do |o, u, v, n, w, h|
        prm = ctx.p
        fw = prm[:frame_width]
        fd = prm[:frame_depth]
        mw = prm[:mullion]
        sw = prm[:sash_width]
        sliding = prm[:type] == :sliding
        cols = sliding ? 2 : prm[:cols]
        rows = sliding ? 1 : prm[:rows]
        iw = w - 2 * fw
        ih = h - 2 * fw
        ctx.need(iw > Geom3.tol && ih > Geom3.tol, :err_window_small)

        # Положение рамы относительно грани: за ней, посередине, перед ней.
        o = o.offset(n, { back: 0.0, middle: fd / 2.0, front: fd }[prm[:position]] - prm[:inset])
        depth = Geom3.scale(n, -fd)
        win = ctx.entities.add_group
        win.name = ctx.name(:window)
        e = win.entities
        at = ->(x, y, z = 0.0) { Geom3.from_uv(x, y, o, u, v, z, n) }
        rect = ->(x0, y0, x1, y1, z = 0.0) { [at[x0, y0, z], at[x1, y0, z], at[x1, y1, z], at[x0, y1, z]] }
        frame_mat = WallTools.material(ctx.model, :frame)
        frame = WallTools.frame_prism(e, rect[0, 0, w, h], rect[fw, fw, w - fw, h - fw], depth, ctx.name(:frame))
        frame.material = frame_mat
        case prm[:profile]
        when :rebated
          # Четверть: узкий выступ внутрь проёма на трети глубины рамы.
          lip = [fw / 2.0, 20.mm.to_f].min
          z = -fd / 3.0
          r = WallTools.frame_prism(e, rect[fw, fw, w - fw, h - fw, z], rect[fw + lip, fw + lip, w - fw - lip, h - fw - lip, z],
                                    Geom3.scale(n, -fd / 3.0), ctx.name(:frame))
          r.material = frame_mat
          fw += lip
          iw -= 2 * lip
          ih -= 2 * lip
        when :casing
          # Наличник: плоская рамка снаружи по стене вокруг проёма.
          cw = fw
          r = WallTools.frame_prism(e, rect[-cw, -cw, w + cw, h + cw, 20.mm.to_f], rect[0, 0, w, h, 20.mm.to_f],
                                    Geom3.scale(n, -20.mm.to_f), ctx.name(:casing))
          r.material = frame_mat
        end

        glass_group = nil
        add_glass = lambda do |quad|
          next unless prm[:glass]

          glass_group ||= e.add_group.tap { |g| g.name = ctx.name(:glass) }
          glass_group.entities.add_face(quad)
        end

        if sliding
          # Две створки внахлёст в разных плоскостях: передняя и задняя.
          lap = sw
          leaf = (iw + lap) / 2.0
          [[fw, -fd * 0.25], [fw + iw - leaf, -fd * 0.75]].each do |x0, zc|
            z0 = zc + fd * 0.2
            sash = WallTools.frame_prism(e, rect[x0, fw, x0 + leaf, h - fw, z0],
                                         rect[x0 + sw, fw + sw, x0 + leaf - sw, h - fw - sw, z0],
                                         Geom3.scale(n, -fd * 0.4), ctx.name(:sash))
            sash.material = frame_mat
            add_glass.call(rect[x0 + sw, fw + sw, x0 + leaf - sw, h - fw - sw, zc])
          end
        else
          pw = (iw - (cols - 1) * mw) / cols
          ph = (ih - (rows - 1) * mw) / rows
          ctx.need(pw > Geom3.tol && ph > Geom3.tol, :err_window_small)
          (1...cols).each do |i|
            x = fw + i * pw + (i - 1) * mw
            Geom3.box(e, at[x, fw], Geom3.scale(u, mw), Geom3.scale(v, ih), depth, ctx.name(:mullion))&.material = frame_mat
          end
          (1...rows).each do |j|
            y = fw + j * ph + (j - 1) * mw
            Geom3.box(e, at[fw, y], Geom3.scale(u, iw), Geom3.scale(v, mw), depth, ctx.name(:mullion))&.material = frame_mat
          end
          cols.times do |i|
            rows.times do |j|
              x = fw + i * (pw + mw)
              y = fw + j * (ph + mw)
              if prm[:type] == :casement
                ctx.need(pw > 2 * sw && ph > 2 * sw, :err_window_small)
                sash = WallTools.frame_prism(e, rect[x, y, x + pw, y + ph, -fd * 0.1],
                                             rect[x + sw, y + sw, x + pw - sw, y + ph - sw, -fd * 0.1],
                                             Geom3.scale(n, -fd * 0.8), ctx.name(:sash))
                sash.material = frame_mat
                add_glass.call(rect[x + sw, y + sw, x + pw - sw, y + ph - sw, -fd / 2.0])
              else
                add_glass.call(rect[x, y, x + pw, y + ph, -fd / 2.0])
              end
            end
          end
        end
        glass_group&.material = WallTools.material(ctx.model, :glass)
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
