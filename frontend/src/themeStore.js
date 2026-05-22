import { reactive, watch } from 'vue';

// 1. Create a reactive object to hold our state
export const themeStore = reactive({
  // 2. Initialize theme from localStorage or default to 'light'
  theme: localStorage.getItem('theme') || 'light',

  // 3. A method to toggle the theme
  toggleTheme() {
    this.theme = this.theme === 'light' ? 'dark' : 'light';
  }
});

// 4. Watch for changes in the theme and save it to localStorage
watch(() => themeStore.theme, (newTheme) => {
  localStorage.setItem('theme', newTheme);
  // Also update the class on the main <html> element
  document.documentElement.className = newTheme;
});

// 5. Apply the initial theme class when the app loads
document.documentElement.className = themeStore.theme;