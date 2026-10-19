# frozen_string_literal: true
#
# ArchiTools — загрузчик / манифест расширения.
#
# Архитектурный набор инструментов для SketchUp, написанный с нуля по мотивам
# заброшенного 1001bit Tools: рёбра (скругление, фаска, продление, деление,
# смещение, уклон), правка (выдавливание, оболочка, профиль по пути, массивы,
# разбивка на панели) и архитектура (стены, проёмы, окна, двери, жалюзи,
# лестницы, балки, стропила, прогоны, кровля, колонны). Кода 1001bit здесь нет.

require 'sketchup.rb'
require 'extensions.rb'

module BACommunity
  module ArchiTools
    ROOT_PATH   = File.dirname(File.expand_path(__FILE__)).freeze
    PLUGIN_PATH = File.join(ROOT_PATH, 'architools').freeze
  end
end

# PLUGIN_NAME и VERSION лежат в constants.rb, подписи — в lang.rb. Язык пакета
# подменяет tools\build_rbz.ps1 -Lang.
require File.join(BACommunity::ArchiTools::PLUGIN_PATH, 'constants')
require File.join(BACommunity::ArchiTools::PLUGIN_PATH, 'lang')

module BACommunity
  module ArchiTools
    unless defined?(@loaded)
      @loaded = true

      extension = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_PATH, 'main.rb'))
      extension.version     = VERSION
      extension.creator     = 'B&A community'
      extension.copyright   = '2026 B&A community'
      extension.description = t(:ext_description)

      Sketchup.register_extension(extension, true)
    end
  end
end
