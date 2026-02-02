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
          <router-link to="/accounts">Accounts</router-link>
          <router-link to="/subscriptions">Subscriptions</router-link>
        </nav>
      </div>

      <div class="header-actions">
        <!-- Search Button -->
        <button class="search-trigger-btn" @click="isSearchModalVisible = true" title="Search Transactions">
          🔍
        </button>
        <ThemeSwitcher />
      </div>
    </header>

    <!-- Mobile Nav Menu -->
    <div class="mobile-nav" :class="{ 'is-open': isMenuOpen }">
      <nav>
        <router-link to="/" @click="closeMenu">Home</router-link>
        <router-link to="/all" @click="closeMenu">Transactions</router-link>
        <router-link to="/accounts" @click="closeMenu">Accounts</router-link>
        <router-link to="/subscriptions" @click="closeMenu">Subscriptions</router-link>
      </nav>
    </div>

    <main>
      <router-view />
    </main>
    
    <SearchModal 
      v-if="isSearchModalVisible" 
      @close="isSearchModalVisible = false" 
    />
  </div>
</template>

<script>
import ThemeSwitcher from './components/ThemeSwitcher.vue';
import SearchModal from './components/SearchModal.vue';
import { themeStore } from './themeStore.js'; // Import to initialize
import { onMounted, ref } from 'vue';
import axios from 'axios';
import { Capacitor, registerPlugin } from '@capacitor/core';
const SendIntent = registerPlugin('SendIntent');

import { useTransactions } from './composables/useTransactions';
import { useIntent } from './composables/useIntent';
import { logger } from './utils/logger';

export default {
  name: 'App',
  components: {
    ThemeSwitcher,
    SearchModal
  },
  setup() {
    const { fetchTransactions } = useTransactions();
    const { setIntentData } = useIntent();

    // 1. Initialize BaseURL IMMEDIATEY for remote logging to work
    if (Capacitor.isNativePlatform()) {
      axios.defaults.baseURL = 'http://100.69.155.6:5001';
      document.body.classList.add('is-native');
      logger.info('App setup started. BaseURL set to: ' + axios.defaults.baseURL, 'App.vue');

      // 2. Register intent listener immediately
      try {
        logger.info('SendIntent properties: ' + Object.keys(SendIntent).join(', '), 'App.vue');
        
        // A. Inspect retainedEventArguments
        if (SendIntent.retainedEventArguments && Array.isArray(SendIntent.retainedEventArguments) && SendIntent.retainedEventArguments.length > 0) {
          logger.info('Retained Arguments Found: ' + JSON.stringify(SendIntent.retainedEventArguments), 'App.vue');
          SendIntent.retainedEventArguments.forEach((arg) => {
            if (arg && arg.extras) {
              logger.info('Processing retained argument', 'App.vue');
              setIntentData(arg);
            }
          });
        }

        // B. Manual Poll for Intent (New Method)
        if (typeof SendIntent.getIntent === 'function') {
           logger.info('Polling manual getIntent...', 'App.vue');
           SendIntent.getIntent().then(result => {
             if (result && result.extras) {
               logger.info('Manual poll found intent data: ' + JSON.stringify(result), 'App.vue');
               setIntentData(result);
             } else {
               logger.info('Manual poll returned no data', 'App.vue');
             }
           }).catch(err => {
             logger.error('Manual poll failed: ' + err.message, 'App.vue');
           });
        } else {
           logger.warn('Manual poll method getIntent not found on SendIntent', 'App.vue');
        }

        // C. Register Listener for future events
        SendIntent.addListener('appSendActionIntent', (data) => {
          logger.info('Shared intent event Fired: ' + JSON.stringify(data), 'App.vue');
          if (data && data.extras) {
            setIntentData(data);
          }
        });
        
        logger.info('SendIntent listener registered successfully', 'App.vue');
      } catch (error) {
        logger.error('Error in SendIntent setup: ' + error.message, 'App.vue');
      }
    }

    // This ensures the theme logic runs when the app starts
    onMounted(async () => {
      // Load transactions globally so search works immediately
      await fetchTransactions();

      try {
        await axios.post('/api/subscriptions/check');
      } catch (error) {
        console.error("Error checking subscriptions:", error);
      }
    });

    const isMenuOpen = ref(false);
    const isSearchModalVisible = ref(false);
    
    const toggleMenu = () => {
      isMenuOpen.value = !isMenuOpen.value;
    };
    const closeMenu = () => {
      isMenuOpen.value = false;
    };

    return { themeStore, isMenuOpen, toggleMenu, closeMenu, isSearchModalVisible }
  }
}
</script>

