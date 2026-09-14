// Поведение сайта: проявление разделов, переключатель снимков и подсветка
// текущего пункта в шапке. Всё три вещи необязательны — без скрипта страница
// остаётся читаемой, поэтому скрытые панели прячет только он.

const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

/* ── Проявление при прокрутке ─────────────────────────────────────────── */

const reveals = document.querySelectorAll('.reveal');

if (reduceMotion || !('IntersectionObserver' in window)) {
  reveals.forEach((item) => item.classList.add('is-visible'));
} else {
  const revealObserver = new IntersectionObserver(
    (entries) => entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      revealObserver.unobserve(entry.target);
    }),
    { threshold: 0.12 },
  );
  reveals.forEach((item) => revealObserver.observe(item));
}

/* ── Переключатель снимков ────────────────────────────────────────────── */

const tabs = [...document.querySelectorAll('[role="tab"]')];

// Стрелки обязаны водить по вкладкам: список из пяти пунктов, пройденный
// табуляцией по одному, — это пять остановок до соседнего снимка.
const select = (tab, { focus = true } = {}) => {
  tabs.forEach((item) => {
    const active = item === tab;
    const panel = document.getElementById(item.getAttribute('aria-controls'));

    item.setAttribute('aria-selected', String(active));
    item.classList.toggle('is-active', active);
    item.tabIndex = active ? 0 : -1;
    panel.hidden = !active;
    panel.classList.toggle('is-active', active);
  });

  if (focus) tab.focus();
};

// Панели прячет скрипт, а не разметка: без него страница показывает все пять
// снимков подряд, а не один и четыре мёртвые кнопки.
if (tabs.length) select(tabs.find((tab) => tab.classList.contains('is-active')) ?? tabs[0], { focus: false });

tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => select(tab, { focus: false }));

  tab.addEventListener('keydown', (event) => {
    const step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[event.key];
    let next = null;

    if (step) next = tabs[(index + step + tabs.length) % tabs.length];
    if (event.key === 'Home') next = tabs[0];
    if (event.key === 'End') next = tabs[tabs.length - 1];
    if (!next) return;

    event.preventDefault();
    select(next);
  });
});

/* ── Текущий раздел в шапке ───────────────────────────────────────────── */

const links = new Map(
  [...document.querySelectorAll('.nav a')].map((link) => [link.hash.slice(1), link]),
);
const sections = [...links.keys()]
  .map((id) => document.getElementById(id))
  .filter(Boolean);

if ('IntersectionObserver' in window && sections.length) {
  const seen = new Set();

  const spy = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) seen.add(entry.target.id);
        else seen.delete(entry.target.id);
      });

      // Помечаем верхний из видимых: иначе при быстрой прокрутке подсветка
      // остаётся на разделе, который уже ушёл за верхний край.
      const current = sections.find((section) => seen.has(section.id));
      links.forEach((link, id) => link.classList.toggle('is-current', id === current?.id));
    },
    { rootMargin: '-66px 0px -55% 0px' },
  );

  sections.forEach((section) => spy.observe(section));
}
