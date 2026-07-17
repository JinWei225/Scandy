<template>
  <button @click="themeStore.toggleTheme" class="text-primary-container hover:bg-on-surface/5 transition-colors duration-150 ease-in-out p-2 flex items-center justify-center" aria-label="Toggle theme">
    <span v-if="themeStore.theme === 'light'" class="material-symbols-outlined">dark_mode</span>
    <span v-else class="material-symbols-outlined">light_mode</span>
  </button>
</template>

<script>
import { themeStore } from '../themeStore.js';

export default {
  name: 'ThemeSwitcher',
  setup() {
    return {
      themeStore
    }
  }
}
</script>
