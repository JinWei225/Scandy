<template>
  <div id="app" class="flex flex-col min-h-screen">
    <!-- TopAppBar -->
    <header class="bg-surface rounded-none border-b border-outline-variant/20 flex justify-between items-center w-full px-6 min-h-[4rem] py-4 md:py-0 sticky top-0 z-50">
      <div class="flex items-center gap-4">
        <h1 class="text-2xl font-black text-primary-container tracking-tighter font-headline uppercase m-0">SCANDY</h1>
        
        <!-- Desktop Nav -->
        <nav class="hidden md:flex gap-6 ml-8 h-full items-center">
          <router-link to="/" class="font-label text-sm text-on-surface-variant uppercase tracking-widest hover:text-primary transition-colors h-full flex items-center border-b-2 border-transparent" active-class="text-primary border-primary">Home</router-link>
          <router-link to="/all" class="font-label text-sm text-on-surface-variant uppercase tracking-widest hover:text-primary transition-colors h-full flex items-center border-b-2 border-transparent" active-class="text-primary border-primary">Summary</router-link>
          <router-link to="/accounts" class="font-label text-sm text-on-surface-variant uppercase tracking-widest hover:text-primary transition-colors h-full flex items-center border-b-2 border-transparent" active-class="text-primary border-primary">Vault</router-link>
          <router-link to="/subscriptions" class="font-label text-sm text-on-surface-variant uppercase tracking-widest hover:text-primary transition-colors h-full flex items-center border-b-2 border-transparent" active-class="text-primary border-primary">Recurring</router-link>
        </nav>
      </div>
      <div class="flex items-center gap-2">
        <button @click="isSearchModalVisible = true" class="text-primary-container hover:bg-white/5 transition-colors duration-150 ease-in-out p-2 flex items-center justify-center">
          <span class="material-symbols-outlined">search</span>
        </button>
      </div>
    </header>

    <!-- Main Content Canvas -->
    <main class="flex-grow flex flex-col pb-24 md:pb-8 w-full max-w-5xl mx-auto px-4 md:px-8 pt-8">
      <router-view />
    </main>

    <!-- BottomNavBar (Mobile Only) -->
    <nav class="md:hidden bg-surface rounded-none border-t border-outline-variant/20 fixed bottom-0 left-0 w-full z-50 h-20 flex justify-around items-stretch px-2 pb-safe">
      <router-link to="/" class="flex flex-col items-center justify-center text-on-surface-variant opacity-60 h-full hover:text-primary transition-colors flex-1" active-class="text-primary-container opacity-100 border-t-2 border-primary-container -mt-[1px]">
        <span class="material-symbols-outlined mb-1 text-[24px]">home</span>
        <span class="font-body font-bold text-[10px] tracking-[0.1em] uppercase">HOME</span>
      </router-link>
      <router-link to="/all" class="flex flex-col items-center justify-center text-on-surface-variant opacity-60 h-full hover:text-primary transition-colors flex-1" active-class="text-primary-container opacity-100 border-t-2 border-primary-container -mt-[1px]">
        <span class="material-symbols-outlined mb-1 text-[24px]">grid_view</span>
        <span class="font-body font-bold text-[10px] tracking-[0.1em] uppercase">SUMMARY</span>
      </router-link>
      <router-link to="/accounts" class="flex flex-col items-center justify-center text-on-surface-variant opacity-60 h-full hover:text-primary transition-colors flex-1" active-class="text-primary-container opacity-100 border-t-2 border-primary-container -mt-[1px]">
        <span class="material-symbols-outlined mb-1 text-[24px]">account_balance_wallet</span>
        <span class="font-body font-bold text-[10px] tracking-[0.1em] uppercase">VAULT</span>
      </router-link>
      <router-link to="/subscriptions" class="flex flex-col items-center justify-center text-on-surface-variant opacity-60 h-full hover:text-primary transition-colors flex-1" active-class="text-primary-container opacity-100 border-t-2 border-primary-container -mt-[1px]">
        <span class="material-symbols-outlined mb-1 text-[24px]">event_repeat</span>
        <span class="font-body font-bold text-[10px] tracking-[0.1em] uppercase">RECURRING</span>
      </router-link>
    </nav>
    
    <SearchModal 
      v-if="isSearchModalVisible" 
      @close="isSearchModalVisible = false" 
    />
  </div>
</template>

<script>
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
    SearchModal
  },
  setup() {
    const { fetchTransactions } = useTransactions();
    const { setIntentData } = useIntent();

    // 1. Initialize BaseURL IMMEDIATEY for remote logging to work
    if (Capacitor.isNativePlatform()) {
      axios.defaults.baseURL = 'http://100.69.155.6:5001';
      document.body.classList.add('is-native');
      logger.info('App started', 'App');

      // 2. Register intent listener immediately
      try {
        if (SendIntent.retainedEventArguments && Array.isArray(SendIntent.retainedEventArguments) && SendIntent.retainedEventArguments.length > 0) {
          SendIntent.retainedEventArguments.forEach((arg) => {
            if (arg && arg.extras) {
              logger.info('Retained intent processed', 'App');
              setIntentData(arg);
            }
          });
        }

        if (typeof SendIntent.getIntent === 'function') {
           SendIntent.getIntent().then(result => {
             if (result && result.extras) {
               logger.info('Polled intent processed', 'App');
               setIntentData(result);
             }
           }).catch(err => {
             logger.error('Poll failed: ' + err.message, 'App');
           });
        }

        SendIntent.addListener('appSendActionIntent', (data) => {
          logger.info('Intent fired', 'App');
          if (data && data.extras) {
            setIntentData(data);
          }
        });
        
        logger.info('Listener active', 'App');
      } catch (error) {
        logger.error('Intent setup err', 'App');
      }
    }

    onMounted(async () => {
      // Force dark mode class on HTML per new design
      document.documentElement.classList.add('dark');
      
      await fetchTransactions();

      try {
        await axios.post('/api/subscriptions/check');
      } catch (error) {
        console.error("Error checking subscriptions:", error);
      }
    });

    const isSearchModalVisible = ref(false);

    return { themeStore, isSearchModalVisible }
  }
}
</script>

<style>
/* Remove old global styles, let Tailwind handle it */
body.is-native header {
  padding-top: calc(1.5rem + env(safe-area-inset-top));
  padding-bottom: 0.5rem;
}
.pb-safe {
  padding-bottom: env(safe-area-inset-bottom);
}
</style>
