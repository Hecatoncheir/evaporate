const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

if (reduceMotion || !('IntersectionObserver' in window)) {
  document.querySelectorAll('.reveal').forEach((item) => item.classList.add('visible'));
} else {
  const observer = new IntersectionObserver(
    (entries) => entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    }),
    { threshold: 0.14 },
  );
  document.querySelectorAll('.reveal').forEach((item) => observer.observe(item));
}

document.querySelectorAll('.hardware-key').forEach((key) => {
  key.addEventListener('click', () => {
    document.querySelectorAll('.hardware-key').forEach((item) => item.classList.remove('active'));
    key.classList.add('active');
  });
});
