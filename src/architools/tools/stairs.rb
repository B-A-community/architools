# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Лестницы: прямой марш (сплошной, по косоурам-плите, на тетивах) и
    # винтовая. Строятся в начале координат и ставятся кликом (PlaceTool).
    module StairTools
      G = Geom3

      module_function

      def xz(x, z)
        Geom::Point3d.new(x, 0, z)
      end

      # Профиль под наклонной линией: верх уже есть в pts, низ — прямая с
      # уклоном slope через (x_end, z_end), обрезанная полом z = 0.
      def close_under(pts, x_end, z_end, slope)
        pts << xz(x_end, z_end)
        x0 = x_end - z_end / slope
        if x0 >= 0
          pts << xz(x0, 0) if x0 > G.tol
        else
          # Нижняя линия выходит из-под первой ступени выше пола.
          pts[0] = xz(0, z_end - x_end * slope)
        end
        pts
      end

      def straight(entities, prm, name)
        n = prm[:risers]
        g = prm[:going]
        r = prm[:rise] / n
        w = prm[:width]
        slope = r / g
        stair = entities.add_group
        stair.name = name
        e = stair.entities
        width_vec = Geom::Vector3d.new(0, w, 0)
        xe = (n - 1) * g

        if %i[treads mono].include?(prm[:type])
          th = prm[:tread_thickness]
          mono = prm[:type] == :mono
          sw = prm[:stringers] || mono ? prm[:stringer_width] : 0.0
          inset = mono ? 0.0 : sw
          (n - 1).times do |i|
            G.box(e, Geom::Point3d.new(i * g - prm[:nosing], inset, (i + 1) * r - th),
                  Geom::Vector3d.new(g + prm[:nosing], 0, 0), Geom::Vector3d.new(0, w - 2 * inset, 0),
                  Geom::Vector3d.new(0, 0, th))
          end
          if prm[:stringers] || mono
            sdv = prm[:stringer_depth] * Math.sqrt(g * g + r * r) / g
            (mono ? [(w - sw) / 2.0] : [0.0, w - sw]).each do |y|
              pts = [xz(0, 0), xz(0, r - th), xz(xe, n * r - th)]
              pts = close_under(pts, xe, n * r - th - sdv, slope)
              pts = pts.map { |pt| Geom::Point3d.new(pt.x, y, pt.z) }
              G.prism(e, pts, Geom::Vector3d.new(0, sw, 0))
            end
          end
          add_straight_railings(stair, prm) if prm[:railing]
          return stair
        end

        pts = [xz(0, 0)]
        n.times do |i|
          pts << xz(i * g, (i + 1) * r)
          pts << xz((i + 1) * g, (i + 1) * r) if i < n - 1
        end
        if prm[:type] == :solid
          pts << xz(xe, 0)
        else
          wv = prm[:waist] * Math.sqrt(g * g + r * r) / g
          pts = close_under(pts, xe, n * r - wv, slope)
        end
        G.prism(e, pts.uniq { |pt| [pt.x.round(6), pt.z.round(6)] }, width_vec)
        add_straight_railings(stair, prm) if prm[:railing]
        stair
      end

      # Линия ограждения марша по носкам: от первой ступени до верхнего пола.
      def flight_line(prm, risers, y)
        g = prm[:going]
        r = prm[:rise] / prm[:risers]
        [Geom::Point3d.new(0, y, r), Geom::Point3d.new((risers - 1) * g, y, risers * r)]
      end

      def rail_inset(prm)
        prm[:post_size] / 2.0 + 10.mm.to_f
      end

      def add_railings(group, paths, prm)
        paths.each do |pts|
          pts = pts.each_with_object([]) { |pt, acc| acc << pt if acc.empty? || acc.last.distance(pt).to_f > G.tol }
          Railing.build(group.entities, pts, prm, ArchiTools.t(:name_railing)) if pts.size >= 2
        end
      end

      def add_straight_railings(stair, prm)
        e = rail_inset(prm)
        n = prm[:risers]
        add_railings(stair, [flight_line(prm, n, e), flight_line(prm, n, prm[:width] - e)], prm)
      end

      # Два марша с площадкой: Г-образная (поворот 90°) или П-образная (180°).
      def landing(entities, prm, name)
        n = prm[:risers]
        n1 = prm[:first_flight]
        n2 = n - n1
        raise UserError, ArchiTools.t(:err_flight_short) if n1 < 2 || n2 < 2

        r = prm[:rise] / n
        g = prm[:going]
        w = prm[:width]
        gap = prm[:gap]
        turn = prm[:turn]
        stair = entities.add_group
        stair.name = name
        flight = lambda do |k|
          straight(stair.entities, prm.merge(risers: k, rise: k * r, railing: false), ArchiTools.t(:name_flight))
        end
        flight.call(n1)
        xl = (n1 - 1) * g
        h1 = n1 * r
        y0, y1 =
          case turn
          when :u_left then [0.0, 2 * w + gap]
          when :u_right then [-(w + gap), w]
          else [0.0, w]
          end
        lt = prm[:type] == :solid ? h1 : [prm[:waist], prm[:tread_thickness]].max
        G.box(stair.entities, Geom::Point3d.new(xl, y0, h1 - lt), Geom::Vector3d.new(w, 0, 0),
              Geom::Vector3d.new(0, y1 - y0, 0), Geom::Vector3d.new(0, 0, lt), ArchiTools.t(:name_landing))
        f2 = flight.call(n2)
        z = G::Z
        rot = ->(a) { Geom::Transformation.rotation(ORIGIN, z, a) }
        t =
          case turn
          when :l_left then Geom::Transformation.translation([xl + w, w, h1]) * rot.call(Math::PI / 2)
          when :l_right then Geom::Transformation.translation([xl, 0, h1]) * rot.call(-Math::PI / 2)
          when :u_left then Geom::Transformation.translation([xl, 2 * w + gap, h1]) * rot.call(Math::PI)
          else Geom::Transformation.translation([xl, -gap, h1]) * rot.call(Math::PI)
          end
        f2.transform!(t)
        add_landing_railings(stair, prm, n1, n2, r, xl, h1, t) if prm[:railing]
        stair
      end

      # Снаружи поворота — одно ограждение через площадку, внутри — по маршам.
      def add_landing_railings(stair, prm, n1, n2, r, xl, h1, t)
        w = prm[:width]
        turn = prm[:turn]
        e = rail_inset(prm)
        left = %i[l_left u_left].include?(turn)
        y_out = left ? e : w - e
        y_in = left ? w - e : e
        p1 = prm.merge(rise: n1 * r, risers: n1)
        p2 = prm.merge(rise: n2 * r, risers: n2)
        l1_out = flight_line(p1, n1, y_out)
        l2_out = flight_line(p2, n2, y_out).map { |pt| pt.transform(t) }
        corners =
          if turn.to_s.start_with?('l')
            hit = Geom.intersect_line_line([Geom::Point3d.new(0, y_out, h1), G::X],
                                           [Geom::Point3d.new(l2_out[0].x, l2_out[0].y, h1), l2_out[1] - l2_out[0]])
            hit ? [Geom::Point3d.new(hit.x, hit.y, h1)] : []
          else
            xc = xl + w - e
            [Geom::Point3d.new(xc, y_out, h1), Geom::Point3d.new(xc, l2_out[0].y, h1)]
          end
        outer = l1_out + corners + l2_out
        inner1 = flight_line(p1, n1, y_in)
        inner2 = flight_line(p2, n2, y_in).map { |pt| pt.transform(t) }
        add_railings(stair, [outer, inner1, inner2], prm)
      end

      # Эскалатор: ступени под углом, гребёнки-площадки внизу и вверху,
      # фартуки, стеклянные балюстрады и поручни-ленты.
      # Ступени эскалатора — не выше 200 мм; проступь из угла.
      def escalator_steps(prm)
        n = [(prm[:rise] / 200.mm.to_f).ceil, 2].max
        r = prm[:rise] / n
        [n, r, r / Math.tan(G.deg(prm[:angle]))]
      end

      def escalator_run(prm)
        n, _, g = escalator_steps(prm)
        (n - 1) * g
      end

      def escalator(entities, prm, name)
        h = prm[:rise]
        w = prm[:width]
        n, _r, g = escalator_steps(prm)
        ll = prm[:landing]
        bh = prm[:balustrade]
        stair = entities.add_group
        stair.name = name
        e = stair.entities
        straight(e, prm.merge(type: :slab, risers: n, going: g, waist: 120.mm.to_f, railing: false),
                 ArchiTools.t(:name_steps))
        xe = (n - 1) * g
        plate = 20.mm.to_f
        G.box(e, Geom::Point3d.new(-ll, 0, -plate), Geom::Vector3d.new(ll, 0, 0), Geom::Vector3d.new(0, w, 0),
              Geom::Vector3d.new(0, 0, plate), ArchiTools.t(:name_landing))
        G.box(e, Geom::Point3d.new(xe, 0, h - plate), Geom::Vector3d.new(ll, 0, 0), Geom::Vector3d.new(0, w, 0),
              Geom::Vector3d.new(0, 0, plate), ArchiTools.t(:name_landing))
        top = [[-ll, 0.0], [0.0, 0.0], [xe, h], [xe + ll, h]]
        skirt = 100.mm.to_f
        depth = prm[:truss_depth]
        side = 120.mm.to_f
        line = ->(lift, y) { top.map { |x, zz| Geom::Point3d.new(x, y, zz + lift) } }
        [-side, w].each do |y|
          poly = line.call(skirt, y) + line.call(-depth, y).reverse
          G.prism(e, poly, Geom::Vector3d.new(0, side, 0))
        end
        glass = e.add_group
        glass.name = ArchiTools.t(:name_glass)
        belt = Profiles.loops(:rect, 80.mm.to_f, 40.mm.to_f, 0, 0)
        [-side / 2.0, w + side / 2.0].each do |y|
          glass.entities.add_face(line.call(skirt, y) + line.call(bh - 40.mm.to_f, y).reverse)
          Profiles.sweep_group(e, line.call(bh, y), false, belt, ArchiTools.t(:name_handrail))
        end
        glass.material = WallTools.material(Sketchup.active_model, :glass)
        stair
      end

      # Г-образная лестница с забежными ступенями в углу вместо площадки.
      # Ступени — блоки до пола (solid) или плиты толщиной tread_thickness.
      def winder(entities, prm, name)
        n = prm[:risers]
        k = prm[:winders]
        n1 = prm[:first_flight]
        n2 = n - 1 - n1 - k
        raise UserError, ArchiTools.t(:err_flight_short) if n1 < 1 || n2 < 1

        r = prm[:rise] / n
        g = prm[:going]
        w = prm[:width]
        stair = entities.add_group
        stair.name = name
        e = stair.entities
        step = lambda do |pts, idx|
          top = (idx + 1) * r
          bottom = prm[:type] == :solid ? 0.0 : top - prm[:tread_thickness]
          G.prism(e, pts.map { |x, y| Geom::Point3d.new(x, y, bottom) }, Geom::Vector3d.new(0, 0, top - bottom))
        end
        n1.times { |i| step.call([[i * g, 0], [(i + 1) * g, 0], [(i + 1) * g, w], [i * g, w]], i) }
        x0 = n1 * g
        # Веер из внутреннего угла (x0, w): лучи от направления −Y до +X.
        corner = lambda do |ang|
          dx = Math.cos(ang)
          dy = Math.sin(ang)
          t = [dx.abs > 1.0e-9 ? w / dx.abs : Float::INFINITY, dy.abs > 1.0e-9 ? w / dy.abs : Float::INFINITY].min
          [x0 + dx * t, w + dy * t]
        end
        k.times do |j|
          a0 = -Math::PI / 2 + Math::PI / 2 * j / k
          a1 = -Math::PI / 2 + Math::PI / 2 * (j + 1) / k
          pts = [[x0, w], corner.call(a0)]
          pts << [x0 + w, 0.0] if a0 < -Math::PI / 4 - 1.0e-9 && a1 > -Math::PI / 4 + 1.0e-9
          pts << corner.call(a1)
          step.call(pts, n1 + j)
        end
        n2.times do |i|
          y = w + i * g
          step.call([[x0, y], [x0 + w, y], [x0 + w, y + g], [x0, y + g]], n1 + k + i)
        end
        if prm[:turn] == :right
          stair.transform!(Geom::Transformation.translation([0, w, 0]) * Geom::Transformation.scaling(ORIGIN, 1, -1, 1))
        end
        stair
      end

      def spiral(entities, prm, name)
        n = prm[:risers]
        r = prm[:rise] / n
        total = G.deg(prm[:angle])
        step = total / n
        sign = prm[:direction] == :cw ? -1.0 : 1.0
        ri = prm[:inner_radius]
        ro = prm[:outer_radius]
        th = prm[:tread_thickness]
        model = Sketchup.active_model

        defn = model.definitions.add(name + ' · ' + ArchiTools.t(:name_tread))
        k = [(step.abs * 180 / Math::PI / 5).ceil, 2].max
        arc = ->(rad) { (0..k).map { |j| a = sign * step * j / k; Geom::Point3d.new(rad * Math.cos(a), rad * Math.sin(a), 0) } }
        outline = ri > G.tol ? arc.call(ro) + arc.call(ri).reverse : arc.call(ro) + [ORIGIN]
        face = defn.entities.add_face(outline)
        face.reverse! if face.normal.z.positive?
        face.pushpull(th)

        stair = entities.add_group
        stair.name = name
        n.times do |i|
          t = Geom::Transformation.translation([0, 0, (i + 1) * r]) *
              Geom::Transformation.rotation(ORIGIN, G::Z, sign * step * i)
          stair.entities.add_instance(defn, t)
        end
        if prm[:column] && ri > G.tol
          col = stair.entities.add_group
          col.name = ArchiTools.t(:name_column)
          circle = col.entities.add_circle(ORIGIN, G::Z, ri, 24)
          f = col.entities.add_face(circle)
          f.reverse! if f.normal.z.negative?
          f.pushpull(prm[:rise])
        end
        stair
      end
    end

    Registry.define(:straight_stairs, :stairs) do |p|
      p.choice :type, :slab, %i[slab solid treads mono]
      p.length :width, 1200
      p.length :rise, 3000
      p.int :risers, 17, min: 2, max: 200
      p.length :going, 280
      p.length :waist, 150, show: { type: :slab }
      p.length :tread_thickness, 40, show: { type: %i[treads mono] }
      p.length :nosing, 20, show: { type: %i[treads mono] }
      p.bool :stringers, true, show: { type: :treads }
      p.length :stringer_width, 50, show: { type: %i[treads mono] }
      p.length :stringer_depth, 250, show: { type: %i[treads mono] }
      p.bool :railing, false
      Railing.params(p, { railing: true })
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:width] > Geom3.tol && prm[:rise] > Geom3.tol && prm[:going] > Geom3.tol, :err_distance)
      g = StairTools.straight(ctx.entities, prm, ctx.name(:stairs))
      ctx.made(g)
      ctx.placing = g
      r = prm[:rise] / prm[:risers]
      ArchiTools.t(:ok_stairs, riser: Sketchup.format_length(r), going: Sketchup.format_length(prm[:going]),
                               run: Sketchup.format_length((prm[:risers] - 1) * prm[:going]),
                               rule: ((2 * r + prm[:going]) * 25.4).round)
    end

    Registry.define(:spiral_stairs, :stairs) do |p|
      p.length :outer_radius, 1000
      p.length :inner_radius, 100
      p.length :rise, 3000
      p.int :risers, 16, min: 2, max: 200
      p.angle :angle, 360, min: 10, max: 3600
      p.choice :direction, :ccw, %i[ccw cw]
      p.length :tread_thickness, 50
      p.bool :column, true
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:outer_radius] > prm[:inner_radius] + Geom3.tol, :err_radius_order)
      g = StairTools.spiral(ctx.entities, prm, ctx.name(:spiral))
      ctx.made(g)
      ctx.placing = g
      ArchiTools.t(:ok_spiral, riser: Sketchup.format_length(prm[:rise] / prm[:risers]))
    end

    Registry.define(:landing_stairs, :stairs) do |p|
      p.choice :turn, :l_left, %i[l_left l_right u_left u_right]
      p.choice :type, :slab, %i[slab solid treads]
      p.length :width, 1100
      p.length :rise, 3000
      p.int :risers, 18, min: 4, max: 200
      p.int :first_flight, 9, min: 2, max: 198
      p.length :going, 280
      p.length :gap, 100, show: { turn: %i[u_left u_right] }
      p.length :waist, 150, show: { type: %i[slab treads] }
      p.length :tread_thickness, 40, show: { type: :treads }
      p.length :nosing, 20, show: { type: :treads }
      p.bool :stringers, true, show: { type: :treads }
      p.length :stringer_width, 50, show: { type: :treads, stringers: true }
      p.length :stringer_depth, 250, show: { type: :treads, stringers: true }
      p.bool :railing, true
      Railing.params(p, { railing: true })
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:width] > Geom3.tol && prm[:rise] > Geom3.tol && prm[:going] > Geom3.tol, :err_distance)
      g = StairTools.landing(ctx.entities, prm, ctx.name(:landing_stairs))
      ctx.made(g)
      ctx.placing = g
      r = prm[:rise] / prm[:risers]
      ArchiTools.t(:ok_landing, riser: Sketchup.format_length(r), a: prm[:first_flight],
                                b: prm[:risers] - prm[:first_flight])
    end

    Registry.define(:escalator, :stairs) do |p|
      p.length :width, 1000
      p.length :rise, 4500
      p.choice :angle, :a30, %i[a30 a35]
      p.length :landing, 1200
      p.length :balustrade, 1000
      p.length :truss_depth, 1100
    end.run do |ctx|
      prm = ctx.p.merge(angle: ctx.p[:angle] == :a35 ? 35.0 : 30.0)
      ctx.need(prm[:width] > Geom3.tol && prm[:rise] > Geom3.tol, :err_distance)
      g = StairTools.escalator(ctx.entities, prm, ctx.name(:escalator))
      ctx.made(g)
      ctx.placing = g
      ArchiTools.t(:ok_escalator, run: Sketchup.format_length(StairTools.escalator_run(prm) + 2 * prm[:landing]))
    end

    Registry.define(:winder_stairs, :stairs) do |p|
      p.choice :turn, :left, %i[left right]
      p.choice :type, :solid, %i[solid treads]
      p.length :width, 1000
      p.length :rise, 2800
      p.int :risers, 16, min: 4, max: 200
      p.int :first_flight, 6, min: 1, max: 198
      p.int :winders, 3, min: 2, max: 6
      p.length :going, 270
      p.length :tread_thickness, 40, show: { type: :treads }
    end.run do |ctx|
      prm = ctx.p
      ctx.need(prm[:width] > Geom3.tol && prm[:rise] > Geom3.tol && prm[:going] > Geom3.tol, :err_distance)
      g = StairTools.winder(ctx.entities, prm, ctx.name(:winder_stairs))
      ctx.made(g)
      ctx.placing = g
      ArchiTools.t(:ok_winder, riser: Sketchup.format_length(prm[:rise] / prm[:risers]), k: prm[:winders])
    end

    Registry.define(:railing, :stairs) do |p|
      Railing.params(p)
      p.length :lift, 0
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges).reject { |c| c[:points].size < 2 }
      ctx.need(!chains.empty?, :need_edges)
      chains.each do |chain|
        pts = chain[:points]
        pts += [pts.first] if chain[:closed]
        pts = Railing.lift(pts, ctx.p[:lift]) if ctx.p[:lift].abs > Geom3.tol
        ctx.made(Railing.build(ctx.entities, pts, ctx.p, ctx.name(:railing)))
      end
      ArchiTools.t(:ok_railing, n: chains.size)
    end
  end
end
