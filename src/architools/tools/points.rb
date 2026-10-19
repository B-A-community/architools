# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Точки и грани по кликам: точка на грани по расстояниям, перпендикуляр
    # к ребру или грани, грань на плоскости по 3 точкам, грань по неплоским
    # точкам, перемещение вершины, выравнивание по 3 точкам.
    module PointTools
      G = Geom3

      module_function

      # Ортонормированные оси по трём точкам: начало в a, X к b, Y к c.
      def frame3(a, b, c)
        x = b - a
        raise UserError, ArchiTools.t(:err_points_collinear) if x.length.to_f < G::MIN_SIZE

        z = x.cross(c - a)
        raise UserError, ArchiTools.t(:err_points_collinear) if z.length.to_f < 1.0e-6 * x.length.to_f**2

        x = x.normalize
        z = z.normalize
        Geom::Transformation.axes(a, x, z.cross(x), z)
      end

      def plane3(a, b, c)
        f = frame3(a, b, c)
        [a, f.zaxis]
      end

      def project(points, plane)
        o, n = plane
        points.map { |pt| pt.project_to_plane([o, n]) }
      end

      # Плоскость, лучше всего проходящая через точки: центр и нормаль Ньюэлла.
      def fit_plane(points)
        n = G.newell_normal(points)
        raise UserError, ArchiTools.t(:err_points_collinear) unless n

        c = points.inject(Geom::Vector3d.new(0, 0, 0)) { |s, pt| s + Geom::Vector3d.new(pt.x, pt.y, pt.z) }
        k = 1.0 / points.size
        [Geom::Point3d.new(c.x * k, c.y * k, c.z * k), n]
      end

      def find_vertex(entities, point)
        entities.grep(Sketchup::Edge).flat_map(&:vertices).uniq.min_by { |v| v.position.distance(point).to_f }
      end
    end

    Registry.define(:point_on_face, :edges) do |p|
      p.length :dist_h, 600
      p.length :dist_v, 1800
    end.picks(count: 2, prompts: %i[pk_reference pk_direction],
              check: ->(ctx) { ctx.need(ctx.faces.size == 1, :need_one_face) }).run do |ctx|
      ctx.need(ctx.faces.size == 1, :need_one_face)
      ctx.need(ctx.points.size >= 2, :need_points, n: 2)
      face = ctx.faces.first
      n = face.normal
      base, dir = PointTools.project(ctx.points.first(2), [face.vertices.first.position, n])
      u = dir - base
      ctx.need(u.length.to_f > Geom3::MIN_SIZE, :err_points_same)
      u = u.normalize
      # «Вертикаль» — в плоскости грани поперёк направления: на стене вверх,
      # на горизонтальной грани — влево от направления, если смотреть сверху.
      up = n.z.negative? ? n.reverse : n
      v = up.cross(u).normalize
      v = v.reverse if v.z < -1.0e-9
      target = base.offset(u, ctx.p[:dist_h]).offset(v, ctx.p[:dist_v])
      ctx.made(ctx.entities.add_cpoint(target))
      ArchiTools.t(:ok_point_on_face)
    end

    Registry.define(:perpendicular, :edges) do |p|
      p.choice :output, :edge, %i[edge guide]
    end.picks(count: 2, prompts: %i[pk_start pk_target]).run do |ctx|
      ctx.need(ctx.points.size >= 2, :need_points, n: 2)
      start = ctx.points[0]
      target = ctx.picked[1] || {}
      foot =
        if target[:edge_line]
          start.project_to_line(target[:edge_line])
        elsif target[:face_plane]
          start.project_to_plane(target[:face_plane])
        end
      ctx.need(foot, :err_no_target)
      ctx.need(foot.distance(start).to_f > Geom3::MIN_SIZE, :err_points_same)
      if ctx.p[:output] == :guide
        ctx.made(ctx.entities.add_cline(start, foot))
      else
        ctx.made(ctx.entities.add_line(start, foot))
      end
      ArchiTools.t(:ok_perpendicular, d: Sketchup.format_length(foot.distance(start)))
    end

    Registry.define(:face_on_plane, :edges).picks(
      count: nil, min: 6, prompts: %i[pk_plane1 pk_plane2 pk_plane3 pk_outline]
    ).run do |ctx|
      pts = ctx.points
      ctx.need(pts.size >= 6, :need_points, n: 6)
      plane = PointTools.plane3(*pts.first(3))
      outline = PointTools.project(pts.drop(3), plane)
      face = ctx.entities.add_face(outline)
      ctx.need(face, :err_face_failed)
      ctx.made(face)
      ArchiTools.t(:ok_face, n: outline.size)
    end

    Registry.define(:best_fit_face, :edges).picks(count: nil, min: 3, prompts: %i[pk_outline]).run do |ctx|
      pts = ctx.points
      ctx.need(pts.size >= 3, :need_points, n: 3)
      plane = PointTools.fit_plane(pts)
      dev = pts.map { |pt| pt.distance_to_plane(plane).to_f }.max
      face = ctx.entities.add_face(PointTools.project(pts, plane))
      ctx.need(face, :err_face_failed)
      ctx.made(face)
      ArchiTools.t(:ok_best_fit, d: Sketchup.format_length(dev))
    end

    Registry.define(:move_vertex, :edges).picks(count: 2, prompts: %i[pk_vertex pk_target]).run do |ctx|
      ctx.need(ctx.points.size >= 2, :need_points, n: 2)
      src = ctx.picked[0] && ctx.picked[0][:vertex_position] || ctx.points[0]
      vertex = PointTools.find_vertex(ctx.entities, src)
      ctx.need(vertex && vertex.position.distance(src).to_f < 1.mm.to_f, :err_no_vertex)
      vec = ctx.points[1] - vertex.position
      ctx.need(vec.length.to_f > Geom3::MIN_SIZE, :err_points_same)
      Geom3.move_vertices(ctx.entities, [vertex], [vec])
      ArchiTools.t(:ok_move_vertex, d: Sketchup.format_length(vec.length))
    end

    Registry.define(:align_3pt, :edges) do |p|
      p.bool :scale, false
    end.picks(count: 6, prompts: %i[pk_base1 pk_base2 pk_base3 pk_target1 pk_target2 pk_target3],
              check: ->(ctx) { ctx.need(!ctx.objects.empty?, :need_objects) }).run do |ctx|
      objects = ctx.objects
      ctx.need(!objects.empty?, :need_objects)
      ctx.need(ctx.points.size >= 6, :need_points, n: 6)
      b = ctx.points[0, 3]
      t = ctx.points[3, 3]
      fb = PointTools.frame3(*b)
      ft = PointTools.frame3(*t)
      k = ctx.p[:scale] ? t[0].distance(t[1]).to_f / b[0].distance(b[1]).to_f : 1.0
      m = ft * Geom::Transformation.scaling(k) * fb.inverse
      objects.each { |o| o.transform!(m) }
      ctx.made(objects)
      ArchiTools.t(:ok_align, n: objects.size)
    end
  end
end
