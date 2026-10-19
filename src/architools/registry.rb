# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Каталог инструментов. Каждый инструмент — это описание параметров и блок,
    # который работает с текущим выделением. Панель строит форму по описанию,
    # меню и тесты зовут тот же Registry.run — путь у всех один.
    module Registry
      Param   = Struct.new(:key, :type, :default, :choices, :min, :max, :show, keyword_init: true)
      ToolDef = Struct.new(:id, :category, :params, :block, :picks, keyword_init: true)

      # Построитель списка параметров для define.
      class ParamList
        attr_reader :list

        def initialize
          @list = []
        end

        # Длина задаётся в мм, хранится в дюймах.
        # show: { другой_ключ: значение | [значения] } — поле видно в панели,
        # только когда другой параметр имеет одно из этих значений.
        def length(key, mm, min: nil, show: nil)
          @list << Param.new(key: key, type: :length, default: mm.to_f.mm.to_f, min: min, show: show)
        end

        def int(key, value, min: 1, max: MAX_ITEMS, show: nil)
          @list << Param.new(key: key, type: :int, default: value, min: min, max: max, show: show)
        end

        def float(key, value, min: nil, max: nil, show: nil)
          @list << Param.new(key: key, type: :float, default: value.to_f, min: min, max: max, show: show)
        end

        def angle(key, value, min: nil, max: nil, show: nil)
          @list << Param.new(key: key, type: :angle, default: value.to_f, min: min, max: max, show: show)
        end

        def bool(key, value, show: nil)
          @list << Param.new(key: key, type: :bool, default: value, show: show)
        end

        def choice(key, value, choices, show: nil)
          @list << Param.new(key: key, type: :choice, default: value, choices: choices, show: show)
        end
      end

      @tools = {}

      class << self
        def define(id, category)
          params = ParamList.new
          yield params if block_given?
          @tools[id] = ToolDef.new(id: id, category: category, params: params.list, block: nil)
          ToolBody.new(@tools[id])
        end

        def [](id)
          @tools[id.to_sym]
        end

        def all
          @tools.values
        end

        def in_category(category)
          @tools.values.select { |tool| tool.category == category }
        end

        # Запуск инструмента на текущем выделении. overrides — значения
        # параметров поверх сохранённых (так зовут тесты). Возвращает
        # { ok:, message: }.
        def run(id, overrides = {})
          tool = self[id] or raise ArgumentError, "unknown tool #{id}"
          model = Sketchup.active_model
          values = Prefs.values(tool)
          overrides.each { |k, v| values[k.to_sym] = v }
          ctx = Context.new(model, values)
          # Инструменту нужны клики: сначала проверяем выделение, потом
          # отдаём мышь PickTool, а он вызовет run ещё раз уже с точками.
          # Тесты передают points: сами — путь тот же, что после кликов.
          if tool.picks && !values.key?(:points)
            begin
              tool.picks[:check]&.call(ctx)
            rescue UserError => e
              return { ok: false, message: e.message }
            end
            PickTool.start(tool, values) if values.fetch(:place, true)
            return { ok: true, message: PickTool.prompt(tool, 0), picking: true }
          end
          model.start_operation(ArchiTools.t(:"tool_#{id}"), true)
          begin
            message = tool.block.call(ctx)
            model.commit_operation
          rescue UserError => e
            model.abort_operation
            return { ok: false, message: e.message }
          rescue StandardError => e
            model.abort_operation
            warn("ArchiTools #{id}: #{e.class}: #{e.message}\n#{e.backtrace.first(6).join("\n")}")
            return { ok: false, message: "#{ArchiTools.t(:err_internal)} #{e.message}" }
          end
          model.selection.clear
          model.selection.add(ctx.created.select(&:valid?)) unless ctx.created.empty?
          if ctx.placing && values.fetch(:place, true)
            PlaceTool.start(ctx.placing)
          end
          { ok: true, message: message.to_s, created: ctx.created.size }
        end
      end

      # Обёртка, чтобы писать define(...) { |p| ... }.run { |ctx| ... }
      class ToolBody
        def initialize(tool)
          @tool = tool
        end

        # Клики в модели: count — сколько точек (nil — сколько угодно, конец
        # по двойному клику или Enter), min — минимум для «сколько угодно»,
        # prompts — ключи подсказок по порядку, check — проверка выделения
        # до начала кликов.
        # max — для «сколько угодно» закончить автоматически на этой точке.
        def picks(count: nil, min: 1, max: nil, prompts: [], check: nil)
          @tool.picks = { count: count, min: min, max: max, prompts: prompts, check: check }
          self
        end

        def run(&block)
          @tool.block = block
          @tool
        end
      end
    end

    # То, что видит блок инструмента: модель, активный контекст, выделение,
    # значения параметров и мелкие помощники.
    class Context
      attr_reader :model, :p, :created
      attr_accessor :placing

      def initialize(model, values)
        @model = model
        @p = values
        @created = []
        @placing = nil
      end

      def entities
        @model.active_entities
      end

      def selection
        @model.selection.to_a
      end

      def edges
        selection.grep(Sketchup::Edge)
      end

      def faces
        selection.grep(Sketchup::Face)
      end

      def objects
        selection.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      end

      def cpoints
        selection.grep(Sketchup::ConstructionPoint)
      end

      # Точки кликов (Point3d) и что было под курсором: { edge_line:,
      # face_plane:, face:, edge:, vertex: } — в мировых координатах.
      def points
        @p[:points] || []
      end

      def picked
        @p[:picked] || []
      end

      def need(condition, key, **vars)
        raise UserError, ArchiTools.t(key, **vars) unless condition
      end

      # Запомнить созданное: после операции оно станет выделением.
      def made(*entities)
        entities.flatten.compact.each { |e| @created << e }
        entities.flatten.first
      end

      def name(key)
        ArchiTools.t(:"name_#{key}")
      end
    end

    # Сохранённые значения параметров: на инструмент и ключ.
    module Prefs
      module_function

      def values(tool)
        tool.params.each_with_object({}) { |param, h| h[param.key] = read(tool, param) }
      end

      def read(tool, param)
        raw = Sketchup.read_default(PREFS_KEY, "#{tool.id}.#{param.key}")
        return param.default if raw.nil?

        case param.type
        when :length, :float, :angle then raw.to_f
        when :int then raw.to_i
        when :bool then raw == true || raw.to_s == 'true'
        when :choice
          sym = raw.to_s.to_sym
          param.choices.include?(sym) ? sym : param.default
        else raw
        end
      end

      def write(tool, param, value)
        stored = value.is_a?(Symbol) ? value.to_s : value
        Sketchup.write_default(PREFS_KEY, "#{tool.id}.#{param.key}", stored)
      end

      def reset(tool)
        tool.params.each { |param| write(tool, param, param.type == :choice ? param.default.to_s : param.default) }
      end

      # Разбор значения из панели. nil — ввод не распознан.
      def parse(param, text)
        text = text.to_s.strip
        value =
          case param.type
          when :length then parse_length(text)
          when :int then Integer(text, 10)
          when :float, :angle then Float(text.tr(',', '.'))
          when :bool then text == 'true'
          when :choice
            sym = text.to_sym
            return nil unless param.choices.include?(sym)

            sym
          end
        value = [value, param.min].max if param.min && value.is_a?(Numeric)
        value = [value, param.max].min if param.max && value.is_a?(Numeric)
        value
      rescue ArgumentError, TypeError
        nil
      end

      # to_l зависит от десятичного разделителя системы: пробуем как ввели,
      # затем с точкой и с запятой.
      def parse_length(text)
        return 0.0 if text.empty?

        [text, text.tr(',', '.'), text.tr('.', ',')].uniq.each do |variant|
          begin
            return variant.to_l.to_f
          rescue ArgumentError
            next
          end
        end
        raise ArgumentError, text
      end

      # Значение для показа в поле.
      def display(param, value)
        case param.type
        when :length then Sketchup.format_length(value.to_f).to_s.sub(/^~ ?/, '')
        when :float, :angle then format_number(value.to_f)
        when :choice then value.to_s
        else value
        end
      end

      def format_number(x)
        s = format('%.3f', x).sub(/\.?0+$/, '')
        s.empty? ? '0' : s
      end
    end
  end
end
