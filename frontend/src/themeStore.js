import { reactive, watch } from 'vue';

// The color palette lives in CSS variables (see assets/main.css): :root/.dark
// hold the dark values and html.light overrides them, so toggling classes on
// <html> re-themes everything.
const applyTheme = (theme) => {
  const root = document.documentElement;
  root.classList.toggle('light', theme === 'light');
  root.classList.toggle('dark', theme !== 'light');
};

export const themeStore = reactive({
  // Dark is the design default
  theme: localStorage.getItem('theme') || 'dark',

  toggleTheme() {
    this.theme = this.theme === 'light' ? 'dark' : 'light';
  }
});

watch(() => themeStore.theme, (newTheme) => {
  localStorage.setItem('theme', newTheme);
  applyTheme(newTheme);
});

// Apply the initial theme class when the app loads
applyTheme(themeStore.theme);
