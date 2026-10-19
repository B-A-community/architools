# frozen_string_literal: true

require 'json'

module BACommunity
  module ArchiTools
    # Окно «О плагине»: версия, авторы, ссылка на репозиторий — как в RALNCS,
    # area counter и PathCopy Advanced.
    module About
      URLS = %w[https://github.com/B-A-community/architools https://github.com/maksarsanjeev].freeze

      def self.show
        @dialog.close if @dialog&.visible?
        @dialog = UI::HtmlDialog.new(
          dialog_title:    ArchiTools.t(:title_about),
          preferences_key: 'BACommunity_ArchiTools_About',
          width:           440,
          height:          330,
          resizable:       false,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_size(440, 330)
        @dialog.set_file(File.join(__dir__, 'html', 'about.html'))
        @dialog.add_action_callback('ready') do |_ctx|
          @dialog.execute_script("init(#{{ version: VERSION }.to_json})")
        end
        # Открываем только свои адреса, что бы ни прислала страница.
        @dialog.add_action_callback('open_url') { |_ctx, url| UI.openURL(url) if URLS.include?(url) }
        @dialog.add_action_callback('close') { |_ctx| @dialog.close }
        @dialog.show
        @dialog
      end
    end
  end
end
