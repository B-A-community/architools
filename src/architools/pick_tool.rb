# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Сбор кликов для инструментов, которым нужны точки в модели (точка на
    # грани, перпендикуляр, грань по 3 точкам, перемещение вершины,
    # выравнивание по 3 точкам, ось вращения). Привязки — обычные SketchUp
    # (InputPoint). Набрав точки, вызывает Registry.run(id, points:, picked:)
    # — тот же путь, по которому идут тесты.
    #
    # Клавиши: Enter или двойной клик — закончить (для «сколько угодно
    # точек»), Backspace — убрать последнюю точку, Esc — отменить.
    class PickTool
      def self.start(tool, values)
        Sketchup.active_model.select_tool(new(tool, values))
      end

      def self.prompt(tool, index)
        keys = tool.picks[:prompts]
        key = keys[index] || keys.last || :pk_point
        ArchiTools.t(key)
      end

      def initialize(tool, values)
        @tool = tool
        @values = values.reject { |k, _| %i[points picked].include?(k) }
        @ip = Sketchup::InputPoint.new
        @points = []
        @picked = []
      end

      def activate
        status
      end

      def deactivate(view)
        view.invalidate
      end

      def resume(_view)
        status
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        view.tooltip = @ip.tooltip
        view.invalidate
      end

      def onLButtonDown(_flags, _x, _y, view)
        return unless @ip.valid?

        @points << @ip.position
        @picked << describe(@ip)
        view.invalidate
        count = @tool.picks[:count]
        count && @points.size >= count ? finish : status
      end

      def onLButtonDoubleClick(_flags, _x, _y, _view)
        finish_open
      end

      def onReturn(_view)
        finish_open
      end

      def onKeyDown(key, _repeat, _flags, view)
        return false unless key == 8 # Backspace

        @points.pop
        @picked.pop
        status
        view.invalidate
        true
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      def draw(view)
        @ip.draw(view) if @ip.display?
        return if @points.empty?

        view.drawing_color = Sketchup::Color.new(43, 108, 176)
        view.line_width = 2
        view.draw_points(@points, 8, 2, view.drawing_color)
        line = @points + (@ip.valid? ? [@ip.position] : [])
        view.draw(GL_LINE_STRIP, line) if line.size > 1
      end

      private

      def describe(ip)
        info = { vertex: ip.vertex, edge: ip.edge, face: ip.face }
        t = ip.transformation
        if ip.edge
          a = ip.edge.start.position.transform(t)
          b = ip.edge.end.position.transform(t)
          info[:edge_line] = [a, b - a]
        end
        if ip.face
          o = ip.face.vertices.first.position.transform(t)
          info[:face_plane] = [o, ip.face.normal.transform(t).normalize]
        end
        info[:vertex_position] = ip.vertex.position.transform(t) if ip.vertex
        info
      end

      def status
        Sketchup.status_text = "#{ArchiTools.t(:"tool_#{@tool.id}")}: #{PickTool.prompt(@tool, @points.size)}" \
                               " #{ArchiTools.t(:st_pick_keys)}"
      end

      def finish_open
        return if @tool.picks[:count]
        return UI.beep if @points.size < @tool.picks[:min]

        finish
      end

      def finish
        points = @points
        picked = @picked
        Sketchup.active_model.select_tool(nil)
        res = Registry.run(@tool.id, @values.merge(points: points, picked: picked))
        Panel.result(res)
        if res[:ok]
          Sketchup.status_text = res[:message]
        else
          UI.messagebox("#{ArchiTools.t(:"tool_#{@tool.id}")}: #{res[:message]}")
        end
      end
    end
  end
end
