# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # FFD — свободная деформация решёткой (как SketchyFFD в JHS Powerbar,
    # написано с нуля). Вокруг группы ставится решётка nx × ny × nz
    # управляющих точек — обычных точек-направляющих в своей группе. Их
    # двигают штатным «Перемещением»; наблюдатель пересчитывает форму:
    #   P(s,t,u) = Σ B_i(s) B_j(t) B_k(u) · Q_ijk,
    # где B — многочлены Бернштейна, (s,t,u) — доли исходного габарита.
    # Рёбра с пометкой «зафиксировано» не деформируются.
    module FFD
      DICT = 'BACommunity_ArchiTools_ffd'
      @state = {} # lattice entityID → { target:, lattice:, n:, base:, verts:, orig:, params: }

      class << self
        attr_reader :state

        def bernstein(n, i, x)
          binom(n, i) * x**i * (1 - x)**(n - i)
        end

        def binom(n, k)
          (1..k).reduce(1) { |acc, i| acc * (n - k + i) / i }
        end

        def vertices_of(target)
          target.definition.entities.grep(Sketchup::Edge).flat_map(&:vertices).uniq
        end

        # Решётка вокруг group: точки в мировых координатах по осям группы.
        def create(parent, target, nx, ny, nz)
          target.make_unique if target.respond_to?(:make_unique)
          b = target.definition.bounds
          lo = b.min
          size = [b.width.to_f, b.height.to_f, b.depth.to_f].map { |v| [v, 1.0e-3].max }
          tr = target.transformation
          lattice = parent.add_group
          lattice.name = ArchiTools.t(:name_ffd_lattice)
          ctrl = {}
          nx.times do |i|
            ny.times do |j|
              nz.times do |k|
                local = Geom::Point3d.new(lo.x + size[0] * i / (nx - 1), lo.y + size[1] * j / (ny - 1), lo.z + size[2] * k / (nz - 1))
                c = lattice.entities.add_cpoint(local.transform(tr))
                c.set_attribute(DICT, 'ijk', [i, j, k])
                ctrl[[i, j, k]] = c
              end
            end
          end
          lattice.set_attribute(DICT, 'size', [nx, ny, nz])
          # Кривые распускаем сразу: вершины кривых transform_by_vectors
          # двигает неверно, а сварка заново пересоздала бы вершины.
          target.definition.entities.grep(Sketchup::Edge).map(&:curve).compact.uniq.each { |c| c.edges.first.explode_curve }
          verts = vertices_of(target)
          orig = verts.map(&:position)
          params = orig.map { |p| [(p.x - lo.x) / size[0], (p.y - lo.y) / size[1], (p.z - lo.z) / size[2]] }
          @state[lattice.entityID] = { target: target, lattice: lattice, n: [nx, ny, nz], verts: verts, orig: orig,
                                       params: params, ctrl: ctrl }
          lattice.entities.add_observer(LatticeWatch.new(lattice.entityID))
          lattice
        end

        def find_state(entity)
          @state.values.find { |s| s[:lattice] == entity || s[:target] == entity }
        end

        def locked?(vertex)
          vertex.edges.any? { |e| e.get_attribute(DICT, 'locked') }
        end

        # Пересчёт формы по текущим управляющим точкам.
        def update(lattice)
          st = @state[lattice.entityID]
          return 0 unless st && st[:target].valid? && lattice.valid?

          inv = st[:target].transformation.inverse
          nx, ny, nz = st[:n]
          q = {}
          st[:ctrl].each { |ijk, c| q[ijk] = c.valid? ? c.position.transform(inv) : nil }
          return 0 if q.values.any?(&:nil?)

          moves = []
          verts = []
          st[:verts].each_with_index do |v, idx|
            next unless v.valid?
            next if locked?(v)

            s, t, u = st[:params][idx]
            x = y = z = 0.0
            nx.times do |i|
              bi = bernstein(nx - 1, i, s)
              next if bi.zero?

              ny.times do |j|
                bj = bi * bernstein(ny - 1, j, t)
                next if bj.zero?

                nz.times do |k|
                  w = bj * bernstein(nz - 1, k, u)
                  next if w.zero?

                  pt = q[[i, j, k]]
                  x += w * pt.x
                  y += w * pt.y
                  z += w * pt.z
                end
              end
            end
            target = Geom::Point3d.new(x, y, z)
            vec = target - v.position
            next if vec.length.to_f < 1.0e-9

            verts << v
            moves << vec
          end
          st[:target].definition.entities.transform_by_vectors(verts, moves) unless verts.empty?
          verts.size
        end

        # Закончить: форма остаётся, решётка удаляется.
        def finish(lattice)
          @state.delete(lattice.entityID)
          lattice.erase! if lattice.valid?
        end
      end

      # Наблюдатель решётки: сдвинули точку — пересчитать (через таймер,
      # чтобы не менять модель внутри обработчика события).
      class LatticeWatch < Sketchup::EntitiesObserver
        def initialize(id)
          super()
          @id = id
        end

        def onElementModified(_entities, _entity)
          return if @pending

          @pending = true
          UI.start_timer(0, false) do
            @pending = false
            st = FFD.state[@id]
            next unless st && st[:lattice].valid?

            model = Sketchup.active_model
            model.start_operation(ArchiTools.t(:tool_ffd), true, false, true)
            FFD.update(st[:lattice])
            model.commit_operation
          end
        end
      end
    end

    Registry.define(:ffd, :modeling) do |p|
      p.choice :mode, :create, %i[create lock unlock finish]
      p.choice :lattice, :g3, %i[g3 g4 custom], show: { mode: :create }
      p.int :nx, 3, min: 2, max: 8, show: { mode: :create, lattice: :custom }
      p.int :ny, 3, min: 2, max: 8, show: { mode: :create, lattice: :custom }
      p.int :nz, 3, min: 2, max: 8, show: { mode: :create, lattice: :custom }
    end.run do |ctx|
      case ctx.p[:mode]
      when :lock, :unlock
        edges = ctx.edges
        ctx.need(!edges.empty?, :need_ffd_edges)
        edges.each { |e| ctx.p[:mode] == :lock ? e.set_attribute(FFD::DICT, 'locked', true) : e.delete_attribute(FFD::DICT, 'locked') }
        next ArchiTools.t(ctx.p[:mode] == :lock ? :ok_ffd_lock : :ok_ffd_unlock, n: edges.size)
      when :finish
        lattices = ctx.objects.map { |o| FFD.find_state(o) }.compact.map { |s| s[:lattice] }.uniq
        ctx.need(!lattices.empty?, :need_ffd_lattice)
        lattices.each { |l| FFD.finish(l) }
        next ArchiTools.t(:ok_ffd_finish, n: lattices.size)
      end
      groups = ctx.objects
      ctx.need(groups.size == 1, :need_one_object)
      n = { g3: [3, 3, 3], g4: [4, 4, 4] }[ctx.p[:lattice]] || [ctx.p[:nx], ctx.p[:ny], ctx.p[:nz]]
      lattice = FFD.create(ctx.entities, groups.first, *n)
      ctx.made(lattice)
      ArchiTools.t(:ok_ffd, n: n.inject(:*))
    end
  end
end
