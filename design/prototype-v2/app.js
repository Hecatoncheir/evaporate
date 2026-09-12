const routes = document.querySelectorAll('[data-route]');
const views = document.querySelectorAll('[data-view]');
const navTabs = document.querySelectorAll('.nav-tab');
const search = document.querySelector('#game-search');
const cards = [...document.querySelectorAll('.game-card')];
const emptyState = document.querySelector('#empty-state');
const resultCount = document.querySelector('#result-count');
const toast = document.querySelector('#toast');
let activeFilter = 'all';
let toastTimer;

function showView(route) {
  const target = document.querySelector(`[data-view="${route}"]`);
  if (!target) return;
  views.forEach((view) => view.classList.toggle('is-active', view === target));
  navTabs.forEach((tab) => {
    const active = tab.dataset.route === route || (route === 'detail' && tab.dataset.route === 'library');
    tab.classList.toggle('is-active', active);
    if (active) tab.setAttribute('aria-current', 'page');
    else tab.removeAttribute('aria-current');
  });
  window.scrollTo({ top: 0, behavior: 'smooth' });
  const heading = target.querySelector('h1');
  if (heading) {
    heading.tabIndex = -1;
    heading.focus({ preventScroll: true });
  }
}

routes.forEach((button) => button.addEventListener('click', () => showView(button.dataset.route)));

function applyFilter() {
  const query = search.value.trim().toLocaleLowerCase('ru');
  let visible = 0;
  cards.forEach((card) => {
    const matchesText = card.dataset.title.toLocaleLowerCase('ru').includes(query);
    const matchesFilter = activeFilter === 'all' || card.dataset.status.includes(activeFilter);
    const shown = matchesText && matchesFilter;
    card.hidden = !shown;
    if (shown) visible += 1;
  });
  emptyState.hidden = visible !== 0;
  const noun = visible === 1 ? 'игра' : visible > 1 && visible < 5 ? 'игры' : 'игр';
  resultCount.textContent = `${visible} ${noun}`;
}

search.addEventListener('input', applyFilter);
document.querySelectorAll('[data-filter]').forEach((button) => {
  button.addEventListener('click', () => {
    activeFilter = button.dataset.filter;
    document.querySelectorAll('[data-filter]').forEach((item) => item.classList.toggle('is-active', item === button));
    applyFilter();
  });
});

document.querySelector('#reset-search').addEventListener('click', () => {
  search.value = '';
  activeFilter = 'all';
  document.querySelectorAll('[data-filter]').forEach((item) => item.classList.toggle('is-active', item.dataset.filter === 'all'));
  applyFilter();
  search.focus();
});

document.addEventListener('keydown', (event) => {
  if (event.key === '/' && document.activeElement !== search) {
    event.preventDefault();
    search.focus();
  }
  if (event.key === 'Escape' && document.querySelector('[data-view="detail"].is-active')) showView('library');
});

function openGame(card) {
  const title = card.dataset.title || 'Signal from Europa';
  const sourceCover = card.querySelector('.cover') || card.querySelector('.continue-art');
  const detailCover = document.querySelector('#detail-cover');
  detailCover.className = `detail-cover ${[...sourceCover.classList].find((name) => name.startsWith('cover-')) || 'cover-signal'}`;
  document.querySelector('#detail-title').textContent = title;
  document.querySelector('#detail-cover-title').innerHTML = title.toUpperCase().replaceAll(' ', '<br>');
  showView('detail');
}

cards.forEach((card) => card.addEventListener('click', () => openGame(card)));
document.querySelector('.continue-card').addEventListener('click', (event) => openGame(event.currentTarget));

function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add('is-visible');
  toastTimer = setTimeout(() => toast.classList.remove('is-visible'), 3200);
}

document.querySelector('.play-button').addEventListener('click', () => showToast('Игра запускается…'));
document.querySelector('#add-game').addEventListener('click', () => showToast('Здесь откроется мастер добавления игры'));
document.querySelector('.transport-button').addEventListener('click', (event) => {
  const button = event.currentTarget;
  const paused = button.classList.toggle('is-paused');
  button.innerHTML = paused ? '<svg><use href="#icon-play"></use></svg>' : '<svg><use href="#icon-pause"></use></svg>';
  button.setAttribute('aria-label', paused ? 'Продолжить загрузку' : 'Приостановить загрузку');
  showToast(paused ? 'Загрузка приостановлена' : 'Загрузка продолжена');
});
