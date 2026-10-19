# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Библиотека сечений: прямоугольник, круг, двутавр, швеллер, уголок,
    # тавр, труба квадратная (RHS) и круглая (CHS). Сечение — список контуров
    # в координатах (a, b): a — вбок, b — вверх, центр в (0, 0). Первый контур
    # внешний, остальные — дыры.
    module Profiles
      G = Geom3
      KINDS = %i[rect round i_beam channel angle tee rhs chs].freeze
      # Каким сечениям нужны толщины стенки / полки.
      WALLED = %i[i_beam channel angle tee rhs chs].freeze

      module_function

      def circle(r, seg, cx = 0.0, cy = 0.0)
        (0...seg).map { |i| a = 2 * Math::PI * i / seg; [cx + r * Math.cos(a), cy + r * Math.sin(a)] }
      end

      # w — ширина (диаметр), d — высота, tw — стенка, tf — полка.
      def loops(kind, w, d, tw, tf, seg = 24)
        hw = w / 2.0
        hd = d / 2.0
        tw = [[tw, hw].min, G::MIN_SIZE].max
        tf = [[tf, hd].min, G::MIN_SIZE].max
        case kind
        when :round then [circle(hw, seg)]
        when :chs
          raise UserError, ArchiTools.t(:err_wall_thick) if tw >= hw

          [circle(hw, seg), circle(hw - tw, seg).reverse]
        when :rhs
          raise UserError, ArchiTools.t(:err_wall_thick) if tw >= hw || tw >= hd

          [[[-hw, -hd], [hw, -hd], [hw, hd], [-hw, hd]],
           [[-hw + tw, -hd + tw], [-hw + tw, hd - tw], [hw - tw, hd - tw], [hw - tw, -hd + tw]]]
        when :i_beam
          t = tw / 2.0
          [[[-hw, -hd], [hw, -hd], [hw, -hd + tf], [t, -hd + tf], [t, hd - tf], [hw, hd - tf],
            [hw, hd], [-hw, hd], [-hw, hd - tf], [-t, hd - tf], [-t, -hd + tf], [-hw, -hd + tf]]]
        when :channel
          [[[-hw, -hd], [hw, -hd], [hw, -hd + tf], [-hw + tw, -hd + tf], [-hw + tw, hd - tf],
            [hw, hd - tf], [hw, hd], [-hw, hd]]]
        when :angle
          [[[-hw, -hd], [hw, -hd], [hw, -hd + tf], [-hw + tw, -hd + tf], [-hw + tw, hd], [-hw, hd]]]
        when :tee
          t = tw / 2.0
          [[[-t, -hd], [t, -hd], [t, hd - tf], [hw, hd - tf], [hw, hd], [-hw, hd], [-hw, hd - tf],
            [-t, hd - tf]]]
        else # :rect
          [[[-hw, -hd], [hw, -hd], [hw, hd], [-hw, hd]]]
        end
      end

      # Сдвиг сечения по b: top — верх на линии пути, bottom — низ, center — центр.
      def aligned(loops, d, align)
        shift = { top: -d / 2.0, bottom: d / 2.0 }[align] || 0.0
        loops.map { |l| l.map { |a, b| [a, b + shift] } }
      end

      # Треугольники торца с дырами. Считает сам SketchUp: временная грань
      # во временной группе, её сетка, группа удаляется.
      def cap_triangles(entities, loops)
        tmp = entities.add_group
        to3 = ->(l) { l.map { |a, b| Geom::Point3d.new(a, b, 0) } }
        face = tmp.entities.add_face(to3.call(loops.first))
        loops.drop(1).each { |l| tmp.entities.add_face(to3.call(l))&.erase! }
        face = tmp.entities.grep(Sketchup::Face).max_by(&:area) unless face&.valid?
        mesh = face.mesh(0)
        tris = mesh.polygons.map { |poly| poly.map { |i| p = mesh.point_at(i.abs); [p.x, p.y] } }
        tmp.erase!
        tris.map { |t| signed_area(t).negative? ? t.reverse : t }
      end

      def signed_area(pts)
        pts.each_with_index.sum { |(a, b), i| c, d = pts[(i + 1) % pts.size]; a * d - c * b } / 2.0
      end

      # Прямой брус сечением loops от p0 до p1; b сечения смотрит по up
      # (например, по нормали грани), a — вбок.
      def bar(entities, p0, p1, up, loops, name = nil)
        t = (p1 - p0).normalize
        up = up - G.scale(t, up.dot(t))
        # Брус вдоль «вверх» (вертикальная труба): берём любую поперечную ось.
        up = (t.parallel?(G::X) ? Geom::Vector3d.new(0, 1, 0) : G::X) - G.scale(t, (t.parallel?(G::X) ? Geom::Vector3d.new(0, 1, 0) : G::X).dot(t)) if up.length.to_f < 1.0e-6
        up = up.normalize
        side = t.cross(up).normalize
        loops = loops.each_with_index.map do |l, i|
          ccw = signed_area(l).positive?
          (i.zero? ? ccw : !ccw) ? l : l.reverse
        end
        ring = ->(o, l) { l.map { |a, b| o.offset(side, a).offset(up, b) } }
        polys = []
        loops.each do |l|
          r0 = ring.call(p0, l)
          r1 = ring.call(p1, l)
          r0.each_index { |i| j = (i + 1) % r0.size; polys << [r0[i], r0[j], r1[j], r1[i]] }
        end
        cap_triangles(entities, loops).each do |tri|
          polys << ring.call(p0, tri).reverse
          polys << ring.call(p1, tri)
        end
        g = G.mesh_group(entities, polys, name)
        ModifyTools.merge_coplanar(g.entities)
        ModifyTools.orient_outward(g.entities)
        g
      end

      # Тело: сечение, проведённое по пути (точки), без закручивания.
      def sweep_group(entities, points, closed, loops, name, smooth: true, vertical: false)
        loops = loops.each_with_index.map do |l, i|
          ccw = signed_area(l).positive?
          (i.zero? ? ccw : !ccw) ? l : l.reverse
        end
        caps = closed ? [] : cap_triangles(entities, loops)
        polys = ModifyTools.sweep(points, closed, loops, caps, vertical: vertical)
        g = G.mesh_group(entities, polys, name)
        ModifyTools.merge_coplanar(g.entities)
        ModifyTools.orient_outward(g.entities)
        ModifyTools.soften_smooth(g.entities, 30) if smooth
        g
      end
    end
  end
end
