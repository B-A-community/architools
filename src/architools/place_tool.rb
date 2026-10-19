# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Расстановка готового объекта кликом: объект едет за курсором (с
    # привязками SketchUp), Tab / ← → поворачивают на 90°, клик ставит,
    # Esc убирает созданное.
    class PlaceTool
      def self.start(entity)
        Sketchup.active_model.select_tool(new(entity))
      end

      def initialize(entity)
        @entity = entity
        @ip = Sketchup::InputPoint.new
        @angle = 0.0
        @point = ORIGIN
      end

      def activate
        Sketchup.status_text = ArchiTools.t(:st_place)
      end

      def deactivate(view)
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        @point = @ip.position
        apply
        view.tooltip = @ip.tooltip
        view.invalidate
      end

      def onLButtonDown(_flags, _x, _y, _view)
        apply
        Sketchup.active_model.select_tool(nil)
      end

      def onKeyDown(key, _repeat, _flags, _view)
        if key == 9 || key == VK_RIGHT
          @angle += Math::PI / 2
        elsif key == VK_LEFT
          @angle -= Math::PI / 2
        else
          return false
        end
        apply
        true
      end

      def onCancel(_reason, _view)
        model = Sketchup.active_model
        if @entity.valid?
          model.start_operation(ArchiTools.t(:op_place), true, false, true)
          @entity.erase!
          model.commit_operation
        end
        model.select_tool(nil)
      end

      def draw(view)
        @ip.draw(view) if @ip.display?
      end

      private

      # Прозрачная операция: сдвиг сливается с созданием в один шаг отмены.
      def apply
        return unless @entity.valid?

        model = Sketchup.active_model
        model.start_operation(ArchiTools.t(:op_place), true, false, true)
        @entity.transformation = Geom::Transformation.translation(@point) *
                                 Geom::Transformation.rotation(ORIGIN, Geom3::Z, @angle)
        model.commit_operation
      end
    end
  end
end
