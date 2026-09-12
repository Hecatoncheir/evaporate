const root = document.documentElement;
const views = [...document.querySelectorAll('[data-view]')];
const navButtons = [...document.querySelectorAll('.nav-button')];
const themeButton = document.querySelector('#theme-button');
const searchDialog = document.querySelector('#search-dialog');
const searchInput = document.querySelector('#search-input');
const searchResults = document.querySelector('#search-results');
const games = [...document.querySelectorAll('.game-card')].map((card) => ({
  title: card.dataset.title,
  game: card.dataset.game,
  installed: card.dataset.installed === 'true',
}));

function applyTheme(theme) {
  root.dataset.theme = theme;
  localStorage.setItem('evaporate-v3-theme', theme);
  themeButton.setAttribute('aria-label', theme === 'dark' ? 'Включить светлую тему' : 'Включить тёмную тему');
  document.querySelector('meta[name="color-scheme"]').content = theme;
}

const savedTheme = localStorage.getItem('evaporate-v3-theme');
applyTheme(savedTheme || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'));

function route(name) {
  const target = views.find((view) => view.dataset.view === name);
  if (!target) return;
  views.forEach((view) => view.classList.toggle('is-active', view === target));
  navButtons.forEach((button) => {
    const active = button.dataset.route === name || (name === 'detail' && button.dataset.route === 'library');
    button.classList.toggle('is-active', active);
    if (active) button.setAttribute('aria-current', 'page'); else button.removeAttribute('aria-current');
  });
  history.replaceState(null, '', `#${name}`);
  target.querySelector('h1')?.focus({ preventScroll: true });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

document.querySelectorAll('[data-route]').forEach((button) => button.addEventListener('click', () => route(button.dataset.route)));
document.querySelectorAll('[data-game]').forEach((button) => button.addEventListener('click', (event) => {
  if (event.target.closest('.play-button')) return;
  route('detail');
}));

themeButton.addEventListener('click', () => applyTheme(root.dataset.theme === 'dark' ? 'light' : 'dark'));

function renderResults(query = '') {
  const normalized = query.trim().toLocaleLowerCase('ru');
  const matches = normalized ? games.filter((game) => game.title.toLocaleLowerCase('ru').includes(normalized)) : games;
  searchResults.replaceChildren();
  matches.forEach((game) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'search-result';
    button.innerHTML = `<strong>${game.title}</strong><small>${game.installed ? 'Установлена' : 'В облаке'}</small>`;
    button.addEventListener('click', () => { searchDialog.close(); route('detail'); });
    searchResults.append(button);
  });
  if (!matches.length) searchResults.innerHTML = '<p>Ничего не найдено</p>';
}

function openSearch() {
  renderResults('');
  searchDialog.showModal();
  requestAnimationFrame(() => searchInput.focus());
}

document.querySelector('#search-button').addEventListener('click', openSearch);
searchInput.addEventListener('input', () => renderResults(searchInput.value));
document.addEventListener('keydown', (event) => {
  if (event.key === '/' && !event.metaKey && !event.ctrlKey && document.activeElement?.tagName !== 'INPUT') {
    event.preventDefault();
    openSearch();
  }
  if (event.key === 'Escape' && !searchDialog.open && location.hash === '#detail') route('library');
});

document.querySelector('#filter-button').addEventListener('click', (event) => {
  const button = event.currentTarget;
  const installedOnly = button.dataset.active !== 'true';
  button.dataset.active = String(installedOnly);
  button.firstChild.textContent = installedOnly ? 'Все игры ' : 'Установленные ';
  document.querySelectorAll('.game-card').forEach((card) => { card.hidden = installedOnly && card.dataset.installed !== 'true'; });
});

const initialRoute = location.hash.slice(1);
if (views.some((view) => view.dataset.view === initialRoute)) route(initialRoute);
