# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Прямой скелет многоугольника — основа вальмовой кровли по контуру
    # любой формы, в том числе невыпуклому и с дырами (внутренние дворы).
    # Все скаты одного уклона: точка ската на высоте t·tg(уклон), где t —
    # время, за которое до неё дошёл фронт от карниза.
    #
    # Алгоритм «фронта волны»: вершины контуров движутся внутрь по
    # биссектрисам так, что рёбра сдвигаются на 1 за единицу времени.
    # События:
    #   * ребро стягивается в точку — две вершины сливаются (edge event);
    #   * входящий (вогнутый) угол упирается в чужое ребро — контур
    #     разрезается на два, а если ребро из другого контура (дыры) —
    #     два контура сливаются в один (split event).
    # Каждый раз берём самое раннее событие по всем контурам. Контур,
    # выродившийся в отрезок, — это конёк: замыкаем его как есть.
    module Skeleton
      EPS = 1.0e-9

      module_function

      # loops — контуры [[x, y], ...]: внешний против часовой, дыры по
      # часовой (внутренность всегда слева). Возвращает по многоугольнику
      # [[x, y, t], ...] на каждое ребро — в порядке рёбер всех контуров.
      def faces(loops)
        loops = [loops] if loops.first.first.is_a?(Numeric)
        edges = []
        lavs = loops.map do |pts|
          first = edges.size
          n = pts.size
          pts.each_with_index do |a, i|
            b = pts[(i + 1) % n]
            dx = b[0] - a[0]
            dy = b[1] - a[1]
            len = Math.hypot(dx, dy)
            edges << { a: a, b: b, dir: [dx / len, dy / len], n: [-dy / len, dx / len] }
          end
          (0...n).map do |i|
            v = { pos: pts[i].dup, prev: first + (i - 1) % n, nxt: first + i, node: [pts[i][0], pts[i][1], 0.0] }
            v[:vel] = velocity(edges[v[:prev]][:n], edges[v[:nxt]][:n])
            v
          end
        end
        segments = Hash.new { |h, k| h[k] = [] }
        scale = loops.flatten.map(&:abs).max.to_f
        time = 0.0
        guard = 0

        loop do
          guard += 1
          raise UserError, ArchiTools.t(:err_skeleton) if guard > 20 * edges.size + 100

          # Выродившиеся контуры — коньки: замыкаем и убираем.
          lavs.reject! do |lav|
            next false unless lav.size <= 2 || area(lav).abs < 1.0e-10 * scale * scale

            finish(lav, time, segments)
            true
          end
          break if lavs.empty?

          event = next_event(lavs, edges, time)
          break unless event

          dt = event[:dt]
          lavs.each { |lav| lav.each { |v| v[:pos] = [v[:pos][0] + v[:vel][0] * dt, v[:pos][1] + v[:vel][1] * dt] } }
          time += dt
          if event[:type] == :edge
            edge_event(lavs, event, time, edges, segments)
          else
            split_event(lavs, event, time, edges, segments)
          end
        end

        (0...edges.size).map { |i| trace(edges[i], segments[i]) }
      end

      def next_event(lavs, edges, time)
        best = nil
        lavs.each_with_index do |lav, li|
          lav.each_with_index do |v, i|
            w = lav[(i + 1) % lav.size]
            dt = collapse_time(v, w)
            best = { type: :edge, dt: dt, lav: li, i: i } if dt && (best.nil? || dt < best[:dt] - EPS)
          end
        end
        lavs.each_with_index do |lav, li|
          lav.each_with_index do |v, i|
            next unless reflex?(v, edges)

            lavs.each_with_index do |other, lj|
              other.each_with_index do |a, ia|
                e = a[:nxt]
                next if e == v[:prev] || e == v[:nxt]

                b = other[(ia + 1) % other.size]
                dt = split_time(v, edges[e], time)
                # При одновременных событиях сначала разрез: иначе слияние
                # двух встречных параллельных рёбер даёт вершину без направления.
                next unless dt && (best.nil? || dt < best[:dt] - EPS ||
                                   (best[:type] == :edge && dt < best[:dt] + 1.0e-7 * (1.0 + best[:dt])))
                next unless on_wavefront_edge?(v, a, b, edges[e], dt)

                best = { type: :split, dt: dt, lav: li, i: i, other: lj, ia: ia }
              end
            end
          end
        end
        best
      end

      def reflex?(v, edges)
        d1 = edges[v[:prev]][:dir]
        d2 = edges[v[:nxt]][:dir]
        d1[0] * d2[1] - d1[1] * d2[0] < -EPS
      end

      # Когда вершина v встанет на сдвинувшуюся прямую ребра e.
      def split_time(v, e, time)
        n = e[:n]
        # Прямая ребра идёт внутрь со скоростью 1, вершина — со скоростью
        # vel; сближаются со скоростью 1 − vel·n.
        closing = 1.0 - (v[:vel][0] * n[0] + v[:vel][1] * n[1])
        return nil if closing <= EPS

        gap = (v[:pos][0] - e[:a][0]) * n[0] + (v[:pos][1] - e[:a][1]) * n[1] - time
        dt = gap / closing
        # Ноль допустим: одновременные удары (симметричный двор) идут подряд.
        dt > -1.0e-9 * (1.0 + gap.abs) ? [dt, 0.0].max : nil
      end

      # Точка удара лежит в пределах текущего отрезка ребра (между a и b).
      def on_wavefront_edge?(v, a, b, e, dt)
        hx = v[:pos][0] + v[:vel][0] * dt
        hy = v[:pos][1] + v[:vel][1] * dt
        ax = a[:pos][0] + a[:vel][0] * dt
        ay = a[:pos][1] + a[:vel][1] * dt
        bx = b[:pos][0] + b[:vel][0] * dt
        by = b[:pos][1] + b[:vel][1] * dt
        d = e[:dir]
        sa = ax * d[0] + ay * d[1]
        sb = bx * d[0] + by * d[1]
        sh = hx * d[0] + hy * d[1]
        tol = 1.0e-7 * [1.0, (sb - sa).abs].max
        sh > sa - tol && sh < sb + tol && sb > sa
      end

      def edge_event(lavs, ev, time, edges, segments)
        lav = lavs[ev[:lav]]
        a = lav[ev[:i]]
        j = (ev[:i] + 1) % lav.size
        b = lav[j]
        node = [(a[:pos][0] + b[:pos][0]) / 2.0, (a[:pos][1] + b[:pos][1]) / 2.0, time]
        [a, b].each { |v| [v[:prev], v[:nxt]].each { |edge| segments[edge] << [v[:node], node] } }
        merged = make_vertex(node, a[:prev], b[:nxt], edges)
        lav[ev[:i]] = merged
        lav.delete_at(j)
      end

      def split_event(lavs, ev, time, edges, segments)
        lav = lavs[ev[:lav]]
        v = lav[ev[:i]]
        node = [v[:pos][0], v[:pos][1], time]
        [v[:prev], v[:nxt]].each { |edge| segments[edge] << [v[:node], node] }
        other = lavs[ev[:other]]
        a = other[ev[:ia]]
        e = a[:nxt]
        v1 = make_vertex(node, v[:prev], e, edges)
        v2 = make_vertex(node, e, v[:nxt], edges)
        ring = lav.rotate(ev[:i]) # [V, Vnext, …, Vprev]
        if ev[:other] == ev[:lav]
          ia = ring.index(a)
          lav2 = [v2] + ring[1..ia]
          lav1 = [v1] + ring[(ia + 1)..]
          lavs[ev[:lav]] = lav1
          lavs << lav2
        else
          ring_a = other.rotate((ev[:ia] + 1) % other.size) # [B, …, A]
          merged = [v1] + ring_a + [v2] + ring[1..]
          lavs[ev[:lav]] = merged
          lavs.delete_at(ev[:other])
        end
      end

      def make_vertex(node, prev, nxt, edges)
        { pos: node[0, 2], prev: prev, nxt: nxt, node: node, vel: velocity(edges[prev][:n], edges[nxt][:n]) }
      end

      # Контур выродился — что осталось, то конёк.
      def finish(lav, time, segments)
        return if lav.empty?

        finals = lav.map do |v|
          fin = [v[:pos][0], v[:pos][1], time]
          [v[:prev], v[:nxt]].each { |edge| segments[edge] << [v[:node], fin] }
          fin
        end
        return if lav.size < 2

        lav.each_with_index { |v, i| segments[v[:nxt]] << [finals[i], finals[(i + 1) % lav.size]] }
      end

      def area(lav)
        pts = lav.map { |v| v[:pos] }
        pts.each_with_index.sum { |(x, y), i| u, w = pts[(i + 1) % pts.size]; x * w - u * y } / 2.0
      end

      def velocity(n1, n2)
        # v·n1 = 1, v·n2 = 1
        det = n1[0] * n2[1] - n1[1] * n2[0]
        if det.abs < EPS
          # Сонаправленные — вершина посреди прямой; встречные — рёбра уже
          # сошлись, вершина стоит на коньке.
          return n1[0] * n2[0] + n1[1] * n2[1] > 0 ? [n1[0], n1[1]] : [0.0, 0.0]
        end

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
        # Вершины должны именно сойтись, а не разминуться.
        miss = (dx - rx * dt)**2 + (dy - ry * dt)**2
        return nil if miss > 1.0e-8 * (dx * dx + dy * dy + 1.0e-12)

        dt >= -EPS ? [dt, 0.0].max : nil
      end

      def key(pt)
        [pt[0].round(5), pt[1].round(5)]
      end

      # Контур ската ребра: от конца ребра по отрезкам скелета к его началу.
      def trace(edge, segs)
        start = [edge[:a][0], edge[:a][1], 0.0]
        finish = [edge[:b][0], edge[:b][1], 0.0]
        adj = Hash.new { |h, k| h[k] = [] }
        nodes = {}
        segs.each do |p, q|
          next if key(p) == key(q)

          nodes[key(p)] = p
          nodes[key(q)] = q
          adj[key(p)] |= [key(q)]
          adj[key(q)] |= [key(p)]
        end
        poly = [start, finish]
        seen = { key(finish) => true }
        cur = key(finish)
        loop do
          nxt = adj[cur].find { |k| !seen[k] }
          break if nxt.nil? || nxt == key(start)

          poly << nodes[nxt]
          seen[nxt] = true
          cur = nxt
          break if poly.size > segs.size + 3
        end
        poly
      end
    end
  end
end
