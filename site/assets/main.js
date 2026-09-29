document.getElementById('year').textContent = new Date().getFullYear();
const copyButton = document.getElementById('copy-email');
const copyStatus = document.getElementById('copy-status');
copyButton.addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText('glebocki.rg@gmail.com');
    copyStatus.textContent = 'Email copied.';
  } catch {
    copyStatus.textContent = 'Select the email address to copy it, or click to open your email app.';
  }
});

// Content is visible by default; enhance only blocks below the initial viewport.
const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
if ('IntersectionObserver' in window && !motionPreference.matches) {
  const blocks = document.querySelectorAll(
    '.section-heading, .project, .about-grid > div, .credentials > .eyebrow, .credentials-grid > *, .contact .wrap'
  );
  const reveal = (block) => {
    block.classList.remove('reveal-pending');
    observer.unobserve(block);
  };
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) reveal(entry.target);
    });
  }, { threshold: 0, rootMargin: '0px 0px -32px 0px' });

  blocks.forEach((block) => {
    if (block.getBoundingClientRect().top < window.innerHeight) return;
    block.classList.add('scroll-reveal', 'reveal-pending');
    observer.observe(block);
  });

  // Keyboard navigation must never land on visually hidden content.
  document.addEventListener('focusin', (event) => {
    const block = event.target.closest('.reveal-pending');
    if (block) reveal(block);
  });
  motionPreference.addEventListener('change', (event) => {
    if (event.matches) {
      blocks.forEach(reveal);
      observer.disconnect();
    }
  });
}
