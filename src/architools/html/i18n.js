// Язык окон — как в RALNCS, area counter и PathCopy Advanced.
// tools\build_rbz.ps1 -Lang en подменяет первую строку. Подписи инструментов
// и параметров приходят из Ruby (lang.rb) — здесь только оболочка окна.
var LANG = 'ru';

var I18N = {
  ru: {
    btn_apply: 'Применить',
    t_apply: 'Выполнить инструмент на текущем выделении (Enter)',
    btn_reset: 'Сброс',
    t_reset: 'Вернуть параметры этого инструмента к исходным',
    t_about: 'О плагине',
    g_select: 'Что выделить',
    g_params: 'Параметры',
    no_params: 'Параметров нет — всё решает выделение.',
    footer: 'Каждое применение — один шаг отмены (Ctrl+Z).',
    about_sub: 'Архитектурные инструменты для SketchUp — по мотивам 1001bit Tools.',
    about_version: 'Версия',
    about_authors: 'Авторы',
    about_repo: 'Репозиторий',
    about_license: 'Apache 2.0 · © 2026 B&A community',
    about_close: 'Закрыть'
  },
  en: {
    btn_apply: 'Apply',
    t_apply: 'Run the tool on the current selection (Enter)',
    btn_reset: 'Reset',
    t_reset: 'Restore this tool’s defaults',
    t_about: 'About',
    g_select: 'What to select',
    g_params: 'Parameters',
    no_params: 'No parameters — the selection decides everything.',
    footer: 'Each run is one undo step (Ctrl+Z).',
    about_sub: 'Architectural tools for SketchUp — inspired by 1001bit Tools.',
    about_version: 'Version',
    about_authors: 'Authors',
    about_repo: 'Repository',
    about_license: 'Apache 2.0 · © 2026 B&A community',
    about_close: 'Close'
  }
};

function t(key) {
  var table = I18N[LANG] || I18N.ru;
  return table[key] !== undefined ? table[key] : (I18N.ru[key] !== undefined ? I18N.ru[key] : key);
}

function applyI18n(root) {
  (root || document).querySelectorAll('[data-t]').forEach(function (el) { el.textContent = t(el.dataset.t); });
  (root || document).querySelectorAll('[data-t-title]').forEach(function (el) { el.title = t(el.dataset.tTitle); });
  document.documentElement.lang = LANG;
}
