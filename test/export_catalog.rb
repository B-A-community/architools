# frozen_string_literal: true
#
# Выгрузка каталога инструментов из живого SketchUp для make_tools_doc.py:
# python test/bridge.py test/export_catalog.rb  ->  %TEMP%/architools_catalog.json

require 'json'
at = BACommunity::ArchiTools
catalog = at::Panel.catalog.map do |c|
  c.merge(tools: c[:tools].map do |t|
    tool = at::Registry[t[:id]]
    t.merge(picks: !tool.picks.nil?,
            params: t[:params].map do |p|
              prm = tool.params.find { |x| x.key == p[:key] }
              p.merge(default: at::Prefs.display(prm, prm.default))
            end)
  end)
end
path = File.join(ENV['TEMP'], 'architools_catalog.json')
File.write(path, JSON.generate(catalog))
"#{catalog.sum { |c| c[:tools].size }} tools -> #{path}"
