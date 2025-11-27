<!-- In frontend/src/App.vue -->
<template>
  <div id="app">
    <!-- This global header will appear on every page -->
    <header class="global-header">
      <div class="logo-section">
        <!-- Mobile Hamburger -->
        <button class="hamburger-btn" @click="toggleMenu" aria-label="Toggle menu">
          <span class="hamburger-line"></span>
          <span class="hamburger-line"></span>
          <span class="hamburger-line"></span>
        </button>

        <h1 class="logo">ScanDy</h1>
        
        <!-- Desktop Nav -->
        <nav class="main-nav desktop-nav">
          <router-link to="/">Home</router-link>
          <router-link to="/all">Transactions</router-link>
          <router-link to="/subscriptions">Subscriptions</router-link>
        </nav>
      </div>
      <ThemeSwitcher />
    </header>

    <!-- Mobile Nav Menu -->
    <div class="mobile-nav" :class="{ 'is-open': isMenuOpen }">
      <nav>
        <router-link to="/" @click="closeMenu">Home</router-link>
        <router-link to="/all" @click="closeMenu">Transactions</router-link>
        <router-link to="/subscriptions" @click="closeMenu">Subscriptions</router-link>
      </nav>
    </div>

    <main>
      <router-view />
    </main>
  </div>
</template>

<script>
import ThemeSwitcher from './components/ThemeSwitcher.vue';
import { themeStore } from './themeStore.js'; // Import to initialize
import { onMounted, ref } from 'vue';
import axios from 'axios';

export default {
  name: 'App',
  components: {
    ThemeSwitcher,
  },
  setup() {
    // This ensures the theme logic runs when the app starts
    onMounted(async () => {
      try {
        await axios.post('/api/subscriptions/check');
      } catch (error) {
        console.error("Error checking subscriptions:", error);
      }
    });

    const isMenuOpen = ref(false);
    const toggleMenu = () => {
      isMenuOpen.value = !isMenuOpen.value;
    };
    const closeMenu = () => {
      isMenuOpen.value = false;
    };

    return { themeStore, isMenuOpen, toggleMenu, closeMenu }
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

.logo-section {
  display: flex;
  align-items: center;
  gap: 2rem;
}

.main-nav {
  display: flex;
  gap: 1.5rem;
}

.main-nav a {
  color: var(--header-color);
  text-decoration: none;
  font-weight: 500;
  opacity: 0.9;
  transition: opacity 0.2s;
}

.main-nav a:hover, .main-nav a.router-link-active {
  opacity: 1;
  text-decoration: underline;
}

/* Hamburger Button */
.hamburger-btn {
  display: none;
  flex-direction: column;
  justify-content: space-around;
  width: 30px;
  height: 25px;
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 0;
  z-index: 20;
}

.hamburger-line {
  width: 100%;
  height: 3px;
  background-color: var(--header-color);
  border-radius: 2px;
  transition: all 0.3s linear;
}

/* Mobile Nav Container */
.mobile-nav {
  position: fixed;
  top: 60px; /* Adjust based on header height */
  left: 0;
  width: 100%;
  background-color: var(--primary-color);
  padding: 1rem 0;
  transform: translateY(-150%);
  transition: transform 0.3s ease-in-out;
  z-index: 10;
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

.mobile-nav.is-open {
  transform: translateY(0);
}

.mobile-nav nav {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5rem;
}

.mobile-nav a {
  color: var(--header-color);
  text-decoration: none;
  font-size: 1.2rem;
  font-weight: 500;
}

/* Responsive Media Queries */
@media (max-width: 768px) {
  .desktop-nav {
    display: none;
  }

  .hamburger-btn {
    display: flex;
  }
}


main {
  /* This ensures the content doesn't get hidden behind the header */
  padding-top: 1rem;
}
</style>