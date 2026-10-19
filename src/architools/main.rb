# frozen_string_literal: true

module BACommunity
  module ArchiTools
    %w[lang constants geom skeleton terrain registry profiles place_tool pick_tool icons about panel
       tools/edges tools/points tools/modify tools/surfaces tools/walls tools/facade tools/railing
       tools/stairs tools/framing tools/site tools/modeling ffd]
      .each { |file| Sketchup.require(File.join(__dir__, file)) }

    # Запуск из меню: с последними параметрами, без окна. Отказ — в окне
    # сообщения, успех — в строке состояния (и в панели, если она открыта).
    def self.run_from_menu(id)
      res = Registry.run(id)
      Panel.result(res)
      if res[:ok]
        Sketchup.status_text = res[:message]
      else
        UI.messagebox("#{t(:"tool_#{id}")}: #{res[:message]}")
      end
      res
    end

    unless defined?(@ui_built)
      @ui_built = true

      panel_command = UI::Command.new(t(:menu_panel)) { Panel.show }
      panel_command.tooltip = t(:tip_panel)
      panel_command.status_bar_text = t(:st_panel)
      panel_command.small_icon = Icons.toolbar('panel')
      panel_command.large_icon = Icons.toolbar('panel')

      menu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)
      menu.add_item(panel_command)
      menu.add_separator

      toolbar = UI::Toolbar.new(PLUGIN_NAME)
      toolbar.add_item(panel_command)
      toolbar.add_separator

      CATEGORIES.each do |cat|
        # Кнопка категории открывает панель на первом её инструменте.
        cmd = UI::Command.new(t(:"cat_#{cat}")) { Panel.show(cat) }
        cmd.tooltip = t(:"cat_#{cat}")
        cmd.status_bar_text = Registry.in_category(cat).map { |tool| t(:"tool_#{tool.id}") }.join(', ')
        cmd.small_icon = Icons.toolbar("cat_#{cat}")
        cmd.large_icon = Icons.toolbar("cat_#{cat}")
        toolbar.add_item(cmd)

        # Пункты меню выполняют инструмент сразу — на них можно повесить
        # горячие клавиши SketchUp.
        sub = menu.add_submenu(t(:"cat_#{cat}"))
        Registry.in_category(cat).each do |tool|
          item = UI::Command.new(t(:"tool_#{tool.id}")) { run_from_menu(tool.id) }
          item.status_bar_text = t(:"hint_#{tool.id}")
          sub.add_item(item)
        end
      end

      menu.add_separator
      menu.add_item(t(:menu_about)) { About.show }

      toolbar.restore
      Sketchup.add_observer(AppWatch.new)
    end
  end
end
