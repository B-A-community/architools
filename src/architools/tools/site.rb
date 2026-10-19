# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Рельеф: площадка со срезкой и подсыпкой, граница на рельефе,
    # горизонтали. Рельеф — выделенные группы или компоненты (как у
    # песочницы SketchUp); контур площадки или граница — отдельная грань
    # или замкнутая цепочка рёбер вне этих групп.
    module SiteTools
      G = Geom3

      module_function

      # Контур в плане из выделенной грани или замкнутой цепочки рёбер.
      def outline(ctx)
        face = ctx.faces.first
        if face
          pts = face.outer_loop.vertices.map(&:position)
          return [pts, face]
        end
        chain = G.chains(ctx.edges).find { |c| c[:closed] }
        raise UserError, ArchiTools.t(:need_site_outline) unless chain

        [chain[:points], nil]
      end
    end

    Registry.define(:cut_fill, :site) do |p|
      p.choice :level_from, :face, %i[face value]
      p.length :level, 0, show: { level_from: :value }
      p.angle :batter, 33.7, min: 5, max: 85
      p.length :step, 500
      p.bool :hide_source, true
    end.run do |ctx|
      ctx.need(!ctx.objects.empty?, :need_terrain)
      pts, = SiteTools.outline(ctx)
      prm = ctx.p
      ctx.need(prm[:step] > 10.mm.to_f, :err_distance)
      mesh = Terrain.from(ctx.objects)
      level = prm[:level_from] == :face ? pts.map { |q| q.z.to_f }.sum / pts.size : prm[:level]
      poly = pts.map { |q| [q.x.to_f, q.y.to_f] }
      x0, x1, y0, y1 = mesh.bounds
      s = prm[:step]
      nx = ((x1 - x0) / s).ceil
      ny = ((y1 - y0) / s).ceil
      raise UserError, ArchiTools.t(:err_too_many) if nx * ny > 400_000

      tan = Math.tan(Geom3.deg(prm[:batter]))
      old = {}
      new = {}
      (0..nx).each do |i|
        (0..ny).each do |j|
          x = [x0 + i * s, x1].min
          y = [y0 + j * s, y1].min
          z = mesh.height_at(x, y)
          next unless z

          d = Terrain.signed_distance(poly, x, y)
          zn =
            if d <= 0 then level
            elsif z > level then [z, level + d * tan].min
            else [z, level - d * tan].max
            end
          old[[i, j]] = z
          new[[i, j]] = Geom::Point3d.new(x, y, zn)
        end
      end
      polys = []
      cut = 0.0
      fill = 0.0
      (0...nx).each do |i|
        (0...ny).each do |j|
          ids = [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
          next unless ids.all? { |k| new[k] }

          [[0, 1, 2], [0, 2, 3]].each do |tri|
            q = tri.map { |t| ids[t] }
            polys << q.map { |k| new[k] }
            a, b, c = q.map { |k| new[k] }
            area = ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)).abs / 2.0
            dz = q.sum { |k| old[k] - new[k].z } / 3.0
            dz.positive? ? cut += area * dz : fill -= area * dz
          end
        end
      end
      ctx.need(!polys.empty?, :need_terrain)
      g = Geom3.mesh_group(ctx.entities, polys, ctx.name(:graded))
      ModifyTools.merge_coplanar(g.entities)
      ModifyTools.soften_smooth(g.entities, 25)
      ctx.objects.each { |o| o.hidden = true } if prm[:hide_source]
      ctx.made(g)
      m3 = 0.0254**3
      ArchiTools.t(:ok_cut_fill, cut: format('%.1f', cut * m3), fill: format('%.1f', fill * m3),
                                 level: Sketchup.format_length(level))
    end

    Registry.define(:trace_boundary, :site).run do |ctx|
      ctx.need(!ctx.objects.empty?, :need_terrain)
      pts, = SiteTools.outline(ctx)
      mesh = Terrain.from(ctx.objects)
      ring = pts + [pts.first]
      lines = []
      line = []
      ring.each_cons(2) do |a, b|
        ts = [0.0]
        mesh.edges_near(a.x.to_f, a.y.to_f, b.x.to_f, b.y.to_f).each do |e0, e1|
          t = Terrain.cross_param(a, b, e0, e1)
          ts << t if t
        end
        ts.sort.uniq { |t| t.round(9) }.each do |t|
          x = a.x + (b.x - a.x) * t
          y = a.y + (b.y - a.y) * t
          z = mesh.height_at(x, y)
          if z
            line << Geom::Point3d.new(x, y, z)
          else
            lines << line if line.size > 1
            line = []
          end
        end
      end
      last = ring.last
      z = mesh.height_at(last.x, last.y)
      line << Geom::Point3d.new(last.x, last.y, z) if z
      lines << line if line.size > 1
      ctx.need(!lines.empty?, :err_outside_terrain)
      g = ctx.entities.add_group
      g.name = ctx.name(:boundary)
      lines.each { |l| g.entities.add_curve(l.each_with_object([]) { |q, acc| acc << q if acc.empty? || acc.last.distance(q).to_f > Geom3::MIN_SIZE }) }
      ctx.made(g)
      ArchiTools.t(:ok_boundary, n: lines.sum(&:size))
    end

    Registry.define(:contour_lines, :site) do |p|
      p.length :start, 0
      p.length :interval, 500
    end.run do |ctx|
      src = ctx.objects + ctx.faces
      src = ctx.entities.to_a.select { |e| e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) } if src.empty?
      mesh = Terrain.from(src.select { |e| !e.is_a?(Sketchup::Face) }, src.grep(Sketchup::Face))
      iv = ctx.p[:interval]
      ctx.need(iv > Geom3::MIN_SIZE, :err_distance)
      zs = mesh.tris.flatten.map { |q| q.z.to_f }
      first = ctx.p[:start] + ((zs.min - ctx.p[:start]) / iv).ceil * iv
      levels = []
      z = first
      while z <= zs.max + 1.0e-9
        levels << z
        z += iv
        raise UserError, ArchiTools.t(:err_too_many) if levels.size > 2000
      end
      g = ctx.entities.add_group
      g.name = ctx.name(:contours)
      count = 0
      levels.each do |level|
        # Чуть выше отметки: плоский участок ровно на уровне горизонтали
        # (площадка) не должен дробиться на линии.
        lv = level + 1.0e-6
        segs = []
        mesh.tris.each do |tri|
          zz = tri.map { |q| q.z.to_f }
          next if zz.min > lv || zz.max < lv || (zz.max - zz.min) < 1.0e-12

          hits = []
          tri.each_with_index do |a, i|
            b = tri[(i + 1) % 3]
            za = a.z.to_f
            zb = b.z.to_f
            next if (za - zb).abs < 1.0e-12
            next unless lv >= [za, zb].min && lv < [za, zb].max

            t = (lv - za) / (zb - za)
            hits << Geom.linear_combination(1.0 - t, a, t, b)
          end
          segs << hits.first(2) if hits.size >= 2
        end
        Terrain.chain(segs).each do |c|
          g.entities.add_curve(c)
          count += 1
        end
      end
      if count.zero?
        g.erase!
        raise UserError, ArchiTools.t(:err_no_contours)
      end
      ctx.made(g)
      ArchiTools.t(:ok_contours, n: count, levels: levels.size)
    end
  end
end
