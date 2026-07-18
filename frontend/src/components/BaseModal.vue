<template>
  <div class="fixed inset-0 bg-surface/90 backdrop-blur-md z-[100] flex justify-center items-center modal-inset-safe" @click.self="$emit('close')">
    <div class="bg-surface border border-outline-variant/30 w-full p-5 sm:p-8 relative max-h-full flex flex-col" :class="maxWidthClass">
      <div class="flex justify-between items-start mb-4 sm:mb-6">
        <h2 class="font-headline text-xl sm:text-2xl text-primary-container uppercase tracking-tight">{{ title }}</h2>
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
// Full class names, not interpolated — Tailwind only sees literals when scanning.
const MAX_WIDTHS = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-2xl'
}

export default {
  name: 'BaseModal',
  props: {
    title: { type: String, required: true },
    size: {
      type: String,
      default: 'lg',
      validator: (value) => value in MAX_WIDTHS
    }
  },
  emits: ['close'],
  computed: {
    maxWidthClass() {
      return MAX_WIDTHS[this.size]
    }
  },
  mounted() {
    document.addEventListener('keydown', this.onKeydown)
  },
  unmounted() {
    document.removeEventListener('keydown', this.onKeydown)
  },
  methods: {
    onKeydown(event) {
      if (event.key === 'Escape') this.$emit('close')
    }
  }
}
</script>

<style scoped>
/* Removed old CSS, replaced with Tailwind classes */
</style>
