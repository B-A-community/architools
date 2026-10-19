# Офлайн-проверка словарей: у ru и en одинаковые ключи, у каждого
# инструмента, параметра и режима есть подпись. Запуск: ruby test/check_lang.rb
module BACommunity; module ArchiTools; end; end
require_relative '../src/architools/lang'
S = BACommunity::ArchiTools::STRINGS
ru = S['ru'].keys
en = S['en'].keys
problems = []
problems << "нет в en: #{(ru - en).join(', ')}" unless (ru - en).empty?
problems << "нет в ru: #{(en - ru).join(', ')}" unless (en - ru).empty?
src = Dir[File.join(__dir__, '../src/architools/**/*.rb')].map { |f| File.read(f, encoding: 'utf-8') }.join("\n")
src.scan(/Registry\.define\(:(\w+)/).flatten.each do |id|
  %w[tool hint].each { |pre| problems << "нет #{pre}_#{id}" unless ru.include?(:"#{pre}_#{id}") }
end
src.scan(/^\s+p\.\w+ :(\w+)/).flatten.uniq.each do |key|
  problems << "нет p_#{key}" unless ru.any? { |k| k.to_s == "p_#{key}" || k.to_s.end_with?("_#{key}") && k.to_s.start_with?('p_') }
end
words = src.scan(/%i\[([^\]]+)\]/).flatten.flat_map(&:split).uniq
# Подсказки кликов (pk_*) — ключи словаря сами по себе.
words.select { |c| c.start_with?('pk_') }.each { |k| problems << "нет #{k}" unless ru.include?(k.to_sym) }
words.each do |c|
  next if %w[edges modify walls facade stairs framing site modeling lang points picked].include?(c) || c.start_with?('pk_')
  problems << "нет c_#{c}" unless ru.any? { |k| k.to_s == "c_#{c}" || (k.to_s.start_with?('c_') && k.to_s.end_with?("_#{c}")) }
end
src.scan(/(?:ArchiTools\.t|ctx\.need\([^,]+,) ?\(?:(\w+)/).flatten.uniq.each do |k|
  problems << "нет #{k}" unless ru.include?(k.to_sym)
end
puts problems.empty? ? "OK: #{ru.size} строк, ru = en" : problems
