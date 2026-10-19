# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Фасад: ламели (жалюзи) по грани и разбивка грани на панели с рамой.
    module FacadeTools
      G = Geom3

      module_function

      def rotate(vec, axis, angle_deg)
        Geom::Transformation.rotation(ORIGIN, axis, G.deg(angle_deg)) * vec
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
      p.length :blade_depth, 150
      p.length :blade_thickness, 20
      p.length :spacing, 200
      p.angle :angle, 30, min: -90, max: 90
      p.length :offset, 100
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      depth = ctx.p[:blade_depth]
      thick = ctx.p[:blade_thickness]
      ctx.need(depth > Geom3.tol, :err_distance)
      blades = 0
      faces.each do |f|
        frame = Geom3.face_frame(f)
        o, u, v, n = frame
        loops = Geom3.face_loops_uv(f, frame)
        umin, umax, vmin, vmax = Geom3.bounds_uv(loops)
        group = ctx.entities.add_group
        group.name = ctx.name(:louvres)
        horizontal = ctx.p[:direction] == :horizontal
        axis = horizontal ? u : v
        across = horizontal ? v : u
        dvec = Geom3.scale(FacadeTools.rotate(n, axis, ctx.p[:angle]), depth)
        tvec = Geom3.scale(FacadeTools.rotate(across, axis, ctx.p[:angle]), [thick, Geom3.tol * 10].max)
        lo, hi = horizontal ? [vmin, vmax] : [umin, umax]
        Geom3.stations(lo, hi, ctx.p[:spacing], ctx.p[:spacing] / 2.0).each do |c|
          spans = horizontal ? Geom3.scan_intervals(loops, c) : Geom3.scan_intervals_v(loops, c)
          spans.each do |a, b|
            base = horizontal ? Geom3.from_uv(a, c, o, u, v) : Geom3.from_uv(c, a, o, u, v)
            center = base.offset(n, ctx.p[:offset] + depth / 2.0)
            origin = center - Geom3.scale(dvec, 0.5) - Geom3.scale(tvec, 0.5)
            if thick <= Geom3.tol
              # Нулевая толщина — одна плоская грань, как в оригинале.
              len = Geom3.scale(axis, b - a)
              group.entities.add_face(origin, origin + len, origin + len + dvec, origin + dvec)
            else
              Geom3.box(group.entities, origin, Geom3.scale(axis, b - a), dvec, tvec)
            end
            blades += 1
            raise UserError, ArchiTools.t(:err_too_many) if blades > MAX_ITEMS
          end
        end
        ctx.made(group)
      end
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
  end
end
