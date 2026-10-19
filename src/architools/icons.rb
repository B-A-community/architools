# frozen_string_literal: true

module BACommunity
  module ArchiTools
    # Пути к иконкам — от этого файла, без «Plugins/…» в коде.
    module Icons
      DIRECTORY = File.join(__dir__, 'icons').freeze

      module_function

      # SketchUp 2016+ берёт SVG на Windows и PDF на macOS, иначе PNG.
      def toolbar(basename)
        vector = Sketchup.platform == :platform_win ? "#{basename}.svg" : "#{basename}.pdf"
        candidate = File.join(DIRECTORY, vector)
        return candidate if Sketchup.version.to_i >= 16 && File.exist?(candidate)

        File.join(DIRECTORY, "#{basename}.png")
      end

      # Для окна: путь относительно html/.
      def web(category)
        "../icons/cat_#{category}.svg"
      end
    end
  end
end
