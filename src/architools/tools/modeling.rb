# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Моделирование — функции JHS Powerbar, написанные заново: сглаживание
    # рёбер, сварка и роспуск кривых, равные сегменты, поиск граней,
    # выдавливание линий, трубы по линиям, опускание на поверхность, точки
    # и компоненты в точки, зеркало, 3D-поворот, случайный масштаб и
    # поворот, сдвиг, Rotix, прокси, замена компонентов, сетка на грани,
    # Split Up. Деформация решёткой (FFD) — в ffd.rb.
    module ModelTools
      G = Geom3
      PROXY_DICT = 'BACommunity_ArchiTools_proxy'

      module_function

      # Рёбра выделения; nested — ещё и рёбра внутри выделенных групп и
      # компонентов (определения меняются у всех экземпляров).
      def edges_of(ctx, nested)
        list = ctx.edges + ctx.faces.flat_map(&:edges)
        if nested
          walk = lambda do |ents|
            ents.each do |e|
              list << e if e.is_a?(Sketchup::Edge)
              walk.call(e.definition.entities) if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            end
          end
          walk.call(ctx.objects)
        end
        list.uniq
      end

      def face_angle(edge)
        fs = edge.faces
        return nil unless fs.size == 2

        a = fs[0].normal.angle_between(fs[1].normal)
        # Нормали могут смотреть врозь (развёрнутая грань) — берём острый.
        [a, Math::PI - a].min
      end

      # Диагональ треугольной пары, образующей четырёхугольник.
      def diagonal?(edge)
        fs = edge.faces
        return false unless fs.size == 2 && fs.all? { |f| f.vertices.size == 3 }

        quad = (fs[0].vertices + fs[1].vertices).uniq
        return false unless quad.size == 4

        len = edge.length.to_f
        fs.all? { |f| f.edges.all? { |e| e == edge || e.length.to_f <= len + G.tol } }
      end

      def chain_points(chain)
        pts = chain[:points]
        chain[:closed] ? pts + [pts.first] : pts
      end

      # Точки на полилинии через равные отрезки длины.
      def resample(pts, n)
        total = G.polyline_length(pts)
        dists = (0..n).map { |i| total * i / n }
        SurfaceTools.along(pts, dists).map(&:first)
      end

      # Отражение относительно плоскости [точка, нормаль].
      def reflection(point, normal)
        n = normal.normalize
        d = Geom::Vector3d.new(point.x, point.y, point.z).dot(n)
        a = [[1 - 2 * n.x * n.x, -2 * n.x * n.y, -2 * n.x * n.z],
             [-2 * n.y * n.x, 1 - 2 * n.y * n.y, -2 * n.y * n.z],
             [-2 * n.z * n.x, -2 * n.z * n.y, 1 - 2 * n.z * n.z]]
        t = [2 * d * n.x, 2 * d * n.y, 2 * d * n.z]
        Geom::Transformation.new([a[0][0], a[1][0], a[2][0], 0,
                                  a[0][1], a[1][1], a[2][1], 0,
                                  a[0][2], a[1][2], a[2][2], 0,
                                  t[0], t[1], t[2], 1])
      end

      # Применить преобразование к выделению: объекты по одному, россыпь
      # геометрии — целиком; copy — к копии, оригинал остаётся.
      def transform_selection(ctx, tr, copy)
        objects = ctx.objects
        loose = ctx.selection.select { |e| e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face) }
        made = []
        objects.each do |o|
          if copy
            made << ModifyTools.copy_object(ctx.entities, o, tr)
          else
            o.transform!(tr)
            made << o
          end
        end
        unless loose.empty?
          if copy
            src = ctx.entities.add_group(loose)
            dup = src.copy
            dup.transform!(tr)
            src.explode
            made.concat(dup.explode.select { |e| e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face) })
          else
            ctx.entities.transform_entities(tr, loose)
            made.concat(loose)
          end
        end
        made
      end

      def bottom_center(obj)
        b = obj.bounds
        Geom::Point3d.new(b.center.x, b.center.y, b.min.z)
      end

      # Квадратная сетка точек грани в её осях, повёрнутая на angle.
      def grid_lines(face, angle_deg, us_of, vs_of)
        o, u, v, n = G.face_frame(face)
        a = G.deg(angle_deg)
        ru = G.rotate_vec(u, n, a)
        rv = G.rotate_vec(v, n, a)
        loops = face.loops.map { |l| l.vertices.map { |vx| G.to_uv(vx.position, o, ru, rv) } }
        umin, umax, vmin, vmax = G.bounds_uv(loops)
        [o, ru, rv, loops, us_of.call(umin, umax), vs_of.call(vmin, vmax)]
      end

      # Proxy: каркас габарита определения.
      def proxy_definition(model, defn)
        name = "Proxy · #{defn.name}"
        found = model.definitions[name]
        return found if found

        pd = model.definitions.add(name)
        b = defn.bounds
        c = (0..7).map { |i| b.corner(i) }
        [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4], [0, 4], [1, 5], [2, 6], [3, 7]].each do |i, j|
          pd.entities.add_line(c[i], c[j])
        end
        pd.set_attribute(PROXY_DICT, 'source', defn.name)
        pd
      end

      def proxy_source(model, defn)
        name = defn.get_attribute(PROXY_DICT, 'source')
        name && model.definitions[name]
      end
    end

    # --- рёбра и грани ---------------------------------------------------------

    Registry.define(:soften_edges, :modeling) do |p|
      p.choice :mode, :angle, %i[angle all none quadrants]
      p.angle :angle, 20, min: 0, max: 180, show: { mode: :angle }
      p.bool :soft, true, show: { mode: :angle }
      p.bool :smooth, true, show: { mode: :angle }
      p.bool :nested, true
    end.run do |ctx|
      edges = ModelTools.edges_of(ctx, ctx.p[:nested])
      ctx.need(!edges.empty?, :need_edges_or_objects)
      limit = Geom3.deg(ctx.p[:angle])
      changed = 0
      edges.each do |e|
        next unless e.valid?

        soft, smooth =
          case ctx.p[:mode]
          when :all then [e.faces.size == 2, e.faces.size == 2]
          when :none then [false, false]
          when :quadrants
            d = ModelTools.diagonal?(e)
            [d, d]
          else
            a = ModelTools.face_angle(e)
            on = a && a <= limit + 1.0e-9
            [on && ctx.p[:soft], on && ctx.p[:smooth]]
          end
        changed += 1 if e.soft? != soft || e.smooth? != smooth
        e.soft = soft
        e.smooth = smooth
      end
      ArchiTools.t(:ok_soften, n: changed, total: edges.size)
    end

    Registry.define(:weld_edges, :modeling).run do |ctx|
      chains = Geom3.chains(ctx.edges).select { |c| c[:edges].size > 1 }
      ctx.need(!chains.empty?, :need_chain)
      ctx.need(ctx.entities.respond_to?(:weld), :err_no_weld)
      chains.each do |c|
        res = Array(ctx.entities.weld(c[:edges]))
        ctx.made(res.flat_map { |x| x.is_a?(Sketchup::Curve) ? x.edges : x }.select { |x| x.is_a?(Sketchup::Entity) })
      end
      ArchiTools.t(:ok_weld, n: chains.size)
    end

    Registry.define(:explode_curves, :modeling) do |p|
      p.bool :nested, false
    end.run do |ctx|
      curves = ModelTools.edges_of(ctx, ctx.p[:nested]).map(&:curve).compact.uniq
      ctx.need(!curves.empty?, :need_curves)
      curves.each { |c| c.edges.first.explode_curve }
      ArchiTools.t(:ok_explode, n: curves.size)
    end

    Registry.define(:equalize_curve, :modeling) do |p|
      p.choice :by, :count, %i[count length]
      p.int :count, 12, min: 1, max: 5000, show: { by: :count }
      p.length :seg_length, 200, show: { by: :length }
    end.run do |ctx|
      chains = Geom3.chains(ctx.edges)
      ctx.need(!chains.empty?, :need_edges)
      chains.each do |chain|
        pts = ModelTools.chain_points(chain)
        len = Geom3.polyline_length(pts)
        n = ctx.p[:by] == :count ? ctx.p[:count] : [(len / ctx.p[:seg_length]).round, 1].max
        raise UserError, ArchiTools.t(:err_too_many) if n > MAX_ITEMS

        fresh = ModelTools.resample(pts, n)
        fresh[-1] = fresh[0] if chain[:closed]
        ctx.entities.erase_entities(chain[:edges].select(&:valid?))
        ctx.made(ctx.entities.add_curve(fresh))
      end
      ArchiTools.t(:ok_equalize, n: chains.size)
    end

    Registry.define(:face_finder, :modeling) do |p|
      p.bool :nested, true
    end.run do |ctx|
      edges = ModelTools.edges_of(ctx, ctx.p[:nested])
      ctx.need(!edges.empty?, :need_edges_or_objects)
      found = edges.sum { |e| e.valid? ? e.find_faces.to_i : 0 }
      ArchiTools.t(:ok_face_finder, n: found)
    end

    Registry.define(:extrude_lines, :modify) do |p|
      p.length :dx, 0
      p.length :dy, 0
      p.length :dz, 1000
      p.bool :group, false
    end.run do |ctx|
      edges = ctx.edges
      ctx.need(!edges.empty?, :need_edges)
      v = Geom::Vector3d.new(ctx.p[:dx], ctx.p[:dy], ctx.p[:dz])
      ctx.need(v.length.to_f > Geom3::MIN_SIZE, :err_distance)
      target = ctx.p[:group] ? ctx.entities.add_group.tap { |g| g.name = ctx.name(:extruded) } : nil
      ents = target ? target.entities : ctx.entities
      count = 0
      edges.each do |e|
        a = e.start.position
        b = e.end.position
        next if (b - a).parallel?(v)

        ctx.made(ents.add_face(a, b, b.offset(v), a.offset(v)))
        count += 1
      end
      ctx.need(count.positive?, :err_parallel_vector)
      ctx.made(target) if target
      ArchiTools.t(:ok_extrude_lines, n: count)
    end

    Registry.define(:lines_to_tubes, :modify) do |p|
      p.length :diameter, 50
      p.int :segments, 12, min: 3, max: 96
      p.bool :joints, true
      p.bool :erase_lines, false
    end.run do |ctx|
      edges = ctx.edges
      ctx.need(!edges.empty?, :need_edges)
      d = ctx.p[:diameter]
      ctx.need(d > Geom3::MIN_SIZE, :err_distance)
      g = ctx.entities.add_group
      g.name = ctx.name(:tubes)
      ring = Profiles.loops(:round, d, d, 0, 0, ctx.p[:segments])
      edges.each do |e|
        tube = Profiles.bar(g.entities, e.start.position, e.end.position, Geom3::Z, ring)
        ModifyTools.soften_smooth(tube.entities, 40)
      end
      if ctx.p[:joints]
        # Шары в узлах — стык труб без щелей.
        prof = (0..8).map { |i| a = Math::PI * i / 8 - Math::PI / 2; [d / 2.0 * Math.cos(a), d / 2.0 * Math.sin(a)] }
        prof[0][0] = 0.0
        prof[-1][0] = 0.0
        edges.flat_map(&:vertices).uniq.each do |v|
          next if v.edges.count { |x| edges.include?(x) } < 2

          s = FrameTools.lathe(g.entities, prof, ctx.p[:segments])
          s.transform!(Geom::Transformation.translation(v.position - ORIGIN))
        end
      end
      ctx.entities.erase_entities(edges) if ctx.p[:erase_lines]
      ctx.made(g)
      ArchiTools.t(:ok_tubes, n: edges.size)
    end

    # --- положение ---------------------------------------------------------------

    Registry.define(:drop, :modeling) do |p|
      p.choice :mode, :below, %i[below level]
      p.length :level, 0, show: { mode: :level }
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      dropped = 0
      objects.each do |o|
        base = ModelTools.bottom_center(o)
        z =
          if ctx.p[:mode] == :level
            ctx.p[:level]
          else
            # Луч вниз из-под объекта: первая поверхность под ним.
            hit = ctx.model.raytest([base.offset(Geom3::Z, -Geom3::MIN_SIZE), Geom3::Z.reverse], true)
            hit && hit.first.z.to_f
          end
        next unless z

        o.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, z - base.z.to_f)))
        dropped += 1
      end
      ctx.made(objects)
      ArchiTools.t(:ok_drop, n: dropped, total: objects.size)
    end

    Registry.define(:cpoints_at_vertices, :modeling).run do |ctx|
      pts = (ctx.edges.flat_map(&:vertices) + ctx.faces.flat_map(&:vertices)).uniq.map(&:position)
      ctx.need(!pts.empty?, :need_edges)
      pts.uniq { |q| q.to_a.map { |c| c.to_f.round(4) } }.each { |q| ctx.made(ctx.entities.add_cpoint(q)) }
      ArchiTools.t(:ok_cpoints, n: ctx.created.size)
    end

    Registry.define(:connect_cpoints, :modeling) do |p|
      p.bool :closed, false
      p.choice :output, :edge, %i[edge guide]
    end.run do |ctx|
      pts = ctx.cpoints.map(&:position)
      ctx.need(pts.size >= 2, :need_two_cpoints)
      # Порядок: от самой «левой» точки к ближайшей ещё не взятой.
      rest = pts.sort_by { |q| q.to_a.map(&:to_f) }
      line = [rest.shift]
      line << rest.delete(rest.min_by { |q| q.distance(line.last).to_f }) until rest.empty?
      line << line.first if ctx.p[:closed] && line.size > 2
      if ctx.p[:output] == :guide
        line.each_cons(2) { |a, b| ctx.made(ctx.entities.add_cline(a, b)) }
      else
        ctx.made(ctx.entities.add_curve(line))
      end
      ArchiTools.t(:ok_connect, n: line.size)
    end

    Registry.define(:comps_to_cpoints, :modeling) do |p|
      p.choice :anchor, :bottom, %i[bottom center origin]
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(objects.size == 1 && !ctx.cpoints.empty?, :need_object_and_cpoints)
      src = objects.first
      b = src.bounds
      ref = { bottom: ModelTools.bottom_center(src), center: b.center, origin: src.transformation.origin }[ctx.p[:anchor]]
      ctx.cpoints.each do |c|
        ctx.made(ModifyTools.copy_object(ctx.entities, src, Geom::Transformation.translation(c.position - ref)))
      end
      ArchiTools.t(:ok_comps_to_cpoints, n: ctx.cpoints.size)
    end

    Registry.define(:mirror, :modeling) do |p|
      p.bool :copy, false
    end.picks(count: nil, min: 2, max: 3, prompts: %i[pk_mirror1 pk_mirror2 pk_mirror3],
              check: ->(ctx) { ctx.need(!ctx.selection.empty?, :need_selection) }).run do |ctx|
      ctx.need(!(ctx.objects.empty? && ctx.edges.empty? && ctx.faces.empty?), :need_selection)
      pts = ctx.points
      ctx.need(pts.size >= 2, :need_points, n: 2)
      normal =
        if pts.size >= 3
          PointTools.plane3(*pts.first(3))[1]
        else
          # Две точки — вертикальная плоскость через них (зеркало в плане).
          d = pts[1] - pts[0]
          ctx.need(d.length.to_f > Geom3::MIN_SIZE && !d.parallel?(Geom3::Z), :err_points_same)
          Geom3::Z.cross(d).normalize
        end
      made = ModelTools.transform_selection(ctx, ModelTools.reflection(pts[0], normal), ctx.p[:copy])
      ctx.made(made)
      ArchiTools.t(:ok_mirror, n: made.size)
    end

    Registry.define(:rotate_3d, :modeling) do |p|
      p.angle :angle, 90, min: -3600, max: 3600
      p.bool :copy, false
    end.picks(count: 2, prompts: %i[pk_axis1 pk_axis2],
              check: ->(ctx) { ctx.need(!ctx.selection.empty?, :need_selection) }).run do |ctx|
      ctx.need(!(ctx.objects.empty? && ctx.edges.empty? && ctx.faces.empty?), :need_selection)
      a, b = ctx.points
      ctx.need(a && b && a.distance(b).to_f > Geom3::MIN_SIZE, :err_points_same)
      tr = Geom::Transformation.rotation(a, b - a, Geom3.deg(ctx.p[:angle]))
      made = ModelTools.transform_selection(ctx, tr, ctx.p[:copy])
      ctx.made(made)
      ArchiTools.t(:ok_rotate_3d, n: made.size)
    end

    Registry.define(:random_transform, :modeling) do |p|
      p.choice :mode, :both, %i[scale rotate both]
      p.float :scale_min, 80, min: 1, show: { mode: %i[scale both] }
      p.float :scale_max, 120, min: 1, show: { mode: %i[scale both] }
      p.angle :angle_max, 180, min: 0, max: 180, show: { mode: %i[rotate both] }
      p.int :seed, 1, min: 0, max: 1_000_000
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      lo, hi = [ctx.p[:scale_min], ctx.p[:scale_max]].minmax
      rng = Random.new(ctx.p[:seed])
      # Порядок выделения у SketchUp случайный — сортируем по положению,
      # чтобы одно «зерно» давало один и тот же результат.
      objects.sort_by { |o| o.bounds.center.to_a.map { |c| c.to_f.round(3) } }.each do |o|
        base = ModelTools.bottom_center(o)
        tr = Geom::Transformation.new
        if %i[scale both].include?(ctx.p[:mode])
          k = (lo + rng.rand * (hi - lo)) / 100.0
          tr = Geom::Transformation.scaling(base, k) * tr
        end
        if %i[rotate both].include?(ctx.p[:mode])
          a = Geom3.deg(ctx.p[:angle_max]) * (2 * rng.rand - 1)
          tr = Geom::Transformation.rotation(base, Geom3::Z, a) * tr
        end
        o.transform!(tr)
      end
      ctx.made(objects)
      ArchiTools.t(:ok_random, n: objects.size)
    end

    Registry.define(:move_by, :modeling) do |p|
      p.length :dx, 1000
      p.length :dy, 0
      p.length :dz, 0
      p.bool :copy, false
    end.run do |ctx|
      ctx.need(!(ctx.objects.empty? && ctx.edges.empty? && ctx.faces.empty?), :need_selection)
      v = Geom::Vector3d.new(ctx.p[:dx], ctx.p[:dy], ctx.p[:dz])
      ctx.need(v.length.to_f > Geom3::MIN_SIZE, :err_distance)
      made = ModelTools.transform_selection(ctx, Geom::Transformation.translation(v), ctx.p[:copy])
      ctx.made(made)
      ArchiTools.t(:ok_move_by, n: made.size, d: Sketchup.format_length(v.length))
    end

    # --- Rotix: поворот стрелками ---------------------------------------------

    # ← по часовой, → против, ↑ сменить плоскость (Z → X → Y), ↓ перевернуть
    # на 180°; Ctrl — шаг 45°, Shift — 1°, иначе шаг из параметров. Центр —
    # середина габарита выделения. Каждый поворот — отдельный шаг отмены.
    class RotixTool
      AXES = [Geom::Vector3d.new(0, 0, 1), Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 1, 0)].freeze

      attr_reader :axis_index

      def initialize(objects, step_deg)
        @objects = objects
        @step = step_deg
        @axis_index = 0
      end

      def activate
        Sketchup.status_text = ArchiTools.t(:st_rotix)
      end

      def center
        b = Geom::BoundingBox.new
        @objects.select(&:valid?).each { |o| b.add(o.bounds) }
        b.center
      end

      def rotate(deg)
        model = Sketchup.active_model
        model.start_operation(ArchiTools.t(:tool_rotix), true)
        tr = Geom::Transformation.rotation(center, AXES[@axis_index], Geom3.deg(deg))
        @objects.select(&:valid?).each { |o| o.transform!(tr) }
        model.commit_operation
      end

      def onKeyDown(key, _repeat, flags, view)
        step = if (flags & CONSTRAIN_MODIFIER_MASK).nonzero? then 1.0
               elsif (flags & COPY_MODIFIER_MASK).nonzero? then 45.0
               else @step
               end
        case key
        when VK_LEFT then rotate(-step)
        when VK_RIGHT then rotate(step)
        when VK_UP
          @axis_index = (@axis_index + 1) % 3
          Sketchup.status_text = "#{ArchiTools.t(:st_rotix)} #{%w[Z X Y][@axis_index]}"
        when VK_DOWN then rotate(180.0)
        else return false
        end
        view.invalidate
        true
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end
    end

    Registry.define(:rotix, :modeling) do |p|
      p.angle :step, 90, min: 0.01, max: 360
    end.run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      tool = RotixTool.new(objects, ctx.p[:step])
      ctx.model.select_tool(tool) if ctx.p.fetch(:place, true)
      ArchiTools.instance_variable_set(:@last_rotix, tool)
      ArchiTools.t(:ok_rotix)
    end

    # --- компоненты ----------------------------------------------------------------

    Registry.define(:proxify, :modeling) do |p|
      p.choice :mode, :toggle, %i[toggle all_instances restore_all]
    end.run do |ctx|
      model = ctx.model
      if ctx.p[:mode] == :restore_all
        restored = 0
        model.definitions.each do |d|
          src = ModelTools.proxy_source(model, d)
          next unless src

          d.instances.each { |i| i.definition = src; restored += 1 }
        end
        next ArchiTools.t(:ok_unproxy, n: restored)
      end
      inst = ctx.selection.grep(Sketchup::ComponentInstance)
      ctx.need(!inst.empty?, :need_components)
      if ctx.p[:mode] == :all_instances
        # Все экземпляры того же исходного компонента — и обычные, и прокси;
        # направление — по первому выделенному.
        sources = inst.map { |i| ModelTools.proxy_source(model, i.definition) || i.definition }.uniq
        to_proxy_dir = ModelTools.proxy_source(model, inst.first.definition).nil?
        inst = sources.flat_map do |src|
          px = model.definitions["Proxy · #{src.name}"]
          src.instances + (px ? px.instances : [])
        end
        inst = inst.select { |i| ModelTools.proxy_source(model, i.definition).nil? == to_proxy_dir }
      end
      to_proxy = 0
      back = 0
      inst.uniq.each do |i|
        src = ModelTools.proxy_source(model, i.definition)
        if src
          i.definition = src
          back += 1
        else
          i.definition = ModelTools.proxy_definition(model, i.definition)
          to_proxy += 1
        end
      end
      ctx.made(inst)
      ArchiTools.t(:ok_proxify, a: to_proxy, b: back)
    end

    Registry.define(:composwapper, :modeling) do |p|
      p.bool :all_instances, false
    end.run do |ctx|
      inst = ctx.selection.grep(Sketchup::ComponentInstance)
      by_def = inst.group_by(&:definition)
      ctx.need(by_def.size >= 2, :need_swap_pair)
      # Образец — компонент, выделенный в меньшем числе экземпляров (один
      # образец и много заменяемых); при равенстве выбора нет — отказ.
      counts = by_def.transform_values(&:size).sort_by { |_, n| n }
      ctx.need(counts[0][1] < counts[1][1], :err_swap_ambiguous)
      source = counts[0][0]
      targets = by_def.reject { |d, _| d == source }
      list = ctx.p[:all_instances] ? targets.keys.flat_map(&:instances) : targets.values.flatten
      list.each { |i| i.definition = source }
      ctx.made(list)
      ArchiTools.t(:ok_swap, n: list.size, name: source.name)
    end

    # --- сетка -------------------------------------------------------------------------

    Registry.define(:mesh_maker, :modeling) do |p|
      p.choice :by, :cell, %i[cell divisions]
      p.length :cell, 250, show: { by: :cell }
      p.int :cols, 4, min: 1, max: 500, show: { by: :divisions }
      p.int :rows, 4, min: 1, max: 500, show: { by: :divisions }
      p.angle :angle, 0, min: -90, max: 90, show: { by: :cell }
      p.choice :output, :split, %i[split guides]
    end.run do |ctx|
      faces = ctx.faces
      ctx.need(!faces.empty?, :need_faces)
      prm = ctx.p
      lines = 0
      faces.each do |f|
        ents = f.parent.entities
        steps = lambda do |lo, hi, n|
          if prm[:by] == :cell
            raise UserError, ArchiTools.t(:err_distance) if prm[:cell] <= Geom3::MIN_SIZE

            k = ((lo / prm[:cell]).floor..(hi / prm[:cell]).ceil).map { |i| i * prm[:cell] }
            k.select { |x| x > lo + Geom3.tol && x < hi - Geom3.tol }
          else
            (1...n).map { |i| lo + (hi - lo) * i / n }
          end
        end
        angle = prm[:by] == :cell ? prm[:angle] : 0.0
        o, ru, rv, loops, us, vs = ModelTools.grid_lines(f, angle, ->(a, b) { steps.call(a, b, prm[:cols]) },
                                                         ->(a, b) { steps.call(a, b, prm[:rows]) })
        raise UserError, ArchiTools.t(:err_too_many) if us.size * vs.size > MAX_ITEMS * 4

        at = ->(a, b) { Geom3.from_uv(a, b, o, ru, rv) }
        draw = lambda do |p0, p1|
          prm[:output] == :guides ? ents.add_cline(p0, p1) : ents.add_line(p0, p1)
          lines += 1
        end
        us.each { |x| Geom3.scan_intervals_v(loops, x).each { |a, b| draw.call(at[x, a], at[x, b]) } }
        # add_line не режет встречные рёбра — дробим на вертикалях.
        vs.each do |y|
          Geom3.scan_intervals(loops, y).each do |a, b|
            cuts = [a] + (prm[:output] == :split ? us.select { |x| x > a + Geom3.tol && x < b - Geom3.tol } : []) + [b]
            cuts.each_cons(2) { |x1, x2| draw.call(at[x1, y], at[x2, y]) }
          end
        end
      end
      ArchiTools.t(:ok_mesh, n: lines)
    end

    Registry.define(:split_up, :modeling) do |p|
      p.int :divisions, 10, min: 1, max: 200
    end.run do |ctx|
      faces = ctx.faces.select { |f| f.loops.size == 1 && f.outer_loop.vertices.size == 4 }
      ctx.need(!faces.empty?, :need_quad_faces)
      n = ctx.p[:divisions]
      raise UserError, ArchiTools.t(:err_too_many) if faces.size * n * n > MAX_ITEMS * 4

      # Углы всех граней — до изменений: разбиение первой грани добавит
      # вершины на общих рёбрах соседних, и их «первые 4 вершины» уже не углы.
      jobs = faces.map do |f|
        { face: f, ents: f.parent.entities, c: f.outer_loop.vertices.map(&:position), normal: f.normal,
          mat: f.material, back: f.back_material }
      end
      jobs.each do |job|
        f = job[:face]
        ents = job[:ents]
        c = job[:c]
        at = lambda do |i, j|
          s = i.to_f / n
          t = j.to_f / n
          Geom.linear_combination(1 - t, Geom.linear_combination(1 - s, c[0], s, c[1]),
                                  t, Geom.linear_combination(1 - s, c[3], s, c[2]))
        end
        f.erase! if f.valid?
        n.times do |i|
          n.times do |j|
            q = [at[i, j], at[i + 1, j], at[i + 1, j + 1], at[i, j + 1]]
            parts = Geom3.planar?(q) ? [q] : [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
            parts.each do |poly|
              nf = begin
                ents.add_face(poly)
              rescue ArgumentError
                # Почти плоская ячейка, которую SketchUp не принял, — двумя треугольниками.
                ents.add_face(poly[0], poly[1], poly[2])
                ents.add_face(poly[0], poly[2], poly[3]) if poly.size == 4
              end
              next unless nf.is_a?(Sketchup::Face)

              nf.reverse! if nf.normal.dot(job[:normal]).negative?
              nf.material = job[:mat]
              nf.back_material = job[:back]
              ctx.made(nf)
            end
          end
        end
      end
      ArchiTools.t(:ok_split_up, n: faces.size, cells: n * n)
    end
  end
end
