# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Фасад: ламели (жалюзи) по грани и разбивка грани на панели с рамой.
    module FacadeTools
      G = Geom3

      # Профили ламелей — семь, как «Louvre 0…6» в оригинале.
      BLADES = %i[flat sheet oval round rhs channel airfoil].freeze

      module_function

      # Сечение ламели: a — по ширине (от грани наружу), b — по толщине.
      def blade_section(kind, depth, thick)
        wall = [2.mm.to_f, thick / 3.0].min
        case kind
        when :oval
          [(0...16).map { |i| t = 2 * Math::PI * i / 16; [depth / 2.0 * Math.cos(t), thick / 2.0 * Math.sin(t)] }]
        when :round then Profiles.loops(:round, depth, depth, 0, 0, 16)
        when :rhs then Profiles.loops(:rhs, depth, thick, wall, wall)
        when :channel then Profiles.loops(:channel, depth, thick, wall, wall)
        when :airfoil
          # Каплевидная ламель: скруглённый нос, сужение к хвосту.
          top = (0..12).map do |i|
            x = (i / 12.0)**1.5
            y = 5 * (thick / depth) * (0.2969 * Math.sqrt(x) - 0.126 * x - 0.3516 * x**2 + 0.2843 * x**3 - 0.1036 * x**4)
            [(x - 0.5) * depth, y * depth]
          end
          top + top[1...-1].reverse.map { |x, y| [x, -y] }
        else []
        end.then { |l| l.empty? || l.first.first.is_a?(Array) ? l : [l] }
      end

      def rotate(vec, axis, angle_deg)
        Geom::Transformation.rotation(ORIGIN, axis, G.deg(angle_deg)) * vec
      end

      # Точка внутри многоугольника с дырами (чёт-нечет по всем контурам).
      def inside?(loops, x, y)
        inside = false
        loops.each do |pts|
          pts.each_with_index do |(x1, y1), i|
            x2, y2 = pts[(i + 1) % pts.size]
            next unless (y1 > y) != (y2 > y)

            inside = !inside if x < x1 + (y - y1) * (x2 - x1) / (y2 - y1)
          end
        end
        inside
      end

      # Отверстие экрана: контур в (u, v) вокруг центра, повёрнутый на angle.
      def hole(shape, cx, cy, w, h, angle, grow = 0.0)
        w += 2 * grow
        h += 2 * grow
        pts =
          if shape == :round
            (0...16).map { |i| a = 2 * Math::PI * i / 16; [w / 2.0 * Math.cos(a), h / 2.0 * Math.sin(a)] }
          else
            [[-w / 2.0, -h / 2.0], [w / 2.0, -h / 2.0], [w / 2.0, h / 2.0], [-w / 2.0, h / 2.0]]
          end
        c = Math.cos(angle)
        s = Math.sin(angle)
        pts.map { |x, y| [cx + x * c - y * s, cy + x * s + y * c] }
      end

      # Профиль листа поперёк волны на одном шаге: [[x, h], ...] от 0 до pitch.
      def deck_period(kind, pitch, height, top_ratio)
        case kind
        when :corrugated
          (0..12).map { |i| x = pitch * i / 12.0; [x, height / 2.0 * (1 - Math.cos(2 * Math::PI * x / pitch))] }
        else
          tw = pitch * top_ratio
          sw = kind == :box ? [pitch * 0.02, G::MIN_SIZE * 5].max : pitch * 0.15
          bw = pitch - tw - 2 * sw
          raise UserError, ArchiTools.t(:err_deck_ratio) if bw <= 0

          [[0, 0], [bw / 2.0, 0], [bw / 2.0 + sw, height], [bw / 2.0 + sw + tw, height],
           [bw / 2.0 + 2 * sw + tw, 0], [pitch, 0]]
        end
      end

      # Позиции по числу делений с краевыми элементами внутри грани.
      def grid(min, max, count, member)
        (0..count).map do |i|
          x = min + (max - min) * i / count
          [[x, min + member / 2.0].max, max - member / 2.0].min
        end
      end
    end

    Registry.define(:louvres, :facade) do |p|
      p.choice :direction, :horizontal, %i[horizontal vertical]
      p.choice :blade, :flat, FacadeTools::BLADES
      p.length :blade_depth, 150
      p.length :blade_thickness, 20, show: { blade: %i[flat oval rhs channel airfoil] }
      p.length :spacing, 200
      p.angle :angle, 30, min: -90, max: 90
      p.choice :position, :front, %i[front middle back]
      p.length :offset, 100, show: { position: %i[front back] }
      p.bool :erase_source, false
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      prm = ctx.p.dup
      depth = prm[:blade_depth]
      # Плоская ламель нулевой толщины — это лист, как «Louvre 0» в оригинале.
      prm[:blade] = :sheet if prm[:blade] == :flat && prm[:blade_thickness] <= Geom3::MIN_SIZE
      thick = prm[:blade] == :sheet ? 0.0 : prm[:blade_thickness]
      thick = depth if prm[:blade] == :round
      ctx.need(depth > Geom3.tol && (prm[:blade] == :sheet || thick > Geom3::MIN_SIZE), :err_distance)
      section = FacadeTools.blade_section(prm[:blade], depth, thick)
      shift = { front: prm[:offset] + depth / 2.0, middle: 0.0, back: -(prm[:offset] + depth / 2.0) }[prm[:position]]
      blades = 0
      faces.each do |f|
        frame = Geom3.face_frame(f)
        o, u, v, n = frame
        loops = Geom3.face_loops_uv(f, frame)
        umin, umax, vmin, vmax = Geom3.bounds_uv(loops)
        group = ctx.entities.add_group
        group.name = ctx.name(:louvres)
        horizontal = prm[:direction] == :horizontal
        axis = horizontal ? u : v
        across = horizontal ? v : u
        ddir = FacadeTools.rotate(n, axis, prm[:angle])
        tdir = FacadeTools.rotate(across, axis, prm[:angle])
        dvec = Geom3.scale(ddir, depth)
        tvec = Geom3.scale(tdir, [thick, Geom3.tol * 10].max)
        lo, hi = horizontal ? [vmin, vmax] : [umin, umax]
        Geom3.stations(lo, hi, prm[:spacing], prm[:spacing] / 2.0).each do |c|
          spans = horizontal ? Geom3.scan_intervals(loops, c) : Geom3.scan_intervals_v(loops, c)
          spans.each do |a, b|
            base = horizontal ? Geom3.from_uv(a, c, o, u, v) : Geom3.from_uv(c, a, o, u, v)
            center = base.offset(n, shift)
            len = Geom3.scale(axis, b - a)
            case prm[:blade]
            when :sheet
              # Нулевая толщина — одна плоская грань, как «Louvre 0» в оригинале.
              origin = center - Geom3.scale(dvec, 0.5)
              group.entities.add_face(origin, origin + len, origin + len + dvec, origin + dvec)
            when :flat
              origin = center - Geom3.scale(dvec, 0.5) - Geom3.scale(tvec, 0.5)
              Geom3.box(group.entities, origin, len, dvec, tvec)
            else
              Profiles.bar(group.entities, center, center + len, tdir, section)
            end
            blades += 1
            raise UserError, ArchiTools.t(:err_too_many) if blades > MAX_ITEMS
          end
        end
        ctx.made(group)
      end
      ctx.entities.erase_entities(faces.select(&:valid?)) if prm[:erase_source]
      ArchiTools.t(:ok_louvres, n: blades)
    end

    Registry.define(:panel_divider, :facade) do |p|
      p.int :cols, 3, min: 1, max: 200
      p.int :rows, 2, min: 1, max: 200
      p.length :frame_width, 50
      p.length :frame_depth, 100
      p.bool :split_face, true
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      fw = ctx.p[:frame_width]
      fd = ctx.p[:frame_depth]
      ctx.need(fw > Geom3.tol, :err_distance)
      faces.each do |f|
        frame = Geom3.face_frame(f)
        o, u, v, n = frame
        loops = Geom3.face_loops_uv(f, frame)
        umin, umax, vmin, vmax = Geom3.bounds_uv(loops)
        us = FacadeTools.grid(umin, umax, ctx.p[:cols], fw)
        vs = FacadeTools.grid(vmin, vmax, ctx.p[:rows], fw)
        group = ctx.entities.add_group
        group.name = ctx.name(:panels)
        out = Geom3.scale(n, fd)
        us.each do |x|
          Geom3.scan_intervals_v(loops, x).each do |a, b|
            Geom3.box(group.entities, Geom3.from_uv(x - fw / 2.0, a, o, u, v), Geom3.scale(u, fw),
                      Geom3.scale(v, b - a), out)
          end
        end
        vs.each do |y|
          Geom3.scan_intervals(loops, y).each do |a, b|
            Geom3.box(group.entities, Geom3.from_uv(a, y - fw / 2.0, o, u, v), Geom3.scale(u, b - a),
                      Geom3.scale(v, fw), out)
          end
        end
        if ctx.p[:split_face]
          ents = f.parent.entities
          us[1...-1].each do |x|
            Geom3.scan_intervals_v(loops, x).each do |a, b|
              ents.add_line(Geom3.from_uv(x, a, o, u, v), Geom3.from_uv(x, b, o, u, v))
            end
          end
          # add_line не режет встречные рёбра — горизонтали дробим на
          # вертикалях сами, иначе грань не разделится.
          vs[1...-1].each do |y|
            Geom3.scan_intervals(loops, y).each do |a, b|
              cuts = [a] + us[1...-1].select { |x| x > a + Geom3.tol && x < b - Geom3.tol } + [b]
              cuts.each_cons(2) do |x1, x2|
                ents.add_line(Geom3.from_uv(x1, y, o, u, v), Geom3.from_uv(x2, y, o, u, v))
              end
            end
          end
        end
        group.material = WallTools.material(ctx.model, :frame)
        ctx.made(group)
      end
      ArchiTools.t(:ok_panels, n: faces.size)
    end

    Registry.define(:perforated_screen, :facade) do |p|
      p.choice :hole_shape, :round, %i[round rect]
      p.length :hole_width, 100
      p.length :hole_height, 100
      p.length :spacing_x, 200
      p.length :spacing_y, 200
      p.angle :angle, 0, min: -90, max: 90
      p.length :margin, 100
      p.length :thickness, 20
      p.bool :erase_source, true
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      prm = ctx.p
      ctx.need(prm[:hole_width] > Geom3::MIN_SIZE && prm[:hole_height] > Geom3::MIN_SIZE &&
               prm[:spacing_x] > Geom3::MIN_SIZE && prm[:spacing_y] > Geom3::MIN_SIZE, :err_distance)
      total = 0
      faces.each do |f|
        frame = Geom3.face_frame(f)
        o, u, v, n = frame
        loops = Geom3.face_loops_uv(f, frame)
        umin, umax, vmin, vmax = Geom3.bounds_uv(loops)
        cx = (umin + umax) / 2.0
        cy = (vmin + vmax) / 2.0
        a = Geom3.deg(prm[:angle])
        reach = Math.hypot(umax - umin, vmax - vmin) / 2.0
        ni = (reach / prm[:spacing_x]).ceil
        nj = (reach / prm[:spacing_y]).ceil
        raise UserError, ArchiTools.t(:err_too_many) if (2 * ni + 1) * (2 * nj + 1) > MAX_ITEMS * 4

        holes = []
        (-nj..nj).each do |j|
          (-ni..ni).each do |i|
            x = i * prm[:spacing_x]
            y = j * prm[:spacing_y]
            hx = cx + x * Math.cos(a) - y * Math.sin(a)
            hy = cy + x * Math.sin(a) + y * Math.cos(a)
            test = FacadeTools.hole(prm[:hole_shape], hx, hy, prm[:hole_width], prm[:hole_height], a, prm[:margin])
            next unless test.all? { |px, py| FacadeTools.inside?(loops, px, py) }

            holes << FacadeTools.hole(prm[:hole_shape], hx, hy, prm[:hole_width], prm[:hole_height], a)
            raise UserError, ArchiTools.t(:err_too_many) if holes.size > MAX_ITEMS
          end
        end
        ctx.need(!holes.empty?, :err_no_holes)
        g = ctx.entities.add_group
        g.name = ctx.name(:screen)
        to3 = ->(l) { l.map { |x, y| Geom3.from_uv(x, y, o, u, v) } }
        plate = g.entities.add_face(to3.call(loops.first))
        loops.drop(1).each { |l| g.entities.add_face(to3.call(l))&.erase! }
        holes.each { |l| g.entities.add_face(to3.call(l))&.erase! }
        plate = g.entities.grep(Sketchup::Face).max_by(&:area)
        plate.reverse! if plate.normal.dot(n).negative?
        plate.pushpull(-prm[:thickness]) if prm[:thickness] > Geom3::MIN_SIZE
        ModifyTools.orient_outward(g.entities) if prm[:thickness] > Geom3::MIN_SIZE
        ctx.made(g)
        total += holes.size
      end
      ctx.entities.erase_entities(faces.select(&:valid?)) if prm[:erase_source]
      ArchiTools.t(:ok_screen, n: total)
    end

    Registry.define(:metal_deck, :facade) do |p|
      p.choice :deck, :trapezoid, %i[trapezoid corrugated box]
      p.choice :direction, :short, %i[short long x y]
      p.length :pitch, 200
      p.length :rib_height, 40
      p.float :top_ratio, 0.35, min: 0.05, max: 0.9, show: { deck: %i[trapezoid box] }
      p.length :thickness, 0
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      prm = ctx.p
      ctx.need(prm[:pitch] > Geom3::MIN_SIZE * 10 && prm[:rib_height] > Geom3::MIN_SIZE, :err_distance)
      period = FacadeTools.deck_period(prm[:deck], prm[:pitch], prm[:rib_height], prm[:top_ratio])
      faces.each do |f|
        n = f.normal
        axis = FrameTools.direction(f, prm[:direction])
        across = n.cross(axis).normalize
        o = f.outer_loop.vertices.first.position
        # (u, v) = (вдоль волны, поперёк волны).
        loops = f.loops.map { |l| l.vertices.map { |vx| Geom3.to_uv(vx.position, o, axis, across) } }
        _, _, amin, amax = Geom3.bounds_uv(loops)
        xs = []
        k = (amin / prm[:pitch]).floor
        while k * prm[:pitch] < amax
          period.each { |x, hgt| xs << [k * prm[:pitch] + x, hgt] }
          k += 1
          raise UserError, ArchiTools.t(:err_too_many) if xs.size > MAX_ITEMS * 2
        end
        xs = xs.uniq { |x, _| x.round(6) }
        # Обрезаем волну по краям грани с интерполяцией высоты.
        hgt_at = lambda do |x|
          i = xs.index { |q, _| q >= x } || xs.size - 1
          return xs[i][1] if i.zero?

          (x0, h0), (x1, h1) = xs[i - 1], xs[i]
          x1 - x0 < 1.0e-12 ? h1 : h0 + (h1 - h0) * (x - x0) / (x1 - x0)
        end
        pts = [[amin, hgt_at.call(amin)]] + xs.select { |x, _| x > amin + 1.0e-9 && x < amax - 1.0e-9 } +
              [[amax, hgt_at.call(amax)]]
        polys = []
        pts.each_cons(2) do |(x0, h0), (x1, h1)|
          next if x1 - x0 < Geom3::MIN_SIZE

          Geom3.scan_intervals(loops, (x0 + x1) / 2.0).each do |a, b|
            p3 = ->(uu, aa, hh) { o.offset(axis, uu).offset(across, aa).offset(n, hh) }
            polys << [p3[a, x0, h0], p3[b, x0, h0], p3[b, x1, h1], p3[a, x1, h1]]
          end
        end
        ctx.need(!polys.empty?, :err_face_failed)
        polys = ModifyTools.shell_polygons(polys, prm[:thickness]) if prm[:thickness] > Geom3::MIN_SIZE
        g = Geom3.mesh_group(ctx.entities, polys, ctx.name(:deck))
        ModifyTools.merge_coplanar(g.entities)
        ModifyTools.soften_smooth(g.entities, 25) if prm[:deck] == :corrugated
        g.material = WallTools.material(ctx.model, :frame)
        ctx.made(g)
      end
      ArchiTools.t(:ok_deck, n: faces.size)
    end
  end
end
