# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Прямой скелет выпуклого многоугольника — основа вальмовой кровли по
    # любому выпуклому контуру. Все скаты одного уклона: точка ската на
    # высоте t·tg(уклон), где t — расстояние до карниза.
    #
    # Алгоритм «фронта волны»: каждая вершина движется внутрь по биссектрисе
    # со скоростью, при которой оба её ребра сдвигаются на 1 за единицу
    # времени. Событие — ребро стягивается в точку; две его вершины
    # сливаются в новую. Для выпуклого контура других событий нет.
    module Skeleton
      EPS = 1.0e-9

      module_function

      # points — [[x, y], ...] против часовой. Возвращает по многоугольнику
      # [[x, y, t], ...] на каждое ребро контура (ребро i: от points[i] к i+1).
      def faces(points)
        n = points.size
        normals = (0...n).map do |i|
          a = points[i]
          b = points[(i + 1) % n]
          dx = b[0] - a[0]
          dy = b[1] - a[1]
          len = Math.hypot(dx, dy)
          [-dy / len, dx / len] # внутрь для обхода против часовой
        end
        # Вершина i лежит между ребром i-1 (входящим) и ребром i (исходящим).
        active = (0...n).map do |i|
          { pos: points[i].dup, prev: (i - 1) % n, nxt: i, node: [points[i][0], points[i][1], 0.0] }
        end
        active.each { |v| v[:vel] = velocity(normals[v[:prev]], normals[v[:nxt]]) }
        segments = Hash.new { |h, k| h[k] = [] }
        time = 0.0

        scale = points.flatten.map(&:abs).max.to_f
        while active.size > 1
          # Фронт выродился в отрезок (сошлись параллельные карнизы) — это
          # конёк: дальше событий нет, замыкаем как есть.
          break if active.size == 2 || area(active).abs < 1.0e-9 * scale * scale

          best = nil
          active.each_with_index do |v, i|
            w = active[(i + 1) % active.size]
            dt = collapse_time(v, w)
            best = [dt, i] if dt && (best.nil? || dt < best[0])
          end
          break unless best

          dt, i = best
          active.each { |v| v[:pos] = [v[:pos][0] + v[:vel][0] * dt, v[:pos][1] + v[:vel][1] * dt] }
          time += dt
          a = active[i]
          b = active[(i + 1) % active.size]
          node = [(a[:pos][0] + b[:pos][0]) / 2.0, (a[:pos][1] + b[:pos][1]) / 2.0, time]
          [a, b].each do |v|
            [v[:prev], v[:nxt]].each { |edge| segments[edge] << [v[:node], node] }
          end
          merged = { pos: node[0, 2], prev: a[:prev], nxt: b[:nxt], node: node }
          merged[:vel] = velocity(normals[merged[:prev]], normals[merged[:nxt]])
          j = (i + 1) % active.size
          active[i] = merged
          active.delete_at(j)
        end

        # Оставшиеся вершины: их путь до текущего положения и рёбра фронта
        # между ними (конёк) — каждому скату со своей стороны.
        unless active.size < 2
          finals = active.map do |v|
            fin = [v[:pos][0], v[:pos][1], time]
            [v[:prev], v[:nxt]].each { |edge| segments[edge] << [v[:node], fin] }
            fin
          end
          active.each_with_index do |v, i|
            segments[v[:nxt]] << [finals[i], finals[(i + 1) % active.size]]
          end
        end

        (0...n).map { |edge| trace(points, edge, segments[edge]) }
      end

      def area(active)
        pts = active.map { |v| v[:pos] }
        pts.each_with_index.sum { |(x, y), i| u, w = pts[(i + 1) % pts.size]; x * w - u * y } / 2.0
      end

      def velocity(n1, n2)
        # v·n1 = 1, v·n2 = 1
        det = n1[0] * n2[1] - n1[1] * n2[0]
        return [n1[0], n1[1]] if det.abs < EPS # параллельные рёбра

        [(n2[1] - n1[1]) / det, (n1[0] - n2[0]) / det]
      end

      def collapse_time(v, w)
        dx = w[:pos][0] - v[:pos][0]
        dy = w[:pos][1] - v[:pos][1]
        rx = v[:vel][0] - w[:vel][0]
        ry = v[:vel][1] - w[:vel][1]
        rr = rx * rx + ry * ry
        return nil if rr < EPS

        dt = (dx * rx + dy * ry) / rr
        dt >= -EPS ? [dt, 0.0].max : nil
      end

      def key(pt)
        [pt[0].round(6), pt[1].round(6)]
      end

      # Контур ската ребра: от конца ребра по отрезкам скелета к его началу.
      def trace(points, edge, segs)
        n = points.size
        start = [points[edge][0], points[edge][1], 0.0]
        finish = [points[(edge + 1) % n][0], points[(edge + 1) % n][1], 0.0]
        adj = Hash.new { |h, k| h[k] = [] }
        nodes = {}
        segs.each do |p, q|
          next if key(p) == key(q)

          nodes[key(p)] = p
          nodes[key(q)] = q
          adj[key(p)] << key(q)
          adj[key(q)] << key(p)
        end
        poly = [start, finish]
        cur = key(finish)
        prev = nil
        loop do
          nxt = (adj[cur] - [prev]).first
          break if nxt.nil? || nxt == key(start)

          poly << nodes[nxt]
          prev = cur
          cur = nxt
          break if poly.size > segs.size + 3
        end
        poly
      end
    end
  end
end
