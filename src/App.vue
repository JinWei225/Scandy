<!-- In frontend/src/App.vue -->
<template>
  <div id="app">
    <!-- This global header will appear on every page -->
    <header class="global-header">
      <h1 class="logo">ScanDy</h1>
      <ThemeSwitcher />
    </header>
    <main>
      <router-view />
    </main>
  </div>
</template>

<script>
import ThemeSwitcher from './components/ThemeSwitcher.vue';
import { themeStore } from './themeStore.js'; // Import to initialize

export default {
  name: 'App',
  components: {
    ThemeSwitcher,
  },
  setup() {
    // This ensures the theme logic runs when the app starts
    return { themeStore }
  }
}
</script>

<style>
/* --- GLOBAL THEME VARIABLES --- */

/* Light Theme (Default) */
:root {
  --primary-color: #3b82f6;
  --secondary-color: #60a5fa;
  --background-color: #f8fafc; /* Very light gray */
  --card-background: #ffffff;   /* Pure white */
  --text-color: #1f2937;        /* Dark gray for text */
  --subtle-text-color: #6b7280; /* Lighter gray for subheadings */
  --header-color: #ffffff;      /* Text on primary color background */
  --border-color: #e5e7eb;      /* Light border */
  --positive-color: #16a34a;    /* Green */
  --negative-color: #dc2626;    /* Red */
}

/* Dark Theme */
html.dark {
  --primary-color: #3b82f6;
  --secondary-color: #60a5fa;
  --background-color: #111827; /* Very dark gray-blue */
  --card-background: #1f2937;   /* Darker gray-blue */
  --text-color: #f9fafb;        /* Off-white for text */
  --subtle-text-color: #9ca3af; /* Lighter gray for subheadings */
  --header-color: #ffffff;
  --border-color: #374151;      /* Dark border */
  --positive-color: #22c55e;    /* Brighter green for dark BG */
  --negative-color: #ef4444;    /* Brighter red for dark BG */
}

/* --- Global Styles & Resets --- */
body {
  margin: 0;
  background-color: var(--background-color);
  color: var(--text-color);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  transition: background-color 0.2s, color 0.2s;
}

.global-header {
  background-color: var(--primary-color);
  color: var(--header-color);
  padding: 0.8rem 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  margin-bottom: 0;
}

.logo {
  font-size: 1.5rem;
  margin: 0;
}

main {
  /* This ensures the content doesn't get hidden behind the header */
  padding-top: 1rem;
}
</style>