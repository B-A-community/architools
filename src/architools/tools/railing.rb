# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Ограждение по линии: стойки, поручень, заполнение (балясины, ригели,
    # стекло). Линия — по низу ограждения: по полу, по носкам ступеней.
    module Railing
      G = Geom3
      INFILL = %i[balusters rails glass none].freeze

      module_function

      # Параметры ограждения в каждом инструменте, где оно есть. show — при
      # каком условии поля видны (для лестниц — только при включённом ограждении).
      def params(p, show = nil)
        cond = ->(extra = {}) { (show || {}).merge(extra) }
        p.length :rail_height, 900, show: show
        p.length :post_spacing, 1200, show: show
        p.length :post_size, 50, show: show
        p.length :handrail, 50, show: show
        p.choice :infill, :balusters, INFILL, show: show
        p.length :baluster_spacing, 120, show: cond.call(infill: :balusters)
        p.int :rails_count, 3, min: 1, max: 20, show: cond.call(infill: :rails)
      end

      # Точки стоек: вершины линии и равные доли каждого участка не длиннее шага.
      def post_points(points, spacing)
        out = [points.first]
        points.each_cons(2) do |a, b|
          len = a.distance(b).to_f
          k = [(len / spacing).ceil, 1].max
          (1..k).each { |i| out << Geom.linear_combination(1.0 - i.to_f / k, a, i.to_f / k, b) }
        end
        out.uniq { |pt| pt.to_a.map { |x| x.to_f.round(3) } }
      end

      def lift(points, h)
        points.map { |pt| pt.offset(G::Z, h) }
      end

      def build(entities, points, prm, name)
        h = prm[:rail_height]
        d = prm[:handrail]
        ps = prm[:post_size]
        raise UserError, ArchiTools.t(:err_distance) unless h > d && ps > G.tol && prm[:post_spacing] > G.tol

        group = entities.add_group
        group.name = name
        e = group.entities
        posts = post_points(points, prm[:post_spacing])
        raise UserError, ArchiTools.t(:err_too_many) if posts.size > MAX_ITEMS

        posts.each do |pt|
          G.box(e, pt.offset(Geom::Vector3d.new(-ps / 2.0, -ps / 2.0, 0)), Geom::Vector3d.new(ps, 0, 0),
                Geom::Vector3d.new(0, ps, 0), Geom::Vector3d.new(0, 0, h - d / 2.0))
        end
        rail = Profiles.loops(:round, d, d, 0, 0, 16)
        Profiles.sweep_group(e, lift(points, h - d / 2.0), false, rail, ArchiTools.t(:name_handrail))

        bottom = 100.mm.to_f
        top = h - d
        case prm[:infill]
        when :balusters
          bs = [ps * 0.4, 12.mm.to_f].max
          bars = post_points(points, prm[:baluster_spacing])
          raise UserError, ArchiTools.t(:err_too_many) if bars.size > MAX_ITEMS

          bars.each do |pt|
            next if posts.any? { |q| q.distance(pt).to_f < ps }

            G.box(e, pt.offset(Geom::Vector3d.new(-bs / 2.0, -bs / 2.0, bottom)), Geom::Vector3d.new(bs, 0, 0),
                  Geom::Vector3d.new(0, bs, 0), Geom::Vector3d.new(0, 0, top - bottom))
          end
          Profiles.sweep_group(e, lift(points, bottom), false, Profiles.loops(:rect, ps, ps * 0.6, 0, 0), nil)
        when :rails
          k = prm[:rails_count]
          small = Profiles.loops(:round, d * 0.5, d * 0.5, 0, 0, 12)
          k.times do |i|
            z = bottom + (top - bottom) * i / [k, 1].max
            Profiles.sweep_group(e, lift(points, z), false, small, nil)
          end
        when :glass
          glass = e.add_group
          glass.name = ArchiTools.t(:name_glass)
          posts.each_cons(2) do |a, b|
            next if a.distance(b).to_f < ps * 2

            dir = (b - a).normalize
            a2 = a.offset(dir, ps / 2.0 + 10.mm.to_f)
            b2 = b.offset(dir, -(ps / 2.0 + 10.mm.to_f))
            glass.entities.add_face(a2.offset(G::Z, bottom), b2.offset(G::Z, bottom), b2.offset(G::Z, top), a2.offset(G::Z, top))
          end
          glass.material = WallTools.material(Sketchup.active_model, :glass)
        end
        group
      end
    end
  end
end
