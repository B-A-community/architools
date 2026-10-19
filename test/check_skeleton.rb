# Офлайн-проверка прямого скелета (кровля по выпуклому контуру).
# Запуск: ruby test/check_skeleton.rb
module BACommunity; module ArchiTools; end; end
require_relative '../src/architools/skeleton'
S = BACommunity::ArchiTools::Skeleton
fails = []
check = lambda do |name, pts, max_t|
  faces = S.faces(pts)
  ok = faces.size == pts.size && faces.all? { |f| f.size >= 3 }
  tmax = faces.flatten(1).map { |p| p[2] }.max
  ok &&= (tmax - max_t).abs < 1e-6
  # Площадь проекции скатов = площадь контура.
  area = ->(poly) { poly.each_with_index.sum { |p, i| q = poly[(i + 1) % poly.size]; p[0] * q[1] - q[0] * p[1] } / 2.0 }
  sum = faces.sum { |f| area.call(f) }
  ok &&= (sum - area.call(pts)).abs < 1e-6 * area.call(pts)
  fails << "#{name}: faces=#{faces.map(&:size)} tmax=#{tmax} sum=#{sum} area=#{area.call(pts)}" unless ok
  puts "#{ok ? 'PASS' : 'FAIL'} #{name}: #{faces.map(&:size).inspect}, конёк t=#{tmax.round(4)}"
end
check.call('прямоугольник 10×6', [[0, 0], [10, 0], [10, 6], [0, 6]], 3.0)
check.call('квадрат', [[0, 0], [4, 0], [4, 4], [0, 4]], 2.0)
check.call('треугольник 3-4-5', [[0, 0], [4, 0], [0, 3]], 1.0)
hex = (0...6).map { |i| a = Math::PI / 3 * i; [Math.cos(a) * 5, Math.sin(a) * 5] }
check.call('шестиугольник', hex, 5 * Math.cos(Math::PI / 6))
check.call('трапеция', [[0, 0], [12, 0], [9, 4], [3, 4]], 2.0)
check.call('вытянутый восьмиугольник', [[1, 0], [9, 0], [10, 1], [10, 3], [9, 4], [1, 4], [0, 3], [0, 1]], 2.0)
puts fails.empty? ? 'OK' : fails
