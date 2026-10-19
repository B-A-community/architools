# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Рёбра: скругление, фаска, продление, деление, центр, смещение, уклон,
    # перпендикуляр к грани.
    module EdgeTools
      G = Geom3

      module_function

      # Угол из двух рёбер: точка пересечения их прямых и для каждого ребра
      # дальний конец и направление от угла к нему.
      def corner(e1, e2)
        raise UserError, ArchiTools.t(:err_parallel) if e1.line[1].parallel?(e2.line[1])

        pt = Geom.intersect_line_line(e1.line, e2.line)
        raise UserError, ArchiTools.t(:err_not_coplanar) unless pt

        info = [e1, e2].map do |e|
          far = e.vertices.max_by { |v| v.position.distance(pt).to_f }.position
          near = e.other_vertex(e.vertices.find { |v| v.position == far }).position
          { edge: e, far: far, near: near, u: (far - pt).normalize, length: far.distance(pt).to_f }
        end
        [pt, info]
      end

      def on_segment?(edge, point)
        a = edge.start.position
        b = edge.end.position
        (a.distance(point).to_f + point.distance(b).to_f - a.distance(b).to_f).abs < G.tol * 10
      end

      # Доводит ребро до точки target на его прямой: разрезает его там или
      # дорисовывает недостающее. Возвращает отрезанный кусок со стороны угла —
      # его удаляют ПОСЛЕ того, как дуга или фаска замкнёт контур: тогда
      # исходная грань не пропадает, а отваливается только уголок.
      def trim_to(entities, info, target)
        edge = info[:edge]
        far = info[:far]
        near = info[:near]
        return nil if near.distance(target).to_f < G.tol

        if far.distance(target).to_f < far.distance(near).to_f - G.tol
          other = edge.split(target)
          [edge, other].compact.find do |piece|
            piece.valid? && piece.vertices.none? { |v| v.position.distance(far).to_f < G.tol }
          end
        else
          entities.add_line(near, target)
          nil
        end
      end

      def erase_cut(entities, pieces)
        list = pieces.compact.select(&:valid?)
        entities.erase_entities(list) unless list.empty?
      end

      def heal(entities, new_edges)
        new_edges.compact.each { |e| e.find_faces if e.valid? }
      end

      # --- скругление и фаска для двух рёбер --------------------------------

      def fillet_pair(entities, e1, e2, radius, segments)
        pt, (a, b) = corner(e1, e2)
        theta = a[:u].angle_between(b[:u])
        raise UserError, ArchiTools.t(:err_parallel) if theta < 1.0e-6 || (Math::PI - theta) < 1.0e-6

        if radius <= G.tol
          cut = [trim_to(entities, a, pt), trim_to(entities, b, pt)]
          erase_cut(entities, cut)
          return []
        end

        t = radius / Math.tan(theta / 2.0)
        if t > a[:length] + G.tol || t > b[:length] + G.tol
          raise UserError, ArchiTools.t(:err_radius_too_big,
                                        max: Sketchup.format_length([a[:length], b[:length]].min * Math.tan(theta / 2.0)))
        end
        t1 = pt.offset(a[:u], t)
        t2 = pt.offset(b[:u], t)
        bis = (a[:u] + b[:u]).normalize
        center = pt.offset(bis, radius / Math.sin(theta / 2.0))
        cut = [trim_to(entities, a, t1), trim_to(entities, b, t2)]
        x = (t1 - center).normalize
        y = (t2 - center).normalize
        normal = x.cross(y).normalize
        sweep = x.angle_between(y)
        arc = entities.add_arc(center, x, normal, radius, 0, sweep, segments)
        erase_cut(entities, cut)
        arc
      end

      def chamfer_pair(entities, e1, e2, d1, d2)
        pt, (a, b) = corner(e1, e2)
        d2 = d1 if d2 <= G.tol
        if d1 > a[:length] + G.tol || d2 > b[:length] + G.tol
          raise UserError, ArchiTools.t(:err_chamfer_too_big)
        end

        t1 = pt.offset(a[:u], d1)
        t2 = pt.offset(b[:u], d2)
        cut = [trim_to(entities, a, t1), trim_to(entities, b, t2)]
        line = entities.add_line(t1, t2)
        erase_cut(entities, cut)
        [line]
      end

      # --- скругление и фаска по цепочке --------------------------------------

      # Все внутренние углы цепочки (и углы замкнутого контура). Цепочка
      # перерисовывается заново, грани восстанавливаются find_faces.
      def rebuild_chain(entities, chain, &corner_points)
        pts = chain[:points]
        n = pts.size
        closed = chain[:closed]
        out = []
        n.times do |i|
          if !closed && (i.zero? || i == n - 1)
            out << [pts[i]]
            next
          end
          prev = pts[(i - 1) % n]
          cur = pts[i]
          nxt = pts[(i + 1) % n]
          u1 = prev - cur
          u2 = nxt - cur
          if u1.parallel?(u2)
            out << [cur]
          else
            out << corner_points.call(cur, u1, u2, prev.distance(cur).to_f, nxt.distance(cur).to_f)
          end
        end
        entities.erase_entities(chain[:edges])
        edges = []
        out.each_with_index do |group, i|
          edges.concat(entities.add_curve(group)) if group.size > 1
          next_group = out[i + 1] || (closed ? out[0] : nil)
          next unless next_group

          a = group.last
          b = next_group.first
          edges << entities.add_line(a, b) if a.distance(b).to_f > G.tol
        end
        edges.compact
      end

      def arc_points(cur, u1, u2, radius, segments, len1, len2)
        theta = u1.angle_between(u2)
        t = radius / Math.tan(theta / 2.0)
        # Половина каждого сегмента — предел, чтобы соседние скругления не наехали.
        limit = [len1, len2].min / 2.0
        if t > limit
          t = limit
          radius = t * Math.tan(theta / 2.0)
        end
        a = u1.normalize
        b = u2.normalize
        center = cur.offset((a + b).normalize, radius / Math.sin(theta / 2.0))
        t1 = cur.offset(a, t)
        t2 = cur.offset(b, t)
        x = t1 - center
        y = t2 - center
        normal = x.cross(y).normalize
        sweep = x.angle_between(y)
        (0..segments).map do |k|
          tr = Geom::Transformation.rotation(center, normal, sweep * k / segments)
          t1.transform(tr)
        end
      end

      # --- деление -----------------------------------------------------------

      # Доли длины ребра (0..1) для режима деления. Все режимы оригинала:
      # на N частей, шаг от начала, шаг от середины, «шаг не больше».
      def division(len, prm)
        s = prm[:seg_length]
        case prm[:by]
        when :count then (1...prm[:count]).map { |i| i.to_f / prm[:count] }
        when :max_length
          raise UserError, ArchiTools.t(:err_distance) if s <= G.tol

          n = (len / s - 1.0e-9).ceil
          (1...n).map { |i| i.to_f / n }
        when :from_middle
          raise UserError, ArchiTools.t(:err_distance) if s <= G.tol

          k = ((len / 2.0) / s).floor
          (-k..k).map { |i| (len / 2.0 + i * s) / len }.select { |f| f > 1.0e-9 && f < 1 - 1.0e-9 }
        else # :length — от начала ребра
          raise UserError, ArchiTools.t(:err_distance) if s <= G.tol

          (1..(len / s).floor).map { |i| i * s / len }.select { |f| f < 1 - 1.0e-9 }
        end
      end

      def divide_edge(entities, edge, fractions, output)
        a = edge.start.position
        b = edge.end.position
        at = ->(f) { Geom.linear_combination(1.0 - f, a, f, b) }
        case output
        when :points then return fractions.map { |f| entities.add_cpoint(at.call(f)) }
        when :midpoints
          marks = [0.0] + fractions + [1.0]
          return marks.each_cons(2).map { |f, g| entities.add_cpoint(at.call((f + g) / 2.0)) }
        end

        pieces = [edge]
        fractions.map { |f| at.call(f) }.each do |p|
          host = pieces.find { |e| e.valid? && on_segment?(e, p) }
          next unless host

          extra = host.split(p)
          pieces << extra if extra
        end
        pieces
      end
    end

    Registry.define(:fillet, :edges) do |p|
      p.length :radius, 300
      p.int :segments, 12, min: 2, max: 360
    end.run do |ctx|
      edges = ctx.edges
      ctx.need(edges.size >= 2, :need_two_edges)
      r = ctx.p[:radius]
      seg = ctx.p[:segments]
      if edges.size == 2
        arc = EdgeTools.fillet_pair(ctx.entities, edges[0], edges[1], r, seg)
        EdgeTools.heal(ctx.entities, arc)
        ctx.made(arc)
        ArchiTools.t(:ok_fillet, n: 1)
      else
        chains = Geom3.chains(edges).select { |c| c[:points].size >= 3 }
        ctx.need(!chains.empty?, :need_chain)
        chains.each do |chain|
          made = EdgeTools.rebuild_chain(ctx.entities, chain) do |cur, u1, u2, l1, l2|
            EdgeTools.arc_points(cur, u1, u2, r, seg, l1, l2)
          end
          EdgeTools.heal(ctx.entities, made)
          ctx.made(made)
        end
        ArchiTools.t(:ok_fillet_chain, n: chains.size)
      end
    end

    Registry.define(:chamfer, :edges) do |p|
      p.length :distance1, 200
      p.length :distance2, 0
    end.run do |ctx|
      edges = ctx.edges
      ctx.need(edges.size >= 2, :need_two_edges)
      d1 = ctx.p[:distance1]
      d2 = ctx.p[:distance2]
      ctx.need(d1 > Geom3.tol, :err_distance)
      if edges.size == 2
        made = EdgeTools.chamfer_pair(ctx.entities, edges[0], edges[1], d1, d2)
        EdgeTools.heal(ctx.entities, made)
        ctx.made(made)
        ArchiTools.t(:ok_chamfer, n: 1)
      else
        chains = Geom3.chains(edges).select { |c| c[:points].size >= 3 }
        ctx.need(!chains.empty?, :need_chain)
        chains.each do |chain|
          made = EdgeTools.rebuild_chain(ctx.entities, chain) do |cur, u1, u2, l1, l2|
            a = [d1, l1 / 2.0].min
            b = [d2 > Geom3.tol ? d2 : d1, l2 / 2.0].min
            [cur.offset(u1, a), cur.offset(u2, b)]
          end
          EdgeTools.heal(ctx.entities, made)
          ctx.made(made)
        end
        ArchiTools.t(:ok_chamfer, n: chains.size)
      end
    end

    Registry.define(:extend_edges, :edges).run do |ctx|
      edges = ctx.edges
      faces = ctx.faces
      if faces.size == 1 && !edges.empty?
        plane = faces.first.plane
        done = 0
        edges.each do |e|
          hit = Geom.intersect_line_plane(e.line, plane)
          next unless hit

          far = e.vertices.max_by { |v| v.position.distance(hit).to_f }.position
          near = e.vertices.min_by { |v| v.position.distance(hit).to_f }.position
          EdgeTools.erase_cut(ctx.entities, [EdgeTools.trim_to(ctx.entities, { edge: e, far: far, near: near }, hit)])
          done += 1
        end
        ctx.need(done.positive?, :err_no_hits)
        ArchiTools.t(:ok_extend_face, n: done)
      else
        ctx.need(edges.size == 2 && faces.empty?, :need_extend)
        EdgeTools.fillet_pair(ctx.entities, edges[0], edges[1], 0.0, 1)
        ArchiTools.t(:ok_extend)
      end
    end

    Registry.define(:divide, :edges) do |p|
      p.choice :by, :count, %i[count length from_middle max_length]
      p.int :count, 4, min: 2, max: 1000, show: { by: :count }
      p.length :seg_length, 1000, show: { by: %i[length from_middle max_length] }
      p.choice :output, :split, %i[split points midpoints]
    end.run do |ctx|
      edges = ctx.edges
      ctx.need(!edges.empty?, :need_edges)
      total = 0
      edges.each do |e|
        fractions = EdgeTools.division(e.length.to_f, ctx.p)
        next if fractions.empty? && ctx.p[:output] != :midpoints
        raise UserError, ArchiTools.t(:err_too_many) if fractions.size > 1000

        ctx.made(EdgeTools.divide_edge(ctx.entities, e, fractions, ctx.p[:output]))
        total += 1
      end
      ArchiTools.t(:ok_divide, n: total)
    end

    Registry.define(:center_point, :edges) do |p|
      p.bool :axis, false
    end.run do |ctx|
      curves = ctx.edges.map(&:curve).compact.grep(Sketchup::ArcCurve).uniq
      faces = ctx.faces
      ctx.need(!curves.empty? || !faces.empty?, :need_arcs)
      curves.each do |c|
        ctx.made(ctx.entities.add_cpoint(c.center))
        ctx.made(ctx.entities.add_cline(c.center, c.normal)) if ctx.p[:axis]
      end
      faces.each do |f|
        # Центр тяжести по треугольникам сетки грани.
        mesh = f.mesh(0)
        sum = Geom::Vector3d.new(0, 0, 0)
        area = 0.0
        mesh.polygons.each do |poly|
          a, b, c = poly.map { |i| mesh.point_at(i.abs) }
          w = (b - a).cross(c - a).length.to_f / 2.0
          cen = Geom.linear_combination(1.0 / 3, a, 2.0 / 3, Geom.linear_combination(0.5, b, 0.5, c))
          sum += Geom::Vector3d.new(cen.x * w, cen.y * w, cen.z * w)
          area += w
        end
        next if area < 1.0e-12

        cpt = Geom::Point3d.new(sum.x / area, sum.y / area, sum.z / area)
        ctx.made(ctx.entities.add_cpoint(cpt))
        ctx.made(ctx.entities.add_cline(cpt, f.normal)) if ctx.p[:axis]
      end
      ArchiTools.t(:ok_center, n: curves.size + faces.size)
    end

    Registry.define(:offset_edges, :edges) do |p|
      p.length :distance, 100
      p.bool :both_sides, false
      p.bool :flip, false
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges)
      ctx.need(!chains.empty?, :need_edges)
      d = ctx.p[:distance]
      ctx.need(d > Geom3.tol, :err_distance)
      d = -d if ctx.p[:flip]
      chains.each do |chain|
        pts = chain[:points]
        next if pts.size < 2

        pts = Geom3.canonical(pts) unless chain[:closed]
        n = Geom3.chain_normal(pts)
        sign = 1.0
        if chain[:closed]
          # Замкнутый контур: положительное смещение — наружу.
          area = Geom3.newell_normal(pts)
          sign = area && area.dot(n).positive? ? -1.0 : 1.0
        end
        dists = ctx.p[:both_sides] ? [d, -d] : [d]
        dists.each do |dist|
          out = Geom3.offset_polyline(pts, dist * sign, n, chain[:closed])
          out << out.first if chain[:closed]
          ctx.made(ctx.entities.add_curve(out))
        end
      end
      ArchiTools.t(:ok_offset, n: chains.size)
    end

    Registry.define(:slope_edges, :edges) do |p|
      p.choice :by, :angle, %i[angle gradient height]
      p.angle :angle, 5, min: -80, max: 80, show: { by: :angle }
      p.float :gradient, 20, min: 0.01, show: { by: :gradient }
      p.length :height, 500, show: { by: :height }
      p.bool :reverse, false
      p.bool :keep_original, false
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges).reject { |c| c[:closed] }
      ctx.need(!chains.empty?, :need_open_chain)
      chains.each do |chain|
        verts = chain[:vertices]
        verts = verts.reverse if Geom3.canonical(verts.map(&:position)).first != verts.first.position
        verts = verts.reverse if verts.last.position.z.to_f < verts.first.position.z.to_f - Geom3.tol
        verts = verts.reverse if ctx.p[:reverse]
        pts = verts.map(&:position)
        plan = pts.each_cons(2).map { |a, b| Math.hypot(b.x - a.x, b.y - a.y) }
        total = plan.sum
        ctx.need(total > Geom3.tol, :err_vertical_chain)
        k =
          case ctx.p[:by]
          when :angle then Math.tan(Geom3.deg(ctx.p[:angle]))
          when :gradient then 1.0 / ctx.p[:gradient]
          else ctx.p[:height] / total
          end
        z0 = pts.first.z
        s = 0.0
        vectors = pts.each_with_index.map do |pt, i|
          s += plan[i - 1] if i.positive?
          Geom::Vector3d.new(0, 0, z0 + s * k - pt.z)
        end
        if ctx.p[:keep_original]
          # Как в оригинале: исходные рёбра остаются, уклон получает копия.
          ctx.made(ctx.entities.add_curve(pts.zip(vectors).map { |q, vec| q.offset(vec) }))
        else
          Geom3.move_vertices(ctx.entities, verts, vectors)
          ctx.made(chain[:edges].select(&:valid?))
        end
      end
      ArchiTools.t(:ok_slope, n: chains.size)
    end

    Registry.define(:normal_line, :edges) do |p|
      p.choice :output, :edge, %i[edge guide]
      p.length :length, 1000, show: { output: :edge }
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      faces.each do |f|
        c = f.bounds.center
        c = c.project_to_plane(f.plane)
        if ctx.p[:output] == :guide
          ctx.made(ctx.entities.add_cline(c, f.normal))
        else
          ctx.made(ctx.entities.add_line(c, c.offset(f.normal, ctx.p[:length])))
        end
      end
      ArchiTools.t(:ok_normal, n: faces.size)
    end
  end
end
