# Офлайн-проверка прямого скелета (вальмовая кровля по любому контуру).
# Запуск: ruby test/check_skeleton.rb
#
# Для каждого контура проверяется:
#   * у каждого ребра карниза есть свой скат (многоугольник ≥ 3 вершин);
#   * сумма площадей скатов в плане = площадь контура минус дыры;
#   * каждый скат плоский (все точки на одной плоскости при z = t);
#   * высота конька — ожидаемая (где её легко посчитать руками).
module BACommunity; module ArchiTools; class UserError < StandardError; end; def self.t(k, **) = k.to_s; end; end
require_relative '../src/architools/skeleton'
S = BACommunity::ArchiTools::Skeleton

def area(poly) = poly.each_with_index.sum { |p, i| q = poly[(i + 1) % poly.size]; p[0] * q[1] - q[0] * p[1] } / 2.0

def flatness(poly)
  # Плоскость по Ньюэллу через центр; наибольшее отклонение точки.
  nx = ny = nz = 0.0
  poly.each_with_index do |p, i|
    q = poly[(i + 1) % poly.size]
    nx += (p[1] - q[1]) * (p[2] + q[2])
    ny += (p[2] - q[2]) * (p[0] + q[0])
    nz += (p[0] - q[0]) * (p[1] + q[1])
  end
  len = Math.sqrt(nx * nx + ny * ny + nz * nz)
  return 0.0 if len < 1e-12

  c = [0, 1, 2].map { |k| poly.sum { |p| p[k] } / poly.size }
  poly.map { |p| ((p[0] - c[0]) * nx + (p[1] - c[1]) * ny + (p[2] - c[2]) * nz).abs / len }.max
end

fails = []
check = lambda do |name, loops, ridge = nil|
  loops = [loops] if loops.first.first.is_a?(Numeric)
  faces = S.faces(loops)
  n_edges = loops.sum(&:size)
  sum = faces.sum { |f| area(f) }
  expected = loops.sum { |l| area(l) }
  tmax = faces.flatten(1).map { |p| p[2] }.max
  flat = faces.map { |f| flatness(f) }.max
  ok = faces.size == n_edges && faces.all? { |f| f.size >= 3 } &&
       (sum - expected).abs < 1e-6 * expected.abs && flat < 1e-6 && (ridge.nil? || (tmax - ridge).abs < 1e-6)
  info = "скатов #{faces.size}/#{n_edges}, площадь #{sum.round(4)}/#{expected.round(4)}, " \
         "неплоскость #{flat.round(9)}, конёк t=#{tmax.round(4)}"
  fails << "#{name}: #{info}" unless ok
  puts "#{ok ? 'PASS' : 'FAIL'} #{name}: #{info}"
end

check.call('прямоугольник 10×6', [[0, 0], [10, 0], [10, 6], [0, 6]], 3.0)
check.call('квадрат', [[0, 0], [4, 0], [4, 4], [0, 4]], 2.0)
check.call('треугольник 3-4-5', [[0, 0], [4, 0], [0, 3]], 1.0)
hex = (0...6).map { |i| a = Math::PI / 3 * i; [Math.cos(a) * 5, Math.sin(a) * 5] }
check.call('шестиугольник', hex, 5 * Math.cos(Math::PI / 6))
check.call('трапеция', [[0, 0], [12, 0], [9, 4], [3, 4]], 2.0)
check.call('вытянутый восьмиугольник', [[1, 0], [9, 0], [10, 1], [10, 3], [9, 4], [1, 4], [0, 3], [0, 1]], 2.0)
# Невыпуклые: здания Г, Т, П, крест.
check.call('Г-образный', [[0, 0], [10, 0], [10, 4], [4, 4], [4, 10], [0, 10]], 2.0)
check.call('Т-образный', [[0, 6], [0, 10], [12, 10], [12, 6], [8, 6], [8, 0], [4, 0], [4, 6]].reverse, 2.0)
check.call('П-образный', [[0, 0], [4, 0], [4, 6], [8, 6], [8, 0], [12, 0], [12, 10], [0, 10]], 2.0)
check.call('крест', [[4, 0], [8, 0], [8, 4], [12, 4], [12, 8], [8, 8], [8, 12], [4, 12], [4, 8], [0, 8], [0, 4], [4, 4]], 2.0)
check.call('Г с разной шириной крыльев', [[0, 0], [14, 0], [14, 5], [3, 5], [3, 9], [0, 9]], 2.5)
# С дырами: двор внутри.
check.call('двор', [[[0, 0], [12, 0], [12, 10], [0, 10]], [[4, 3], [4, 7], [8, 7], [8, 3]]], 2.0)
check.call('двор со смещением', [[[0, 0], [14, 0], [14, 10], [0, 10]], [[3, 2], [3, 6], [9, 6], [9, 2]]], 2.5)
# Неортогональные: косой Г, звезда, неправильный многоугольник с косым двором.
check.call('косой Г', [[0, 0], [11, 1], [10.5, 5], [5, 4.6], [3.8, 11], [-0.5, 10]])
star = (0...10).map { |i| r = i.even? ? 10 : 5.5; a = Math::PI / 5 * i + 0.13; [r * Math.cos(a), r * Math.sin(a)] }
check.call('звезда', star)
check.call('кривой двор', [[[0, 0], [16, 1], [17, 11], [7, 13], [-1, 9]], [[5, 4], [6, 8], [11, 8.5], [10, 4.2]]])
puts fails.empty? ? 'OK' : "FAILED: #{fails.size}"
