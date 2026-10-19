# Перезагрузка ArchiTools в запущенном SketchUp после dev_install.ps1:
# python test/bridge.py test/reload.rb
dir = File.join(Sketchup.find_support_file('Plugins'), 'architools')
%w[lang constants geom skeleton terrain registry profiles place_tool pick_tool icons about panel].each { |f| load File.join(dir, "#{f}.rb") }
%w[edges points modify surfaces walls facade railing stairs framing site modeling].each { |f| load File.join(dir, 'tools', "#{f}.rb") }
load File.join(dir, "ffd.rb")
"reloaded #{BACommunity::ArchiTools::Registry.all.size} tools"
