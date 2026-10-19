# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Рельеф как набор треугольников: высота в точке плана, пересечения с
    # горизонтальной плоскостью. Треугольники берутся из выделенных групп и
    # компонентов (как у песочницы SketchUp) и из выделенных граней.
    module Terrain
      G = Geom3

      # Набор треугольников с сеткой-индексом для быстрого поиска по плану.
      class Mesh
        attr_reader :tris, :bounds

        def initialize(tris)
          raise UserError, ArchiTools.t(:need_terrain) if tris.empty?

          @tris = tris
          xs = tris.flatten.map { |p| p.x.to_f }
          ys = tris.flatten.map { |p| p.y.to_f }
          @bounds = [xs.min, xs.max, ys.min, ys.max]
          area = (xs.max - xs.min) * (ys.max - ys.min)
          @cell = [Math.sqrt(area / [tris.size, 1].max) * 2, 1.0e-3].max
          @grid = Hash.new { |h, k| h[k] = [] }
          tris.each_with_index do |t, i|
            x0, x1 = t.map { |p| p.x.to_f }.minmax
            y0, y1 = t.map { |p| p.y.to_f }.minmax
            (cell(x0)..cell(x1)).each { |cx| (cell(y0)..cell(y1)).each { |cy| @grid[[cx, cy]] << i } }
          end
        end

        def cell(v) = (v / @cell).floor

        # Высота рельефа в точке плана; nil — точка вне рельефа.
        def height_at(x, y)
          @grid[[cell(x), cell(y)]].each do |i|
            a, b, c = @tris[i]
            d = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
            next if d.abs < 1.0e-12

            l1 = ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (y - c.y)) / d
            l2 = ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (y - c.y)) / d
            l3 = 1.0 - l1 - l2
            next unless l1 > -1.0e-9 && l2 > -1.0e-9 && l3 > -1.0e-9

            return l1 * a.z + l2 * b.z + l3 * c.z
          end
          nil
        end

        # Рёбра треугольников, которые может пересечь отрезок плана.
        def edges_near(x0, y0, x1, y1)
          ids = []
          (cell([x0, x1].min)..cell([x0, x1].max)).each do |cx|
            (cell([y0, y1].min)..cell([y0, y1].max)).each { |cy| ids.concat(@grid[[cx, cy]]) }
          end
          ids.uniq.flat_map { |i| t = @tris[i]; [[t[0], t[1]], [t[1], t[2]], [t[2], t[0]]] }
        end
      end

      module_function

      # Треугольники всех граней внутри сущностей (с вложенными группами).
      def collect(entities, transform, out)
        entities.each do |e|
          case e
          when Sketchup::Face
            mesh = e.mesh(0)
            mesh.polygons.each { |poly| out << poly.map { |i| mesh.point_at(i.abs).transform(transform) } }
          when Sketchup::Group, Sketchup::ComponentInstance
            collect(e.definition.entities, transform * e.transformation, out)
          end
        end
        out
      end

      # Рельеф из выделения: группы и компоненты целиком плюс грани,
      # кроме исключённых (контур площадки, граница).
      def from(objects, faces = [])
        tris = []
        collect(objects, Geom::Transformation.new, tris)
        collect(faces, Geom::Transformation.new, tris)
        Mesh.new(tris)
      end

      # Расстояние от точки до многоугольника в плане: минус — внутри.
      def signed_distance(poly, x, y)
        best = Float::INFINITY
        inside = false
        poly.each_with_index do |(x1, y1), i|
          x2, y2 = poly[(i + 1) % poly.size]
          dx = x2 - x1
          dy = y2 - y1
          len2 = dx * dx + dy * dy
          t = len2.zero? ? 0.0 : [[((x - x1) * dx + (y - y1) * dy) / len2, 0.0].max, 1.0].min
          best = [best, Math.hypot(x - (x1 + t * dx), y - (y1 + t * dy))].min
          inside = !inside if (y1 > y) != (y2 > y) && x < x1 + (y - y1) * dx / dy
        end
        inside ? -best : best
      end

      # Пересечение двух отрезков плана: доля вдоль первого или nil.
      def cross_param(p, q, a, b)
        rx = q.x - p.x
        ry = q.y - p.y
        sx = b.x - a.x
        sy = b.y - a.y
        den = rx * sy - ry * sx
        return nil if den.abs < 1.0e-12

        t = ((a.x - p.x) * sy - (a.y - p.y) * sx) / den
        u = ((a.x - p.x) * ry - (a.y - p.y) * rx) / den
        t > 1.0e-9 && t < 1 - 1.0e-9 && u > -1.0e-9 && u < 1 + 1.0e-9 ? t : nil
      end

      # Сшивает отрезки в цепочки по совпадающим концам.
      def chain(segments)
        key = ->(p) { [p.x.to_f.round(4), p.y.to_f.round(4), p.z.to_f.round(4)] }
        adj = Hash.new { |h, k| h[k] = [] }
        pts = {}
        segments.each_with_index do |(a, b), i|
          next if key.call(a) == key.call(b)

          [a, b].each { |p| pts[key.call(p)] = p }
          adj[key.call(a)] << i
          adj[key.call(b)] << i
        end
        used = {}
        chains = []
        walk = lambda do |start|
          line = [pts[start]]
          cur = start
          loop do
            i = adj[cur].find { |j| !used[j] }
            break unless i

            used[i] = true
            a, b = segments[i]
            nxt = key.call(a) == cur ? key.call(b) : key.call(a)
            line << pts[nxt]
            cur = nxt
          end
          line
        end
        adj.each { |k, list| chains << walk.call(k) if list.size == 1 && list.any? { |j| !used[j] } }
        adj.each_key { |k| chains << walk.call(k) if adj[k].any? { |j| !used[j] } }
        chains.select { |c| c.size >= 2 }
      end
    end
  end
end
