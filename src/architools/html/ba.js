// Дизайн-код плагинов B&A community — общие JS-хелперы для HtmlDialog.
// Подключение: <script src="ba.js"></script> перед своим скриптом.
// Все функции лежат в window.BA, ничего глобального не засоряют.
(function (w) {
  var BA = {};

  // Экранирование для innerHTML
  BA.esc = function (s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
                    .replace(/"/g, '&quot;');
  };

  // Тост вместо alert: подтверждения и мягкие отказы. Нужен <div id="toast"></div>.
  BA.toast = function (msg, ms) {
    var t = document.getElementById('toast');
    if (!t) return;
    t.textContent = msg;
    t.classList.add('on');
    clearTimeout(BA._toastTimer);
    BA._toastTimer = setTimeout(function () { t.classList.remove('on'); }, ms || 2400);
  };

  // Подтверждение перед изменением модели: обязательно упоминаем отмену.
  BA.confirmUndoable = function (lines) {
    return confirm((Array.isArray(lines) ? lines : [lines]).concat('Действие можно отменить (Ctrl+Z).').join('\n'));
  };

  // Буфер обмена в двух форматах сразу: TSV (текст) + HTML (с заливкой ячеек).
  // Google Таблицы / Excel при Ctrl+V берут HTML и сохраняют background-color.
  // rows: [[{v, bg?}, ...], ...], header: ['Колонка', ...]
  BA.tableToTsv = function (header, rows) {
    var lines = [header.join('\t')];
    rows.forEach(function (r) { lines.push(r.map(function (c) { return c.v; }).join('\t')); });
    return lines.join('\n');
  };
  BA.tableToHtml = function (header, rows) {
    var head = '<tr>' + header.map(function (h) {
      return '<td style="font-weight:bold">' + BA.esc(h) + '</td>';
    }).join('') + '</tr>';
    var body = rows.map(function (r) {
      return '<tr>' + r.map(function (c) {
        return '<td' + (c.bg ? ' style="background-color:' + c.bg + '"' : '') + '>' + BA.esc(c.v) + '</td>';
      }).join('') + '</tr>';
    }).join('');
    return '<table>' + head + body + '</table>';
  };
  BA.copyBoth = function (tsv, html, onDone) {
    function legacy() {
      var ta = document.createElement('textarea');
      ta.value = tsv;
      document.body.appendChild(ta);
      ta.select();
      function handler(e) {
        e.clipboardData.setData('text/plain', tsv);
        e.clipboardData.setData('text/html', html);
        e.preventDefault();
      }
      document.addEventListener('copy', handler);
      try { document.execCommand('copy'); } finally {
        document.removeEventListener('copy', handler);
        document.body.removeChild(ta);
      }
      if (onDone) onDone();
    }
    if (navigator.clipboard && navigator.clipboard.write && w.ClipboardItem) {
      var item = new ClipboardItem({
        'text/plain': new Blob([tsv], { type: 'text/plain' }),
        'text/html': new Blob([html], { type: 'text/html' })
      });
      navigator.clipboard.write([item]).then(onDone || function () {}, legacy);
    } else {
      legacy();
    }
  };
  // Удобная обёртка: скопировать таблицу и показать тост
  BA.copyTable = function (header, rows, what) {
    BA.copyBoth(BA.tableToTsv(header, rows), BA.tableToHtml(header, rows), function () {
      BA.toast('Скопировано: ' + rows.length + ' строк × ' + header.length + ' столбцов. Вставьте в Google Таблицу (Ctrl+V).');
    });
  };

  // Попап-панель: открыть/закрыть по кнопке, закрыть кликом снаружи.
  BA.popover = function (btnId, panelId) {
    var btn = document.getElementById(btnId), panel = document.getElementById(panelId);
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      panel.classList.toggle('open');
      btn.classList.toggle('on', panel.classList.contains('open'));
    });
    document.addEventListener('click', function (e) {
      if (panel.classList.contains('open') && !panel.contains(e.target)) {
        panel.classList.remove('open');
        btn.classList.remove('on');
      }
    });
  };

  // Чекбокс «все» + чекбоксы строк
  BA.checkAll = function (allId, rowSelector) {
    document.getElementById(allId).addEventListener('change', function (e) {
      document.querySelectorAll(rowSelector).forEach(function (cb) { cb.checked = e.target.checked; });
    });
  };

  // Цвета
  BA.hexToRgb = function (hex) {
    var h = hex.replace('#', '');
    return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)];
  };
  BA.hexToRgbStr = function (hex) { return BA.hexToRgb(hex).join('-'); };   // «240-211-208», как в ТЗ
  BA.swatch = function (hex) { return '<span class="sw" style="background:' + hex + '"></span>'; };

  // Бейдж-шкала: пороги [1, 2, 5] → ok / good / warn / bad
  BA.scalePill = function (value, thresholds, titles) {
    var cls = ['ok', 'good', 'warn', 'bad'];
    var i = 0;
    while (i < thresholds.length && value >= thresholds[i]) i++;
    var title = titles && titles[i] ? ' title="' + BA.esc(titles[i]) + '"' : '';
    return '<span class="pill ' + cls[i] + '"' + title + '>' + value.toFixed(1) + '</span>';
  };

  w.BA = BA;
})(window);
