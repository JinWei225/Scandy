<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex justify-center items-center p-4" @click.self="$emit('close')">
    <div class="bg-surface border border-outline-variant/30 w-full max-w-2xl p-8 relative max-h-[90vh] flex flex-col">
      <div class="flex justify-between items-start mb-6">
        <h2 class="font-headline text-2xl text-primary-container uppercase tracking-tight">{{ title }}</h2>
        <button class="text-on-surface-variant hover:text-error transition-colors" @click="$emit('close')">
          <span class="material-symbols-outlined text-[24px]">close</span>
        </button>
      </div>
      <div class="overflow-y-auto flex-1">
        <slot></slot>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'BaseModal',
  props: {
    title: { type: String, required: true }
  },
  emits: ['close']
}
</script>

<style scoped>
/* Removed old CSS, replaced with Tailwind classes */
</style>