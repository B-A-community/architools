# frozen_string_literal: true

require 'json'

module BACommunity
  module ArchiTools
    # Панель: немодальное окно рядом с видом. Слева направо — категория,
    # инструмент, параметры, «Применить». Параметры запоминаются на каждый
    # инструмент; статус показывает, что сейчас выделено.
    module Panel
      HTML_FILE = File.join(__dir__, 'html', 'panel.html').freeze

      @dialog = nil
      @current = nil

      class << self
        attr_reader :current

        def show(category = nil)
          @current = Registry.in_category(category).first&.id if category
          @current ||= (Sketchup.read_default(PREFS_KEY, 'panel.tool') || Registry.all.first.id).to_sym
          @current = Registry.all.first.id unless Registry[@current]
          if visible?
            @dialog.bring_to_front
            push
          else
            @dialog = build
            @dialog.show
          end
          SelectionWatch.attach
        end

        def visible?
          !@dialog.nil? && @dialog.visible?
        end

        def push
          return unless visible?

          @dialog.execute_script("window.at && at.update(#{payload.to_json});")
        end

        def push_selection
          return unless visible?

          @dialog.execute_script("window.at && at.selection(#{selection_text.to_json});")
        end

        def result(res)
          return unless visible?

          @dialog.execute_script("window.at && at.result(#{res.to_json});")
          push_selection
        end

        def catalog
          CATEGORIES.map do |cat|
            {
              id: cat,
              label: ArchiTools.t(:"cat_#{cat}"),
              icon: Icons.web(cat),
              tools: Registry.in_category(cat).map do |tool|
                {
                  id: tool.id,
                  label: ArchiTools.t(:"tool_#{tool.id}"),
                  hint: ArchiTools.t(:"hint_#{tool.id}"),
                  params: tool.params.map do |param|
                    {
                      key: param.key,
                      type: param.type,
                      label: ArchiTools.label(:p, tool.id, param.key),
                      choices: param.choices&.map { |c| [c, ArchiTools.label(:c, tool.id, c)] },
                      show: param.show&.transform_values { |v| Array(v).map(&:to_s) }
                    }
                  end
                }
              end
            }
          end
        end

        def selection_text
          sel = Sketchup.active_model.selection.to_a
          return ArchiTools.t(:sel_empty) if sel.empty?

          counts = {
            edges: sel.grep(Sketchup::Edge).size,
            faces: sel.grep(Sketchup::Face).size,
            objects: sel.count { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) },
            cpoints: sel.grep(Sketchup::ConstructionPoint).size
          }
          counts[:other] = sel.size - counts.values.sum
          counts.reject { |_, n| n.zero? }.map { |k, n| "#{ArchiTools.t(:"sel_#{k}")}: #{n}" }.join(' · ')
        end

        private

        def build
          dialog = UI::HtmlDialog.new(
            dialog_title:    PLUGIN_NAME,
            preferences_key: 'BACommunity_ArchiTools_Panel',
            scrollable:      true,
            resizable:       true,
            width:           380,
            height:          720,
            min_width:       320,
            min_height:      420,
            style:           UI::HtmlDialog::STYLE_UTILITY
          )
          dialog.set_file(HTML_FILE)
          dialog.add_action_callback('ready') do |_ctx|
            dialog.execute_script("at.init(#{{ catalog: catalog }.to_json});")
            push
          end
          dialog.add_action_callback('pick') do |_ctx, id|
            if Registry[id]
              @current = id.to_sym
              Sketchup.write_default(PREFS_KEY, 'panel.tool', id.to_s)
              push
            end
          end
          dialog.add_action_callback('set') { |_ctx, id, key, value| assign(id, key, value) }
          dialog.add_action_callback('reset') do |_ctx, id|
            tool = Registry[id]
            Prefs.reset(tool) if tool
            push
          end
          dialog.add_action_callback('apply') do |_ctx, id|
            # Окно держит фокус: возвращаем его виду, чтобы сразу работали
            # клавиши SketchUp и расстановка кликом.
            res = Registry.run(id.to_sym)
            result(res)
          end
          dialog.add_action_callback('about') { |_ctx| About.show }
          dialog
        end

        def payload
          tool = Registry[@current]
          values = Prefs.values(tool)
          {
            current: tool.id,
            category: tool.category,
            values: tool.params.to_h { |param| [param.key, Prefs.display(param, values[param.key])] },
            selection: selection_text
          }
        end

        def assign(id, key, value)
          tool = Registry[id]
          return unless tool

          param = tool.params.find { |x| x.key.to_s == key.to_s }
          return unless param

          parsed = Prefs.parse(param, value)
          if parsed.nil?
            UI.beep
          else
            Prefs.write(tool, param, parsed)
          end
          push
        end
      end
    end

    # Следит за выделением, чтобы статус панели не отставал от модели.
    class SelectionWatch < Sketchup::SelectionObserver
      def self.attach
        model = Sketchup.active_model
        return if @model == model

        @instance ||= new
        @model&.selection&.remove_observer(@instance)
        model.selection.add_observer(@instance)
        @model = model
      end

      def onSelectionBulkChange(_selection)
        throttle
      end

      def onSelectionCleared(_selection)
        throttle
      end

      def onSelectionAdded(_selection, _entity)
        throttle
      end

      def onSelectionRemoved(_selection, _entity)
        throttle
      end

      private

      # Выделение рамкой шлёт десятки событий — обновляем окно одним таймером.
      def throttle
        return if @pending

        @pending = true
        UI.start_timer(0.15, false) do
          @pending = false
          Panel.push_selection
        end
      end
    end

    # Новая или открытая модель — переподключаем наблюдатель выделения.
    class AppWatch < Sketchup::AppObserver
      def onNewModel(_model)
        SelectionWatch.attach if Panel.visible?
        Panel.push_selection
      end

      def onOpenModel(_model)
        onNewModel(nil)
      end
    end
  end
end
