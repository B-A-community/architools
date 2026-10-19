# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Отказ с понятной причиной: панель показывает текст, операция откатывается.
    class UserError < StandardError; end

    # Общая геометрия: цепочки рёбер, локальные оси грани, сечение полигона
    # прямой, коробки. Всё в дюймах (внутренние единицы SketchUp).
    module Geom3
      Z = Geom::Vector3d.new(0, 0, 1).freeze
      X = Geom::Vector3d.new(1, 0, 0).freeze

      module_function

      def tol
        TOLERANCE
      end

      # --- цепочки рёбер ---------------------------------------------------

      # Разбирает набор рёбер на упорядоченные цепочки точек.
      # Возвращает [{ points:, vertices:, edges:, closed: }].
      # В узлах, где сходятся три ребра и больше, цепочка рвётся.
      def chains(edges)
        edges = edges.uniq
        set = {}
        edges.each { |e| set[e] = true }
        by_vertex = Hash.new { |h, k| h[k] = [] }
        edges.each { |e| e.vertices.each { |v| by_vertex[v] << e } }

        used = {}
        result = []
        walk = lambda do |start_vertex, first_edge|
          pts = [start_vertex.position]
          verts = [start_vertex]
          chain_edges = []
          v = start_vertex
          e = first_edge
          loop do
            used[e] = true
            chain_edges << e
            v = e.other_vertex(v)
            pts << v.position
            verts << v
            nexts = by_vertex[v].reject { |x| used[x] }
            break if by_vertex[v].size != 2 || nexts.empty?

            e = nexts.first
          end
          closed = pts.size > 2 && pts.first.distance(pts.last).to_f < tol
          if closed
            pts.pop
            verts.pop
          end
          { points: pts, vertices: verts, edges: chain_edges, closed: closed }
        end

        # Сначала открытые цепочки — от концов (степень 1) и от узлов (≥3).
        by_vertex.each do |v, list|
          next if list.size == 2

          list.each { |e| result << walk.call(v, e) unless used[e] }
        end
        # Оставшиеся — замкнутые контуры.
        edges.each do |e|
          next if used[e]

          result << walk.call(e.start, e)
        end
        result
      end

      # Открытая цепочка в однозначном направлении: от конца с меньшим X,
      # при равенстве — с меньшим Y, затем Z. Порядок, в котором SketchUp
      # хранит рёбра, тогда не влияет на «слева / справа».
      def canonical(points)
        key = ->(p) { [p.x.to_f.round(6), p.y.to_f.round(6), p.z.to_f.round(6)] }
        (key.call(points.last) <=> key.call(points.first)).negative? ? points.reverse : points
      end

      def polyline_length(points, closed = false)
        pts = closed ? points + [points.first] : points
        pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
      end

      # Нормаль плоскости точек (метод Ньюэлла). nil, если точки на прямой.
      def newell_normal(points)
        x = y = z = 0.0
        points.each_with_index do |p, i|
          q = points[(i + 1) % points.size]
          x += (p.y - q.y) * (p.z + q.z)
          y += (p.z - q.z) * (p.x + q.x)
          z += (p.x - q.x) * (p.y + q.y)
        end
        n = Geom::Vector3d.new(x, y, z)
        n.length.to_f < 1.0e-9 ? nil : n.normalize
      end

      # Плоскость открытой цепочки: по всем тройкам точек; для прямой — Z.
      def chain_normal(points)
        n = points.size >= 3 ? newell_normal(points) : nil
        if n.nil?
          dir = points.last - points.first
          return dir.parallel?(Z) ? X.clone : Z.clone
        end
        n.z < -tol ? n.reverse : n
      end

      # --- смещение полилинии в плоскости -----------------------------------

      # Смещает полилинию на distance влево по ходу (относительно normal).
      # Углы — по пересечению смещённых прямых (стык «в ус»).
      def offset_polyline(points, distance, normal, closed)
        n = points.size
        return points.map(&:clone) if distance.abs < tol

        seg_count = closed ? n : n - 1
        lines = (0...seg_count).map do |i|
          a = points[i]
          b = points[(i + 1) % n]
          dir = (b - a).normalize
          side = normal.cross(dir).normalize
          shift = Geom::Vector3d.new(side.x * distance, side.y * distance, side.z * distance)
          [a.offset(shift), dir]
        end
        (0...n).map do |i|
          if !closed && i.zero?
            lines[0][0]
          elsif !closed && i == n - 1
            l = lines[seg_count - 1]
            l[0].offset(l[1], points[i - 1].distance(points[i]).to_f)
          else
            prev = lines[(i - 1) % seg_count]
            cur = lines[i % seg_count]
            hit = prev[1].parallel?(cur[1]) ? nil : Geom.intersect_line_line(prev, cur)
            hit || cur[0]
          end
        end
      end

      # --- локальные оси грани ----------------------------------------------

      # origin, u (горизонталь в плоскости), v (вверх / вверх по скату), n.
      def face_frame(face)
        n = face.normal
        u = n.parallel?(Z) ? X.clone : Z.cross(n).normalize
        v = n.cross(u).normalize
        [face.outer_loop.vertices.first.position, u, v, n]
      end

      def to_uv(point, origin, u, v)
        d = point - origin
        [d.dot(u), d.dot(v)]
      end

      def from_uv(a, b, origin, u, v, w = 0.0, n = nil)
        p = origin.offset(u, a).offset(v, b)
        n && w.abs > 0 ? p.offset(n, w) : p
      end

      # Все контуры грани в координатах (u, v).
      def face_loops_uv(face, frame)
        o, u, v, = frame
        face.loops.map { |loop| loop.vertices.map { |vx| to_uv(vx.position, o, u, v) } }
      end

      def bounds_uv(loops)
        all = loops.flatten(1)
        us = all.map(&:first)
        vs = all.map(&:last)
        [us.min, us.max, vs.min, vs.max]
      end

      # Пересечение горизонтали v = c с полигоном (все контуры): отрезки по u.
      def scan_intervals(loops, c)
        xs = []
        loops.each do |pts|
          pts.each_with_index do |p, i|
            q = pts[(i + 1) % pts.size]
            v1 = p[1]
            v2 = q[1]
            next if (v1 - v2).abs < 1.0e-12
            next unless (c >= [v1, v2].min) && (c < [v1, v2].max)

            t = (c - v1) / (v2 - v1)
            xs << p[0] + t * (q[0] - p[0])
          end
        end
        xs.sort!
        xs.each_slice(2).select { |pair| pair.size == 2 && pair[1] - pair[0] > tol }
      end

      # Тот же разрез по вертикали u = c: отрезки по v.
      def scan_intervals_v(loops, c)
        swapped = loops.map { |pts| pts.map { |a, b| [b, a] } }
        scan_intervals(swapped, c)
      end

      # Позиции по шагу внутри [from, to] с отступом первого элемента.
      def stations(from, to, spacing, first_offset = nil)
        raise UserError, ArchiTools.t(:err_spacing) if spacing <= tol

        first_offset ||= 0.0
        out = []
        x = from + first_offset
        while x <= to + tol
          out << x
          raise UserError, ArchiTools.t(:err_too_many) if out.size > MAX_ITEMS

          x += spacing
        end
        out
      end

      # --- тела ---------------------------------------------------------------

      # Меньше этого SketchUp склеивает точки (его допуск 0,001").
      MIN_SIZE = 0.002

      # Параллелепипед: угол origin, рёбра-векторы a, b, c. Отдельная группа.
      # Вырожденный (ребро короче допуска SketchUp) не строится — nil.
      def box(entities, origin, a, b, c, name = nil)
        return nil if [a, b, c].any? { |vec| vec.length.to_f < MIN_SIZE }

        g = entities.add_group
        g.name = name if name
        p = [origin, origin + a, origin + a + b, origin + b]
        q = p.map { |x| x + c }
        ents = g.entities
        quads = [
          [p[0], p[3], p[2], p[1]], [q[0], q[1], q[2], q[3]],
          [p[0], p[1], q[1], q[0]], [p[1], p[2], q[2], q[1]],
          [p[2], p[3], q[3], q[2]], [p[3], p[0], q[0], q[3]]
        ]
        center = origin + Geom::Vector3d.linear_combination(0.5, a, 0.5, b) + scale(c, 0.5)
        quads.each { |quad| orient_out(ents.add_face(quad), center) }
        g
      end

      # Призма: основание points (замкнутое, плоское) + вектор выдавливания.
      def prism(entities, points, vector, name = nil)
        g = entities.add_group
        g.name = name if name
        face = g.entities.add_face(points)
        raise UserError, ArchiTools.t(:err_face_failed) unless face

        dist = vector.length.to_f
        face.reverse! if face.normal.dot(vector) < 0
        face.pushpull(dist)
        ModifyTools.orient_outward(g.entities)
        g
      end

      def orient_out(face, center)
        return unless face

        c = face.bounds.center
        face.reverse! if face.normal.dot(c - center) < 0
      end

      def scale(vec, k)
        Geom::Vector3d.new(vec.x * k, vec.y * k, vec.z * k)
      end

      # Сетка из полигонов (каждый — массив точек) в группу с мягкими рёбрами
      # между треугольниками одной грани.
      def mesh_group(entities, polygons, name = nil, smooth: false)
        g = entities.add_group
        g.name = name if name
        mesh = Geom::PolygonMesh.new
        polygons.each do |poly|
          # Совпавшие соседние точки (ось вращения, вырожденный угол) убираем.
          poly = poly.each_with_object([]) { |pt, acc| acc << pt if acc.empty? || acc.last.distance(pt).to_f > MIN_SIZE }
          poly.pop while poly.size > 1 && poly.last.distance(poly.first).to_f <= MIN_SIZE
          next if poly.size < 3

          if planar?(poly) && convex?(poly)
            mesh.add_polygon(poly)
          else
            # Неплоский многоугольник SketchUp молча выбрасывает — дыра в теле,
            # а веер из одной вершины у вогнутого вылезает наружу. Режем
            # честно: отсечение ушей в плоскости многоугольника.
            triangulate(poly).each { |tri| mesh.add_polygon(tri) }
          end
        end
        flags = smooth ? 12 : 0 # SOFTEN + SMOOTH
        g.entities.fill_from_mesh(mesh, true, flags)
        g
      end

      def convex?(points)
        return true if points.size <= 3

        n = newell_normal(points)
        return false unless n

        points.each_index.all? do |i|
          a = points[i - 1]
          b = points[i]
          c = points[(i + 1) % points.size]
          (b - a).cross(c - b).dot(n) >= -1.0e-9
        end
      end

      # Триангуляция простого многоугольника (возможно, слегка неплоского)
      # отсечением ушей в проекции на его плоскость Ньюэлла.
      def triangulate(points)
        n = newell_normal(points)
        return [] unless n

        u = (n.parallel?(Z) ? X : Z.cross(n)).normalize
        v = n.cross(u).normalize
        p2 = points.map { |pt| [Geom::Vector3d.new(pt.x, pt.y, pt.z).dot(u), Geom::Vector3d.new(pt.x, pt.y, pt.z).dot(v)] }
        idx = (0...points.size).to_a
        tris = []
        cross = ->(a, b, c) { (p2[b][0] - p2[a][0]) * (p2[c][1] - p2[a][1]) - (p2[b][1] - p2[a][1]) * (p2[c][0] - p2[a][0]) }
        inside = lambda do |q, a, b, c|
          d1 = (p2[b][0] - p2[a][0]) * (p2[q][1] - p2[a][1]) - (p2[b][1] - p2[a][1]) * (p2[q][0] - p2[a][0])
          d2 = (p2[c][0] - p2[b][0]) * (p2[q][1] - p2[b][1]) - (p2[c][1] - p2[b][1]) * (p2[q][0] - p2[b][0])
          d3 = (p2[a][0] - p2[c][0]) * (p2[q][1] - p2[c][1]) - (p2[a][1] - p2[c][1]) * (p2[q][0] - p2[c][0])
          d1 >= -1.0e-12 && d2 >= -1.0e-12 && d3 >= -1.0e-12
        end
        guard = 0
        while idx.size > 3 && guard < points.size * points.size
          guard += 1
          ear = idx.each_index.find do |k|
            a = idx[k - 1]
            b = idx[k]
            c = idx[(k + 1) % idx.size]
            next false unless cross.call(a, b, c) > 1.0e-12

            idx.none? { |q| ![a, b, c].include?(q) && inside.call(q, a, b, c) }
          end
          ear ||= idx.each_index.max_by { |k| cross.call(idx[k - 1], idx[k], idx[(k + 1) % idx.size]) }
          tris << [points[idx[ear - 1]], points[idx[ear]], points[idx[(ear + 1) % idx.size]]]
          idx.delete_at(ear)
        end
        tris << idx.map { |i| points[i] } if idx.size == 3
        tris
      end

      def planar?(points)
        return true if points.size <= 3

        n = newell_normal(points)
        return false unless n

        o = points.first
        points.all? { |pt| (pt - o).dot(n).abs < 1.0e-6 }
      end

      # Сдвиг вершин по векторам. Вершины кривых (дуги, окружности, Curve)
      # transform_by_vectors двигает неверно — кривые распускаем и после
      # сдвига свариваем обратно.
      def move_vertices(entities, vertices, vectors)
        curves = vertices.flat_map(&:edges).map(&:curve).compact.uniq
        groups = curves.map(&:edges)
        curves.each { |c| c.edges.first.explode_curve }
        entities.transform_by_vectors(vertices, vectors)
        if entities.respond_to?(:weld)
          groups.each do |edges|
            alive = edges.select(&:valid?)
            entities.weld(alive) if alive.size > 1
          end
        end
      end

      def deg(angle)
        angle * Math::PI / 180.0
      end

      def rotate_vec(vec, axis, angle)
        Geom::Transformation.rotation(ORIGIN, axis, angle) * vec
      end
    end
  end
end