<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

/* --- GLOBAL THEME VARIABLES --- */

/* Light Theme (Default) */
:root {
  --primary-color: #ea580c; /* Orange 600 */
  --secondary-color: #fb923c; /* Orange 400 */
  --accent-color: #f43f5e; /* Rose 500 */
  --background-color: #f3f4f6; /* Cool Gray 100 */
  --card-background: rgba(255, 255, 255, 0.8);
  --text-color: #111827; /* Gray 900 */
  --subtle-text-color: #6b7280; /* Gray 500 */
  --header-color: #ffffff;
  --border-color: rgba(229, 231, 235, 0.5); /* Gray 200 with opacity */
  --positive-color: #10b981; /* Emerald 500 */
  --negative-color: #ef4444; /* Red 500 */
  --glass-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.15);
  --glass-border: 1px solid rgba(255, 255, 255, 0.18);
}

/* Dark Theme */
html.dark {
  --primary-color: #f97316; /* Orange 500 */
  --secondary-color: #fb923c; /* Orange 400 */
  --accent-color: #fb7185; /* Rose 400 */
  --background-color: #0c0a09; /* Stone 950 - Warmer dark */
  --card-background: rgba(28, 25, 23, 0.7); /* Stone 900 with opacity */
  --text-color: #fafaf9; /* Stone 50 */
  --subtle-text-color: #a8a29e; /* Stone 400 */
  --header-color: #ffffff;
  --border-color: rgba(68, 64, 60, 0.5); /* Stone 700 with opacity */
  --positive-color: #34d399; /* Emerald 400 */
  --negative-color: #f87171; /* Red 400 */
  --glass-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
  --glass-border: 1px solid rgba(255, 255, 255, 0.05);
}

/* --- Global Styles & Resets --- */
body {
  margin: 0;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: var(--background-color);
  color: var(--text-color);
  transition: background-color 0.3s, color 0.3s;
  overflow-x: hidden; /* Prevent horizontal scroll globally */
}

.global-header {
  background: rgba(234, 88, 12, 0.85); /* Orange 600 with opacity */
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  color: var(--header-color);
  
  /* Safe area padding - Default Attempt */
  padding-top: max(1rem, env(safe-area-inset-top));
  padding-left: max(2rem, env(safe-area-inset-left));
  padding-right: max(2rem, env(safe-area-inset-right));
  padding-bottom: 1rem;

  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  position: sticky;
  top: 0;
  z-index: 100;
  border-bottom: var(--glass-border);
}

/* Force extra padding for native android/ios if safe-area is failing */
body.is-native .global-header {
  padding-top: calc(1rem + 30px); /* Add ~30px for status bar */
}

html.dark .global-header {
  background: rgba(28, 25, 23, 0.85); /* Stone 900 (Dark Orange/Brown) with opacity */
}

