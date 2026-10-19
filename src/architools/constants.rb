# frozen_string_literal: true

module BACommunity
  module ArchiTools
    PLUGIN_NAME = 'ArchiTools'
    VERSION     = '0.3.0'

    # Ключ для Sketchup.read_default / write_default.
    PREFS_KEY = 'BACommunity_ArchiTools'

    # Геометрический допуск в дюймах (внутренняя единица SketchUp).
    TOLERANCE = 1.0e-4

    # Потолок на число создаваемых элементов: опечатка «шаг 0,1 мм» не должна
    # вешать SketchUp на полчаса.
    MAX_ITEMS = 5_000

    # Порядок категорий в панели и на панели инструментов.
    CATEGORIES = %i[edges modify walls facade stairs framing site].freeze
  end
end
