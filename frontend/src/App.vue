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
          <router-link to="/settings" class="font-label text-sm text-on-surface-variant uppercase tracking-widest hover:text-primary transition-colors h-full flex items-center border-b-2 border-transparent" active-class="text-primary border-primary">Settings</router-link>
        </nav>
      </div>
      <div class="flex items-center gap-2">
        <button @click="isSearchModalVisible = true" class="text-primary-container hover:bg-on-surface/5 transition-colors duration-150 ease-in-out p-2 flex items-center justify-center">
          <span class="material-symbols-outlined">search</span>
        </button>
      </div>
    </header>

    <!-- Auto-recorded subscription charges (see improvements.md 1.14) -->
    <div v-if="subscriptionNotice" class="w-full max-w-5xl mx-auto px-4 md:px-8 pt-4">
      <div class="bg-surface-container-high border border-outline-variant/30 flex items-start gap-3 px-4 py-3 relative">
        <div class="absolute left-0 top-0 bottom-0 w-[2px] bg-primary-container"></div>
        <span class="material-symbols-outlined text-primary-container text-[20px] mt-0.5">event_repeat</span>
        <p class="font-body text-sm text-on-surface flex-1">{{ subscriptionNotice }}</p>
        <button @click="subscriptionNotice = null" class="text-on-surface-variant hover:text-error transition-colors">
          <span class="material-symbols-outlined text-[20px]">close</span>
        </button>
      </div>
    </div>

    <!-- Main Content Canvas -->
    <main class="flex-grow flex flex-col pb-nav-safe md:pb-8 w-full max-w-5xl mx-auto px-4 md:px-8 pt-8">
      <router-view />
    </main>

    <!-- BottomNavBar (Mobile Only) -->
    <nav class="md:hidden bg-surface rounded-none border-t border-outline-variant/20 fixed bottom-0 left-0 w-full z-50 flex justify-around items-stretch px-2 bottom-nav-safe">
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
      <router-link to="/settings" class="flex flex-col items-center justify-center text-on-surface-variant opacity-60 h-full hover:text-primary transition-colors flex-1" active-class="text-primary-container opacity-100 border-t-2 border-primary-container -mt-[1px]">
        <span class="material-symbols-outlined mb-1 text-[24px]">settings</span>
        <span class="font-body font-bold text-[10px] tracking-[0.1em] uppercase">SETTINGS</span>
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
import { onMounted, ref } from 'vue';
import axios from 'axios';
import { Capacitor } from '@capacitor/core';

import { useIntent, SendIntent } from './composables/useIntent';
import { useTransactions } from './composables/useTransactions';
import { logger } from './utils/logger';

export default {
  name: 'App',
  components: {
    SearchModal
  },
  setup() {
    const { setIntentData } = useIntent();

    // 1. Initialize BaseURL IMMEDIATELY for remote logging to work.
    // The address is configurable via .env.production so a Tailscale IP
    // change doesn't require a code edit.
    if (Capacitor.isNativePlatform()) {
      axios.defaults.baseURL = process.env.VUE_APP_NATIVE_API_URL || 'http://100.69.155.6:5001';
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

    const subscriptionNotice = ref(null);
    // Only refetched when a charge was actually recorded, so this does not
    // reintroduce the double-fetch-on-mount removed in improvements.md §5.
    const { fetchTransactions } = useTransactions();

    onMounted(async () => {
      try {
        const response = await axios.post('/api/subscriptions/check');
        const created = response.data?.created || [];
        if (created.length > 0) {
          // Charges land silently otherwise — tell the user and show them in the ledger.
          const names = created.map(tx => (tx.description || '').replace(/^Subscription: /, '')).join(', ');
          const noun = created.length === 1 ? 'charge' : 'charges';
          subscriptionNotice.value = `Recorded ${created.length} subscription ${noun}: ${names}`;
          setTimeout(() => { subscriptionNotice.value = null; }, 10000);
          await fetchTransactions();
        }
      } catch (error) {
        console.error("Error checking subscriptions:", error);
      }
    });

    const isSearchModalVisible = ref(false);

    return { isSearchModalVisible, subscriptionNotice }
  }
}
</script>

<style>
body.is-native header {
  padding-top: calc(1.5rem + env(safe-area-inset-top));
  padding-bottom: 0.5rem;
}
/*
 * The bottom nav must GROW by the safe-area inset, not absorb it.
 * Tailwind's preflight sets box-sizing: border-box, so a fixed `h-20` plus
 * `padding-bottom: env(...)` keeps the total at 5rem and shrinks the content
 * box instead. On phones using 3-button navigation the inset is ~48px, which
 * leaves ~32px for a stack that needs ~44px — the icons then overflow above
 * the bar's painted background. Height and padding are set together here so
 * they can't drift apart again.
 */
.bottom-nav-safe {
  height: calc(5rem + env(safe-area-inset-bottom));
  padding-bottom: env(safe-area-inset-bottom);
}

/* Keep the last row of content clear of the nav, inset included. Scoped below
   the md breakpoint so it can't fight the `md:pb-8` on the same element. */
@media (max-width: 767px) {
  .pb-nav-safe {
    padding-bottom: calc(6rem + env(safe-area-inset-bottom));
  }
}
</style>