.logo {
  font-size: 1.75rem;
  margin: 0;
  font-weight: 800;
  letter-spacing: -0.025em;
  background: linear-gradient(to right, #ffffff, #ffedd5);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.logo-section {
  display: flex;
  align-items: center;
  gap: 2rem;
}

.main-nav {
  display: flex;
  gap: 2rem;
}

.main-nav a {
  color: var(--header-color);
  text-decoration: none;
  font-weight: 500;
  opacity: 0.8;
  transition: all 0.2s ease;
  position: relative;
}

.main-nav a::after {
  content: '';
  position: absolute;
  width: 0;
  height: 2px;
  bottom: -4px;
  left: 0;
  background-color: white;
  transition: width 0.3s ease;
}

.main-nav a:hover, .main-nav a.router-link-active {
  opacity: 1;
  text-decoration: none;
}

.main-nav a:hover::after, .main-nav a.router-link-active::after {
  width: 100%;
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
  top: 70px; /* Adjust based on header height */
  left: 0;
  width: 100%;
  background: rgba(234, 88, 12, 0.95);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  padding: 2rem 0;
  transform: translateY(-150%);
  transition: transform 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  z-index: 90;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  border-bottom: var(--glass-border);
}

body.is-native .mobile-nav {
  top: 97px; /* Adjust for native header height */
}

html.dark .mobile-nav {
  background: rgba(28, 25, 23, 0.95);
}

.mobile-nav.is-open {
  transform: translateY(0);
}

.mobile-nav nav {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2rem;
}

.mobile-nav a {
  color: var(--header-color);
  text-decoration: none;
  font-size: 1.25rem;
  font-weight: 600;
  transition: transform 0.2s;
}

.mobile-nav a:active {
  transform: scale(0.95);
}

/* Responsive Media Queries */
@media (max-width: 768px) {
  .desktop-nav {
    display: none;
  }

  .hamburger-btn {
    display: flex;
  }
  
  .global-header {
    padding: 0.8rem 1.5rem;
  }
}


main {
  /* This ensures the content doesn't get hidden behind the header */
  padding-top: 1rem;
  min-height: calc(100vh - 80px);
}

/* Global Button Styles */
button {
  font-family: 'Inter', sans-serif;
}

/* Global Button Styles */
.icon-btn {
  background: rgba(255, 255, 255, 0.5);
  border: 1px solid transparent;
  font-size: 1.1rem;
  cursor: pointer;
  padding: 0.5rem;
  border-radius: 8px;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
}

.icon-btn.edit { color: var(--primary-color); }
.icon-btn.delete { color: #ef4444; }

.icon-btn:hover {
  background-color: white;
  transform: scale(1.1);
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

html.dark .icon-btn {
  background: rgba(255, 255, 255, 0.1);
}

html.dark .icon-btn:hover {
  background: rgba(255, 255, 255, 0.2);
}

html.dark .icon-btn.edit {
  color: #f1f5f9; /* Slate 100 - Light gray/white for better contrast */
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.search-trigger-btn {
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 0.5rem;
  border-radius: 50%;
  transition: background-color 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
}

.search-trigger-btn:hover {
  background-color: rgba(255, 255, 255, 0.2);
}

@media (max-width: 768px) {
  .search-trigger-btn {
    margin-left: auto; /* Push to right on mobile */
    margin-right: 0.5rem;
  }
}

/* --- Global Modal Mobile Improvements --- */
@media (max-width: 600px) {
  .modal-content {
    padding: 1.25rem !important; /* Smaller padding */
    width: 92% !important;
    max-height: 92vh !important; /* Take up more vertical space */
    overflow-y: auto !important; /* Scrollable content */
    border-radius: 12px !important;
  }

  .modal-content h2 {
    font-size: 1.25rem !important;
    margin-bottom: 1rem !important;
  }

  .form-group {
    margin-bottom: 0.75rem !important;
  }

  .form-group label {
    font-size: 0.8rem !important;
    margin-bottom: 0.25rem !important;
  }

  .form-group input, 
  .form-group select {
    padding: 0.6rem !important;
    font-size: 0.9rem !important;
    border-radius: 6px !important;
  }

  .modal-actions {
    margin-top: 1.5rem !important;
    gap: 0.5rem !important;
  }

  .modal-actions button {
    padding: 0.6rem 1rem !important;
    font-size: 0.9rem !important;
    border-radius: 6px !important;
    flex: 1; /* Make buttons equal width */
  }

  .modal-overlay {
    padding: 10px !important; /* Prevent sticking to edges */
  }
}
</style>